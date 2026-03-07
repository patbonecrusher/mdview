use pulldown_cmark::{CodeBlockKind, Event, Options, Parser, Tag, TagEnd};

use crate::config::Config;
use crate::plantuml;

pub fn render_to_html(markdown: &str, base_dir: &str, config: &Config) -> String {
    let options = Options::ENABLE_TABLES
        | Options::ENABLE_FOOTNOTES
        | Options::ENABLE_STRIKETHROUGH
        | Options::ENABLE_TASKLISTS;

    let parser = Parser::new_ext(markdown, options);

    let mut html_output = String::new();
    let mut in_code_block = false;
    let mut code_block_lang = String::new();
    let mut code_block_content = String::new();

    let mut events: Vec<Event> = Vec::new();

    for event in parser {
        match &event {
            Event::Start(Tag::CodeBlock(kind)) => {
                in_code_block = true;
                code_block_content.clear();
                code_block_lang = match kind {
                    CodeBlockKind::Fenced(lang) => lang.to_string(),
                    CodeBlockKind::Indented => String::new(),
                };
                continue;
            }
            Event::End(TagEnd::CodeBlock) => {
                in_code_block = false;
                let rendered = render_code_block(&code_block_lang, &code_block_content, config);
                events.push(Event::Html(rendered.into()));
                continue;
            }
            Event::Text(text) if in_code_block => {
                code_block_content.push_str(text);
                continue;
            }
            Event::Start(Tag::Link { dest_url, title, .. }) => {
                let url = dest_url.to_string();
                let title = title.to_string();
                if url.ends_with(".md") {
                    let resolved = resolve_md_link(&url, base_dir);
                    let title_attr = if title.is_empty() {
                        String::new()
                    } else {
                        format!(" title=\"{}\"", title)
                    };
                    events.push(Event::Html(
                        format!("<a href=\"mdview://open?file={}\"{}>" , resolved, title_attr).into(),
                    ));
                    continue;
                }
            }
            Event::Start(Tag::Image { dest_url, title, .. }) => {
                let url = dest_url.to_string();
                let title = title.to_string();
                if url.ends_with(".svg") {
                    let resolved = resolve_path(&url, base_dir);
                    if let Ok(svg_content) = std::fs::read_to_string(&resolved) {
                        events.push(Event::Html(
                            format!("<div class=\"svg-container\" title=\"{}\">{}</div>", title, svg_content).into(),
                        ));
                        // skip the image end tag
                        continue;
                    }
                }
            }
            _ => {}
        }
        events.push(event);
    }

    pulldown_cmark::html::push_html(&mut html_output, events.into_iter());
    wrap_html(&html_output, config)
}

fn render_code_block(lang: &str, content: &str, config: &Config) -> String {
    match lang {
        "mermaid" => {
            format!(
                "<div class=\"mermaid\">\n{}\n</div>",
                content
            )
        }
        "plantuml" | "puml" => {
            let themed = format!("{}{}", config.theme.plantuml_theme(), content);
            let encoded = plantuml::encode(&themed);
            format!(
                "<div class=\"plantuml\"><img src=\"https://www.plantuml.com/plantuml/svg/{}\" alt=\"PlantUML diagram\" /></div>",
                encoded
            )
        }
        "svg" => {
            format!("<div class=\"svg-container\">{}</div>", content)
        }
        _ => {
            let escaped = html_escape(content);
            if lang.is_empty() {
                format!("<pre><code>{}</code></pre>", escaped)
            } else {
                format!(
                    "<pre><code class=\"language-{}\">{}</code></pre>",
                    lang, escaped
                )
            }
        }
    }
}

fn resolve_md_link(url: &str, base_dir: &str) -> String {
    let path = std::path::Path::new(base_dir).join(url);
    path.to_string_lossy().to_string()
}

fn resolve_path(url: &str, base_dir: &str) -> String {
    let path = std::path::Path::new(base_dir).join(url);
    path.to_string_lossy().to_string()
}

fn html_escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

fn wrap_html(body: &str, config: &Config) -> String {
    let hljs_style = config.theme.hljs_style();
    let mermaid_theme = config.theme.mermaid_theme();
    let mermaid_init = if mermaid_theme == "auto" {
        "const mermaidTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default';\nmermaid.initialize({ startOnLoad: true, theme: mermaidTheme });".to_string()
    } else {
        format!("mermaid.initialize({{ startOnLoad: true, theme: '{}' }});", mermaid_theme)
    };

    let hljs_link = if hljs_style == "auto" {
        r#"<link rel="stylesheet" media="(prefers-color-scheme: light)" href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release/build/styles/github.min.css">
<link rel="stylesheet" media="(prefers-color-scheme: dark)" href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release/build/styles/github-dark.min.css">"#.to_string()
    } else {
        format!(
            r#"<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release/build/styles/{}.min.css">"#,
            hljs_style
        )
    };

    format!(
        r#"<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
{css}
{theme_css}
</style>
{hljs_link}
<script src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release/build/highlight.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
<script>
{mermaid_init}
</script>
</head>
<body>
<div class="container">
{body}
</div>
<script>
hljs.highlightAll();
if (typeof mermaid !== 'undefined') {{
    mermaid.contentLoaded();
}}
</script>
</body>
</html>"#,
        css = include_str!("style.css"),
        theme_css = config.to_css_overrides(),
        hljs_link = hljs_link,
        mermaid_init = mermaid_init,
        body = body
    )
}
