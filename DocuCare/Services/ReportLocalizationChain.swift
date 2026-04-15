import Foundation
import SwiftData

/// Serializes report title/summary localization so SwiftData never sees concurrent `save()` calls
/// or overlapping Gemini updates for the same store.
actor ReportLocalizationChain {
    static let shared = ReportLocalizationChain()

    /// Batch-align many reports, persisting once at the end.
    func synchronizeOwnedReports(_ reports: [MedicalReport], targetCode: String, modelContext: ModelContext) async {
        let snapshot = reports.filter { $0.contentLanguageCode != targetCode }
        for report in snapshot {
            try? Task.checkCancellation()
            await ReportContentTranslator.alignLanguage(
                of: report,
                to: targetCode,
                modelContext: modelContext,
                persistChanges: false
            )
        }
        try? Task.checkCancellation()
        await MainActor.run {
            try? modelContext.save()
        }
    }

    /// Align a single report (e.g. detail screen), persisting when successful.
    func synchronizeReport(_ report: MedicalReport, targetCode: String, modelContext: ModelContext) async {
        guard report.contentLanguageCode != targetCode else { return }
        try? Task.checkCancellation()
        await ReportContentTranslator.alignLanguage(
            of: report,
            to: targetCode,
            modelContext: modelContext,
            persistChanges: true
        )
    }
}
