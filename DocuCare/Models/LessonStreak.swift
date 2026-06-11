import Foundation
import SwiftData

/// Tracks a single user's lifetime streak across `DailyLesson` completions.
///
/// One row per account (`ownerEmail` is the unique key). All date math is done by comparing
/// `"yyyy-MM-dd"` strings in device-local time — keeping it dead-simple and avoiding
/// time-zone drift inside `Date`.
@Model
final class LessonStreak {
    @Attribute(.unique) var ownerEmail: String
    var currentStreak: Int
    var longestStreak: Int
    /// `"yyyy-MM-dd"` of the most recent day the user finished a lesson, or `nil` if none.
    var lastCompletedDateKey: String?
    var totalLessonsCompleted: Int

    init(
        ownerEmail: String,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastCompletedDateKey: String? = nil,
        totalLessonsCompleted: Int = 0
    ) {
        self.ownerEmail = ownerEmail
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastCompletedDateKey = lastCompletedDateKey
        self.totalLessonsCompleted = totalLessonsCompleted
    }

    /// Streak number to display on the toolbar badge: returns 0 if `lastCompletedDateKey`
    /// is neither today nor yesterday (streak is effectively broken until the next completion).
    func displayStreak(todayKey: String, yesterdayKey: String) -> Int {
        guard let last = lastCompletedDateKey else { return 0 }
        if last == todayKey || last == yesterdayKey {
            return currentStreak
        }
        return 0
    }
}
