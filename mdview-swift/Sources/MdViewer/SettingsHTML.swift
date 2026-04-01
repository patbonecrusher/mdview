import Foundation

enum SettingsHTML {
    static func generate(config: AppConfig) -> String {
        let currentTheme = config.theme.displayName
        let fontFamily = htmlEscape(config.fontFamily)
        let fontSize = config.fontSize
        let codeFontFamily = htmlEscape(config.codeFontFamily)
        let codeFontSize = config.codeFontSize

        let autoSel = currentTheme == "auto" ? " selected" : ""
        let lightSel = currentTheme == "light" ? " selected" : ""
        let darkSel = currentTheme == "dark" ? " selected" : ""
        let modestSel = currentTheme == "modest" ? " selected" : ""
        let modestDarkSel = currentTheme == "modest-dark" ? " selected" : ""

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        :root {
            --bg: #ffffff;
            --fg: #1a1a2e;
            --accent: #2563eb;
            --input-bg: #f4f4f8;
            --border: #e0e0e0;
        }
        @media (prefers-color-scheme: dark) {
            :root {
                --bg: #08131c;
                --fg: #e2e8f0;
                --accent: #60a5fa;
                --input-bg: #0f1f2e;
                --border: #1a3044;
            }
        }
        * { box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
            background: var(--bg);
            color: var(--fg);
            margin: 0;
            padding: 2rem;
        }
        .settings {
            max-width: 520px;
            margin: 0 auto;
        }
        h1 {
            font-size: 1.5rem;
            font-weight: 600;
            margin: 0 0 1.5rem 0;
        }
        .field {
            margin-bottom: 1.2rem;
        }
        label {
            display: block;
            font-size: 0.85rem;
            font-weight: 500;
            margin-bottom: 0.3rem;
            color: var(--fg);
            opacity: 0.7;
        }
        select, input[type="text"], input[type="number"] {
            width: 100%;
            padding: 0.5rem 0.7rem;
            font-size: 0.95rem;
            border: 1px solid var(--border);
            border-radius: 6px;
            background: var(--input-bg);
            color: var(--fg);
            outline: none;
            font-family: inherit;
        }
        select:focus, input:focus {
            border-color: var(--accent);
        }
        .hint {
            font-size: 0.75rem;
            opacity: 0.5;
            margin-top: 0.2rem;
        }
        .buttons {
            display: flex;
            gap: 0.8rem;
            margin-top: 2rem;
        }
        button {
            padding: 0.5rem 1.2rem;
            font-size: 0.95rem;
            border-radius: 6px;
            border: 1px solid var(--border);
            cursor: pointer;
            font-family: inherit;
        }
        button.primary {
            background: var(--accent);
            color: #fff;
            border-color: var(--accent);
        }
        button.secondary {
            background: var(--input-bg);
            color: var(--fg);
        }
        .theme-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 0.8rem;
            margin-top: 0.3rem;
        }
        .theme-card {
            border: 2px solid var(--border);
            border-radius: 8px;
            padding: 0.7rem;
            cursor: pointer;
            transition: border-color 0.15s;
        }
        .theme-card.selected {
            border-color: var(--accent);
        }
        .theme-card:hover {
            border-color: var(--accent);
            opacity: 0.9;
        }
        .theme-card .preview {
            height: 48px;
            border-radius: 4px;
            margin-bottom: 0.4rem;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 0.75rem;
            font-weight: 500;
        }
        .theme-card .name {
            font-size: 0.8rem;
            text-align: center;
            font-weight: 500;
        }
        </style>
        </head>
        <body>
        <div class="settings">
            <h1>Settings</h1>

