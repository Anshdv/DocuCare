import SwiftUI

/// Celebration screen shown after the third question in a `DailyLesson` is answered,
/// and also as a standalone "streak overview" when the user taps the flame badge on the
/// reports toolbar.
///
/// - `streak`: the user's saved streak. `nil` means "no row yet" → render zeros.
/// - `correctCount` / `totalQuestions`: only set when arriving from the quiz; together they
///   drive the score card. When either is `nil`, the score card is hidden.
/// - `streakIncreased`: `true` only after a quiz that bumped today's streak — drives the
///   "new personal best" badge.
/// - `onStartLesson`: when set (standalone overview), shows a "Start today's lesson" button
///   if today's lesson hasn't been completed yet.
struct StreakSummaryView: View {
    @EnvironmentObject private var session: SessionManager

    let streak: LessonStreak?
    let correctCount: Int?
    let totalQuestions: Int?
    let streakIncreased: Bool
    var onStartLesson: (() -> Void)?
    var onDone: () -> Void

    init(
        streak: LessonStreak?,
        correctCount: Int? = nil,
        totalQuestions: Int? = nil,
        streakIncreased: Bool = false,
        onStartLesson: (() -> Void)? = nil,
        onDone: @escaping () -> Void
    ) {
        self.streak = streak
        self.correctCount = correctCount
        self.totalQuestions = totalQuestions
        self.streakIncreased = streakIncreased
        self.onStartLesson = onStartLesson
        self.onDone = onDone
    }

    @State private var animateFlame: Bool = false

    private var lang: String { session.effectiveLanguageCode() }

    private var currentStreak: Int { streak?.currentStreak ?? 0 }
    private var longestStreak: Int { streak?.longestStreak ?? 0 }
    private var totalLessonsCompleted: Int { streak?.totalLessonsCompleted ?? 0 }

    private var isNewRecord: Bool {
        longestStreak > 0 && currentStreak == longestStreak && streakIncreased
    }

    private var showsScoreCard: Bool {
        correctCount != nil && totalQuestions != nil
    }

    private var completedToday: Bool {
        streak?.lastCompletedDateKey == DailyLessonService.todayKey()
    }

    /// Standalone overview + lesson not yet done today → offer to start it.
    private var showsStartLessonButton: Bool {
        onStartLesson != nil && !completedToday
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView {
                VStack(spacing: 24) {
                    flameHero
                    if showsScoreCard {
                        scoreCard
                    }
                    statsCard
                    if showsStartLessonButton {
                        startLessonButton
                    } else {
                        comeBackCard
                    }
                    doneButton
                    Spacer(minLength: 32)
                }
                .padding(.horizontal)
                .padding(.top, 24)
            }
        }
        .preferredColorScheme(.light)
        .toolbarColorScheme(.light, for: .navigationBar)
        .navigationTitle(L10n.string(.dailyLessonNavTitle, languageCode: lang))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) {
                animateFlame = true
            }
        }
    }

    // MARK: - Subviews

    private var flameHero: some View {
        VStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(animateFlame ? 1.0 : 0.6)
                .opacity(animateFlame ? 1.0 : 0.0)
                .shadow(color: .orange.opacity(0.45), radius: 16, y: 4)

            Text("\(currentStreak)")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.softText)
                .contentTransition(.numericText(value: Double(currentStreak)))

            Text(L10n.string(.dailyLessonStreakDayUnit, languageCode: lang))
                .font(.headline)
                .foregroundStyle(AppTheme.secondaryText)
                .textCase(.lowercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 18)
        .appCardStyle()
    }

    @ViewBuilder
    private var scoreCard: some View {
        if let correct = correctCount, let total = totalQuestions {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
                Text(L10n.lessonScore(correct: correct, total: total, languageCode: lang))
                    .font(.headline)
                    .foregroundStyle(AppTheme.softText)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .appCardStyle()
        }
    }

    private var statsCard: some View {
        VStack(spacing: 0) {
            statRow(
                label: L10n.string(.dailyLessonStreakCurrent, languageCode: lang),
                value: "\(currentStreak)"
            )
            Divider().padding(.horizontal, 4)
            statRow(
                label: L10n.string(.dailyLessonStreakLongest, languageCode: lang),
                value: "\(longestStreak)",
                trailing: isNewRecord ? L10n.string(.dailyLessonStreakNewRecord, languageCode: lang) : nil
            )
            Divider().padding(.horizontal, 4)
            statRow(
                label: L10n.string(.dailyLessonStreakTotal, languageCode: lang),
                value: "\(totalLessonsCompleted)"
            )
        }
        .padding(.vertical, 6)
        .appCardStyle()
    }

    @ViewBuilder
    private func statRow(label: String, value: String, trailing: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.body)
                .foregroundStyle(AppTheme.softText)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.softText)
                if let t = trailing {
                    Text(t)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var comeBackCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.and.horizon.fill")
                .foregroundStyle(AppTheme.accent)
            Text(L10n.string(.dailyLessonComeBackTomorrow, languageCode: lang))
                .font(.callout)
                .foregroundStyle(AppTheme.softText)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(14)
        .appCardStyle()
    }

    private var startLessonButton: some View {
        Button {
            onStartLesson?()
        } label: {
            Label(
                L10n.string(.streakStartTodaysLesson, languageCode: lang),
                systemImage: "book.fill"
            )
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private var doneButton: some View {
        Button {
            onDone()
        } label: {
            Label(L10n.string(.dailyLessonDone, languageCode: lang), systemImage: "checkmark")
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}
