import SwiftUI
import SwiftData

/// Sheet for creating or editing a `CalendarEvent` (appointment, vaccination, wellness
/// reminder, at-home measurement, etc).
struct AddCalendarEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var session: SessionManager

    private let editing: CalendarEvent?
    private let initialDate: Date

    @State private var title: String = ""
    @State private var kind: CalendarEventKind = .appointment
    @State private var date: Date = Date()
    @State private var hasTime: Bool = true
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var reminderOption: ReminderOption = .at

    @State private var showingDeleteConfirm = false

    init(existing: CalendarEvent? = nil, initialDate: Date = Date()) {
        self.editing = existing
        self.initialDate = initialDate
    }

    private var lang: String { session.effectiveLanguageCode() }
    private var locale: Locale { Locale(identifier: AppLanguage.localeIdentifier(from: lang)) }
    private var isEditing: Bool { editing != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                Form {
                    titleSection
                    kindSection
                    dateSection
                    locationSection
                    reminderSection
                    notesSection
                    if isEditing {
                        deleteSection
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .preferredColorScheme(.light)
            .tint(AppTheme.accent)
            .navigationTitle(L10n.string(
                isEditing ? .calendarEventFormEditTitle : .calendarEventFormAddTitle,
                languageCode: lang
            ))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string(.cancel, languageCode: lang)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.string(.calendarMedFormSave, languageCode: lang)) {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                    .bold()
                }
            }
            .onAppear { hydrateFromExisting() }
            .alert(
                L10n.string(.calendarDeleteEventTitle, languageCode: lang),
                isPresented: $showingDeleteConfirm
            ) {
                Button(L10n.string(.delete, languageCode: lang), role: .destructive) {
                    if let event = editing {
                        CalendarService.deleteEvent(event, in: context)
                    }
                    dismiss()
                }
                Button(L10n.string(.cancel, languageCode: lang), role: .cancel) {}
            } message: {
                Text(L10n.string(.calendarDeleteEventMessage, languageCode: lang))
            }
            .id("\(lang)-\(session.localizationRevision)")
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        Section {
            TextField(
                "",
                text: $title,
                prompt: Text(L10n.string(.calendarEventFormTitlePlaceholder, languageCode: lang))
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.9))
            )
            .foregroundStyle(AppTheme.softText)
            .listRowBackground(AppTheme.chipFill)
        } header: {
            Text(L10n.string(.calendarEventFormDetailsHeader, languageCode: lang))
                .foregroundStyle(AppTheme.softText)
        }
    }

    private var kindSection: some View {
        Section {
            ForEach(CalendarEventKind.allCases) { option in
                Button {
                    kind = option
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: option.systemImage)
                            .foregroundStyle(Color(hex: option.accentHex) ?? AppTheme.accent)
                            .frame(width: 24)
                        Text(kindTitle(option))
                            .foregroundStyle(AppTheme.softText)
                        Spacer()
                        if kind == option {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppTheme.accent)
                                .bold()
                        }
                    }
                }
                .listRowBackground(AppTheme.chipFill)
            }
        } header: {
            Text(L10n.string(.calendarEventFormKindHeader, languageCode: lang))
                .foregroundStyle(AppTheme.softText)
        }
    }

    private var dateSection: some View {
        Section {
            Toggle(
                L10n.string(.calendarEventFormAllDay, languageCode: lang),
                isOn: Binding(
                    get: { !hasTime },
                    set: { hasTime = !$0 }
                )
            )
            .foregroundStyle(AppTheme.softText)
            .listRowBackground(AppTheme.chipFill)

            DatePicker(
                L10n.string(.calendarEventFormDate, languageCode: lang),
                selection: $date,
                displayedComponents: hasTime ? [.date, .hourAndMinute] : .date
            )
            .environment(\.locale, locale)
            .foregroundStyle(AppTheme.softText)
            .listRowBackground(AppTheme.chipFill)
        } header: {
            Text(L10n.string(.calendarEventFormDateHeader, languageCode: lang))
                .foregroundStyle(AppTheme.softText)
        }
    }

    private var locationSection: some View {
        Section {
            TextField(
                "",
                text: $location,
                prompt: Text(L10n.string(.calendarEventFormLocationPlaceholder, languageCode: lang))
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.9))
            )
            .foregroundStyle(AppTheme.softText)
            .listRowBackground(AppTheme.chipFill)
        } header: {
            Text(L10n.string(.calendarEventFormLocationHeader, languageCode: lang))
                .foregroundStyle(AppTheme.softText)
        }
    }

    private var reminderSection: some View {
        Section {
            Picker(
                L10n.string(.calendarEventFormReminder, languageCode: lang),
                selection: $reminderOption
            ) {
                ForEach(ReminderOption.allCases) { option in
                    Text(reminderTitle(option, hasTime: hasTime))
                        .tag(option)
                }
            }
            .foregroundStyle(AppTheme.softText)
            .listRowBackground(AppTheme.chipFill)
        } header: {
            Text(L10n.string(.calendarEventFormReminderHeader, languageCode: lang))
                .foregroundStyle(AppTheme.softText)
        }
    }

    private var notesSection: some View {
        Section {
            TextField(
                "",
                text: $notes,
                prompt: Text(L10n.string(.calendarMedFormNotesPlaceholder, languageCode: lang))
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.9)),
                axis: .vertical
            )
            .lineLimit(2...5)
            .foregroundStyle(AppTheme.softText)
            .listRowBackground(AppTheme.chipFill)
        } header: {
            Text(L10n.string(.calendarMedFormNotesHeader, languageCode: lang))
                .foregroundStyle(AppTheme.softText)
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                HStack {
                    Spacer()
                    Label(
                        L10n.string(.calendarDeleteEvent, languageCode: lang),
                        systemImage: "trash"
                    )
                    Spacer()
                }
            }
            .listRowBackground(AppTheme.chipFill)
        }
    }

    // MARK: - Logic

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func kindTitle(_ kind: CalendarEventKind) -> String {
        switch kind {
        case .appointment: return L10n.string(.calendarKindAppointment, languageCode: lang)
        case .vaccination: return L10n.string(.calendarKindVaccination, languageCode: lang)
        case .wellness: return L10n.string(.calendarKindWellness, languageCode: lang)
        case .measurement: return L10n.string(.calendarKindMeasurement, languageCode: lang)
        case .other: return L10n.string(.calendarKindOther, languageCode: lang)
        }
    }

    enum ReminderOption: String, CaseIterable, Identifiable, Hashable {
        case none
        case at
        case fifteen
        case thirty
        case oneHour
        case oneDay

        var id: String { rawValue }

        var minutesBefore: Int? {
            switch self {
            case .none: return nil
            case .at: return 0
            case .fifteen: return 15
            case .thirty: return 30
            case .oneHour: return 60
            case .oneDay: return 60 * 24
            }
        }

        static func from(minutes: Int?) -> ReminderOption {
            guard let m = minutes else { return .none }
            switch m {
            case 0: return .at
            case 15: return .fifteen
            case 30: return .thirty
            case 60: return .oneHour
            case 60 * 24: return .oneDay
            default: return .at
            }
        }
    }

    private func reminderTitle(_ option: ReminderOption, hasTime: Bool) -> String {
        switch option {
        case .none: return L10n.string(.calendarEventReminderNone, languageCode: lang)
        case .at:
            return hasTime
                ? L10n.string(.calendarEventReminderAtTime, languageCode: lang)
                : L10n.string(.calendarEventReminderOnDay, languageCode: lang)
        case .fifteen: return L10n.string(.calendarEventReminder15Min, languageCode: lang)
        case .thirty: return L10n.string(.calendarEventReminder30Min, languageCode: lang)
        case .oneHour: return L10n.string(.calendarEventReminder1Hour, languageCode: lang)
        case .oneDay: return L10n.string(.calendarEventReminder1Day, languageCode: lang)
        }
    }

    private func hydrateFromExisting() {
        if let existing = editing {
            title = existing.title
            kind = existing.kind
            date = existing.startDate
            hasTime = existing.hasTime
            location = existing.location
            notes = existing.notes
            reminderOption = ReminderOption.from(minutes: existing.reminderMinutesBefore)
        } else {
            // Anchor to the selected day in the calendar grid; if it's today, snap to
            // the next half-hour so the user almost never has to scroll the time picker.
            let cal = Calendar.current
            if cal.isDateInToday(initialDate) {
                date = nextHalfHour(from: Date())
            } else {
                var comps = cal.dateComponents([.year, .month, .day], from: initialDate)
                comps.hour = 9
                comps.minute = 0
                date = cal.date(from: comps) ?? initialDate
            }
        }
    }

    private func nextHalfHour(from now: Date) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let minute = comps.minute ?? 0
        if minute < 30 {
            comps.minute = 30
        } else {
            comps.hour = (comps.hour ?? 0) + 1
            comps.minute = 0
        }
        return cal.date(from: comps) ?? now
    }

    private func save() async {
        let owner = session.email.lowercased()
        guard !owner.isEmpty else {
            dismiss()
            return
        }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedDate: Date = {
            if hasTime { return date }
            return Calendar.current.startOfDay(for: date)
        }()

        if let existing = editing {
            existing.title = trimmedTitle
            existing.kind = kind
            existing.startDate = resolvedDate
            existing.hasTime = hasTime
            existing.location = trimmedLocation
            existing.notes = trimmedNotes
            existing.reminderMinutesBefore = reminderOption.minutesBefore
            await CalendarService.updateEvent(existing, in: context)
        } else {
            let event = CalendarEvent(
                ownerEmail: owner,
                title: trimmedTitle,
                notes: trimmedNotes,
                location: trimmedLocation,
                startDate: resolvedDate,
                hasTime: hasTime,
                kind: kind,
                reminderMinutesBefore: reminderOption.minutesBefore
            )
            await CalendarService.createEvent(event, in: context)
        }
        dismiss()
    }
}