            <div class="field">
                <label>Theme</label>
                <div class="theme-grid">
                    <div class="theme-card\(autoSel)" data-theme="auto" onclick="selectTheme('auto')">
                        <div class="preview" style="background: linear-gradient(135deg, #fff 50%, #08131c 50%); color: #666;">Auto</div>
                        <div class="name">Auto (System)</div>
                    </div>
                    <div class="theme-card\(lightSel)" data-theme="light" onclick="selectTheme('light')">
                        <div class="preview" style="background: #fff; border: 1px solid #e0e0e0; color: #1a1a2e;">Aa</div>
                        <div class="name">Light</div>
                    </div>
                    <div class="theme-card\(darkSel)" data-theme="dark" onclick="selectTheme('dark')">
                        <div class="preview" style="background: #08131c; color: #e2e8f0;">Aa</div>
                        <div class="name">Dark</div>
                    </div>
                    <div class="theme-card\(modestSel)" data-theme="modest" onclick="selectTheme('modest')">
                        <div class="preview" style="background: #fff; border: 1px solid #fafafa; color: #444; font-family: 'Open Sans Condensed', sans-serif;">Aa</div>
                        <div class="name">Modest</div>
                    </div>
                    <div class="theme-card\(modestDarkSel)" data-theme="modest-dark" onclick="selectTheme('modest-dark')">
                        <div class="preview" style="background: #1e1e1e; color: #c8c8c8; font-family: 'Open Sans Condensed', sans-serif;">Aa</div>
                        <div class="name">Modest Dark</div>
                    </div>
                </div>
            </div>

            <div class="field">
                <label>Body Font Family</label>
                <input type="text" id="font_family" value="\(fontFamily)" placeholder="System default">
                <div class="hint">Leave empty for theme default</div>
            </div>

            <div class="field">
                <label>Body Font Size (px)</label>
                <input type="number" id="font_size" value="\(fontSize)" min="10" max="32">
            </div>

            <div class="field">
                <label>Code Font Family</label>
                <input type="text" id="code_font_family" value="\(codeFontFamily)" placeholder="System default">
                <div class="hint">Leave empty for theme default</div>
            </div>

            <div class="field">
                <label>Code Font Size (px)</label>
                <input type="number" id="code_font_size" value="\(codeFontSize)" min="10" max="32">
            </div>

            <div class="buttons">
                <button class="primary" onclick="save()">Save</button>
                <button class="secondary" onclick="cancel()">Cancel</button>
            </div>
        </div>

        <script>
        let selectedTheme = '\(currentTheme)';

        const themes = {
            light:        { bg: '#ffffff', fg: '#1a1a2e', accent: '#2563eb', inputBg: '#f4f4f8', border: '#e0e0e0' },
            dark:         { bg: '#08131c', fg: '#e2e8f0', accent: '#60a5fa', inputBg: '#0f1f2e', border: '#1a3044' },
            modest:       { bg: '#ffffff', fg: '#444444', accent: '#3498db', inputBg: '#f4f4f8', border: '#e0e0e0' },
            'modest-dark':{ bg: '#1e1e1e', fg: '#c8c8c8', accent: '#5dade2', inputBg: '#2a2a2a', border: '#3a3a3a' },
        };

        function applyThemeColors(name) {
            const r = document.documentElement.style;
            if (name === 'auto') {
                r.removeProperty('--bg');
                r.removeProperty('--fg');
                r.removeProperty('--accent');
                r.removeProperty('--input-bg');
                r.removeProperty('--border');
                return;
            }
            const t = themes[name];
            if (t) {
                r.setProperty('--bg', t.bg);
                r.setProperty('--fg', t.fg);
                r.setProperty('--accent', t.accent);
                r.setProperty('--input-bg', t.inputBg);
                r.setProperty('--border', t.border);
            }
        }

        function selectTheme(name) {
            selectedTheme = name;
            document.querySelectorAll('.theme-card').forEach(c => {
                c.classList.toggle('selected', c.dataset.theme === name);
            });
            applyThemeColors(name);
        }

        function save() {
            const data = {
                theme: selectedTheme,
                font_family: document.getElementById('font_family').value,
                font_size: document.getElementById('font_size').value,
                code_font_family: document.getElementById('code_font_family').value,
                code_font_size: document.getElementById('code_font_size').value,
            };
            const json = JSON.stringify(data);
            window.webkit.messageHandlers.ipc.postMessage('settings:' + json);
        }

        function cancel() {
            window.webkit.messageHandlers.ipc.postMessage('settings:{}');
        }
        </script>
        </body>
        </html>
        """
    }

    private static func htmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
