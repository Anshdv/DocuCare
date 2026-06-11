import Foundation
import SwiftData

/// Owner-scoped queries and mutations for the calendar feature.
///
/// The view layer talks to this service instead of the `ModelContext` directly so
/// that local-notification side-effects (schedule / cancel) always travel with the
/// data change, and so the dose-materialization logic lives in exactly one place.
@MainActor
enum CalendarService {

    // MARK: - Day arithmetic

    static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func endOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        var comps = DateComponents()
        comps.day = 1
        comps.second = -1
        return calendar.date(byAdding: comps, to: startOfDay(date, calendar: calendar)) ?? date
    }

    // MARK: - Events

    /// All events for the signed-in user falling on `day` (local time), oldest first.
    static func events(ownerEmail: String, on day: Date, in context: ModelContext) -> [CalendarEvent] {
        let owner = ownerEmail.lowercased()
        let descriptor = FetchDescriptor<CalendarEvent>(
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        guard let rows = try? context.fetch(descriptor) else { return [] }
        let cal = Calendar.current
        let target = cal.startOfDay(for: day)
        return rows.filter { event in
            event.ownerEmail == owner && cal.startOfDay(for: event.startDate) == target
        }
    }

    /// Days in `[startDay, endDay]` (inclusive, midnight-aligned) that have at least
    /// one event. Used to paint dots on the month grid.
    static func eventDays(
        ownerEmail: String,
        from startDay: Date,
        to endDay: Date,
        in context: ModelContext
    ) -> Set<Date> {
        let owner = ownerEmail.lowercased()
        let descriptor = FetchDescriptor<CalendarEvent>()
        guard let rows = try? context.fetch(descriptor) else { return [] }
        let cal = Calendar.current
        let lower = cal.startOfDay(for: startDay)
        let upper = cal.startOfDay(for: endDay)
        var set: Set<Date> = []
        for event in rows where event.ownerEmail == owner {
            let day = cal.startOfDay(for: event.startDate)
            if day >= lower && day <= upper {
                set.insert(day)
            }
        }
        return set
    }

    static func upcomingEvents(
        ownerEmail: String,
        limit: Int = 5,
        from now: Date = Date(),
        in context: ModelContext
    ) -> [CalendarEvent] {
        let owner = ownerEmail.lowercased()
        let descriptor = FetchDescriptor<CalendarEvent>(
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )
        guard let rows = try? context.fetch(descriptor) else { return [] }
        return rows
            .filter { $0.ownerEmail == owner && $0.startDate >= now }
            .prefix(limit)
            .map { $0 }
    }

    static func createEvent(_ event: CalendarEvent, in context: ModelContext) async {
        context.insert(event)
        try? context.save()
        await NotificationService.rescheduleEventReminder(for: event)
    }

    /// Updates fields on an existing event and reschedules its notification.
    static func updateEvent(_ event: CalendarEvent, in context: ModelContext) async {
        try? context.save()
        await NotificationService.rescheduleEventReminder(for: event)
    }

    static func deleteEvent(_ event: CalendarEvent, in context: ModelContext) {
        NotificationService.cancelEventReminder(eventID: event.id)
        context.delete(event)
        try? context.save()
    }

    // MARK: - Medication schedules

    static func medicationSchedules(
        ownerEmail: String,
        in context: ModelContext
    ) -> [MedicationSchedule] {
        let owner = ownerEmail.lowercased()
        let descriptor = FetchDescriptor<MedicationSchedule>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let rows = try? context.fetch(descriptor) else { return [] }
        return rows.filter { $0.ownerEmail == owner }
    }

    static func createSchedule(_ schedule: MedicationSchedule, in context: ModelContext) async {
        context.insert(schedule)
        try? context.save()
        await NotificationService.rescheduleMedicationReminders(for: schedule)
    }

    static func updateSchedule(_ schedule: MedicationSchedule, in context: ModelContext) async {
        try? context.save()
        await NotificationService.rescheduleMedicationReminders(for: schedule)
    }

    static func deleteSchedule(_ schedule: MedicationSchedule, in context: ModelContext) {
        let id = schedule.id
        NotificationService.cancelMedicationReminders(scheduleID: id)
        // Drop accompanying logs so the trash icon really does "forget the medication".
        if let logs = try? context.fetch(FetchDescriptor<MedicationLog>()) {
            for log in logs where log.scheduleID == id {
                context.delete(log)
            }
        }
        context.delete(schedule)
        try? context.save()
    }

    // MARK: - Dose materialization

    /// A single concrete dose occurrence (schedule × time-on-day) with its current
    /// taken / skipped status, if any. Sorted ascending by `dueDateTime` from callers.
    struct DoseOccurrence: Identifiable, Hashable {
        let id: String
        let schedule: MedicationSchedule
        let dueDateTime: Date
        let log: MedicationLog?

        var status: MedicationDoseStatus? { log?.status }
        var isTaken: Bool { log?.status == .taken }
        var isSkipped: Bool { log?.status == .skipped }
    }

    /// All medication doses scheduled for `day` for the signed-in user, sorted by time
    /// of day. Each occurrence is paired with its `MedicationLog` if the user has
    /// already marked it taken / skipped.
    static func doses(
        ownerEmail: String,
        on day: Date,
        in context: ModelContext
    ) -> [DoseOccurrence] {
        let owner = ownerEmail.lowercased()
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)

        let schedules = medicationSchedules(ownerEmail: owner, in: context)
            .filter { $0.applies(on: dayStart, calendar: cal) }
        guard !schedules.isEmpty else { return [] }

        // Pull the day's logs once and index them in memory; avoids n × m fetches.
        let logs = (try? context.fetch(FetchDescriptor<MedicationLog>())) ?? []
        let nextDay = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let logsForDay = logs.filter { log in
            log.ownerEmail == owner &&
            log.dueDateTime >= dayStart && log.dueDateTime < nextDay
        }

        var occurrences: [DoseOccurrence] = []
        for schedule in schedules {
            for minutes in schedule.timesMinutes {
                guard let due = cal.date(
                    bySettingHour: minutes / 60,
                    minute: minutes % 60,
                    second: 0,
                    of: dayStart
                ) else { continue }
                let log = logsForDay.first {
                    $0.scheduleID == schedule.id &&
                    abs($0.dueDateTime.timeIntervalSince(due)) < 30
                }
                occurrences.append(DoseOccurrence(
                    id: "\(schedule.id.uuidString)-\(minutes)",
                    schedule: schedule,
                    dueDateTime: due,
                    log: log
                ))
            }
        }
        return occurrences.sorted { $0.dueDateTime < $1.dueDateTime }
    }

    /// Days with at least one scheduled dose (used to paint dots on the month grid).
    static func medicationDays(
        ownerEmail: String,
        from startDay: Date,
        to endDay: Date,
        in context: ModelContext
    ) -> Set<Date> {
        let owner = ownerEmail.lowercased()
        let schedules = medicationSchedules(ownerEmail: owner, in: context)
        guard !schedules.isEmpty else { return [] }
        let cal = Calendar.current
        var set: Set<Date> = []
        var day = cal.startOfDay(for: startDay)
        let last = cal.startOfDay(for: endDay)
        while day <= last {
            if schedules.contains(where: { $0.applies(on: day, calendar: cal) }) {
                set.insert(day)
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return set
    }

    // MARK: - Marking doses

    /// Records `status` for the given dose. Replaces any previous log entry for the
    /// same `(scheduleID, dueDateTime)` so a "taken" can be un-toggled cleanly.
    static func setStatus(
        for occurrence: DoseOccurrence,
        status: MedicationDoseStatus?,
        ownerEmail: String,
        in context: ModelContext
    ) {
        let owner = ownerEmail.lowercased()
        // Always remove existing log for this dose first, then optionally insert a new one.
        if let logs = try? context.fetch(FetchDescriptor<MedicationLog>()) {
            for log in logs where log.scheduleID == occurrence.schedule.id &&
                abs(log.dueDateTime.timeIntervalSince(occurrence.dueDateTime)) < 30 &&
                log.ownerEmail == owner {
                context.delete(log)
            }
        }
        if let status = status {
            let log = MedicationLog(
                ownerEmail: owner,
                scheduleID: occurrence.schedule.id,
                dueDateTime: occurrence.dueDateTime,
                status: status
            )
            context.insert(log)
        }
        try? context.save()
    }

    // MARK: - Ownership migration (for email changes)

    /// Re-points every owned `CalendarEvent`, `MedicationSchedule`, and `MedicationLog`
    /// from `oldEmail` to `newEmail`. Mirrors `DailyLessonService.migrateOwnership`.
    static func migrateOwnership(
        from oldEmail: String,
        to newEmail: String,
        in context: ModelContext
    ) {
        let from = oldEmail.lowercased()
        let to = newEmail.lowercased()
        guard from != to, !from.isEmpty, !to.isEmpty else { return }

        if let events = try? context.fetch(FetchDescriptor<CalendarEvent>()) {
            for e in events where e.ownerEmail == from { e.ownerEmail = to }
        }
        if let schedules = try? context.fetch(FetchDescriptor<MedicationSchedule>()) {
            for s in schedules where s.ownerEmail == from { s.ownerEmail = to }
        }
        if let logs = try? context.fetch(FetchDescriptor<MedicationLog>()) {
            for l in logs where l.ownerEmail == from { l.ownerEmail = to }
        }
        try? context.save()
    }
}
