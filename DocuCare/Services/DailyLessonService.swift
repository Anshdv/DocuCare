import Foundation
import SwiftData

/// Generates, caches, and scores daily health-education lessons.
///
/// `ensureTodaysLesson` is the main entry point: it returns a cached `DailyLesson` for
/// `(ownerEmail, today)` if one exists, otherwise calls Gemini to generate a fresh one.
/// All persistence goes through `ModelContext` so it stays consistent with the rest of the app.
@MainActor
enum DailyLessonService {

    // MARK: - Errors

    enum ServiceError: LocalizedError {
        case missingEmail
        case invalidGeminiResponse
        case wrongQuestionCount(Int)

        var errorDescription: String? {
            switch self {
            case .missingEmail: return "No signed-in user."
            case .invalidGeminiResponse: return "The lesson server returned an unreadable response."
            case .wrongQuestionCount(let n): return "Expected 3 questions, got \(n)."
            }
        }
    }

    // MARK: - Date keys

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func todayKey(now: Date = Date()) -> String {
        dateKeyFormatter.string(from: now)
    }

    static func yesterdayKey(now: Date = Date()) -> String {
        let cal = Calendar.current
        let y = cal.date(byAdding: .day, value: -1, to: now) ?? now
        return dateKeyFormatter.string(from: y)
    }

    // MARK: - Fetching / caching

    /// Returns a cached lesson for today if present; otherwise generates one via Gemini and saves it.
    static func ensureTodaysLesson(
        ownerEmail: String,
        languageCode: String,
        in context: ModelContext
    ) async throws -> DailyLesson {
        let owner = ownerEmail.lowercased()
        guard !owner.isEmpty else { throw ServiceError.missingEmail }
        let today = todayKey()

        if let cached = try fetchLesson(ownerEmail: owner, dateKey: today, in: context) {
            return cached
        }

        let client = try GeminiClient()
        let prompt = GeminiPrompts.dailyHealthLessonPrompt(appLanguageCode: languageCode, dateKey: today)
        let raw = try await client.AI_Response(
            text: "Generate today's lesson now.",
            prompt: prompt,
            maxOutputTokens: 1500
        )
        let payload = try parseLessonJSON(raw)

        let lesson = DailyLesson(
            dateKey: today,
            ownerEmail: owner,
            languageCode: languageCode,
            topic: payload.topic,
            articleMarkdown: payload.article,
            questionsJSON: LessonQuestionCoder.encode(payload.questions)
        )
        context.insert(lesson)
        try? context.save()
        return lesson
    }

    static func fetchLesson(
        ownerEmail: String,
        dateKey: String,
        in context: ModelContext
    ) throws -> DailyLesson? {
        let owner = ownerEmail.lowercased()
        let descriptor = FetchDescriptor<DailyLesson>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let rows = try context.fetch(descriptor)
        return rows.first { $0.ownerEmail == owner && $0.dateKey == dateKey }
    }

    static func fetchOrCreateStreak(
        ownerEmail: String,
        in context: ModelContext
    ) throws -> LessonStreak {
        let owner = ownerEmail.lowercased()
        let descriptor = FetchDescriptor<LessonStreak>()
        let rows = try context.fetch(descriptor)
        if let existing = rows.first(where: { $0.ownerEmail == owner }) {
            return existing
        }
        let streak = LessonStreak(ownerEmail: owner)
        context.insert(streak)
        try? context.save()
        return streak
    }

    // MARK: - Scoring & streak updates

    /// Records an answer for question at `index`. Idempotent-ish: bumping the same question twice
    /// after a correct answer won't double-count, because the view layer disables the choice row.
    static func recordAnswer(
        lesson: DailyLesson,
        question: LessonQuestion,
        chosenIndex: Int,
        in context: ModelContext
    ) {
        if chosenIndex == question.safeCorrectIndex {
            lesson.answeredCorrectlyCount = min(lesson.answeredCorrectlyCount + 1, lesson.questions.count)
        }
        try? context.save()
    }

