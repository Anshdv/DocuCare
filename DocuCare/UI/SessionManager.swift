import Foundation
import Combine

struct UserRecord: Codable {
    var password: String
    var hasConsented: Bool
    /// `AppLanguage.rawValue`
    var preferredLanguageCode: String

    init(password: String, hasConsented: Bool, preferredLanguageCode: String = AppLanguage.english.rawValue) {
        self.password = password
        self.hasConsented = hasConsented
        self.preferredLanguageCode = preferredLanguageCode
    }

    enum CodingKeys: String, CodingKey {
        case password, hasConsented, preferredLanguageCode
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        password = try c.decode(String.self, forKey: .password)
        hasConsented = try c.decode(Bool.self, forKey: .hasConsented)
        preferredLanguageCode = try c.decodeIfPresent(String.self, forKey: .preferredLanguageCode) ?? AppLanguage.english.rawValue
    }
}

final class SessionManager: ObservableObject {
    @Published var isLoggedIn: Bool {
        didSet { UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn") }
    }
    @Published var email: String = ""
    @Published var hasConsented: Bool = false
    /// Mirrors the signed-in user's `preferredLanguageCode`, or the last known UI language when logged out.
    @Published var preferredLanguageCode: String

    /// Bumped whenever UI language strings should refresh (e.g. TextField prompts).
    @Published private(set) var localizationRevision: UInt = 0

    static let shared = SessionManager()

    private let usersKey = "users"
    private let lastPreferredLanguageKey = "lastPreferredLanguageCode"

    private var users: [String: UserRecord] {
        get {
            if let data = UserDefaults.standard.data(forKey: usersKey),
               let decoded = try? JSONDecoder().decode([String: UserRecord].self, from: data) {
                return decoded
            }
            // Migrate legacy user storage (password-only)
            if let oldDict = UserDefaults.standard.dictionary(forKey: usersKey) as? [String: String] {
                let migrated = oldDict.mapValues {
                    UserRecord(password: $0, hasConsented: false, preferredLanguageCode: AppLanguage.english.rawValue)
                }
                if let data = try? JSONEncoder().encode(migrated) {
                    UserDefaults.standard.set(data, forKey: usersKey)
                }
                return migrated
            }
            return [:]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: usersKey)
            }
        }
    }

    private init() {
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        self.email = UserDefaults.standard.string(forKey: "lastUser") ?? ""
        let storedLang = UserDefaults.standard.string(forKey: lastPreferredLanguageKey)
        self.preferredLanguageCode = storedLang ?? AppLanguage.bestMatchForSystem().rawValue
        if isLoggedIn {
            let lowercased = self.email.lowercased()
            self.hasConsented = users[lowercased]?.hasConsented ?? false
            if let code = users[lowercased]?.preferredLanguageCode {
                self.preferredLanguageCode = code
            }
        }
    }

    enum SignUpResult {
        case success
        case failure(String)
    }

    /// Effective UI / AI language: logged-in user's setting, otherwise last session or system locale.
    func effectiveLanguageCode() -> String {
        if isLoggedIn {
            return preferredLanguageCode
        }
        return UserDefaults.standard.string(forKey: lastPreferredLanguageKey) ?? AppLanguage.bestMatchForSystem().rawValue
    }

    private func persistLanguageCode(_ code: String) {
        preferredLanguageCode = code
        localizationRevision &+= 1
        UserDefaults.standard.set(code, forKey: lastPreferredLanguageKey)
    }

    /// Registration; `preferredLanguageCode` is stored when the account is created.
    func signUp(email: String, password: String, preferredLanguageCode: String) -> SignUpResult {
        var users = self.users
        let lowercased = email.lowercased()
        if users[lowercased] != nil {
            return .failure(L10n.string(.accountExists, languageCode: preferredLanguageCode))
        }
        users[lowercased] = UserRecord(
            password: password,
            hasConsented: false,
            preferredLanguageCode: preferredLanguageCode
        )
        self.users = users
        return .success
    }

    func logIn(email: String, password: String) -> Bool {
        let lowercased = email.lowercased()
        guard let user = users[lowercased], user.password == password else {
            return false
        }
        self.email = email
        self.isLoggedIn = true
        self.hasConsented = user.hasConsented
        persistLanguageCode(user.preferredLanguageCode)
        UserDefaults.standard.set(lowercased, forKey: "lastUser")
        return true
    }

    func logOut() {
        self.email = ""
        self.isLoggedIn = false
        self.hasConsented = false
        UserDefaults.standard.removeObject(forKey: "lastUser")
    }

    /// Returns `nil` on success, or a short reason: `"wrongPassword"`, `"invalid"`, `"same"`, `"taken"`.
    func changeEmail(to newEmailRaw: String, currentPassword: String) -> String? {
        let trimmed = newEmailRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        let newKey = trimmed.lowercased()
        let oldKey = email.lowercased()
        guard !trimmed.isEmpty else { return "invalid" }
        guard Self.isValidEmail(trimmed) else { return "invalid" }
        guard newKey != oldKey else { return "same" }
        guard users[newKey] == nil else { return "taken" }
        guard var user = users[oldKey], user.password == currentPassword else { return "wrongPassword" }
        var next = self.users
        next[newKey] = user
        next.removeValue(forKey: oldKey)
        self.users = next
        self.email = trimmed
        UserDefaults.standard.set(newKey, forKey: "lastUser")
        return nil
    }

    /// Returns `true` if the password was updated; `false` if the current password was wrong or the new password was empty.
    func changePassword(from currentPassword: String, to newPassword: String) -> Bool {
        let key = email.lowercased()
        let trimmedNew = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNew.isEmpty else { return false }
        guard var user = users[key], user.password == currentPassword else { return false }
        user.password = trimmedNew
        var next = self.users
        next[key] = user
        self.users = next
        return true
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let regex = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES[c] %@", regex).evaluate(with: email)
    }

    /// Update language for the current user (and UI).
    func setPreferredLanguageCode(_ code: String) {
        let key = email.lowercased()
        guard !key.isEmpty else {
            persistLanguageCode(code)
            return
        }
        var users = self.users
        if var user = users[key] {
            user.preferredLanguageCode = code
            users[key] = user
            self.users = users
        }
        persistLanguageCode(code)
    }

    func recordConsent() {
        recordConsent(for: self.email)
    }

    func recordConsent(for email: String) {
        let lowercased = email.lowercased()
        var users = self.users
        if var user = users[lowercased] {
            user.hasConsented = true
            users[lowercased] = user
            self.users = users
        }
        if self.email.lowercased() == lowercased {
            self.hasConsented = true
        }
    }

    func attemptBiometricLogin(completion: @escaping (Bool) -> Void) {
        guard let lastUser = UserDefaults.standard.string(forKey: "lastUser") else {
            completion(false)
            return
        }
        let lang = users[lastUser]?.preferredLanguageCode
            ?? UserDefaults.standard.string(forKey: lastPreferredLanguageKey)
            ?? AppLanguage.bestMatchForSystem().rawValue
        let reason = L10n.string(.biometricUnlockDocuCare, languageCode: lang)
        BiometricAuth.authenticateUser(reason: reason) { [weak self] success, error in
            if success {
                self?.email = lastUser
                self?.isLoggedIn = true
                let lowercased = lastUser.lowercased()
                self?.hasConsented = self?.users[lowercased]?.hasConsented ?? false
                if let code = self?.users[lowercased]?.preferredLanguageCode {
                    self?.persistLanguageCode(code)
                }
                completion(true)
            } else {
                completion(false)
            }
        }
    }
}
