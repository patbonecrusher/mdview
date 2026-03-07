use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use muda::{AboutMetadata, Menu, MenuEvent, MenuItem, PredefinedMenuItem, Submenu};
use notify::RecommendedWatcher;
use tao::event::{Event, WindowEvent};
use tao::event_loop::{ControlFlow, EventLoopBuilder};
use tao::window::WindowBuilder;
use wry::WebViewBuilder;

use crate::config::{Config, Theme};
use crate::markdown;
use crate::watcher;

const ICON_PNG: &[u8] = include_bytes!("../assets/mdview.iconset/icon_256x256.png");
const WELCOME_LOGO: &[u8] = include_bytes!("../assets/welcome_logo.png");

enum UserEvent {
    FileChanged,
    Navigate(PathBuf),
    MenuEvent(MenuEvent),
    ApplySettings(String),
}

fn title_for_file(file: &Option<PathBuf>) -> String {
    match file {
        Some(f) => format!(
            "MdViewer - {}",
            f.file_name().unwrap_or_default().to_string_lossy()
        ),
        None => "MdViewer".to_string(),
    }
}

fn welcome_html(_config: &Config) -> String {
    use base64::Engine;
    let logo_b64 = base64::engine::general_purpose::STANDARD.encode(WELCOME_LOGO);

    format!(
        r#"<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
html, body {{
    height: 100%;
}}
body {{
    background: #08131c;
    color: #f5f5f7;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    min-height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
}}
.welcome {{
    text-align: center;
}}
.welcome img {{
    width: 420px;
    height: auto;
    margin-bottom: 2rem;
    margin-left: -34px;
}}
.welcome h1 {{
    font-size: 1.6rem;
    font-weight: 600;
    letter-spacing: -0.02em;
    margin-bottom: 0.6rem;
}}
.welcome p {{
    font-size: 0.95rem;
    color: #86868b;
    line-height: 1.6;
}}
.welcome kbd {{
    background: #2c2c2e;
    border: 1px solid #3a3a3c;
    border-radius: 4px;
    padding: 0.1em 0.4em;
    font-family: inherit;
    font-size: 0.85em;
}}
</style>
</head>
<body>
<div class="welcome">
    <img src="data:image/png;base64,{logo}" alt="MdViewer">
    <h1>Welcome to MdViewer</h1>
    <p>Open a file with <kbd>Cmd</kbd> + <kbd>O</kbd> or drop one on the dock icon.<br>
    From the terminal: <kbd>mdview myfile.md</kbd></p>
</div>
</body>
</html>"#,
        logo = logo_b64
    )
}

