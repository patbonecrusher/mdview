import Foundation

enum Theme: String, CaseIterable {
    case auto
    case light
    case dark
    case modest
    case modestDark = "modest-dark"

    var displayName: String {
        switch self {
        case .auto: return "auto"
        case .light: return "light"
        case .dark: return "dark"
        case .modest: return "modest"
        case .modestDark: return "modest-dark"
        }
    }

    static func fromName(_ name: String) -> Theme {
        switch name {
        case "light": return .light
        case "dark": return .dark
        case "modest": return .modest
        case "modest-dark": return .modestDark
        default: return .auto
        }
    }

    var themeCSSContent: String {
        switch self {
        case .modest:
            return loadResource("modest", ext: "css") ?? ""
        case .modestDark:
            return loadResource("modest_dark", ext: "css") ?? ""
        default:
            return ""
        }
    }

    var hljsStyle: String {
        switch self {
        case .dark, .modestDark: return "github-dark"
        case .light, .modest: return "github"
        case .auto: return "auto"
        }
    }

    var mermaidTheme: String {
        switch self {
        case .dark, .modestDark: return "dark"
        case .light, .modest: return "default"
        case .auto: return "auto"
        }
    }

    var plantumlTheme: String {
        switch self {
        case .dark, .modestDark: return "!theme cyborg-outline\n"
        default: return ""
        }
    }

    private func loadResource(_ name: String, ext: String) -> String? {
        guard let url = resourceBundle.url(forResource: name, withExtension: ext) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

class AppConfig: ObservableObject {
    @Published var theme: Theme = .auto
    @Published var fontFamily: String = ""
    @Published var fontSize: UInt32 = 16
    @Published var codeFontFamily: String = ""
    @Published var codeFontSize: UInt32 = 14

    static let shared = AppConfig()

    init() {
        load()
    }

    private static var configDir: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/mdviewer")
    }

    private static var configPath: URL {
        configDir.appendingPathComponent("config")
    }

    func load() {
        let path = Self.configPath
        guard FileManager.default.fileExists(atPath: path.path),
              let content = try? String(contentsOf: path, encoding: .utf8) else { return }
        parse(content)
    }

    func save() {
        let dir = Self.configDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let content = """
        theme = \(theme.displayName)
        font_family = \(fontFamily)
        font_size = \(fontSize)
        code_font_family = \(codeFontFamily)
        code_font_size = \(codeFontSize)
        """
        try? content.write(to: Self.configPath, atomically: true, encoding: .utf8)
    }

    private func parse(_ content: String) {
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            guard let eqIdx = trimmed.firstIndex(of: "=") else { continue }
            let key = trimmed[trimmed.startIndex..<eqIdx].trimmingCharacters(in: .whitespaces)
            let value = trimmed[trimmed.index(after: eqIdx)...].trimmingCharacters(in: .whitespaces)
            switch key {
            case "theme": theme = Theme.fromName(value)
            case "font_family": fontFamily = value
            case "font_size": if let v = UInt32(value) { fontSize = v }
            case "code_font_family": codeFontFamily = value
            case "code_font_size": if let v = UInt32(value) { codeFontSize = v }
            default: break
            }
        }
    }

    func toCSSOverrides() -> String {
        var css = ""

        switch theme {
        case .light:
            css += """
            :root {
              --bg: #ffffff; --fg: #1a1a2e; --code-bg: #f4f4f8;
              --border: #e0e0e0; --link: #2563eb; --heading: #0f172a;
              --blockquote-border: #3b82f6; --blockquote-bg: #eff6ff;
            }\n
            """
        case .dark:
            css += """
            :root {
              --bg: #08131c; --fg: #e2e8f0; --code-bg: #0f1f2e;
              --border: #1a3044; --link: #60a5fa; --heading: #f1f5f9;
              --blockquote-border: #3b82f6; --blockquote-bg: #0c1a28;
            }\n
            """
        case .modest, .modestDark:
            css += theme.themeCSSContent
        case .auto:
            break
        }

        if !fontFamily.isEmpty {
            css += "body { font-family: \(fontFamily); }\n"
        }
        if fontSize != 16 {
            css += "body { font-size: \(fontSize)px; }\n"
        }
        if !codeFontFamily.isEmpty {
            css += "code, pre code { font-family: \(codeFontFamily); }\n"
        }
        if codeFontSize != 14 {
            css += "code, pre code { font-size: \(codeFontSize)px; }\n"
        }

        return css
    }
}
