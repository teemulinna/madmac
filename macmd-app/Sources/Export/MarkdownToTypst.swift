import Foundation

/// Converts Markdown text to Typst markup.
/// Handles: headings, bold, italic, links, images, code blocks,
/// lists (ordered + unordered), blockquotes, horizontal rules.
enum MarkdownToTypst {

    static func convert(_ markdown: String) -> String {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var output: [String] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Fenced code block
            if line.hasPrefix("```") {
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var code: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    code.append(lines[i])
                    i += 1
                }
                let langTag = lang.isEmpty ? "" : " \(lang)"
                output.append("```\(langTag)")
                output.append(contentsOf: code)
                output.append("```")
                i += 1
                continue
            }

            // Heading
            if let heading = parseHeading(line) {
                let prefix = String(repeating: "=", count: heading.level)
                output.append("\(prefix) \(convertInline(heading.text))")
                i += 1
                continue
            }

            // Horizontal rule
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("---") &&
               line.trimmingCharacters(in: .whitespacesAndNewlines).allSatisfy({ $0 == "-" || $0 == " " }) &&
               line.filter({ $0 == "-" }).count >= 3 {
                output.append("#line(length: 100%, stroke: 0.5pt + luma(200))")
                i += 1
                continue
            }

            // Blockquote
            if line.hasPrefix(">") {
                var quoteLines: [String] = []
                while i < lines.count && lines[i].hasPrefix(">") {
                    let content = String(lines[i].dropFirst(1)).trimmingCharacters(in: .init(charactersIn: " "))
                    quoteLines.append(convertInline(content))
                    i += 1
                }
                output.append("#quote(block: true)[\(quoteLines.joined(separator: "\n"))]")
                continue
            }

            // Unordered list
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                while i < lines.count && (lines[i].hasPrefix("- ") || lines[i].hasPrefix("* ")) {
                    let item = String(lines[i].dropFirst(2))
                    output.append("- \(convertInline(item))")
                    i += 1
                }
                output.append("")
                continue
            }

            // Ordered list
            if let _ = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                while i < lines.count, let range = lines[i].range(of: #"^\d+\.\s"#, options: .regularExpression) {
                    let item = String(lines[i][range.upperBound...])
                    output.append("+ \(convertInline(item))")
                    i += 1
                }
                output.append("")
                continue
            }

            // Image (standalone line)
            if let img = parseImage(line) {
                if img.alt.isEmpty {
                    output.append("#image(\"\(escapeTypstString(img.path))\")")
                } else {
                    output.append("#figure(image(\"\(escapeTypstString(img.path))\"), caption: [\(convertInline(img.alt))])")
                }
                i += 1
                continue
            }

            // Empty line → preserve
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                output.append("")
                i += 1
                continue
            }

            // Paragraph
            output.append(convertInline(line))
            i += 1
        }

        return output.joined(separator: "\n")
    }

    // MARK: - Inline conversion

    static func convertInline(_ text: String) -> String {
        var result = text

        // Inline images first (before links): ![alt](path) → #image("path")
        result = result.replacingOccurrences(
            of: #"!\[([^\]]*)\]\(([^)]+)\)"#, with: "#image(\"$2\")", options: .regularExpression)

        // Links: [text](url) → #link("url")[text]
        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\(([^)]+)\)"#, with: "#link(\"$2\")[$1]", options: .regularExpression)

        // Strikethrough: ~~text~~ → #strike[text]
        result = result.replacingOccurrences(
            of: #"~~(.+?)~~"#, with: "#strike[$1]", options: .regularExpression)

        // Italic first: *text* (single) → _text_
        // Must run BEFORE bold so we can distinguish ** from *
        result = result.replacingOccurrences(
            of: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, with: "_$1_", options: .regularExpression)

        // Bold: **text** → *text* (Typst bold syntax)
        result = result.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#, with: "*$1*", options: .regularExpression)

        return result
    }

    // MARK: - Helpers

    private struct Heading { let level: Int; let text: String }
    private struct Image { let alt: String; let path: String }

    private static func parseHeading(_ line: String) -> Heading? {
        var level = 0
        for ch in line {
            if ch == "#" { level += 1 } else { break }
        }
        guard level > 0 && level <= 6 else { return nil }
        let rest = line.dropFirst(level)
        guard rest.first == " " else { return nil }
        return Heading(level: level, text: rest.trimmingCharacters(in: .whitespaces))
    }

    private static func parseImage(_ line: String) -> Image? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("![") else { return nil }
        guard let altEnd = trimmed.range(of: "](") else { return nil }
        guard trimmed.hasSuffix(")") else { return nil }
        let alt = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<altEnd.lowerBound])
        let path = String(trimmed[altEnd.upperBound..<trimmed.index(before: trimmed.endIndex)])
        return Image(alt: alt, path: path)
    }

    private static func escapeTypstString(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
