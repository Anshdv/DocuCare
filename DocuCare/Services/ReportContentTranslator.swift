import Foundation
import SwiftData

@MainActor
enum ReportContentTranslator {
    /// Rewrites `title` and `summary` into `targetCode` when they are not already stored in that language.
    /// - Note: Passes `reportID` (not a live model) so work survives `ModelContext.reset` when SwiftUI rebuilds after language changes.
    /// - Note: Gemini runs in `Task.detached` so `await` does **not** release MainActor while the store has
    ///   unsaved edits; otherwise `loadReport` / other MainActor code can `fetch` the same `ModelContext` and SwiftData may trap (`EXC_BREAKPOINT`).
    static func alignLanguage(
        reportID: UUID,
        to targetCode: String,
        modelContext: ModelContext
    ) async {
        guard let reportBefore = report(reportID: reportID, in: modelContext),
              reportBefore.contentLanguageCode != targetCode else { return }

        let rawSummary = reportBefore.summary ?? ""
        let summaryText = rawSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        let hadSummary = !summaryText.isEmpty
        let titleSnapshot = reportBefore.title

        let prompt: String
        let userMessage: String
        if hadSummary {
            prompt = GeminiPrompts.translateReportTitleAndSummaryPrompt(targetLanguageCode: targetCode)
            userMessage = "TITLE: \(titleSnapshot)\n\nSUMMARY:\n\(rawSummary)"
        } else {
            prompt = GeminiPrompts.translateReportTitleOnlyPrompt(targetLanguageCode: targetCode)
            userMessage = "TITLE: \(titleSnapshot)"
        }

        let out: String
        do {
            try Task.checkCancellation()
            out = try await Task.detached(priority: .userInitiated) { @Sendable in
                let client = try GeminiClient()
                return try await client.AI_Response(
                    text: userMessage,
                    prompt: prompt,
                    images: nil,
                    maxOutputTokens: 2048
                )
            }.value
            try Task.checkCancellation()
        } catch is CancellationError {
            // Aborted by a newer language-change task; leave stored data unchanged.
            return
        } catch {
            // Keep existing text; user may be offline or over quota — will retry on next open or language change.
            return
        }

        applyTranslationOutput(
            reportID: reportID,
            out: out,
            hadSummary: hadSummary,
            targetCode: targetCode,
            modelContext: modelContext
        )
    }

    /// Fetch → mutate → save with **no** `await` in between (MainActor reentrancy / SwiftData traps otherwise).
    private static func applyTranslationOutput(
        reportID: UUID,
        out: String,
        hadSummary: Bool,
        targetCode: String,
        modelContext: ModelContext
    ) {
        guard let report = report(reportID: reportID, in: modelContext) else { return }
        guard report.contentLanguageCode != targetCode else { return }

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
        try? modelContext.save()
    }

    private static func report(reportID: UUID, in modelContext: ModelContext) -> MedicalReport? {
        try? MedicalReport.fetchByID(reportID, in: modelContext)
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
