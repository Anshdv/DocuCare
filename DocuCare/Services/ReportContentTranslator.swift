import Foundation
import SwiftData

@MainActor
enum ReportContentTranslator {
    /// Rewrites `title` and `summary` into `targetCode` when they are not already stored in that language.
    /// - Parameter persistChanges: When batching many reports, pass `false` and save once on the caller side.
    static func alignLanguage(
        of report: MedicalReport,
        to targetCode: String,
        modelContext: ModelContext,
        persistChanges: Bool = true
    ) async {
        guard report.contentLanguageCode != targetCode else { return }

        let rawSummary = report.summary ?? ""
        let summaryText = rawSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let hadSummary = !summaryText.isEmpty

        do {
            let client = try GeminiClient()
            let prompt: String
            let userMessage: String
            if hadSummary {
                prompt = GeminiPrompts.translateReportTitleAndSummaryPrompt(targetLanguageCode: targetCode)
                userMessage = "TITLE: \(report.title)\n\nSUMMARY:\n\(rawSummary)"
            } else {
                prompt = GeminiPrompts.translateReportTitleOnlyPrompt(targetLanguageCode: targetCode)
                userMessage = "TITLE: \(report.title)"
            }

            let out = try await client.AI_Response(
                text: userMessage,
                prompt: prompt,
                images: nil,
                maxOutputTokens: 2048
            )
            try Task.checkCancellation()

            if hadSummary {
                let (newTitle, newSummary) = parseTitleAndSummary(from: out, fallbackTitle: report.title, fallbackSummary: report.summary ?? "")
                report.title = newTitle.isEmpty ? report.title : ReportTitleRules.clamp(newTitle)
                report.summary = newSummary.isEmpty ? report.summary : newSummary
            } else {
                let line = out.split(separator: "\n").map(String.init).first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    report.title = ReportTitleRules.clamp(trimmed)
                }
            }

            report.contentLanguageCode = targetCode
            if persistChanges {
                try? modelContext.save()
            }
        } catch is CancellationError {
            // Aborted by a newer language-change task; leave stored data unchanged.
        } catch {
            // Keep existing text; user may be offline or over quota — will retry on next open or language change.
        }
    }

    private static func parseTitleAndSummary(from aiOutput: String, fallbackTitle: String, fallbackSummary: String) -> (String, String) {
        let lines = aiOutput.components(separatedBy: .newlines)
        let titleIdx = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? 0
        let rawTitle = lines[titleIdx].trimmingCharacters(in: .whitespacesAndNewlines)
        let title = rawTitle.isEmpty ? fallbackTitle : rawTitle
        let summaryStartIdx = lines[(titleIdx + 1)...].firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? (titleIdx + 1)
        let summary = lines[summaryStartIdx...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (title, summary.isEmpty ? fallbackSummary : summary)
    }
}
