import AppKit
import Foundation

@MainActor
enum FeedbackMarkdown {
    static func render(_ markdown: String) -> NSAttributedString {
        let source = normalizeListMarkers(in: markdown)
        guard let parsed = try? AttributedString(
            markdown: source,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return plainText(markdown)
        }

        let result = NSMutableAttributedString(
            attributedString: NSAttributedString(parsed)
        )
        style(result)
        return result
    }

    private static func style(_ result: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: result.length)
        guard fullRange.length > 0 else { return }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        paragraphStyle.paragraphSpacing = 2
        result.addAttributes(
            [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle
            ],
            range: fullRange
        )

        result.enumerateAttribute(
            .inlinePresentationIntent,
            in: fullRange
        ) { value, range, _ in
            guard let number = value as? NSNumber else { return }
            let intent = InlinePresentationIntent(rawValue: number.uintValue)
            let isStrong = intent.contains(.stronglyEmphasized)
            let isCode = intent.contains(.code)

            var font = isCode
                ? NSFont.monospacedSystemFont(
                    ofSize: 12.5,
                    weight: isStrong ? .semibold : .regular
                )
                : NSFont.systemFont(
                    ofSize: 13,
                    weight: isStrong ? .semibold : .regular
                )
            if intent.contains(.emphasized) {
                font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            }
            result.addAttribute(.font, value: font, range: range)

            if isCode {
                result.addAttribute(
                    .backgroundColor,
                    value: NSColor.separatorColor.withAlphaComponent(0.3),
                    range: range
                )
            }
        }

        result.removeAttribute(.inlinePresentationIntent, range: fullRange)
        result.removeAttribute(.link, range: fullRange)
    }

    private static func plainText(_ value: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        paragraphStyle.paragraphSpacing = 2
        return NSAttributedString(
            string: value,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle
            ]
        )
    }

    private static func normalizeListMarkers(in markdown: String) -> String {
        markdown
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let value = String(line)
                let indentation = value.prefix { $0 == " " || $0 == "\t" }
                let content = value.dropFirst(indentation.count)
                guard content.hasPrefix("- ") else { return value }
                return "\(indentation)• \(content.dropFirst(2))"
            }
            .joined(separator: "\n")
    }
}
