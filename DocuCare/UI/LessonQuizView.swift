import SwiftUI
import SwiftData

/// 3-question MCQ flow for a `DailyLesson`. One question per screen with instant feedback.
/// On finishing question 3, runs `DailyLessonService.completeLesson` and pushes `StreakSummaryView`.
struct LessonQuizView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager

    let lesson: DailyLesson
    var onFinish: () -> Void = {}

    @State private var currentIndex: Int = 0
    @State private var selectedChoiceIndex: Int? = nil
    @State private var hasRevealedAnswer: Bool = false
    @State private var correctCount: Int = 0
    @State private var showingSummary: Bool = false
    @State private var summaryStreak: LessonStreak?
    @State private var streakIncreasedFromPrevious: Bool = false

    private var lang: String { session.effectiveLanguageCode() }
    private var questions: [LessonQuestion] { lesson.questions }

    private var currentQuestion: LessonQuestion? {
        guard currentIndex >= 0 && currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var body: some View {
        ZStack {
            AppBackgroundView()
            if let q = currentQuestion {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        progressHeader
                        questionCard(q)
                        choicesList(for: q)
                        if hasRevealedAnswer {
                            feedbackCard(for: q)
                            nextButton
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .animation(.easeOut(duration: 0.2), value: hasRevealedAnswer)
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                ProgressView()
                    .tint(AppTheme.accent)
            }
        }
        .preferredColorScheme(.light)
        .toolbarColorScheme(.light, for: .navigationBar)
        .navigationTitle(L10n.string(.dailyLessonNavTitle, languageCode: lang))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingSummary) {
            if let s = summaryStreak {
                StreakSummaryView(
                    streak: s,
                    correctCount: correctCount,
                    totalQuestions: questions.count,
                    streakIncreased: streakIncreasedFromPrevious
                ) {
                    onFinish()
                    dismiss()
                }
                .environmentObject(session)
            }
        }
    }

    // MARK: - Subviews

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                L10n.questionProgress(
                    current: currentIndex + 1,
                    total: questions.count,
                    languageCode: lang
                )
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.secondaryText)
            .textCase(.uppercase)

            ProgressView(
                value: Double(currentIndex) + (hasRevealedAnswer ? 1 : 0),
                total: Double(questions.count)
            )
            .progressViewStyle(.linear)
            .tint(AppTheme.accent)
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func questionCard(_ q: LessonQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(q.prompt)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.softText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .appCardStyle()
    }

    @ViewBuilder
    private func choicesList(for q: LessonQuestion) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(q.choices.enumerated()), id: \.offset) { idx, choice in
                choiceRow(idx: idx, label: choice, question: q)
            }
        }
    }

    @ViewBuilder
    private func choiceRow(idx: Int, label: String, question: LessonQuestion) -> some View {
        let isSelected = selectedChoiceIndex == idx
        let isCorrect = idx == question.safeCorrectIndex

        Button {
            guard !hasRevealedAnswer else { return }
            selectedChoiceIndex = idx
            hasRevealedAnswer = true
            if isCorrect {
                correctCount += 1
            }
            DailyLessonService.recordAnswer(
                lesson: lesson,
                question: question,
                chosenIndex: idx,
                in: context
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: choiceIconName(isSelected: isSelected, isCorrect: isCorrect))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(choiceIconColor(isSelected: isSelected, isCorrect: isCorrect))
                    .frame(width: 24)
                Text(label)
                    .font(.body)
                    .foregroundStyle(AppTheme.softText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(choiceBackground(isSelected: isSelected, isCorrect: isCorrect))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(choiceStroke(isSelected: isSelected, isCorrect: isCorrect), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(hasRevealedAnswer)
    }

    @ViewBuilder
    private func feedbackCard(for q: LessonQuestion) -> some View {
        let chosen = selectedChoiceIndex ?? -1
        let wasCorrect = chosen == q.safeCorrectIndex
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(wasCorrect ? .green : .red)
                Text(L10n.string(wasCorrect ? .dailyLessonCorrect : .dailyLessonIncorrect, languageCode: lang))
                    .font(.headline)
                    .foregroundStyle(AppTheme.softText)
            }
            Text(q.explanation)
                .font(.callout)
                .foregroundStyle(AppTheme.softText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle()
    }

    private var nextButton: some View {
        let isLast = currentIndex == questions.count - 1
        return Button {
            if isLast {
                finishQuiz()
            } else {
                advanceToNextQuestion()
            }
        } label: {
            Label(
                L10n.string(isLast ? .dailyLessonFinish : .dailyLessonNext, languageCode: lang),
                systemImage: isLast ? "checkmark.circle.fill" : "arrow.right.circle.fill"
            )
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    // MARK: - Styling helpers

    private func choiceIconName(isSelected: Bool, isCorrect: Bool) -> String {
        if hasRevealedAnswer {
            if isCorrect { return "checkmark.circle.fill" }
            if isSelected { return "xmark.circle.fill" }
            return "circle"
        }
        return isSelected ? "largecircle.fill.circle" : "circle"
    }

    private func choiceIconColor(isSelected: Bool, isCorrect: Bool) -> Color {
        if hasRevealedAnswer {
            if isCorrect { return .green }
            if isSelected { return .red }
            return AppTheme.secondaryText.opacity(0.6)
        }
        return isSelected ? AppTheme.accent : AppTheme.secondaryText
    }

    private func choiceBackground(isSelected: Bool, isCorrect: Bool) -> Color {
        if hasRevealedAnswer {
            if isCorrect { return Color.green.opacity(0.12) }
            if isSelected { return Color.red.opacity(0.10) }
            return AppTheme.chipFill
        }
        return AppTheme.chipFill
    }

    private func choiceStroke(isSelected: Bool, isCorrect: Bool) -> Color {
        if hasRevealedAnswer {
            if isCorrect { return .green.opacity(0.8) }
            if isSelected { return .red.opacity(0.8) }
            return Color(red: 0.80, green: 0.84, blue: 0.93)
        }
        return isSelected ? AppTheme.accent.opacity(0.7) : Color(red: 0.80, green: 0.84, blue: 0.93)
    }

    // MARK: - Flow

    private func advanceToNextQuestion() {
        selectedChoiceIndex = nil
        hasRevealedAnswer = false
        currentIndex += 1
    }

    private func finishQuiz() {
        let email = session.email.lowercased()
        let priorStreak = (try? DailyLessonService.fetchOrCreateStreak(
            ownerEmail: email,
            in: context
        ))?.currentStreak ?? 0

        do {
            let updated = try DailyLessonService.completeLesson(
                lesson: lesson,
                ownerEmail: email,
                in: context
            )
            summaryStreak = updated
            streakIncreasedFromPrevious = updated.currentStreak > priorStreak
            showingSummary = true
        } catch {
            // Still surface the summary even if streak persistence fails; defaults to zero.
            summaryStreak = LessonStreak(ownerEmail: email)
            streakIncreasedFromPrevious = false
            showingSummary = true
        }
    }
}
