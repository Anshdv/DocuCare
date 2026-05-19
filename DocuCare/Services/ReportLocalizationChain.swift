import Foundation
import SwiftData

/// Serializes report title/summary localization across the whole app.
///
/// An `actor` is **not** enough here: each `await alignLanguage(...)` **suspends** the actor, so a
/// second caller (e.g. open report detail while ContentView is batch-translating) can start another
/// `alignLanguage` overlapping the first—SwiftData then may trap (`EXC_BREAKPOINT`).
///
/// Instead we chain `Task { @MainActor in ... }` work so the next job starts only after the previous
/// fully completes, including all nested `await`s.
@MainActor
enum ReportLocalizationChain {
    private static var tail: Task<Void, Never>?

    private static func runSerialized(_ operation: @escaping @MainActor () async -> Void) async {
        let previous = tail
        let next = Task { @MainActor in
            await previous?.value
            await operation()
        }
        tail = next
        await next.value
    }

    /// Batch-align many reports (each translation persists in `alignLanguage`).
    static func synchronizeOwnedReports(_ reportIDs: [UUID], targetCode: String, modelContext: ModelContext) async {
        await runSerialized {
            for reportID in reportIDs {
                try? Task.checkCancellation()
                await ReportContentTranslator.alignLanguage(
                    reportID: reportID,
                    to: targetCode,
                    modelContext: modelContext
                )
            }
            try? Task.checkCancellation()
        }
    }

    /// Align a single report (e.g. detail screen).
    static func synchronizeReport(reportID: UUID, targetCode: String, modelContext: ModelContext) async {
        await runSerialized {
            try? Task.checkCancellation()
            await ReportContentTranslator.alignLanguage(
                reportID: reportID,
                to: targetCode,
                modelContext: modelContext
            )
        }
    }
}