pub fn run(file: Option<PathBuf>, config: Config) {
    let config = Arc::new(Mutex::new(config));

    // Set dock icon before event loop / window creation
    set_macos_dock_icon();

    let event_loop = EventLoopBuilder::<UserEvent>::with_user_event()
        .build();

    // Build macOS menu bar
    let menu_bar = Menu::new();

    // App menu (MdViewer)
    let app_menu = Submenu::new("MdViewer", true);
    let settings_item = MenuItem::with_id(
        "settings",
        "Settings...",
        true,
        Some("CmdOrCtrl+,".parse().unwrap()),
    );
    let _ = app_menu.append_items(&[
        &PredefinedMenuItem::about(None, Some(AboutMetadata {
            name: Some("MdViewer".into()),
            version: Some(env!("CARGO_PKG_VERSION").into()),
            comments: Some("A markdown viewer with diagram support".into()),
            ..Default::default()
        })),
        &PredefinedMenuItem::separator(),
        &settings_item,
        &PredefinedMenuItem::separator(),
        &PredefinedMenuItem::services(None),
        &PredefinedMenuItem::separator(),
        &PredefinedMenuItem::hide(None),
        &PredefinedMenuItem::hide_others(None),
        &PredefinedMenuItem::show_all(None),
        &PredefinedMenuItem::separator(),
        &PredefinedMenuItem::quit(None),
    ]);

    // File menu
    let file_menu = Submenu::new("File", true);
    let open_item = MenuItem::with_id(
        "open",
        "Open...",
        true,
        Some("CmdOrCtrl+O".parse().unwrap()),
    );
    let _ = file_menu.append_items(&[
        &open_item,
        &PredefinedMenuItem::separator(),
        &PredefinedMenuItem::close_window(None),
    ]);

    // Edit menu
    let edit_menu = Submenu::new("Edit", true);
    let _ = edit_menu.append_items(&[
        &PredefinedMenuItem::undo(None),
        &PredefinedMenuItem::redo(None),
        &PredefinedMenuItem::separator(),
        &PredefinedMenuItem::cut(None),
        &PredefinedMenuItem::copy(None),
        &PredefinedMenuItem::paste(None),
        &PredefinedMenuItem::select_all(None),
    ]);

    // View menu
    let view_menu = Submenu::new("View", true);
    let reload_item = MenuItem::with_id(
        "reload",
        "Reload",
        true,
        Some("CmdOrCtrl+R".parse().unwrap()),
    );
    let _ = view_menu.append_items(&[
        &reload_item,
        &PredefinedMenuItem::separator(),
        &PredefinedMenuItem::fullscreen(None),
    ]);

    // Window menu
    let window_menu = Submenu::new("Window", true);
    let _ = window_menu.append_items(&[
        &PredefinedMenuItem::minimize(None),
        &PredefinedMenuItem::maximize(None),
        &PredefinedMenuItem::separator(),
        &PredefinedMenuItem::bring_all_to_front(None),
    ]);

    let _ = menu_bar.append_items(&[
        &app_menu,
        &file_menu,
        &edit_menu,
        &view_menu,
        &window_menu,
    ]);

    menu_bar.init_for_nsapp();

    // Forward menu events to the event loop
    let menu_proxy = event_loop.create_proxy();
    MenuEvent::set_event_handler(Some(move |event| {
        let _ = menu_proxy.send_event(UserEvent::MenuEvent(event));
    }));

    let window_icon = load_window_icon();
    let window = WindowBuilder::new()
        .with_title(title_for_file(&file))
        .with_inner_size(tao::dpi::LogicalSize::new(960.0, 800.0))
        .with_window_icon(window_icon)
        .build(&event_loop)
        .expect("Failed to create window");

    let current_file: Arc<Mutex<Option<PathBuf>>> = Arc::new(Mutex::new(file.clone()));
    let current_file_nav = current_file.clone();
    let current_file_reload = current_file.clone();
    let current_file_settings = current_file.clone();
    let in_settings = Arc::new(Mutex::new(false));
    let in_settings_nav = in_settings.clone();
    let in_settings_ipc = in_settings.clone();

    let html = match &file {
        Some(f) => load_and_render(f, &config.lock().unwrap()),
        None => welcome_html(&config.lock().unwrap()),
    };

    let nav_proxy = event_loop.create_proxy();
    let ipc_proxy = event_loop.create_proxy();

    let webview = WebViewBuilder::new()
        .with_html(&html)
        .with_navigation_handler(move |uri| {
            if *in_settings_nav.lock().unwrap() {
                return true;
            }
            if let Some(file_param) = uri.strip_prefix("mdview://open?file=") {
                let decoded = urlencoding_decode(file_param);
                let path = PathBuf::from(decoded);
                let _ = nav_proxy.send_event(UserEvent::Navigate(path));
                return false;
            }
            true
        })
        .with_ipc_handler(move |msg| {
            let body = msg.body();
            if body.starts_with("settings:") {
                let json = &body["settings:".len()..];
                let _ = ipc_proxy.send_event(UserEvent::ApplySettings(json.to_string()));
            }
        })
        .build(&window)
        .expect("Failed to create webview");

    // Start file watcher if we have a file
    let _watcher: Option<(RecommendedWatcher, std::sync::mpsc::Receiver<()>)> =
        file.as_ref().map(|f| {
            let watch_proxy = event_loop.create_proxy();
            let (w, rx) = watcher::watch(f);
            std::thread::spawn(move || {
                while rx.recv().is_ok() {
                    let _ = watch_proxy.send_event(UserEvent::FileChanged);
                    std::thread::sleep(std::time::Duration::from_millis(200));
                    while rx.try_recv().is_ok() {}
                }
            });
            (w, std::sync::mpsc::channel().1) // keep watcher alive
        });

    let open_id = open_item.id().clone();
    let reload_id = reload_item.id().clone();
    let settings_id = settings_item.id().clone();

    event_loop.run(move |event, _, control_flow| {
        *control_flow = ControlFlow::Wait;

        match event {
            Event::UserEvent(UserEvent::FileChanged) => {
                if *in_settings.lock().unwrap() {
                    return;
                }
                let f = current_file.lock().unwrap().clone();
                if let Some(f) = &f {
                    let html = load_and_render(f, &config.lock().unwrap());
                    let _ = webview.load_html(&html);
                }
            }
            Event::UserEvent(UserEvent::Navigate(path)) => {
                if path.exists() {
                    let file_opt = Some(path.clone());
                    *current_file_nav.lock().unwrap() = file_opt.clone();
                    let html = load_and_render(&path, &config.lock().unwrap());
                    let _ = webview.load_html(&html);
                    window.set_title(&title_for_file(&file_opt));
                } else {
                    eprintln!("File not found: {}", path.display());
                }
            }
            Event::UserEvent(UserEvent::MenuEvent(event)) => {
                if event.id == open_id {
                    let dialog = rfd::FileDialog::new()
                        .add_filter("Markdown", &["md", "markdown"])
                        .set_title("Open Markdown File");
                    if let Some(path) = dialog.pick_file() {
                        let path = std::fs::canonicalize(&path).unwrap_or(path);
                        let file_opt = Some(path.clone());
                        *current_file_nav.lock().unwrap() = file_opt.clone();
                        let html = load_and_render(&path, &config.lock().unwrap());
                        let _ = webview.load_html(&html);
                        window.set_title(&title_for_file(&file_opt));
                        *in_settings_ipc.lock().unwrap() = false;
                    }
                } else if event.id == reload_id {
                    *in_settings_ipc.lock().unwrap() = false;
                    let f = current_file_reload.lock().unwrap().clone();
                    if let Some(f) = &f {
                        let html = load_and_render(f, &config.lock().unwrap());
                        let _ = webview.load_html(&html);
                    }
                    window.set_title(&title_for_file(&f));
                } else if event.id == settings_id {
                    *in_settings_ipc.lock().unwrap() = true;
                    let html = settings_html(&config.lock().unwrap());
                    let _ = webview.load_html(&html);
                    window.set_title("MdViewer - Settings");
                }
            }
            Event::UserEvent(UserEvent::ApplySettings(json)) => {
                let mut cfg = config.lock().unwrap();
                apply_settings_from_json(&json, &mut cfg);
                cfg.save();

                *in_settings_ipc.lock().unwrap() = false;
                let f = current_file_settings.lock().unwrap().clone();
                let html = match &f {
                    Some(f) => load_and_render(f, &cfg),
                    None => welcome_html(&cfg),
                };
                let _ = webview.load_html(&html);
                window.set_title(&title_for_file(&f));
            }
            Event::WindowEvent {
                event: WindowEvent::CloseRequested,
                ..
            } => {
                *control_flow = ControlFlow::Exit;
            }
            _ => {}
        }
    });
}

