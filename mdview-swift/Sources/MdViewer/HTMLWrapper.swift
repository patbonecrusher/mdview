import Foundation

enum HTMLWrapper {
    static func wrap(body: String, config: AppConfig) -> String {
        let hljsStyle = config.theme.hljsStyle
        let mermaidTheme = config.theme.mermaidTheme

        let mermaidInit: String
        if mermaidTheme == "auto" {
            mermaidInit = """
            const mermaidTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default';
            mermaid.initialize({ startOnLoad: true, theme: mermaidTheme });
            """
        } else {
            mermaidInit = "mermaid.initialize({ startOnLoad: true, theme: '\(mermaidTheme)' });"
        }

        let hljsLink: String
        if hljsStyle == "auto" {
            hljsLink = """
            <link rel="stylesheet" media="(prefers-color-scheme: light)" href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release/build/styles/github.min.css">
            <link rel="stylesheet" media="(prefers-color-scheme: dark)" href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release/build/styles/github-dark.min.css">
            """
        } else {
            hljsLink = """
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release/build/styles/\(hljsStyle).min.css">
            """
        }

        let css = loadCSS() ?? ""
        let themeCSS = config.toCSSOverrides()

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        \(css)
        \(themeCSS)
        </style>
        \(hljsLink)
        <script src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release/build/highlight.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
        <script>
        \(mermaidInit)
        </script>
        </head>
        <body>
        <div class="container">
        \(body)
        </div>
        <script>
        hljs.highlightAll();
        if (typeof mermaid !== 'undefined') {
            mermaid.contentLoaded();
        }
        </script>
        </body>
        </html>
        """
    }

    private static func loadCSS() -> String? {
        guard let url = Bundle.module.url(forResource: "style", withExtension: "css") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
