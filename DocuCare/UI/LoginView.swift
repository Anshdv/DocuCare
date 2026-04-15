import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var session: SessionManager
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var error: String?
    @FocusState private var focusField: Field?

    // Sign-up state
    @State private var showSignUp = false
    @State private var signUpEmail: String = ""
    @State private var signUpPassword: String = ""
    @State private var signUpLanguageCode: String = AppLanguage.bestMatchForSystem().rawValue
    @State private var signUpError: String?
    @FocusState private var signUpFocusField: Field?
    @State private var pendingConsentEmail: String?
    @State private var pendingSignUpLanguageCode: String = AppLanguage.english.rawValue

    // Navigation
    @State private var shouldShowConsentAfterSignUp = false
    @State private var path: [Route] = []

    @State private var consentError: String?

    enum Field { case email, password }

    enum Route: Hashable {
        case consent
        case handoff
    }

    private var lang: String { session.effectiveLanguageCode() }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geometry in
                ZStack {
                    AppBackgroundView()
                    ScrollView {
                        VStack {
                            Spacer(minLength: geometry.size.height / 7)

                            VStack(spacing: 28) {
                                Image(systemName: "cross.case.circle.fill")
                                    .resizable()
                                    .frame(width: 74, height: 74)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [AppTheme.accent, AppTheme.accentSecondary],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .padding(.top, 42)

                                Text(L10n.string(.welcomeTitle, languageCode: lang))
                                    .font(.title).bold()
                                    .foregroundStyle(AppTheme.softText)
                                Text(L10n.string(.welcomeSubtitle, languageCode: lang))
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .padding(.bottom, 2)

                                VStack(spacing: 14) {
                                    TextField(
                                        "",
                                        text: $email,
                                        prompt: Text(L10n.string(.email, languageCode: lang))
                                            .foregroundStyle(AppTheme.secondaryText.opacity(0.9))
                                    )
                                        .autocapitalization(.none)
                                        .keyboardType(.emailAddress)
                                        .appTextFieldStyle()
                                        .focused($focusField, equals: .email)

                                    SecureField(
                                        "",
                                        text: $password,
                                        prompt: Text(L10n.string(.password, languageCode: lang))
                                            .foregroundStyle(AppTheme.secondaryText.opacity(0.9))
                                    )
                                        .appTextFieldStyle()
                                        .focused($focusField, equals: .password)
                                }
                                .id(session.localizationRevision)
                                .padding(.horizontal, 26)

                                if let error = error {
                                    Text(error)
                                        .foregroundColor(.red)
                                        .font(.callout)
                                }

                                Button {
                                    login()
                                } label: {
                                    Text(L10n.string(.logIn, languageCode: lang))
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                .padding(.horizontal, 26)
                                .disabled(email.isEmpty || password.isEmpty)

                                Button {
                                    showSignUp = true
                                    signUpEmail = ""
                                    signUpPassword = ""
                                    signUpError = nil
                                    signUpLanguageCode = AppLanguage.bestMatchForSystem().rawValue
                                } label: {
                                    Text(L10n.string(.signUpPrompt, languageCode: lang))
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(AppTheme.accentSecondary)
                                }
                                .padding(.top, 4)
                                .padding(.bottom, 10)
                            }
                            .frame(maxWidth: .infinity)
                            .appCardStyle()
                            .padding(.horizontal, 20)

                            Spacer(minLength: geometry.size.height / 6)
                        }
                        .frame(minHeight: geometry.size.height)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            hideKeyboard()
                        }
                    }
                }
                .ignoresSafeArea()
                .sheet(isPresented: $showSignUp) {
                    signUpSheet
                }
                .onChange(of: showSignUp) { _, newValue in
                    if !newValue && shouldShowConsentAfterSignUp {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            path.append(.consent)
                            shouldShowConsentAfterSignUp = false
                        }
                    }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .consent:
                    ConsentAndPrivacyView(languageCode: pendingSignUpLanguageCode) {
                        path.append(.handoff)
                    }

                case .handoff:
                    Color.clear
                        .onAppear {
                            guard let email = pendingConsentEmail else {
                                _ = path.popLast()
                                return
                            }
                            let lc = pendingSignUpLanguageCode
                            switch session.signUp(email: email, password: signUpPassword, preferredLanguageCode: lc) {
                            case .success:
                                session.recordConsent(for: email)
                                self.email = email
                                self.password = signUpPassword
                                _ = session.logIn(email: email, password: signUpPassword)

                                pendingConsentEmail = nil
                                path.removeAll()

                            case .failure(let message):
                                consentError = message
                                pendingConsentEmail = nil
                                path.removeAll()
                            }
                        }
                }
            }
            .alert(L10n.string(.signUpErrorAlertTitle, languageCode: lang), isPresented: .constant(consentError != nil), actions: {
                Button(L10n.string(.ok, languageCode: lang)) { consentError = nil }
            }, message: {
                Text(consentError ?? "")
            })
        }
    }

    private var signUpSheet: some View {
        NavigationView {
            ZStack {
                AppBackgroundView()
                VStack(spacing: 28) {
                    Text(L10n.string(.createAccountTitle, languageCode: signUpLanguageCode))
                        .font(.title2).bold()
                        .foregroundStyle(AppTheme.softText)
                        .padding(.top, 40)

                    VStack(alignment: .center, spacing: 10) {
                        Text(L10n.string(.chooseLanguage, languageCode: signUpLanguageCode))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        Picker(L10n.string(.language, languageCode: signUpLanguageCode), selection: $signUpLanguageCode) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.pickerTitle).tag(language.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .accessibilityLabel(L10n.string(.language, languageCode: signUpLanguageCode))
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 32)

                    VStack(spacing: 18) {
                        TextField(
                            "",
                            text: $signUpEmail,
                            prompt: Text(L10n.string(.email, languageCode: signUpLanguageCode))
                                .foregroundStyle(AppTheme.secondaryText.opacity(0.9))
                        )
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .appTextFieldStyle()
                        .focused($signUpFocusField, equals: .email)

                        SecureField(
                            "",
                            text: $signUpPassword,
                            prompt: Text(L10n.string(.password, languageCode: signUpLanguageCode))
                                .foregroundStyle(AppTheme.secondaryText.opacity(0.9))
                        )
                        .appTextFieldStyle()
                        .focused($signUpFocusField, equals: .password)
                    }
                    .id("\(signUpLanguageCode)-\(session.localizationRevision)")
                    .padding(.horizontal, 32)

                    if let error = signUpError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.callout)
                    }

                    Button {
                        signUp()
                    } label: {
                        Text(L10n.string(.createAccount, languageCode: signUpLanguageCode))
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 32)
                    .disabled(signUpEmail.isEmpty || signUpPassword.isEmpty)

                    Spacer()
                }
                .appCardStyle()
                .padding(.horizontal, 20)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string(.cancel, languageCode: signUpLanguageCode)) { showSignUp = false }
                }
            }
            .onAppear { signUpFocusField = .email }
            .onTapGesture {
                hideKeyboard()
            }
        }
    }

    private func login() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if session.logIn(email: trimmedEmail, password: password) {
            error = nil
        } else {
            error = L10n.string(.invalidCredentials, languageCode: lang)
            password = ""
            focusField = .password
        }
    }

    private func signUp() {
        let trimmedEmail = signUpEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = signUpPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            signUpError = L10n.string(.emailPasswordRequired, languageCode: signUpLanguageCode)
            return
        }
        guard isValidEmail(trimmedEmail) else {
            signUpError = L10n.string(.invalidEmail, languageCode: signUpLanguageCode)
            return
        }

        pendingConsentEmail = trimmedEmail.lowercased()
        pendingSignUpLanguageCode = signUpLanguageCode
        shouldShowConsentAfterSignUp = true
        showSignUp = false
    }

    private func isValidEmail(_ email: String) -> Bool {
        let regex =
            #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES[c] %@", regex)
            .evaluate(with: email)
    }
}

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif
