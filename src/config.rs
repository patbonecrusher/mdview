use std::path::PathBuf;

#[derive(Clone)]
pub struct Config {
    pub theme: Theme,
    pub font_family: String,
    pub font_size: u32,
    pub code_font_family: String,
    pub code_font_size: u32,
}

#[derive(Clone, PartialEq)]
pub enum Theme {
    Light,
    Dark,
    Auto,
    Modest,
    ModestDark,
}

impl Theme {
    pub fn name(&self) -> &str {
        match self {
            Theme::Auto => "auto",
            Theme::Light => "light",
            Theme::Dark => "dark",
            Theme::Modest => "modest",
            Theme::ModestDark => "modest-dark",
        }
    }

    pub fn from_name(name: &str) -> Self {
        match name {
            "light" => Theme::Light,
            "dark" => Theme::Dark,
            "modest" => Theme::Modest,
            "modest-dark" => Theme::ModestDark,
            _ => Theme::Auto,
        }
    }

    pub fn theme_css(&self) -> &str {
        match self {
            Theme::Modest => include_str!("themes/modest.css"),
            Theme::ModestDark => include_str!("themes/modest_dark.css"),
            _ => "",
        }
    }

    pub fn hljs_style(&self) -> &str {
        match self {
            Theme::Dark | Theme::ModestDark => "github-dark",
            Theme::Light | Theme::Modest => "github",
            Theme::Auto => "auto",
        }
    }

    pub fn mermaid_theme(&self) -> &str {
        match self {
            Theme::Dark | Theme::ModestDark => "dark",
            Theme::Light | Theme::Modest => "default",
            Theme::Auto => "auto",
        }
    }

    pub fn plantuml_theme(&self) -> &str {
        match self {
            Theme::Dark | Theme::ModestDark => "!theme cyborg-outline\n",
            _ => "",
        }
    }
}

impl Default for Config {
    fn default() -> Self {
        Self {
            theme: Theme::Auto,
            font_family: String::new(),
            font_size: 16,
            code_font_family: String::new(),
            code_font_size: 14,
        }
    }
}

impl Config {
    pub fn load() -> Self {
        let path = config_path();
        if path.exists() {
            if let Ok(content) = std::fs::read_to_string(&path) {
                return Self::parse(&content);
            }
        }
        Self::default()
    }

    pub fn save(&self) {
        let dir = dirs_path();
        let _ = std::fs::create_dir_all(&dir);
        let path = config_path();
        let content = format!(
            "theme = {}\nfont_family = {}\nfont_size = {}\ncode_font_family = {}\ncode_font_size = {}\n",
            self.theme.name(),
            self.font_family,
            self.font_size,
            self.code_font_family,
            self.code_font_size,
        );
        let _ = std::fs::write(path, content);
    }

    fn parse(content: &str) -> Self {
        let mut config = Self::default();
        for line in content.lines() {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            if let Some((key, value)) = line.split_once('=') {
                let key = key.trim();
                let value = value.trim();
                match key {
                    "theme" => config.theme = Theme::from_name(value),
                    "font_family" => config.font_family = value.to_string(),
                    "font_size" => {
                        if let Ok(v) = value.parse() {
                            config.font_size = v;
                        }
                    }
                    "code_font_family" => config.code_font_family = value.to_string(),
                    "code_font_size" => {
                        if let Ok(v) = value.parse() {
                            config.code_font_size = v;
                        }
                    }
                    _ => {}
                }
            }
        }
        config
    }

    pub fn to_css_overrides(&self) -> String {
        let mut css = String::new();

        // Theme-specific CSS
        match &self.theme {
            Theme::Light => {
                css.push_str(":root {\n");
                css.push_str("  --bg: #ffffff; --fg: #1a1a2e; --code-bg: #f4f4f8;\n");
                css.push_str("  --border: #e0e0e0; --link: #2563eb; --heading: #0f172a;\n");
                css.push_str("  --blockquote-border: #3b82f6; --blockquote-bg: #eff6ff;\n");
                css.push_str("}\n");
            }
            Theme::Dark => {
                css.push_str(":root {\n");
                css.push_str("  --bg: #08131c; --fg: #e2e8f0; --code-bg: #0f1f2e;\n");
                css.push_str("  --border: #1a3044; --link: #60a5fa; --heading: #f1f5f9;\n");
                css.push_str("  --blockquote-border: #3b82f6; --blockquote-bg: #0c1a28;\n");
                css.push_str("}\n");
            }
            Theme::Modest | Theme::ModestDark => {
                css.push_str(self.theme.theme_css());
            }
            Theme::Auto => {}
        }

        // Font overrides (only if explicitly set)
        if !self.font_family.is_empty() {
            css.push_str(&format!("body {{ font-family: {}; }}\n", self.font_family));
        }
        if self.font_size != 16 {
            css.push_str(&format!("body {{ font-size: {}px; }}\n", self.font_size));
        }
        if !self.code_font_family.is_empty() {
            css.push_str(&format!(
                "code, pre code {{ font-family: {}; }}\n",
                self.code_font_family
            ));
        }
        if self.code_font_size != 14 {
            css.push_str(&format!(
                "code, pre code {{ font-size: {}px; }}\n",
                self.code_font_size
            ));
        }

        css
    }
}

fn config_path() -> PathBuf {
    dirs_path().join("config")
}

fn dirs_path() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".into());
    PathBuf::from(home).join(".config").join("mdviewer")
}
