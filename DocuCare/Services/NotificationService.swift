import Foundation
import UserNotifications

/// Thin wrapper around `UNUserNotificationCenter` for the calendar feature.
///
/// We keep this here (rather than directly in views) so:
/// - authorization is requested in exactly one place,
/// - notification identifiers follow a predictable scheme that makes
///   "cancel everything for this schedule" trivial,
/// - tests / previews can stub it later if needed.
@MainActor
enum NotificationService {

    // MARK: - Identifier scheme
    //
    // Medication doses: "med.<scheduleID>.<HHmm>.<weekday(1...7)>"
    //   One repeating notification per weekday × per dose time. iOS handles the recurrence
    //   automatically with `UNCalendarNotificationTrigger(repeats: true)`.
    //
    // Calendar events: "evt.<eventID>"
    //   Single fire at (startDate - reminderMinutesBefore).

    static func medicationIdentifier(scheduleID: UUID, minutes: Int, weekday: Int) -> String {
        let hh = minutes / 60
        let mm = minutes % 60
        return String(format: "med.%@.%02d%02d.%d", scheduleID.uuidString, hh, mm, weekday)
    }

    static func eventIdentifier(eventID: UUID) -> String {
        "evt.\(eventID.uuidString)"
    }

    // MARK: - Authorization

    /// Requests permission if it hasn't been determined yet. Safe to call repeatedly; it
    /// only prompts the user the first time.
    static func ensureAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Medication scheduling

    /// Schedules repeating reminders for every weekday × dose time enabled on this
    /// schedule. Idempotent: any previously scheduled notifications for the same
    /// `scheduleID` are removed first.
    static func rescheduleMedicationReminders(for schedule: MedicationSchedule) async {
        cancelMedicationReminders(scheduleID: schedule.id)

        guard schedule.remindersEnabled else { return }
        guard await ensureAuthorization() else { return }

        let times = schedule.timesMinutes
        guard !times.isEmpty else { return }
        let mask = schedule.daysOfWeekMask

        let center = UNUserNotificationCenter.current()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        for weekday in 1...7 {
            let bit = 1 << (weekday - 1)
            guard (mask & bit) != 0 else { continue }
            for minutes in times {
                let id = medicationIdentifier(scheduleID: schedule.id, minutes: minutes, weekday: weekday)
                let content = UNMutableNotificationContent()
                content.title = schedule.name
                let body: String = {
                    let dose = schedule.dosageInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
                    if dose.isEmpty {
                        return formatDoseTime(minutes)
                    }
                    return "\(dose) • \(formatDoseTime(minutes))"
                }()
                content.body = body
                content.sound = .default
                content.userInfo = [
                    "kind": "medication",
                    "scheduleID": schedule.id.uuidString,
                    "minutes": minutes,
                    "weekday": weekday
                ]

                var components = DateComponents()
                components.weekday = weekday
                components.hour = minutes / 60
                components.minute = minutes % 60
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                do {
                    try await center.add(request)
                } catch {
                    // Soft-fail; reminders are best-effort, the app shouldn't crash.
                    print("NotificationService: failed to schedule \(id):", error)
                }
            }
        }
    }

    /// Removes any pending dose reminders for `scheduleID` (across all weekdays/times).
    static func cancelMedicationReminders(scheduleID: UUID) {
        let prefix = "med.\(scheduleID.uuidString)."
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
    }

    // MARK: - Calendar event scheduling

    /// Schedules a single one-shot reminder at `event.startDate - reminderMinutesBefore`.
    /// Skips scheduling if reminder time is already in the past.
    static func rescheduleEventReminder(for event: CalendarEvent) async {
        cancelEventReminder(eventID: event.id)
        guard let minutesBefore = event.reminderMinutesBefore, minutesBefore >= 0 else { return }
        guard await ensureAuthorization() else { return }

        let fireDate = event.startDate.addingTimeInterval(TimeInterval(-minutesBefore * 60))
        guard fireDate > Date() else { return }

        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = eventReminderBody(event)
        content.sound = .default
        content.userInfo = ["kind": "event", "eventID": event.id.uuidString]

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let comps = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: eventIdentifier(eventID: event.id),
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
        } catch {
            print("NotificationService: failed to schedule event reminder:", error)
        }
    }

    static func cancelEventReminder(eventID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [eventIdentifier(eventID: eventID)])
    }

    // MARK: - Helpers

    private static func formatDoseTime(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        let df = DateFormatter()
        df.locale = Locale.current
        df.setLocalizedDateFormatFromTemplate("jm")
        var comps = DateComponents()
        comps.hour = h
        comps.minute = m
        let date = Calendar.current.date(from: comps) ?? Date()
        return df.string(from: date)
    }

    private static func eventReminderBody(_ event: CalendarEvent) -> String {
        let df = DateFormatter()
        df.locale = Locale.current
        if event.hasTime {
            df.setLocalizedDateFormatFromTemplate("MMMd jm")
        } else {
            df.setLocalizedDateFormatFromTemplate("MMMd")
        }
        var pieces: [String] = [df.string(from: event.startDate)]
        let loc = event.location.trimmingCharacters(in: .whitespacesAndNewlines)
        if !loc.isEmpty {
            pieces.append(loc)
        }
        return pieces.joined(separator: " • ")
    }
}
