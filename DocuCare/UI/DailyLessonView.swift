import SwiftUI
import SwiftData

/// Entry screen for the gamified daily health-education feature.
///
/// Flow:
/// 1. On appear, look up today's `DailyLesson` for the signed-in user; if absent, ask Gemini for one.
/// 2. Show the article + topic + streak chip.
/// 3. "Start Quiz" pushes `LessonQuizView` for the 3 MCQs.
struct DailyLessonView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var session: SessionManager

    @State private var lesson: DailyLesson?
    @State private var streak: LessonStreak?
    @State private var isLoading: Bool = false
    @State private var loadError: String?
    @State private var showingQuiz: Bool = false

    private var lang: String { session.effectiveLanguageCode() }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        streakChip
                        if isLoading {
                            loadingCard
                        } else if let lesson = lesson {
                            lessonCard(lesson)
                            disclaimerCard
                            startQuizButton(lesson: lesson)
                        } else if let err = loadError {
                            errorCard(message: err)
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .preferredColorScheme(.light)
            .toolbarColorScheme(.light, for: .navigationBar)
            .navigationTitle(L10n.string(.dailyLessonNavTitle, languageCode: lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string(.dailyLessonDone, languageCode: lang)) {
                        dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: $showingQuiz) {
                if let lesson = lesson {
                    LessonQuizView(lesson: lesson) {
                        // On finish, refresh the streak snapshot from disk.
                        refreshStreak()
                    }
                    .environmentObject(session)
                }
            }
            .task {
                await loadLesson()
            }
            .id("\(lang)-\(session.localizationRevision)")
        }
    }

    // MARK: - Subviews

    private var streakChip: some View {
        HStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(streakFlameColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(displayStreak)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.softText)
                Text(L10n.string(.dailyLessonStreakBadge, languageCode: lang))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
        }
        .padding(14)
        .appCardStyle()
    }

    @ViewBuilder
    private var loadingCard: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppTheme.accent)
            Text(L10n.string(.dailyLessonGenerating, languageCode: lang))
                .font(.callout)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 18)
        .appCardStyle()
    }

    @ViewBuilder
    private func lessonCard(_ lesson: DailyLesson) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string(.dailyLessonTodaysTopic, languageCode: lang))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .textCase(.uppercase)
            Text(lesson.topic)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.softText)
                .fixedSize(horizontal: false, vertical: true)
            Text(lesson.articleMarkdown)
                .font(.body)
                .foregroundStyle(AppTheme.softText)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if lesson.isCompleted {
                Label(
                    L10n.string(.dailyLessonAlreadyCompleted, languageCode: lang),
                    systemImage: "checkmark.seal.fill"
                )
                .font(.footnote)
                .foregroundStyle(AppTheme.accent)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .appCardStyle()
    }

    private var disclaimerCard: some View {
        Text(L10n.string(.dailyLessonDisclaimer, languageCode: lang))
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryText)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func startQuizButton(lesson: DailyLesson) -> some View {
        Button {
            showingQuiz = true
        } label: {
            Label(L10n.string(.dailyLessonStartQuiz, languageCode: lang), systemImage: "questionmark.app.fill")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(lesson.isCompleted)
        .opacity(lesson.isCompleted ? 0.6 : 1.0)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func errorCard(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text(L10n.string(.dailyLessonGenerationFailed, languageCode: lang))
                .font(.headline)
                .foregroundStyle(AppTheme.softText)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
            Button(L10n.string(.dailyLessonRetry, languageCode: lang)) {
                Task { await loadLesson(forceRefresh: true) }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 4)
        }
        .padding(20)
        .appCardStyle()
    }

    // MARK: - Streak display

    private var displayStreak: Int {
        guard let streak = streak else { return 0 }
        return streak.displayStreak(
            todayKey: DailyLessonService.todayKey(),
            yesterdayKey: DailyLessonService.yesterdayKey()
        )
    }

    private var streakFlameColor: Color {
        displayStreak > 0 ? .orange : AppTheme.secondaryText.opacity(0.5)
    }

    // MARK: - Data

    private func loadLesson(forceRefresh: Bool = false) async {
        let email = session.email
        guard !email.isEmpty else {
            loadError = "Not signed in."
            return
        }
        isLoading = true
        loadError = nil
        if forceRefresh { lesson = nil }
        do {
            let owner = email.lowercased()
            let fetched = try await DailyLessonService.ensureTodaysLesson(
                ownerEmail: owner,
                languageCode: lang,
                in: context
            )
            lesson = fetched
            refreshStreak()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    private func refreshStreak() {
        let email = session.email.lowercased()
        guard !email.isEmpty else { return }
        streak = try? DailyLessonService.fetchOrCreateStreak(ownerEmail: email, in: context)
    }
}
