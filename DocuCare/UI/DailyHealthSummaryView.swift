import SwiftUI

/// AI-generated daily wellness summary built from the user's Apple Health snapshot.
/// Presented as a sheet from the home screen; only reachable when the user has
/// connected DocuCare to Apple Health.
struct DailyHealthSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager

    @State private var summary: String?
    @State private var isLoading: Bool = false
    @State private var loadError: String?

    private var lang: String { session.effectiveLanguageCode() }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if isLoading {
                            loadingCard
                        } else if let summary = summary {
                            summaryCard(summary)
                            disclaimerCard
                        } else if let err = loadError {
                            errorCard(message: err)
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
            }
            .preferredColorScheme(.light)
            .toolbarColorScheme(.light, for: .navigationBar)
            .navigationTitle(L10n.string(.healthSummaryNavTitle, languageCode: lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string(.dailyLessonDone, languageCode: lang)) {
                        dismiss()
                    }
                }
            }
            .task {
                await generateSummary()
            }
        }
    }

    // MARK: - Subviews

    private var loadingCard: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppTheme.accent)
            Text(L10n.string(.healthSummaryGenerating, languageCode: lang))
                .font(.callout)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 18)
        .appCardStyle()
    }

    private func summaryCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart.text.square.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accent)
                Text(L10n.string(.healthSummaryNavTitle, languageCode: lang))
                    .font(.headline)
                    .foregroundStyle(AppTheme.softText)
            }
            Text(text)
                .font(.body)
                .foregroundStyle(AppTheme.softText)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .appCardStyle()
    }

    private var disclaimerCard: some View {
        Text(L10n.string(.aiDisclaimer, languageCode: lang))
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryText)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private func errorCard(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text(L10n.string(.healthSummaryFailed, languageCode: lang))
                .font(.headline)
                .foregroundStyle(AppTheme.softText)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
            Button(L10n.string(.dailyLessonRetry, languageCode: lang)) {
                Task { await generateSummary() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 4)
        }
        .padding(20)
        .appCardStyle()
    }

    // MARK: - Data

    private func generateSummary() async {
        guard summary == nil else { return }
        isLoading = true
        loadError = nil

        let snapshot = await HealthKitService.shared.fetchSnapshot()
        guard let block = snapshot.aiContextBlock() else {
            loadError = L10n.string(.healthSummaryEmpty, languageCode: lang)
            isLoading = false
            return
        }

        do {
            let client = try GeminiClient()
            let prompt = GeminiPrompts.dailyHealthSummaryPrompt(appLanguageCode: lang)
            let userMessage = """
            PATIENT HEALTH CONTEXT (from Apple Health, shared by the patient):
            \(block)
            """
            let text = try await client.AI_Response(
                text: userMessage,
                prompt: prompt,
                maxOutputTokens: 2048
            )
            guard !text.isEmpty else { throw GeminiClient.ClientError.emptyOutput }
            summary = text
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}