    /// Marks the lesson completed (attempted all 3) and advances the streak per the rules:
    /// last == today → no-op; last == yesterday → ++; otherwise → reset to 1.
    @discardableResult
    static func completeLesson(
        lesson: DailyLesson,
        ownerEmail: String,
        in context: ModelContext
    ) throws -> LessonStreak {
        if lesson.completedAt == nil {
            lesson.completedAt = Date()
        }
        let streak = try fetchOrCreateStreak(ownerEmail: ownerEmail, in: context)
        let today = todayKey()
        let yesterday = yesterdayKey()

        if streak.lastCompletedDateKey == today {
            // Already counted for today.
        } else {
            if streak.lastCompletedDateKey == yesterday {
                streak.currentStreak += 1
            } else {
                streak.currentStreak = 1
            }
            streak.longestStreak = max(streak.longestStreak, streak.currentStreak)
            streak.lastCompletedDateKey = today
            streak.totalLessonsCompleted += 1
        }
        try? context.save()
        return streak
    }

    // MARK: - Ownership migration (for email changes)

    static func migrateOwnership(
        from oldEmail: String,
        to newEmail: String,
        in context: ModelContext
    ) {
        let from = oldEmail.lowercased()
        let to = newEmail.lowercased()
        guard from != to, !from.isEmpty, !to.isEmpty else { return }

        if let lessons = try? context.fetch(FetchDescriptor<DailyLesson>()) {
            for lesson in lessons where lesson.ownerEmail == from {
                lesson.ownerEmail = to
            }
        }

        if let streaks = try? context.fetch(FetchDescriptor<LessonStreak>()) {
            let movingFrom = streaks.first(where: { $0.ownerEmail == from })
            let existingAtNew = streaks.first(where: { $0.ownerEmail == to })

            switch (movingFrom, existingAtNew) {
            case (nil, _):
                break
            case (let src?, nil):
                src.ownerEmail = to
            case (let src?, let dst?):
                // New account already has a streak (rare). Keep whichever is longer; drop the other.
                if src.currentStreak > dst.currentStreak ||
                   (src.currentStreak == dst.currentStreak && src.longestStreak > dst.longestStreak) {
                    context.delete(dst)
                    src.ownerEmail = to
                } else {
                    context.delete(src)
                }
            }
        }
        try? context.save()
    }

    // MARK: - JSON parsing

    private struct LessonPayload {
        let topic: String
        let article: String
        let questions: [LessonQuestion]
    }

    private struct LessonPayloadDTO: Decodable {
        let topic: String
        let article: String
        let questions: [QuestionDTO]

        struct QuestionDTO: Decodable {
            let prompt: String
            let choices: [String]
            let correctIndex: Int
            let explanation: String
        }
    }

    private static func parseLessonJSON(_ raw: String) throws -> LessonPayload {
        let cleaned = stripMarkdownFences(raw)
        guard let data = cleaned.data(using: .utf8) else {
            throw ServiceError.invalidGeminiResponse
        }
        let dto: LessonPayloadDTO
        do {
            dto = try JSONDecoder().decode(LessonPayloadDTO.self, from: data)
        } catch {
            print("DailyLessonService JSON decode failed:", error, "raw:", cleaned)
            throw ServiceError.invalidGeminiResponse
        }
        guard dto.questions.count == 3 else {
            throw ServiceError.wrongQuestionCount(dto.questions.count)
        }
        let questions = dto.questions.map { q in
            LessonQuestion(
                prompt: q.prompt,
                choices: q.choices,
                correctIndex: q.correctIndex,
                explanation: q.explanation
            )
        }
        return LessonPayload(topic: dto.topic, article: dto.article, questions: questions)
    }

    /// Gemini occasionally wraps JSON in ```json ... ``` fences despite instructions otherwise; strip them.
    private static func stripMarkdownFences(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            if let firstNewline = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNewline)...])
            }
        }
        if s.hasSuffix("```") {
            s = String(s.dropLast(3))
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