fn load_and_render(file: &PathBuf, config: &Config) -> String {
    let content = std::fs::read_to_string(file).unwrap_or_else(|e| {
        format!("# Error\n\nCould not read file: {}", e)
    });
    let base_dir = file
        .parent()
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_default();
    markdown::render_to_html(&content, &base_dir, config)
}

fn apply_settings_from_json(json: &str, config: &mut Config) {
    if let Some(theme) = extract_json_string(json, "theme") {
        config.theme = Theme::from_name(&theme);
    }
    if let Some(font) = extract_json_string(json, "font_family") {
        config.font_family = font;
    }
    if let Some(size) = extract_json_string(json, "font_size") {
        if let Ok(v) = size.parse() {
            config.font_size = v;
        }
    }
    if let Some(font) = extract_json_string(json, "code_font_family") {
        config.code_font_family = font;
    }
    if let Some(size) = extract_json_string(json, "code_font_size") {
        if let Ok(v) = size.parse() {
            config.code_font_size = v;
        }
    }
}

fn extract_json_string(json: &str, key: &str) -> Option<String> {
    let pattern = format!("\"{}\":\"", key);
    if let Some(start) = json.find(&pattern) {
        let value_start = start + pattern.len();
        if let Some(end) = json[value_start..].find('"') {
            return Some(json[value_start..value_start + end].to_string());
        }
    }
    None
}

