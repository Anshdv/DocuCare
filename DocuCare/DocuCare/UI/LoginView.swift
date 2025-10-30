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
    @State private var signUpError: String?
    @FocusState private var signUpFocusField: Field?

    enum Field { case email, password }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack {
                    Spacer(minLength: geometry.size.height / 7)

                    VStack(spacing: 32) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 72, height: 72)
                            .foregroundColor(.blue)
                            .padding(.top, 60)

                        Text("Welcome to DocuCare")
                            .font(.title).bold()
                        Text("AI-powered summaries for smarter care")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.bottom)

                        VStack(spacing: 18) {
                            TextField("Email", text: $email)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                                .focused($focusField, equals: .email)

                            SecureField("Password", text: $password)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                                .focused($focusField, equals: .password)
                        }
                        .padding(.horizontal, 32)

                        if let error = error {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.callout)
                        }

                        Button {
                            login()
                        } label: {
                            Text("Log In")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 32)
                        .disabled(email.isEmpty || password.isEmpty)

                        Button {
                            showSignUp = true
                            signUpEmail = ""
                            signUpPassword = ""
                            signUpError = nil
                        } label: {
                            Text("Don't have an account? Sign Up")
                                .font(.callout)
                        }
                        .padding(.top, 10)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground).opacity(0.98))
                    .cornerRadius(16)
                    .shadow(color: Color(.black).opacity(0.05), radius: 8, y: 2)

                    Spacer(minLength: geometry.size.height / 6)
                }
                .frame(minHeight: geometry.size.height)
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            }
            .background(Color(.systemBackground))
            .ignoresSafeArea()
            .sheet(isPresented: $showSignUp) {
                signUpSheet
            }
        }
    }

    private var signUpSheet: some View {
        NavigationView {
            VStack(spacing: 28) {
                Text("Create a New Account")
                    .font(.title2).bold()
                    .padding(.top, 40)

                VStack(spacing: 18) {
                    TextField("Email", text: $signUpEmail)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                        .focused($signUpFocusField, equals: .email)

                    SecureField("Password", text: $signUpPassword)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                        .focused($signUpFocusField, equals: .password)
                }
                .padding(.horizontal, 32)

                if let error = signUpError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.callout)
                }

                Button {
                    signUp()
                } label: {
                    Text("Create Account")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 32)
                .disabled(signUpEmail.isEmpty || signUpPassword.isEmpty)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showSignUp = false }
                }
            }
            .onAppear { signUpFocusField = .email }
        }
    }

    private func login() {
        if session.logIn(email: email, password: password) {
            error = nil
        } else {
            error = "Invalid email or password."
            password = ""
            focusField = .password
        }
    }

    private func signUp() {
        let trimmedEmail = signUpEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = signUpPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            signUpError = "Email and password required."
            return
        }
        guard isValidEmail(trimmedEmail) else {
            signUpError = "Please enter a valid email address."
            return
        }
        switch session.signUp(email: trimmedEmail, password: trimmedPassword) {
        case .success:
            showSignUp = false
            email = trimmedEmail
            password = trimmedPassword
            login()
        case .failure(let errorStr):
            signUpError = errorStr
        }
    }

    /// Returns true if the email matches general RFC 5322 email syntax.
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
#endif // canImport(UIKit)
