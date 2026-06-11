import Foundation
import SwiftData

/// One day's gamified health-education lesson, scoped to a single user account.
///
/// `dateKey` is `"yyyy-MM-dd"` in the device's local time zone — the same key used by
/// `LessonStreak.lastCompletedDateKey` so streak math is a string comparison.
@Model
final class DailyLesson {
    @Attribute(.unique) var id: UUID
    var dateKey: String
    var ownerEmail: String
    /// Language at the time the lesson was generated (`AppLanguage.rawValue`).
    var languageCode: String
    var topic: String
    var articleMarkdown: String
    /// JSON-encoded `[LessonQuestion]`. See `LessonQuestionCoder`.
    var questionsJSON: String
    /// 0...3. Bumped each time the user answers a question correctly.
    var answeredCorrectlyCount: Int
    /// Set once when the user attempts all 3 questions, regardless of correctness.
    var completedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        dateKey: String,
        ownerEmail: String,
        languageCode: String,
        topic: String,
        articleMarkdown: String,
        questionsJSON: String,
        answeredCorrectlyCount: Int = 0,
        completedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.dateKey = dateKey
        self.ownerEmail = ownerEmail
        self.languageCode = languageCode
        self.topic = topic
        self.articleMarkdown = articleMarkdown
        self.questionsJSON = questionsJSON
        self.answeredCorrectlyCount = answeredCorrectlyCount
        self.completedAt = completedAt
        self.createdAt = createdAt
    }

    var questions: [LessonQuestion] {
        LessonQuestionCoder.decode(questionsJSON)
    }

    var isCompleted: Bool { completedAt != nil }
}
