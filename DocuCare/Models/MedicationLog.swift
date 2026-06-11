import Foundation
import SwiftData

/// One audit entry per dose the user explicitly acknowledges (taken or skipped).
///
/// Absent rows mean the dose hasn't been touched yet — we don't pre-create
/// pending rows for every scheduled time. The view computes "pending" vs "taken"
/// by looking up `(scheduleID, dueDateTime)` against the most recent log entry.
@Model
final class MedicationLog {
    @Attribute(.unique) var id: UUID
    var ownerEmail: String
    var scheduleID: UUID
    var dueDateTime: Date
    /// `MedicationDoseStatus.rawValue`.
    var statusRaw: String
    var loggedAt: Date

    init(
        id: UUID = UUID(),
        ownerEmail: String,
        scheduleID: UUID,
        dueDateTime: Date,
        status: MedicationDoseStatus,
        loggedAt: Date = Date()
    ) {
        self.id = id
        self.ownerEmail = ownerEmail
        self.scheduleID = scheduleID
        self.dueDateTime = dueDateTime
        self.statusRaw = status.rawValue
        self.loggedAt = loggedAt
    }

    var status: MedicationDoseStatus {
        get { MedicationDoseStatus(rawValue: statusRaw) ?? .taken }
        set { statusRaw = newValue.rawValue }
    }
}

enum MedicationDoseStatus: String, Codable {
    case taken
    case skipped
}
