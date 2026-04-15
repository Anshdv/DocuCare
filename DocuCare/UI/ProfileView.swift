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
            Button(L10n.string(.ok, languageCode: lang)) {
                alertTitle = nil
                alertMessage = nil
            }
        } message: {
            Text(alertMessage ?? "")
        }
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
