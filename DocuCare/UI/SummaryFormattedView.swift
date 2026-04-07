import SwiftUI

/// Renders stored AI summaries: paragraph text plus lines that look like list items (Gemini uses "- " bullets).
struct SummaryFormattedView: View {
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .paragraph(let text):
                    Text(text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .bullet(let text):
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\u{2022}")
                            .foregroundStyle(.secondary)
                        Text(text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .multilineTextAlignment(.leading)
    }

    private var blocks: [Block] { Self.buildBlocks(from: summary) }

    private enum Block {
        case paragraph(String)
        case bullet(String)
    }

    private static func buildBlocks(from summary: String) -> [Block] {
        let normalized = summary
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        var out: [Block] = []
        var paragraphLines: [String] = []

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            out.append(.paragraph(paragraphLines.joined(separator: "\n")))
            paragraphLines.removeAll()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flushParagraph()
                continue
            }
            if let body = bulletBody(from: trimmed) {
                flushParagraph()
                out.append(.bullet(body))
            } else {
                paragraphLines.append(trimmed)
            }
        }
        flushParagraph()

        if out.isEmpty, !summary.isEmpty {
            return [.paragraph(summary)]
        }
        return out
    }

    /// Recognizes common bullet prefixes from Gemini or manual edits.
    private static func bulletBody(from line: String) -> String? {
        let prefixes = ["- ", "• ", "* ", "– ", "— "]
        for p in prefixes where line.hasPrefix(p) {
            return String(line.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
        }
        if line.hasPrefix("•") {
            return String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        if line.first == "-", line.count > 1 {
            let afterHyphen = line.dropFirst()
            if afterHyphen.first == " " {
                return afterHyphen.dropFirst().trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}
