import SwiftUI
import SwiftData

/// Sheet for creating or editing a `MedicationSchedule`.
///
/// Same view handles both flows; pass `existing:` for edit mode (the model is mutated
/// in place so any open calendar rows reflect the change immediately).
struct AddMedicationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var session: SessionManager

    private let editing: MedicationSchedule?

    // MARK: - Form state

    @State private var name: String = ""
    @State private var dosage: String = ""
    @State private var notes: String = ""
    @State private var times: [Int] = [8 * 60]   // 8:00 AM default
    @State private var daysMask: Int = MedicationSchedule.everyDayMask
    @State private var startDate: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Date().addingTimeInterval(60 * 60 * 24 * 30)
    @State private var remindersEnabled: Bool = true
    @State private var colorHex: String = "#2F6FE6"

    @State private var showingDeleteConfirm = false

    init(existing: MedicationSchedule? = nil) {
        self.editing = existing
    }

    private var lang: String { session.effectiveLanguageCode() }
    private var locale: Locale { Locale(identifier: AppLanguage.localeIdentifier(from: lang)) }
    private var isEditing: Bool { editing != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                Form {
                    nameSection
                    timesSection
                    daysSection
                    dateRangeSection
                    remindersSection
                    colorSection
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
                isEditing ? .calendarMedFormEditTitle : .calendarMedFormAddTitle,
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
                L10n.string(.calendarDeleteMedTitle, languageCode: lang),
                isPresented: $showingDeleteConfirm
            ) {
                Button(L10n.string(.delete, languageCode: lang), role: .destructive) {
                    if let schedule = editing {
                        CalendarService.deleteSchedule(schedule, in: context)
                    }
                    dismiss()
                }
                Button(L10n.string(.cancel, languageCode: lang), role: .cancel) {}
            } message: {
                Text(L10n.string(.calendarDeleteMedMessage, languageCode: lang))
            }
            .id("\(lang)-\(session.localizationRevision)")
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section {
            TextField(
                "",
                text: $name,
                prompt: Text(L10n.string(.calendarMedFormNamePlaceholder, languageCode: lang))
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.9))
            )
            .foregroundStyle(AppTheme.softText)
            .listRowBackground(AppTheme.chipFill)

            TextField(
                "",
                text: $dosage,
                prompt: Text(L10n.string(.calendarMedFormDosagePlaceholder, languageCode: lang))
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.9))
            )
            .foregroundStyle(AppTheme.softText)
            .listRowBackground(AppTheme.chipFill)
        } header: {
            Text(L10n.string(.calendarMedFormDetailsHeader, languageCode: lang))
                .foregroundStyle(AppTheme.softText)
        }
    }

    private var timesSection: some View {
        Section {
            ForEach(Array(times.enumerated()), id: \.offset) { idx, minutes in
                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(AppTheme.accent)
                    DatePicker(
                        "",
                        selection: timeBinding(at: idx),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .environment(\.locale, locale)
                    Spacer()
                    if times.count > 1 {
                        Button {
                            times.remove(at: idx)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                                .imageScale(.large)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(L10n.string(.calendarMedFormRemoveTime, languageCode: lang))
                    }
                }
                .listRowBackground(AppTheme.chipFill)
                .foregroundStyle(AppTheme.softText)
            }
            Button {
                addAnotherTime()
            } label: {
                Label(
                    L10n.string(.calendarMedFormAddTime, languageCode: lang),
                    systemImage: "plus.circle.fill"
                )
                .foregroundStyle(AppTheme.accent)
            }
            .listRowBackground(AppTheme.chipFill)
        } header: {
            Text(L10n.string(.calendarMedFormTimesHeader, languageCode: lang))
                .foregroundStyle(AppTheme.softText)
        } footer: {
            Text(L10n.string(.calendarMedFormTimesFooter, languageCode: lang))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var daysSection: some View {
        Section {
            ForEach(orderedWeekdayList, id: \.weekday) { item in
                let isOn = (daysMask & (1 << (item.weekday - 1))) != 0
                Button {
                    toggleDay(item.weekday)
                } label: {
                    HStack {
                        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isOn ? AppTheme.accent : AppTheme.secondaryText)
                        Text(item.symbol)
                            .foregroundStyle(AppTheme.softText)
                        Spacer()
                    }
                }
                .listRowBackground(AppTheme.chipFill)
            }
            HStack(spacing: 12) {
                Button(L10n.string(.calendarMedFormEveryDay, languageCode: lang)) {
                    daysMask = MedicationSchedule.everyDayMask
                }
                .buttonStyle(.bordered)
                Button(L10n.string(.calendarMedFormWeekdays, languageCode: lang)) {
                    // Sunday=1, Monday=2 ... Saturday=7. Weekdays = Mon-Fri (bits 2..6).
                    daysMask = (1<<1) | (1<<2) | (1<<3) | (1<<4) | (1<<5)
                }
                .buttonStyle(.bordered)
            }
            .listRowBackground(AppTheme.chipFill)
        } header: {
            Text(L10n.string(.calendarMedFormDaysHeader, languageCode: lang))
                .foregroundStyle(AppTheme.softText)
        }
    }

    private var dateRangeSection: some View {
        Section {
            DatePicker(
                L10n.string(.calendarMedFormStart, languageCode: lang),
                selection: $startDate,
                displayedComponents: .date
            )
            .environment(\.locale, locale)
            .foregroundStyle(AppTheme.softText)
            .listRowBackground(AppTheme.chipFill)

            Toggle(
                L10n.string(.calendarMedFormHasEnd, languageCode: lang),
                isOn: $hasEndDate
            )
            .foregroundStyle(AppTheme.softText)
            .listRowBackground(AppTheme.chipFill)

            if hasEndDate {
                DatePicker(
                    L10n.string(.calendarMedFormEnd, languageCode: lang),
                    selection: $endDate,
                    in: startDate...,
                    displayedComponents: .date
                )
                .environment(\.locale, locale)
                .foregroundStyle(AppTheme.softText)
                .listRowBackground(AppTheme.chipFill)
            }
        } header: {
            Text(L10n.string(.calendarMedFormRangeHeader, languageCode: lang))
                .foregroundStyle(AppTheme.softText)
        }
    }

    private var remindersSection: some View {
        Section {
            Toggle(
                L10n.string(.calendarMedFormReminders, languageCode: lang),
                isOn: $remindersEnabled
            )
            .foregroundStyle(AppTheme.softText)
            .listRowBackground(AppTheme.chipFill)
        } footer: {
            Text(L10n.string(.calendarMedFormRemindersFooter, languageCode: lang))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var colorSection: some View {
        Section {
            HStack(spacing: 12) {
                ForEach(Self.swatches, id: \.self) { hex in
                    Button {
                        colorHex = hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: hex) ?? AppTheme.accent)
                                .frame(width: 32, height: 32)
                            if colorHex == hex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.string(.calendarMedFormColor, languageCode: lang))
                }
                Spacer()
            }
            .listRowBackground(AppTheme.chipFill)
        } header: {
            Text(L10n.string(.calendarMedFormColor, languageCode: lang))
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
                        L10n.string(.calendarDeleteMedication, languageCode: lang),
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
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !times.isEmpty &&
        daysMask != 0
    }

    private static let swatches: [String] = [
        "#2F6FE6", // blue
        "#3FA34D", // green
        "#E08A2B", // amber
        "#D24D62", // red
        "#A04CCF", // purple
        "#1FA2A6"  // teal
    ]

    private struct WeekdayItem {
        let weekday: Int    // 1...7
        let symbol: String
    }

    private var orderedWeekdayList: [WeekdayItem] {
        let df = DateFormatter()
        df.locale = locale
        let symbols = df.standaloneWeekdaySymbols ?? []
        guard symbols.count == 7 else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let firstWeekday = calendar.firstWeekday
        return (0..<7).map { offset in
            let weekday = ((firstWeekday - 1 + offset) % 7) + 1
            return WeekdayItem(weekday: weekday, symbol: symbols[weekday - 1])
        }
    }

    private func timeBinding(at idx: Int) -> Binding<Date> {
        Binding(
            get: {
                let minutes = times[safe: idx] ?? 0
                var comps = DateComponents()
                comps.hour = minutes / 60
                comps.minute = minutes % 60
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
                if idx < times.count { times[idx] = minutes }
                times.sort()
            }
        )
    }

    private func addAnotherTime() {
        let next: Int
        if let last = times.max() {
            next = min(1410, last + 6 * 60) // 6 hours later, capped at 23:30
        } else {
            next = 8 * 60
        }
        times.append(next)
        times.sort()
    }

    private func toggleDay(_ weekday: Int) {
        let bit = 1 << (weekday - 1)
        if (daysMask & bit) != 0 {
            // Don't allow zero days.
            if daysMask == bit { return }
            daysMask &= ~bit
        } else {
            daysMask |= bit
        }
    }

    private func hydrateFromExisting() {
        guard let existing = editing else { return }
        name = existing.name
        dosage = existing.dosageInstructions
        notes = existing.notes
        times = existing.timesMinutes.isEmpty ? [8 * 60] : existing.timesMinutes
        daysMask = existing.daysOfWeekMask == 0 ? MedicationSchedule.everyDayMask : existing.daysOfWeekMask
        startDate = existing.startDate
        hasEndDate = existing.endDate != nil
        endDate = existing.endDate ?? Date().addingTimeInterval(60 * 60 * 24 * 30)
        remindersEnabled = existing.remindersEnabled
        colorHex = existing.colorHex
    }

    private func save() async {
        let owner = session.email.lowercased()
        guard !owner.isEmpty else {
            dismiss()
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDosage = dosage.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedStart = Calendar.current.startOfDay(for: startDate)
        let normalizedEnd: Date? = hasEndDate ? Calendar.current.startOfDay(for: endDate) : nil

        if let existing = editing {
            existing.name = trimmedName
            existing.dosageInstructions = trimmedDosage
            existing.notes = trimmedNotes
            existing.timesJSON = MedicationSchedule.encodeTimes(times)
            existing.daysOfWeekMask = daysMask
            existing.startDate = normalizedStart
            existing.endDate = normalizedEnd
            existing.remindersEnabled = remindersEnabled
            existing.colorHex = colorHex
            await CalendarService.updateSchedule(existing, in: context)
        } else {
            let schedule = MedicationSchedule(
                ownerEmail: owner,
                name: trimmedName,
                dosageInstructions: trimmedDosage,
                notes: trimmedNotes,
                timesMinutes: times,
                daysOfWeekMask: daysMask,
                startDate: normalizedStart,
                endDate: normalizedEnd,
                remindersEnabled: remindersEnabled,
                colorHex: colorHex
            )
            await CalendarService.createSchedule(schedule, in: context)
        }
        dismiss()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