fn settings_html(config: &Config) -> String {
    let current_theme = config.theme.name();

    let font_family = html_escape(&config.font_family);
    let font_size = config.font_size;
    let code_font_family = html_escape(&config.code_font_family);
    let code_font_size = config.code_font_size;

    format!(
        r#"<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
:root {{
    --bg: #ffffff;
    --fg: #1a1a2e;
    --accent: #2563eb;
    --input-bg: #f4f4f8;
    --border: #e0e0e0;
}}
@media (prefers-color-scheme: dark) {{
    :root {{
        --bg: #08131c;
        --fg: #e2e8f0;
        --accent: #60a5fa;
        --input-bg: #0f1f2e;
        --border: #1a3044;
    }}
}}
* {{ box-sizing: border-box; }}
body {{
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    background: var(--bg);
    color: var(--fg);
    margin: 0;
    padding: 2rem;
}}
.settings {{
    max-width: 520px;
    margin: 0 auto;
}}
h1 {{
    font-size: 1.5rem;
    font-weight: 600;
    margin: 0 0 1.5rem 0;
}}
.field {{
    margin-bottom: 1.2rem;
}}
label {{
    display: block;
    font-size: 0.85rem;
    font-weight: 500;
    margin-bottom: 0.3rem;
    color: var(--fg);
    opacity: 0.7;
}}
select, input[type="text"], input[type="number"] {{
    width: 100%;
    padding: 0.5rem 0.7rem;
    font-size: 0.95rem;
    border: 1px solid var(--border);
    border-radius: 6px;
    background: var(--input-bg);
    color: var(--fg);
    outline: none;
    font-family: inherit;
}}
select:focus, input:focus {{
    border-color: var(--accent);
}}
.hint {{
    font-size: 0.75rem;
    opacity: 0.5;
    margin-top: 0.2rem;
}}
.buttons {{
    display: flex;
    gap: 0.8rem;
    margin-top: 2rem;
}}
button {{
    padding: 0.5rem 1.2rem;
    font-size: 0.95rem;
    border-radius: 6px;
    border: 1px solid var(--border);
    cursor: pointer;
    font-family: inherit;
}}
button.primary {{
    background: var(--accent);
    color: #fff;
    border-color: var(--accent);
}}
button.secondary {{
    background: var(--input-bg);
    color: var(--fg);
}}

/* Theme preview cards */
.theme-grid {{
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 0.8rem;
    margin-top: 0.3rem;
}}
.theme-card {{
    border: 2px solid var(--border);
    border-radius: 8px;
    padding: 0.7rem;
    cursor: pointer;
    transition: border-color 0.15s;
}}
.theme-card.selected {{
    border-color: var(--accent);
}}
.theme-card:hover {{
    border-color: var(--accent);
    opacity: 0.9;
}}
.theme-card .preview {{
    height: 48px;
    border-radius: 4px;
    margin-bottom: 0.4rem;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.75rem;
    font-weight: 500;
}}
.theme-card .name {{
    font-size: 0.8rem;
    text-align: center;
    font-weight: 500;
}}
</style>
</head>
<body>
<div class="settings">
    <h1>Settings</h1>

    <div class="field">
        <label>Theme</label>
        <div class="theme-grid">
            <div class="theme-card{auto_sel}" data-theme="auto" onclick="selectTheme('auto')">
                <div class="preview" style="background: linear-gradient(135deg, #fff 50%, #08131c 50%); color: #666;">Auto</div>
                <div class="name">Auto (System)</div>
            </div>
            <div class="theme-card{light_sel}" data-theme="light" onclick="selectTheme('light')">
                <div class="preview" style="background: #fff; border: 1px solid #e0e0e0; color: #1a1a2e;">Aa</div>
                <div class="name">Light</div>
            </div>
            <div class="theme-card{dark_sel}" data-theme="dark" onclick="selectTheme('dark')">
                <div class="preview" style="background: #08131c; color: #e2e8f0;">Aa</div>
                <div class="name">Dark</div>
            </div>
            <div class="theme-card{modest_sel}" data-theme="modest" onclick="selectTheme('modest')">
                <div class="preview" style="background: #fff; border: 1px solid #fafafa; color: #444; font-family: 'Open Sans Condensed', sans-serif;">Aa</div>
                <div class="name">Modest</div>
            </div>
            <div class="theme-card{modest_dark_sel}" data-theme="modest-dark" onclick="selectTheme('modest-dark')">
                <div class="preview" style="background: #1e1e1e; color: #c8c8c8; font-family: 'Open Sans Condensed', sans-serif;">Aa</div>
                <div class="name">Modest Dark</div>
            </div>
        </div>
    </div>

    <div class="field">
        <label>Body Font Family</label>
        <input type="text" id="font_family" value="{font_family}" placeholder="System default">
        <div class="hint">Leave empty for theme default</div>
    </div>

    <div class="field">
        <label>Body Font Size (px)</label>
        <input type="number" id="font_size" value="{font_size}" min="10" max="32">
    </div>

    <div class="field">
        <label>Code Font Family</label>
        <input type="text" id="code_font_family" value="{code_font_family}" placeholder="System default">
        <div class="hint">Leave empty for theme default</div>
    </div>

    <div class="field">
        <label>Code Font Size (px)</label>
        <input type="number" id="code_font_size" value="{code_font_size}" min="10" max="32">
    </div>

    <div class="buttons">
        <button class="primary" onclick="save()">Save</button>
        <button class="secondary" onclick="cancel()">Cancel</button>
    </div>
</div>

<script>
let selectedTheme = '{current_theme}';

const themes = {{
    light:        {{ bg: '#ffffff', fg: '#1a1a2e', accent: '#2563eb', inputBg: '#f4f4f8', border: '#e0e0e0' }},
    dark:         {{ bg: '#08131c', fg: '#e2e8f0', accent: '#60a5fa', inputBg: '#0f1f2e', border: '#1a3044' }},
    modest:       {{ bg: '#ffffff', fg: '#444444', accent: '#3498db', inputBg: '#f4f4f8', border: '#e0e0e0' }},
    'modest-dark':{{ bg: '#1e1e1e', fg: '#c8c8c8', accent: '#5dade2', inputBg: '#2a2a2a', border: '#3a3a3a' }},
}};

function applyThemeColors(name) {{
    const r = document.documentElement.style;
    if (name === 'auto') {{
        // Reset to system preference
        r.removeProperty('--bg');
        r.removeProperty('--fg');
        r.removeProperty('--accent');
        r.removeProperty('--input-bg');
        r.removeProperty('--border');
        return;
    }}
    const t = themes[name];
    if (t) {{
        r.setProperty('--bg', t.bg);
        r.setProperty('--fg', t.fg);
        r.setProperty('--accent', t.accent);
        r.setProperty('--input-bg', t.inputBg);
        r.setProperty('--border', t.border);
    }}
}}

function selectTheme(name) {{
    selectedTheme = name;
    document.querySelectorAll('.theme-card').forEach(c => {{
        c.classList.toggle('selected', c.dataset.theme === name);
    }});
    applyThemeColors(name);
}}

function save() {{
    const data = {{
        theme: selectedTheme,
        font_family: document.getElementById('font_family').value,
        font_size: document.getElementById('font_size').value,
        code_font_family: document.getElementById('code_font_family').value,
        code_font_size: document.getElementById('code_font_size').value,
    }};
    const json = JSON.stringify(data);
    window.ipc.postMessage('settings:' + json);
}}

function cancel() {{
    // Send empty settings to just go back without saving
    window.ipc.postMessage('settings:{{}}');
}}
</script>
</body>
</html>"#,
        auto_sel = if current_theme == "auto" { " selected" } else { "" },
        light_sel = if current_theme == "light" { " selected" } else { "" },
        dark_sel = if current_theme == "dark" { " selected" } else { "" },
        modest_sel = if current_theme == "modest" { " selected" } else { "" },
        modest_dark_sel = if current_theme == "modest-dark" { " selected" } else { "" },
        font_family = font_family,
        font_size = font_size,
        code_font_family = code_font_family,
        code_font_size = code_font_size,
        current_theme = current_theme,
    )
}

