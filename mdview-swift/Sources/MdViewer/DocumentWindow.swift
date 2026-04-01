import Foundation
import Combine

class DocumentWindow: ObservableObject, Identifiable {
    let id = UUID()
    @Published var currentFile: URL?
    @Published var htmlContent: String = ""
    @Published var isShowingSettings: Bool = false
    @Published var zoomLevel: Double = 1.0

    var fileWatcher: FileWatcher?
    var cancellables = Set<AnyCancellable>()
    private let config: AppConfig

    init(file: URL? = nil, config: AppConfig) {
        self.config = config
        if let file = file {
            openFile(file)
        } else {
            htmlContent = Self.welcomeHTML(config: config)
        }
    }

    var isWelcome: Bool {
        currentFile == nil && !isShowingSettings
    }

    func openFile(_ file: URL) {
        currentFile = file
        isShowingSettings = false
        renderFile()
        startWatching()
    }

    func reload() {
        if isShowingSettings {
            isShowingSettings = false
        }
        if currentFile != nil {
            renderFile()
        } else {
            htmlContent = Self.welcomeHTML(config: config)
        }
    }

    func showSettings() {
        isShowingSettings = true
        htmlContent = SettingsHTML.generate(config: config)
    }

    func applySettings(json: String) {
        parseAndApplySettings(json: json, config: config)
        config.save()
        isShowingSettings = false
        if currentFile != nil {
            renderFile()
        } else {
            htmlContent = Self.welcomeHTML(config: config)
        }
    }

    func renderFile() {
        guard let file = currentFile else { return }
        let content: String
        do {
            content = try String(contentsOf: file, encoding: .utf8)
        } catch {
            content = "# Error\n\nCould not read file: \(error.localizedDescription)"
        }
        let baseDir = file.deletingLastPathComponent().path
        let renderer = MarkdownRenderer(baseDir: baseDir, config: config)
        htmlContent = renderer.render(content)
    }

    private func startWatching() {
        fileWatcher?.stop()
        guard let file = currentFile else { return }
        fileWatcher = FileWatcher(path: file.path) { [weak self] in
            guard let self = self, !self.isShowingSettings else { return }
            self.renderFile()
        }
    }

    var windowTitle: String {
        if isShowingSettings { return "MdViewer - Settings" }
        guard let file = currentFile else { return "MdViewer" }
        return "MdViewer - \(file.lastPathComponent)"
    }

    static func welcomeHTML(config: AppConfig) -> String {
        let logoData: String
        if let url = Bundle.module.url(forResource: "welcome_logo", withExtension: "png"),
           let data = try? Data(contentsOf: url) {
            logoData = data.base64EncodedString()
        } else {
            logoData = ""
        }

        let themeCSS: String
        switch config.theme {
        case .light:
            themeCSS = ":root { --wbg: #ffffff; --wfg: #1a1a2e; --wsub: #6b7280; --wkbd-bg: #f0f0f0; --wkbd-border: #d0d0d0; --card-bg: #08131c; }"
        case .dark:
            themeCSS = ":root { --wbg: #08131c; --wfg: #f5f5f7; --wsub: #86868b; --wkbd-bg: #2c2c2e; --wkbd-border: #3a3a3c; --card-bg: var(--wbg); }"
        case .modest:
            themeCSS = ":root { --wbg: #ffffff; --wfg: #444444; --wsub: #888888; --wkbd-bg: #fafafa; --wkbd-border: #e0e0e0; --card-bg: #08131c; }"
        case .modestDark:
            themeCSS = ":root { --wbg: #1e1e1e; --wfg: #c8c8c8; --wsub: #888888; --wkbd-bg: #2a2a2a; --wkbd-border: #3a3a3a; --card-bg: var(--wbg); }"
        case .auto:
            themeCSS = """
            :root { --wbg: #ffffff; --wfg: #1a1a2e; --wsub: #6b7280; --wkbd-bg: #f0f0f0; --wkbd-border: #d0d0d0; --card-bg: #08131c; }
            @media (prefers-color-scheme: dark) {
                :root { --wbg: #08131c; --wfg: #f5f5f7; --wsub: #86868b; --wkbd-bg: #2c2c2e; --wkbd-border: #3a3a3c; --card-bg: var(--wbg); }
            }
            """
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        \(themeCSS)
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html, body {
            height: 100%;
        }
        body {
            background: var(--wbg);
            color: var(--wfg);
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
            min-height: 100%;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .welcome {
            text-align: center;
        }
        .logo-card {
            background: var(--card-bg);
            border-radius: 20px;
            padding: 2rem 2.5rem 1rem;
            display: inline-block;
            margin-bottom: 2rem;
        }
        .logo-card img {
            width: 420px;
            height: auto;
            margin-left: -34px;
        }
        .welcome h1 {
            font-size: 1.6rem;
            font-weight: 600;
            letter-spacing: -0.02em;
            margin-bottom: 0.6rem;
        }
        .welcome p {
            font-size: 0.95rem;
            color: var(--wsub);
            line-height: 1.6;
        }
        .welcome kbd {
            background: var(--wkbd-bg);
            border: 1px solid var(--wkbd-border);
            border-radius: 4px;
            padding: 0.1em 0.4em;
            font-family: inherit;
            font-size: 0.85em;
        }
        </style>
        </head>
        <body>
        <div class="welcome">
            <div class="logo-card"><img src="data:image/png;base64,\(logoData)" alt="MdViewer"></div>
            <h1>Welcome to MdViewer</h1>
            <p>Open a file with <kbd>Cmd</kbd> + <kbd>O</kbd> or drop one on the dock icon.<br>
            From the terminal: <kbd>mdview myfile.md</kbd></p>
        </div>
        </body>
        </html>
        """
    }

    private func parseAndApplySettings(json: String, config: AppConfig) {
        // Simple JSON extraction (matching Rust behavior)
        if let theme = extractJSONString(json, key: "theme") {
            config.theme = Theme.fromName(theme)
        }
        if let font = extractJSONString(json, key: "font_family") {
            config.fontFamily = font
        }
        if let size = extractJSONString(json, key: "font_size"), let v = UInt32(size) {
            config.fontSize = v
        }
        if let font = extractJSONString(json, key: "code_font_family") {
            config.codeFontFamily = font
        }
        if let size = extractJSONString(json, key: "code_font_size"), let v = UInt32(size) {
            config.codeFontSize = v
        }
    }

    private func extractJSONString(_ json: String, key: String) -> String? {
        let pattern = "\"\(key)\":\""
        guard let range = json.range(of: pattern) else { return nil }
        let rest = json[range.upperBound...]
        guard let endQuote = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[rest.startIndex..<endQuote])
    }
}
