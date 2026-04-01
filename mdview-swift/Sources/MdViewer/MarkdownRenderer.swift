import Foundation
import Markdown

struct MarkdownRenderer {
    let baseDir: String
    let config: AppConfig

    func render(_ markdown: String) -> String {
        let document = Document(parsing: markdown, options: [.parseBlockDirectives])
        var converter = HTMLConverter(baseDir: baseDir, config: config)
        let html = converter.convert(document)
        return HTMLWrapper.wrap(body: html, config: config)
    }
}

private struct HTMLConverter {
    let baseDir: String
    let config: AppConfig
    private var html = ""

    init(baseDir: String, config: AppConfig) {
        self.baseDir = baseDir
        self.config = config
    }

    mutating func convert(_ document: Document) -> String {
        html = ""
        for child in document.children {
            convertMarkup(child)
        }
        return html
    }

    private mutating func convertMarkup(_ markup: any Markup) {
        switch markup {
        case let heading as Heading:
            convertHeading(heading)
        case let paragraph as Paragraph:
            convertParagraph(paragraph)
        case let codeBlock as CodeBlock:
            convertCodeBlock(codeBlock)
        case let list as UnorderedList:
            html += "<ul>\n"
            for child in list.children { convertMarkup(child) }
            html += "</ul>\n"
        case let list as OrderedList:
            html += "<ol>\n"
            for child in list.children { convertMarkup(child) }
            html += "</ol>\n"
        case let item as ListItem:
            convertListItem(item)
        case let blockquote as BlockQuote:
            html += "<blockquote>\n"
            for child in blockquote.children { convertMarkup(child) }
            html += "</blockquote>\n"
        case let table as Markdown.Table:
            convertTable(table)
        case is ThematicBreak:
            html += "<hr>\n"
        case let htmlBlock as HTMLBlock:
            html += htmlBlock.rawHTML
        case let text as Markdown.Text:
            html += htmlEscape(text.string)
        case let code as InlineCode:
            html += "<code>\(htmlEscape(code.code))</code>"
        case let emphasis as Emphasis:
            html += "<em>"
            for child in emphasis.children { convertMarkup(child) }
            html += "</em>"
        case let strong as Strong:
            html += "<strong>"
            for child in strong.children { convertMarkup(child) }
            html += "</strong>"
        case let strikethrough as Strikethrough:
            html += "<del>"
            for child in strikethrough.children { convertMarkup(child) }
            html += "</del>"
        case let link as Markdown.Link:
            convertLink(link)
        case let image as Markdown.Image:
            convertImage(image)
        case is SoftBreak:
            html += "\n"
        case is LineBreak:
            html += "<br>\n"
        case let inlineHTML as InlineHTML:
            html += inlineHTML.rawHTML
        default:
            for child in markup.children {
                convertMarkup(child)
            }
        }
    }

    private mutating func convertHeading(_ heading: Heading) {
        let level = heading.level
        html += "<h\(level)>"
        for child in heading.children { convertMarkup(child) }
        html += "</h\(level)>\n"
    }

    private mutating func convertParagraph(_ paragraph: Paragraph) {
        html += "<p>"
        for child in paragraph.children { convertMarkup(child) }
        html += "</p>\n"
    }

    private mutating func convertCodeBlock(_ codeBlock: CodeBlock) {
        let lang = codeBlock.language ?? ""
        let content = codeBlock.code

        switch lang.lowercased() {
        case "mermaid":
            html += "<div class=\"mermaid\">\n\(content)\n</div>\n"
        case "plantuml", "puml":
            let themed = config.theme.plantumlTheme + content
            let encoded = PlantUMLEncoder.encode(themed)
            html += "<div class=\"plantuml\"><img src=\"https://www.plantuml.com/plantuml/svg/\(encoded)\" alt=\"PlantUML diagram\" /></div>\n"
        case "svg":
            html += "<div class=\"svg-container\">\(content)</div>\n"
        default:
            let escaped = htmlEscape(content)
            if lang.isEmpty {
                html += "<pre><code>\(escaped)</code></pre>\n"
            } else {
                html += "<pre><code class=\"language-\(lang)\">\(escaped)</code></pre>\n"
            }
        }
    }

    private mutating func convertLink(_ link: Markdown.Link) {
        let destination = link.destination ?? ""
        let title = link.title ?? ""

        if destination.hasSuffix(".md") {
            let resolved = resolveMDLink(destination)
            let titleAttr = title.isEmpty ? "" : " title=\"\(title)\""
            html += "<a href=\"mdview://open?file=\(resolved)\"\(titleAttr)>"
            for child in link.children { convertMarkup(child) }
            html += "</a>"
        } else {
            let titleAttr = title.isEmpty ? "" : " title=\"\(title)\""
            html += "<a href=\"\(htmlEscape(destination))\"\(titleAttr)>"
            for child in link.children { convertMarkup(child) }
            html += "</a>"
        }
    }

    private mutating func convertImage(_ image: Markdown.Image) {
        let source = image.source ?? ""
        let title = image.title ?? ""

        if source.hasSuffix(".svg") {
            let resolved = resolvePath(source)
            if let svgContent = try? String(contentsOfFile: resolved, encoding: .utf8) {
                html += "<div class=\"svg-container\" title=\"\(htmlEscape(title))\">\(svgContent)</div>"
                return
            }
        }

        let resolvedSource: String
        if !source.hasPrefix("http://") && !source.hasPrefix("https://") && !source.hasPrefix("data:") {
            let resolved = resolvePath(source)
            resolvedSource = "file://\(resolved)"
        } else {
            resolvedSource = source
        }

        var alt = ""
        for child in image.children {
            if let text = child as? Markdown.Text {
                alt += text.string
            }
        }

        html += "<img src=\"\(htmlEscape(resolvedSource))\" alt=\"\(htmlEscape(alt))\""
        if !title.isEmpty {
            html += " title=\"\(htmlEscape(title))\""
        }
        html += ">"
    }

    private mutating func convertListItem(_ item: ListItem) {
        if let checkbox = item.checkbox {
            let checked = checkbox == .checked ? " checked" : ""
            html += "<li><input type=\"checkbox\" disabled\(checked)> "
            for child in item.children {
                if let para = child as? Paragraph {
                    for c in para.children { convertMarkup(c) }
                } else {
                    convertMarkup(child)
                }
            }
            html += "</li>\n"
        } else {
            html += "<li>"
            for child in item.children {
                if item.childCount == 1, let para = child as? Paragraph {
                    for c in para.children { convertMarkup(c) }
                } else {
                    convertMarkup(child)
                }
            }
            html += "</li>\n"
        }
    }

    private mutating func convertTable(_ table: Markdown.Table) {
        html += "<table>\n"

        let head = table.head
        html += "<thead><tr>\n"
        for cell in head.cells {
            html += "<th>"
            for child in cell.children { convertMarkup(child) }
            html += "</th>\n"
        }
        html += "</tr></thead>\n"

        html += "<tbody>\n"
        for row in table.body.rows {
            html += "<tr>\n"
            for cell in row.cells {
                html += "<td>"
                for child in cell.children { convertMarkup(child) }
                html += "</td>\n"
            }
            html += "</tr>\n"
        }
        html += "</tbody>\n"
        html += "</table>\n"
    }

    private func resolveMDLink(_ url: String) -> String {
        (baseDir as NSString).appendingPathComponent(url)
    }

    private func resolvePath(_ url: String) -> String {
        (baseDir as NSString).appendingPathComponent(url)
    }

    private func htmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