fn html_escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

fn load_window_icon() -> Option<tao::window::Icon> {
    let img = image::load_from_memory(ICON_PNG).ok()?.into_rgba8();
    let (w, h) = img.dimensions();
    tao::window::Icon::from_rgba(img.into_raw(), w, h).ok()
}

#[cfg(target_os = "macos")]
fn set_macos_dock_icon() {
    use objc2::AnyThread;
    use objc2::MainThreadMarker;
    use objc2_app_kit::{NSApplication, NSImage, NSApplicationActivationPolicy};
    use objc2_foundation::NSData;

    let mtm = MainThreadMarker::new().expect("must be called from main thread");
    let app = NSApplication::sharedApplication(mtm);

    app.setActivationPolicy(NSApplicationActivationPolicy::Regular);

    let data = NSData::with_bytes(ICON_PNG);
    if let Some(image) = NSImage::initWithData(NSImage::alloc(), &data) {
        unsafe { app.setApplicationIconImage(Some(&image)) };
    }
}

#[cfg(not(target_os = "macos"))]
fn set_macos_dock_icon() {}

fn urlencoding_decode(s: &str) -> String {
    let mut result = String::new();
    let mut chars = s.bytes();
    while let Some(b) = chars.next() {
        if b == b'%' {
            let h = chars.next().unwrap_or(0);
            let l = chars.next().unwrap_or(0);
            let hex = [h, l];
            if let Ok(s) = std::str::from_utf8(&hex) {
                if let Ok(val) = u8::from_str_radix(s, 16) {
                    result.push(val as char);
                    continue;
                }
            }
            result.push('%');
            result.push(h as char);
            result.push(l as char);
        } else {
            result.push(b as char);
        }
    }
    result
}
