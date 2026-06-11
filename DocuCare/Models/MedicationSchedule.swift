import Foundation
import SwiftData

/// A recurring medication regimen owned by one user account.
///
/// Doses are not pre-materialized — they're derived for any given day from
/// `(timesPerDayMinutes, daysOfWeekMask, startDate, endDate)`. Actual "taken /
/// skipped" marks live in `MedicationLog`, keyed by `(scheduleID, dueDateTime)`.
@Model
final class MedicationSchedule {
    @Attribute(.unique) var id: UUID
    var ownerEmail: String

    /// Display name (e.g. "Lisinopril 10 mg").
    var name: String
    /// Free-form dosage / instruction text (e.g. "1 tablet with water").
    var dosageInstructions: String
    /// Optional prescribing-doctor / pharmacy note.
    var notes: String

    /// Minutes past midnight (0–1439) at which each daily dose is due, sorted ascending.
    /// JSON-encoded to keep SwiftData's nested-collection support simple.
    var timesJSON: String

    /// Bitmask over weekdays (`1 << (weekday - 1)`, matching `Calendar.component(.weekday, ...)`
    /// where Sunday == 1). `0b1111111` (127) means every day.
    var daysOfWeekMask: Int

    /// First day this schedule applies (midnight local).
    var startDate: Date
    /// Last day (midnight local) the schedule applies, inclusive. `nil` means ongoing.
    var endDate: Date?

    var remindersEnabled: Bool

    /// Hex string used to color-code rows in the daily list.
    var colorHex: String

    var createdAt: Date

    init(
        id: UUID = UUID(),
        ownerEmail: String,
        name: String,
        dosageInstructions: String = "",
        notes: String = "",
        timesMinutes: [Int],
        daysOfWeekMask: Int = MedicationSchedule.everyDayMask,
        startDate: Date,
        endDate: Date? = nil,
        remindersEnabled: Bool = true,
        colorHex: String = "#2F6FE6",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.ownerEmail = ownerEmail
        self.name = name
        self.dosageInstructions = dosageInstructions
        self.notes = notes
        self.timesJSON = MedicationSchedule.encodeTimes(timesMinutes)
        self.daysOfWeekMask = daysOfWeekMask
        self.startDate = startDate
        self.endDate = endDate
        self.remindersEnabled = remindersEnabled
        self.colorHex = colorHex
        self.createdAt = createdAt
    }

    // MARK: - Derived

    /// All dose offsets (minutes past midnight) in ascending order.
    var timesMinutes: [Int] {
        Self.decodeTimes(timesJSON)
    }

    static let everyDayMask: Int = 0b111_1111

    static func encodeTimes(_ minutes: [Int]) -> String {
        let normalized = minutes.map { max(0, min(1439, $0)) }.sorted()
        let data = (try? JSONEncoder().encode(normalized)) ?? Data("[]".utf8)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func decodeTimes(_ json: String) -> [Int] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONDecoder().decode([Int].self, from: data) else {
            return []
        }
        return arr.map { max(0, min(1439, $0)) }.sorted()
    }

    /// Returns true if this schedule has a dose on `day` (midnight in local TZ).
    func applies(on day: Date, calendar: Calendar = .current) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        if dayStart < calendar.startOfDay(for: startDate) { return false }
        if let end = endDate, dayStart > calendar.startOfDay(for: end) { return false }
        let weekday = calendar.component(.weekday, from: dayStart)
        let bit = 1 << (weekday - 1)
        return (daysOfWeekMask & bit) != 0
    }
}
