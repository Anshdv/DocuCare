import SwiftUI
import SwiftData
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

/// Main calendar screen.
///
/// Layout (top → bottom):
/// 1. Month header with prev / next chevrons and "today" pill.
/// 2. 7-column month grid; each cell shows the day number and tiny colored dots
///    indicating which categories of events live on that day.
/// 3. Scrollable list of the *selected* day's items, grouped:
///    - Medications (with big "Mark taken" toggles, color-coded per pill)
///    - Appointments / vaccinations / wellness / measurements
/// 4. Two big "Add" buttons at the bottom (medication, event).
///
/// All typography is intentionally larger than the rest of the app to suit
/// elderly users with reduced near vision.
struct CalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var session: SessionManager

    // Powers the month-grid dots; the per-day list view re-fetches through
    // `CalendarService` so it always sees the freshest writes.
    @Query private var allEvents: [CalendarEvent]
    @Query private var allSchedules: [MedicationSchedule]
    @Query private var allLogs: [MedicationLog]   // observed so taken/skipped toggles redraw cells

    @State private var displayedMonth: Date = Date()
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())

    @State private var showingAddMedication = false
    @State private var showingAddEvent = false
    @State private var editingSchedule: MedicationSchedule? = nil
    @State private var editingEvent: CalendarEvent? = nil

    @State private var notificationStatus: UNAuthorizationStatusWrapper = .unknown
    @State private var pendingDeleteEvent: CalendarEvent? = nil
    @State private var pendingDeleteSchedule: MedicationSchedule? = nil

    private var lang: String { session.effectiveLanguageCode() }
    private var owner: String { session.email.lowercased() }
    private var locale: Locale { Locale(identifier: AppLanguage.localeIdentifier(from: lang)) }
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = locale
        c.timeZone = .current
        return c
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        monthGridCard
                        if notificationStatus == .denied {
                            notificationPermissionBanner
                        }
                        selectedDaySection
                        upcomingSection
                        addButtonsRow
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .preferredColorScheme(.light)
            .toolbarColorScheme(.light, for: .navigationBar)
            .navigationTitle(L10n.string(.calendarNavTitle, languageCode: lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string(.calendarDone, languageCode: lang)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let today = calendar.startOfDay(for: Date())
                        displayedMonth = today
                        selectedDay = today
                    } label: {
                        Text(L10n.string(.calendarToday, languageCode: lang))
                    }
                }
            }
            .sheet(isPresented: $showingAddMedication) {
                AddMedicationView()
                    .environmentObject(session)
            }
            .sheet(isPresented: $showingAddEvent) {
                AddCalendarEventView(initialDate: selectedDay)
                    .environmentObject(session)
            }
            .sheet(item: $editingSchedule) { schedule in
                AddMedicationView(existing: schedule)
                    .environmentObject(session)
            }
            .sheet(item: $editingEvent) { event in
                AddCalendarEventView(existing: event)
                    .environmentObject(session)
            }
            .task {
                await refreshNotificationStatus()
            }
            // Touch `allLogs.count` so SwiftData re-runs the body when a dose is marked
            // taken / skipped (the per-day list re-fetches through CalendarService).
            .id("\(lang)-\(session.localizationRevision)-\(allLogs.count)-\(allEvents.count)-\(allSchedules.count)")
            .alert(
                L10n.string(.calendarDeleteEventTitle, languageCode: lang),
                isPresented: Binding(
                    get: { pendingDeleteEvent != nil },
                    set: { if !$0 { pendingDeleteEvent = nil } }
                ),
                presenting: pendingDeleteEvent
            ) { event in
                Button(L10n.string(.delete, languageCode: lang), role: .destructive) {
                    CalendarService.deleteEvent(event, in: context)
                    pendingDeleteEvent = nil
                }
                Button(L10n.string(.cancel, languageCode: lang), role: .cancel) {
                    pendingDeleteEvent = nil
                }
            } message: { _ in
                Text(L10n.string(.calendarDeleteEventMessage, languageCode: lang))
            }
            .alert(
                L10n.string(.calendarDeleteMedTitle, languageCode: lang),
                isPresented: Binding(
                    get: { pendingDeleteSchedule != nil },
                    set: { if !$0 { pendingDeleteSchedule = nil } }
                ),
                presenting: pendingDeleteSchedule
            ) { schedule in
                Button(L10n.string(.delete, languageCode: lang), role: .destructive) {
                    CalendarService.deleteSchedule(schedule, in: context)
                    pendingDeleteSchedule = nil
                }
                Button(L10n.string(.cancel, languageCode: lang), role: .cancel) {
                    pendingDeleteSchedule = nil
                }
            } message: { _ in
                Text(L10n.string(.calendarDeleteMedMessage, languageCode: lang))
            }
        }
    }

    // MARK: - Month grid

    @ViewBuilder
    private var monthGridCard: some View {
        VStack(spacing: 14) {
            monthHeader
            weekdayLabels
            monthGrid
        }
        .padding(16)
        .appCardStyle()
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.softText)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(AppTheme.chipFill))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string(.calendarPrevMonth, languageCode: lang))

            Spacer()

            Text(monthTitle(displayedMonth))
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.softText)

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.softText)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(AppTheme.chipFill))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string(.calendarNextMonth, languageCode: lang))
        }
    }

    private var weekdayLabels: some View {
        HStack(spacing: 0) {
            ForEach(orderedWeekdaySymbols, id: \.self) { sym in
                Text(sym)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let days = monthGridDays
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, cellDay in
                if let day = cellDay {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 56)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let isToday = calendar.isDateInToday(day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let hasMeds = scheduleAppliesOn(day)
        let kinds = eventKinds(on: day)

        Button {
            selectedDay = day
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 17, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(dayNumberColor(isSelected: isSelected, isToday: isToday))
                    .frame(maxWidth: .infinity)
                HStack(spacing: 3) {
                    if hasMeds {
                        dot(color: medicationDotColor)
                    }
                    ForEach(kinds.prefix(3), id: \.self) { kind in
                        dot(color: Color(hex: kind.accentHex) ?? AppTheme.accent)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(dayCellBackground(isSelected: isSelected, isToday: isToday))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(dayCellStroke(isSelected: isSelected, isToday: isToday), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityDayLabel(day, hasMeds: hasMeds, kinds: kinds))
    }

    private func dot(color: Color) -> some View {
        Circle().fill(color).frame(width: 5, height: 5)
    }

    private func dayNumberColor(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return .white }
        if isToday { return AppTheme.accent }
        return AppTheme.softText
    }

    private func dayCellBackground(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return AppTheme.accent }
        if isToday { return AppTheme.accent.opacity(0.10) }
        return AppTheme.chipFill
    }

    private func dayCellStroke(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return AppTheme.accent }
        if isToday { return AppTheme.accent.opacity(0.5) }
        return AppTheme.cardStroke
    }

    // MARK: - Selected day section

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDayHeader)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.softText)
                .frame(maxWidth: .infinity, alignment: .leading)

            let doses = CalendarService.doses(ownerEmail: owner, on: selectedDay, in: context)
            let events = CalendarService.events(ownerEmail: owner, on: selectedDay, in: context)

            if doses.isEmpty && events.isEmpty {
                emptyDayCard
            } else {
                if !doses.isEmpty {
                    sectionHeader(L10n.string(.calendarSectionMedications, languageCode: lang), icon: "pills.fill")
                    VStack(spacing: 10) {
                        ForEach(doses) { occurrence in
                            doseRow(occurrence)
                        }
                    }
                }
                if !events.isEmpty {
                    sectionHeader(L10n.string(.calendarSectionEvents, languageCode: lang), icon: "calendar")
                        .padding(.top, doses.isEmpty ? 0 : 6)
                    VStack(spacing: 10) {
                        ForEach(events) { event in
                            eventRow(event)
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.accent)
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.softText)
            Spacer()
        }
    }

    private var emptyDayCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.secondaryText.opacity(0.65))
            Text(L10n.string(.calendarNoEventsTitle, languageCode: lang))
                .font(.headline)
                .foregroundStyle(AppTheme.softText)
            Text(L10n.string(.calendarNoEventsSubtitle, languageCode: lang))
                .font(.callout)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .appCardStyle()
    }

    @ViewBuilder
    private func doseRow(_ occurrence: CalendarService.DoseOccurrence) -> some View {
        let schedule = occurrence.schedule
        let accent = Color(hex: schedule.colorHex) ?? AppTheme.accent

        HStack(alignment: .center, spacing: 14) {
            // Color stripe + pill icon
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.18))
                Image(systemName: "pills.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.softText)
                    .lineLimit(2)
                if !schedule.dosageInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(schedule.dosageInstructions)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                }
                Text(formatTime(occurrence.dueDateTime))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.softText)
            }

            Spacer(minLength: 8)

            doseStatusButton(occurrence)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.chipFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        )
        .contextMenu {
            Button {
                editingSchedule = schedule
            } label: {
                Label(L10n.string(.calendarEditMedication, languageCode: lang), systemImage: "square.and.pencil")
            }
            Button(role: .destructive) {
                pendingDeleteSchedule = schedule
            } label: {
                Label(L10n.string(.calendarDeleteMedication, languageCode: lang), systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func doseStatusButton(_ occurrence: CalendarService.DoseOccurrence) -> some View {
        Menu {
            Button {
                CalendarService.setStatus(for: occurrence, status: .taken, ownerEmail: owner, in: context)
            } label: {
                Label(L10n.string(.calendarMarkTaken, languageCode: lang), systemImage: "checkmark.circle.fill")
            }
            Button {
                CalendarService.setStatus(for: occurrence, status: .skipped, ownerEmail: owner, in: context)
            } label: {
                Label(L10n.string(.calendarMarkSkipped, languageCode: lang), systemImage: "xmark.circle.fill")
            }
            if occurrence.status != nil {
                Divider()
                Button {
                    CalendarService.setStatus(for: occurrence, status: nil, ownerEmail: owner, in: context)
                } label: {
                    Label(L10n.string(.calendarUndoDose, languageCode: lang), systemImage: "arrow.uturn.backward")
                }
            }
        } label: {
            doseStatusLabel(for: occurrence)
        }
    }

    @ViewBuilder
    private func doseStatusLabel(for occurrence: CalendarService.DoseOccurrence) -> some View {
        switch occurrence.status {
        case .taken:
            statusPill(
                title: L10n.string(.calendarStatusTaken, languageCode: lang),
                systemImage: "checkmark.circle.fill",
                fg: .white,
                bg: Color(red: 0.20, green: 0.65, blue: 0.34)
            )
        case .skipped:
            statusPill(
                title: L10n.string(.calendarStatusSkipped, languageCode: lang),
                systemImage: "xmark.circle.fill",
                fg: .white,
                bg: Color(red: 0.78, green: 0.36, blue: 0.36)
            )
        case .none:
            statusPill(
                title: L10n.string(.calendarStatusTake, languageCode: lang),
                systemImage: "circle",
                fg: AppTheme.accent,
                bg: AppTheme.accent.opacity(0.12)
            )
        }
    }

    private func statusPill(title: String, systemImage: String, fg: Color, bg: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(fg)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(bg))
    }

    @ViewBuilder
    private func eventRow(_ event: CalendarEvent) -> some View {
        let accent = Color(hex: event.kind.accentHex) ?? AppTheme.accent

        Button {
            editingEvent = event
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accent.opacity(0.18))
                    Image(systemName: event.kind.systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.softText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Text(eventKindTitle(event.kind))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(accent.opacity(0.18)))
                            .foregroundStyle(accent)
                        Text(event.hasTime ? formatTime(event.startDate) : L10n.string(.calendarAllDay, languageCode: lang))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    let trimmedLocation = event.location.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedLocation.isEmpty {
                        Label(trimmedLocation, systemImage: "mappin.and.ellipse")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)
                    }
                    let trimmedNotes = event.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedNotes.isEmpty {
                        Text(trimmedNotes)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(3)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.75))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.chipFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                pendingDeleteEvent = event
            } label: {
                Label(L10n.string(.calendarDeleteEvent, languageCode: lang), systemImage: "trash")
            }
        }
    }

    // MARK: - Upcoming

    @ViewBuilder
    private var upcomingSection: some View {
        let upcoming = CalendarService.upcomingEvents(ownerEmail: owner, limit: 3, in: context)
            .filter { !calendar.isDate($0.startDate, inSameDayAs: selectedDay) }
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(L10n.string(.calendarSectionUpcoming, languageCode: lang), icon: "clock")
                VStack(spacing: 10) {
                    ForEach(upcoming) { event in
                        upcomingRow(event)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private func upcomingRow(_ event: CalendarEvent) -> some View {
        let accent = Color(hex: event.kind.accentHex) ?? AppTheme.accent
        return Button {
            selectedDay = calendar.startOfDay(for: event.startDate)
            displayedMonth = event.startDate
        } label: {
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text(shortMonth(event.startDate))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                        .textCase(.uppercase)
                    Text("\(calendar.component(.day, from: event.startDate))")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.softText)
                }
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accent.opacity(0.15))
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.softText)
                        .lineLimit(1)
                    Text(event.hasTime ? formatDateTime(event.startDate) : formatDate(event.startDate))
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.65))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.chipFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add buttons

    private var addButtonsRow: some View {
        HStack(spacing: 12) {
            Button {
                showingAddMedication = true
            } label: {
                Label(L10n.string(.calendarAddMedication, languageCode: lang), systemImage: "pills.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                showingAddEvent = true
            } label: {
                Label(L10n.string(.calendarAddEvent, languageCode: lang), systemImage: "calendar.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.top, 8)
    }

    private var notificationPermissionBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 22))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.string(.calendarNotifPermTitle, languageCode: lang))
                    .font(.headline)
                    .foregroundStyle(AppTheme.softText)
                Text(L10n.string(.calendarNotifPermMessage, languageCode: lang))
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    openSettings()
                } label: {
                    Text(L10n.string(.calendarOpenSettings, languageCode: lang))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppTheme.accent))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }

    private func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    // MARK: - Helpers

    private var medicationDotColor: Color { Color(red: 0.20, green: 0.65, blue: 0.34) }

    private func shiftMonth(by delta: Int) {
        if let new = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = new
        }
    }

    private func monthTitle(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = locale
        df.setLocalizedDateFormatFromTemplate("yMMMM")
        return df.string(from: date)
    }

    private var orderedWeekdaySymbols: [String] {
        let df = DateFormatter()
        df.locale = locale
        let raw = df.veryShortStandaloneWeekdaySymbols ?? df.shortWeekdaySymbols ?? []
        let firstWeekday = calendar.firstWeekday
        guard !raw.isEmpty else { return [] }
        let offset = firstWeekday - 1
        return Array(raw[offset...] + raw[..<offset])
    }

    /// Returns the days that fill the visible month grid, with `nil` for leading
    /// blanks before the 1st of the month.
    private var monthGridDays: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstOfMonth = interval.start
        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        let firstWeekday = calendar.firstWeekday
        let leading = (weekdayOfFirst - firstWeekday + 7) % 7
        let range = calendar.range(of: .day, in: .month, for: displayedMonth) ?? (1..<31)
        let dayCount = range.count

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            if let date = calendar.date(byAdding: .day, value: offset, to: firstOfMonth) {
                cells.append(calendar.startOfDay(for: date))
            }
        }
        // Pad to a multiple of 7.
        let remainder = cells.count % 7
        if remainder != 0 {
            cells.append(contentsOf: Array(repeating: nil, count: 7 - remainder))
        }
        return cells
    }

    private func scheduleAppliesOn(_ day: Date) -> Bool {
        for schedule in allSchedules where schedule.ownerEmail == owner {
            if schedule.applies(on: day, calendar: calendar) { return true }
        }
        return false
    }

    private func eventKinds(on day: Date) -> [CalendarEventKind] {
        let kinds = allEvents
            .filter { $0.ownerEmail == owner && calendar.isDate($0.startDate, inSameDayAs: day) }
            .map(\.kind)
        // Deduplicate, preserving insertion order.
        var seen: Set<String> = []
        var out: [CalendarEventKind] = []
        for k in kinds where !seen.contains(k.rawValue) {
            seen.insert(k.rawValue)
            out.append(k)
        }
        return out
    }

    private var selectedDayHeader: String {
        let df = DateFormatter()
        df.locale = locale
        df.setLocalizedDateFormatFromTemplate("EEEEMMMd")
        let base = df.string(from: selectedDay)
        if calendar.isDateInToday(selectedDay) {
            return "\(L10n.string(.calendarToday, languageCode: lang)) · \(base)"
        }
        return base
    }

    private func formatTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = locale
        df.setLocalizedDateFormatFromTemplate("jm")
        return df.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = locale
        df.setLocalizedDateFormatFromTemplate("MMMd")
        return df.string(from: date)
    }

    private func formatDateTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = locale
        df.setLocalizedDateFormatFromTemplate("MMMd jm")
        return df.string(from: date)
    }

    private func shortMonth(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = locale
        df.setLocalizedDateFormatFromTemplate("MMM")
        return df.string(from: date)
    }

    private func eventKindTitle(_ kind: CalendarEventKind) -> String {
        switch kind {
        case .appointment: return L10n.string(.calendarKindAppointment, languageCode: lang)
        case .vaccination: return L10n.string(.calendarKindVaccination, languageCode: lang)
        case .wellness: return L10n.string(.calendarKindWellness, languageCode: lang)
        case .measurement: return L10n.string(.calendarKindMeasurement, languageCode: lang)
        case .other: return L10n.string(.calendarKindOther, languageCode: lang)
        }
    }

    private func accessibilityDayLabel(_ day: Date, hasMeds: Bool, kinds: [CalendarEventKind]) -> String {
        let df = DateFormatter()
        df.locale = locale
        df.dateStyle = .full
        var pieces: [String] = [df.string(from: day)]
        if hasMeds { pieces.append(L10n.string(.calendarA11yHasMeds, languageCode: lang)) }
        if !kinds.isEmpty { pieces.append(L10n.string(.calendarA11yHasEvents, languageCode: lang)) }
        return pieces.joined(separator: ", ")
    }

    private func refreshNotificationStatus() async {
        let status = await NotificationService.authorizationStatus()
        switch status {
        case .denied:
            notificationStatus = .denied
        case .authorized, .provisional, .ephemeral:
            notificationStatus = .authorized
        default:
            notificationStatus = .unknown
        }
    }

    enum UNAuthorizationStatusWrapper {
        case unknown, authorized, denied
    }
}

// MARK: - Color hex utility

extension Color {
    /// Parses a `#RRGGBB` or `#RRGGBBAA` hex string. Returns `nil` for malformed input.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }
        var value: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&value) else { return nil }
        let r, g, b, a: Double
        if s.count == 6 {
            r = Double((value & 0xFF0000) >> 16) / 255.0
            g = Double((value & 0x00FF00) >> 8) / 255.0
            b = Double(value & 0x0000FF) / 255.0
            a = 1.0
        } else {
            r = Double((value & 0xFF000000) >> 24) / 255.0
            g = Double((value & 0x00FF0000) >> 16) / 255.0
            b = Double((value & 0x0000FF00) >> 8) / 255.0
            a = Double(value & 0x000000FF) / 255.0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
