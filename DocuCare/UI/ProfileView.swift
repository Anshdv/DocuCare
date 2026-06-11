import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var session: SessionManager

    @State private var newEmail: String = ""
    @State private var emailChangePassword: String = ""
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""

    @State private var showingPrivacy = false
    @State private var alertTitle: String?
    @State private var alertMessage: String?

    @State private var isRequestingHealthAuth = false
    @State private var showingHealthDisconnectConfirm = false
    @State private var showingHealthOpenSettingsButton = false

    @State private var healthSnapshot: HealthSnapshot?
    @State private var healthSnapshotFetchedAt: Date?
    @State private var isLoadingHealthSnapshot = false
    @State private var healthSnapshotTask: Task<Void, Never>?

    private var lang: String { session.effectiveLanguageCode() }

    var body: some View {
        ZStack {
            AppBackgroundView()
            Form {
                Section {
                    LabeledContent(L10n.string(.email, languageCode: lang)) {
                        Text(session.email)
                            .foregroundStyle(AppTheme.secondaryText)
                            .textSelection(.enabled)
                    }
                    .listRowBackground(AppTheme.chipFill)

                    TextField(
                        "",
                        text: $newEmail,
                        prompt: Text(L10n.string(.profileNewEmailPlaceholder, languageCode: lang))
                            .foregroundStyle(AppTheme.secondaryText.opacity(0.9))
                    )
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .foregroundStyle(AppTheme.softText)
                    .listRowBackground(AppTheme.chipFill)

                    SecureField(
                        "",
                        text: $emailChangePassword,
                        prompt: Text(L10n.string(.profileCurrentPasswordForEmail, languageCode: lang))
                            .foregroundStyle(AppTheme.secondaryText.opacity(0.9))
                    )
                    .textContentType(.password)
                    .foregroundStyle(AppTheme.softText)
                    .listRowBackground(AppTheme.chipFill)

                    Button(L10n.string(.profileUpdateEmail, languageCode: lang)) {
                        applyEmailChange()
                    }
                    .disabled(newEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || emailChangePassword.isEmpty)
                    .listRowBackground(AppTheme.chipFill)
                } header: {
                    Text(L10n.string(.profileAccountSection, languageCode: lang))
                        .foregroundStyle(AppTheme.softText)
                }

                Section {
                    Picker(L10n.string(.language, languageCode: lang), selection: Binding(
                        get: { session.preferredLanguageCode },
                        set: { session.setPreferredLanguageCode($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.pickerTitle).tag(language.rawValue)
                        }
                    }
                    .foregroundStyle(AppTheme.softText)
                    .listRowBackground(AppTheme.chipFill)
                } header: {
                    Text(L10n.string(.changeLanguage, languageCode: lang))
                        .foregroundStyle(AppTheme.softText)
                }

                Section {
                    Picker(L10n.string(.fontSize, languageCode: lang), selection: Binding(
                        get: { session.preferredFontSize },
                        set: { session.setPreferredFontSize($0) }
                    )) {
                        ForEach(AppFontSize.allCases) { size in
                            Text(L10n.string(size.localizationKey, languageCode: lang))
                                .tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(AppTheme.chipFill)

                    Text(L10n.string(.fontSizePreview, languageCode: lang))
                        .font(.body)
                        .dynamicTypeSize(session.preferredFontSize.dynamicTypeSize)
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowBackground(AppTheme.chipFill)
                } header: {
                    Text(L10n.string(.fontSize, languageCode: lang))
                        .foregroundStyle(AppTheme.softText)
                }

                Section {
                    SecureField(
                        "",
                        text: $currentPassword,
                        prompt: Text(L10n.string(.profileCurrentPassword, languageCode: lang))
                            .foregroundStyle(AppTheme.secondaryText.opacity(0.9))
                    )
                    .textContentType(.password)
                    .foregroundStyle(AppTheme.softText)
                    .listRowBackground(AppTheme.chipFill)

                    SecureField(
                        "",
                        text: $newPassword,
                        prompt: Text(L10n.string(.profileNewPassword, languageCode: lang))
                            .foregroundStyle(AppTheme.secondaryText.opacity(0.9))
                    )
                    .textContentType(.newPassword)
                    .foregroundStyle(AppTheme.softText)
                    .listRowBackground(AppTheme.chipFill)

                    SecureField(
                        "",
                        text: $confirmPassword,
                        prompt: Text(L10n.string(.profileConfirmPassword, languageCode: lang))
                            .foregroundStyle(AppTheme.secondaryText.opacity(0.9))
                    )
                    .textContentType(.newPassword)
                    .foregroundStyle(AppTheme.softText)
                    .listRowBackground(AppTheme.chipFill)

                    Button(L10n.string(.profileSavePassword, languageCode: lang)) {
                        applyPasswordChange()
                    }
                    .disabled(currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
                    .listRowBackground(AppTheme.chipFill)
                } header: {
                    Text(L10n.string(.profileSecuritySection, languageCode: lang))
                        .foregroundStyle(AppTheme.softText)
                }

                Section {
                    appleHealthSectionContent
                } header: {
                    Text(L10n.string(.appleHealthSection, languageCode: lang))
                        .foregroundStyle(AppTheme.softText)
                } footer: {
                    appleHealthSectionFooter
                }

                if session.healthKitConnected && HealthKitService.shared.isAvailable {
                    Section {
                        appleHealthDataSectionContent
                    } header: {
                        appleHealthDataSectionHeader
                    } footer: {
                        if let snapshot = healthSnapshot, !snapshot.isEmpty {
                            Text(L10n.string(.appleHealthDataFooter, languageCode: lang))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                }

                Section {
                    Button(L10n.string(.profilePrivacyButton, languageCode: lang)) {
                        showingPrivacy = true
                    }
                    .listRowBackground(AppTheme.chipFill)
                }

                Section {
                    Button(role: .destructive) {
                        session.logOut()
                        dismiss()
                    } label: {
                        Text(L10n.string(.logOut, languageCode: lang))
                    }
                    .listRowBackground(AppTheme.chipFill)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .id("\(session.preferredLanguageCode)-\(session.localizationRevision)")
        }
        .preferredColorScheme(.light)
        .tint(AppTheme.accent)
        .navigationTitle(L10n.string(.profileTitle, languageCode: lang))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.string(.profileDone, languageCode: lang)) {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingPrivacy) {
            NavigationStack {
                ZStack {
                    AppBackgroundView()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(L10n.string(.consentPolicyTitle, languageCode: lang))
                                .font(.title2.bold())
                                .foregroundStyle(AppTheme.softText)
                            Text(L10n.string(.consentPolicyBody, languageCode: lang))
                                .font(.body)
                                .foregroundStyle(AppTheme.softText)
                        }
                        .padding()
                        .textSelection(.enabled)
                    }
                }
                .preferredColorScheme(.light)
                .id("\(lang)-\(session.localizationRevision)")
                .navigationTitle(L10n.string(.consentPolicyTitle, languageCode: lang))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.string(.profileDone, languageCode: lang)) {
                            showingPrivacy = false
                        }
                    }
                }
            }
        }
        .alert(alertTitle ?? "", isPresented: Binding(
            get: { alertTitle != nil },
            set: { if !$0 { alertTitle = nil; alertMessage = nil } }
        )) {
            if showingHealthOpenSettingsButton,
               let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Button(L10n.string(.appleHealthOpenSettings, languageCode: lang)) {
                    UIApplication.shared.open(settingsURL)
                    alertTitle = nil
                    alertMessage = nil
                    showingHealthOpenSettingsButton = false
                }
            }
            Button(L10n.string(.ok, languageCode: lang)) {
                alertTitle = nil
                alertMessage = nil
                showingHealthOpenSettingsButton = false
            }
        } message: {
            Text(alertMessage ?? "")
        }
        .alert(
            L10n.string(.appleHealthDisconnectTitle, languageCode: lang),
            isPresented: $showingHealthDisconnectConfirm
        ) {
            Button(L10n.string(.appleHealthDisconnectConfirm, languageCode: lang), role: .destructive) {
                session.setHealthKitConnected(false)
                healthSnapshotTask?.cancel()
                healthSnapshot = nil
                healthSnapshotFetchedAt = nil
            }
            Button(L10n.string(.cancel, languageCode: lang), role: .cancel) {}
        } message: {
            Text(L10n.string(.appleHealthDisconnectMessage, languageCode: lang))
        }
        .onAppear {
            if session.healthKitConnected, healthSnapshot == nil {
                refreshHealthSnapshot()
            }
        }
        .onChange(of: session.healthKitConnected) { _, isConnected in
            if isConnected {
                refreshHealthSnapshot()
            } else {
                healthSnapshotTask?.cancel()
                healthSnapshot = nil
                healthSnapshotFetchedAt = nil
            }
        }
    }

    // MARK: - Apple Health section

    @ViewBuilder
    private var appleHealthSectionContent: some View {
        if !HealthKitService.shared.isAvailable {
            Text(L10n.string(.appleHealthUnavailable, languageCode: lang))
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .listRowBackground(AppTheme.chipFill)
        } else {
            Toggle(isOn: healthKitBinding) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string(.appleHealthToggle, languageCode: lang))
                        .foregroundStyle(AppTheme.softText)
                    if isRequestingHealthAuth {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(isRequestingHealthAuth)
            .listRowBackground(AppTheme.chipFill)
        }
    }

    @ViewBuilder
    private var appleHealthSectionFooter: some View {
        if HealthKitService.shared.isAvailable {
            Text(session.healthKitConnected
                 ? L10n.string(.appleHealthConnectedFooter, languageCode: lang)
                 : L10n.string(.appleHealthDescription, languageCode: lang))
                .foregroundStyle(AppTheme.secondaryText)
        } else {
            EmptyView()
        }
    }

    private var healthKitBinding: Binding<Bool> {
        Binding<Bool>(
            get: { session.healthKitConnected },
            set: { newValue in
                if newValue {
                    requestHealthAuthorization()
                } else {
                    showingHealthDisconnectConfirm = true
                }
            }
        )
    }

    private func requestHealthAuthorization() {
        guard !isRequestingHealthAuth else { return }
        isRequestingHealthAuth = true
        HealthKitService.shared.requestAuthorization { result in
            isRequestingHealthAuth = false
            switch result {
            case .success:
                // Apple does not expose per-type read decisions; treat a completed sheet as a
                // successful opt-in. If no data ends up readable, the data section below makes
                // that explicit with "Not shared" rows.
                session.setHealthKitConnected(true)
                refreshHealthSnapshot()
            case .failure:
                showingHealthOpenSettingsButton = true
                alertTitle = L10n.string(.appleHealthAuthFailedTitle, languageCode: lang)
                alertMessage = L10n.string(.appleHealthAuthFailedMessage, languageCode: lang)
            }
        }
    }

    // MARK: - Apple Health data display

    @ViewBuilder
    private var appleHealthDataSectionHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(L10n.string(.appleHealthDataSectionTitle, languageCode: lang))
                .foregroundStyle(AppTheme.softText)
            Spacer()
            Button {
                refreshHealthSnapshot()
            } label: {
                Label(L10n.string(.appleHealthRefresh, languageCode: lang), systemImage: "arrow.clockwise")
                    .labelStyle(.titleAndIcon)
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .textCase(nil)
            .disabled(isLoadingHealthSnapshot)
            .opacity(isLoadingHealthSnapshot ? 0.4 : 1)
        }
    }

    @ViewBuilder
    private var appleHealthDataSectionContent: some View {
        if isLoadingHealthSnapshot && healthSnapshot == nil {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text(L10n.string(.appleHealthDataLoading, languageCode: lang))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .listRowBackground(AppTheme.chipFill)
        } else if let snapshot = healthSnapshot {
            if snapshot.isEmpty {
                Text(L10n.string(.appleHealthDataEmpty, languageCode: lang))
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .listRowBackground(AppTheme.chipFill)
            } else {
                if let fetchedAt = healthSnapshotFetchedAt {
                    Text(String(
                        format: L10n.string(.appleHealthLastUpdatedFormat, languageCode: lang),
                        relativeDate(fetchedAt)
                    ))
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .listRowBackground(AppTheme.chipFill)
                }
                ForEach(snapshot.displayRows(languageCode: lang)) { row in
                    appleHealthDataRow(row)
                        .listRowBackground(AppTheme.chipFill)
                }
            }
        }
    }

    @ViewBuilder
    private func appleHealthDataRow(_ row: HealthDisplayRow) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.string(row.labelKey, languageCode: lang))
                    .foregroundStyle(AppTheme.softText)
                if let date = row.sampleDate {
                    Text(String(
                        format: L10n.string(.appleHealthLastUpdatedFormat, languageCode: lang),
                        sampleDateText(date)
                    ))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText)
                }
            }
            Spacer()
            if let value = row.value, !value.isEmpty {
                Text(value)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.softText)
            } else {
                Text(L10n.string(.appleHealthNotShared, languageCode: lang))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func refreshHealthSnapshot() {
        guard session.healthKitConnected, HealthKitService.shared.isAvailable else { return }
        healthSnapshotTask?.cancel()
        isLoadingHealthSnapshot = true
        healthSnapshotTask = Task { @MainActor in
            let snapshot = await HealthKitService.shared.fetchSnapshot()
            if Task.isCancelled { return }
            self.healthSnapshot = snapshot
            self.healthSnapshotFetchedAt = Date()
            self.isLoadingHealthSnapshot = false
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: AppLanguage.localeIdentifier(from: lang))
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func sampleDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppLanguage.localeIdentifier(from: lang))
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func applyEmailChange() {
        let trimmed = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldLower = session.email.lowercased()
        if let code = session.changeEmail(to: trimmed, currentPassword: emailChangePassword) {
            switch code {
            case "wrongPassword":
                alertTitle = L10n.string(.error, languageCode: lang)
                alertMessage = L10n.string(.incorrectPasswordError, languageCode: lang)
            case "invalid":
                alertTitle = L10n.string(.error, languageCode: lang)
                alertMessage = L10n.string(.invalidEmail, languageCode: lang)
            case "same":
                alertTitle = L10n.string(.error, languageCode: lang)
                alertMessage = L10n.string(.profileEmailUnchanged, languageCode: lang)
            case "taken":
                alertTitle = L10n.string(.error, languageCode: lang)
                alertMessage = L10n.string(.accountExists, languageCode: lang)
            default:
                alertTitle = L10n.string(.error, languageCode: lang)
                alertMessage = L10n.string(.error, languageCode: lang)
            }
            return
        }
        migrateReportOwnership(from: oldLower, to: session.email.lowercased())
        DailyLessonService.migrateOwnership(
            from: oldLower,
            to: session.email.lowercased(),
            in: modelContext
        )
        CalendarService.migrateOwnership(
            from: oldLower,
            to: session.email.lowercased(),
            in: modelContext
        )
        emailChangePassword = ""
        newEmail = session.email
        alertTitle = L10n.string(.profileSuccessTitle, languageCode: lang)
        alertMessage = L10n.string(.profileEmailUpdated, languageCode: lang)
    }

    private func applyPasswordChange() {
        guard newPassword == confirmPassword else {
            alertTitle = L10n.string(.error, languageCode: lang)
            alertMessage = L10n.string(.profilePasswordsMismatch, languageCode: lang)
            return
        }
        if session.changePassword(from: currentPassword, to: newPassword) {
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
            alertTitle = L10n.string(.profileSuccessTitle, languageCode: lang)
            alertMessage = L10n.string(.profilePasswordUpdated, languageCode: lang)
        } else {
            alertTitle = L10n.string(.error, languageCode: lang)
            alertMessage = L10n.string(.incorrectPasswordError, languageCode: lang)
        }
    }

    private func migrateReportOwnership(from oldOwner: String, to newOwner: String) {
        let o = oldOwner.lowercased()
        let n = newOwner.lowercased()
        guard o != n else { return }
        let descriptor = FetchDescriptor<MedicalReport>(
            predicate: #Predicate<MedicalReport> { report in
                report.ownerEmail == o
            }
        )
        guard let reports = try? modelContext.fetch(descriptor) else { return }
        for report in reports {
            report.ownerEmail = n
        }
        try? modelContext.save()
    }
}
