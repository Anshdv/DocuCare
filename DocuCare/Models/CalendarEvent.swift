import Foundation
import SwiftData

/// A single non-medication entry in the user's health calendar.
///
/// Covers things like doctor visits, vaccinations, lab work, wellness reminders
/// (walk, hydration), and at-home measurements (blood pressure, glucose). Medication
/// doses live in `MedicationSchedule` / `MedicationLog` because they recur on a
/// fixed daily pattern and need separate "taken / skipped" bookkeeping.
@Model
final class CalendarEvent {
    @Attribute(.unique) var id: UUID
    var ownerEmail: String

    var title: String
    var notes: String
    var location: String

    /// Date (and, if `hasTime`, time) the event is scheduled for. All-day events use
    /// midnight in the device's current time zone so day comparisons work cleanly.
    var startDate: Date
    /// `false` when the event is all-day (only the calendar day matters).
    var hasTime: Bool

    /// Raw value of `CalendarEventKind`. Stored as a string so the DB schema stays
    /// stable if we add or rename kinds later.
    var kindRaw: String

    /// Minutes before `startDate` at which to post a local notification. `nil` or `0`
    /// disables reminders. The actual scheduling is done by `NotificationService`.
    var reminderMinutesBefore: Int?

    var createdAt: Date

    init(
        id: UUID = UUID(),
        ownerEmail: String,
        title: String,
        notes: String = "",
        location: String = "",
        startDate: Date,
        hasTime: Bool = true,
        kind: CalendarEventKind = .appointment,
        reminderMinutesBefore: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.ownerEmail = ownerEmail
        self.title = title
        self.notes = notes
        self.location = location
        self.startDate = startDate
        self.hasTime = hasTime
        self.kindRaw = kind.rawValue
        self.reminderMinutesBefore = reminderMinutesBefore
        self.createdAt = createdAt
    }

    var kind: CalendarEventKind {
        get { CalendarEventKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }
}

/// Categorizes calendar entries for filtering and color-coding. Keep raw values stable
/// since they're persisted; localize the display name via `L10n`.
enum CalendarEventKind: String, CaseIterable, Identifiable {
    case appointment
    case vaccination
    case wellness
    case measurement
    case other

    var id: String { rawValue }

    /// SF Symbol used in calendar rows and pickers.
    var systemImage: String {
        switch self {
        case .appointment: return "stethoscope"
        case .vaccination: return "syringe.fill"
        case .wellness: return "heart.circle.fill"
        case .measurement: return "waveform.path.ecg"
        case .other: return "calendar.badge.clock"
        }
    }

    /// Accent color used to badge events; intentionally distinct from medication blue.
    var accentHex: String {
        switch self {
        case .appointment: return "#2F6FE6"
        case .vaccination: return "#3FA34D"
        case .wellness: return "#E08A2B"
        case .measurement: return "#A04CCF"
        case .other: return "#5C6770"
        }
    }
}
