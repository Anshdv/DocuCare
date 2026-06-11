import Foundation
import Combine

struct UserRecord: Codable {
    var password: String
    var hasConsented: Bool
    /// `AppLanguage.rawValue`
    var preferredLanguageCode: String
    /// `AppFontSize.rawValue`
    var preferredFontSizeRaw: String
    /// User explicitly opted in to having DocuCare read from Apple Health.
    /// Defaults to `false`; toggled only after the system Health auth sheet completes.
    var healthKitConnected: Bool

    init(
        password: String,
        hasConsented: Bool,
        preferredLanguageCode: String = AppLanguage.english.rawValue,
        preferredFontSizeRaw: String = AppFontSize.default.rawValue,
        healthKitConnected: Bool = false
    ) {
        self.password = password
        self.hasConsented = hasConsented
        self.preferredLanguageCode = preferredLanguageCode
        self.preferredFontSizeRaw = preferredFontSizeRaw
        self.healthKitConnected = healthKitConnected
    }

    enum CodingKeys: String, CodingKey {
        case password, hasConsented, preferredLanguageCode, preferredFontSizeRaw, healthKitConnected
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        password = try c.decode(String.self, forKey: .password)
        hasConsented = try c.decode(Bool.self, forKey: .hasConsented)
        preferredLanguageCode = try c.decodeIfPresent(String.self, forKey: .preferredLanguageCode) ?? AppLanguage.english.rawValue
        preferredFontSizeRaw = try c.decodeIfPresent(String.self, forKey: .preferredFontSizeRaw) ?? AppFontSize.default.rawValue
        healthKitConnected = try c.decodeIfPresent(Bool.self, forKey: .healthKitConnected) ?? false
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
    /// Mirrors the signed-in user's `preferredFontSize`, or the last known choice when logged out.
    @Published var preferredFontSize: AppFontSize
    /// Whether the signed-in user has connected DocuCare to Apple Health.
    /// Drives whether health context is attached to AI requests.
    @Published var healthKitConnected: Bool = false

    /// Bumped whenever UI language strings should refresh (e.g. TextField prompts).
    @Published private(set) var localizationRevision: UInt = 0

    static let shared = SessionManager()

    private let usersKey = "users"
    private let lastPreferredLanguageKey = "lastPreferredLanguageCode"
    private let lastPreferredFontSizeKey = "lastPreferredFontSize"

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
        let storedFontSize = UserDefaults.standard.string(forKey: lastPreferredFontSizeKey)
        self.preferredFontSize = AppFontSize.from(rawValue: storedFontSize)
        if isLoggedIn {
            let lowercased = self.email.lowercased()
            self.hasConsented = users[lowercased]?.hasConsented ?? false
            if let code = users[lowercased]?.preferredLanguageCode {
                self.preferredLanguageCode = code
            }
            if let fontRaw = users[lowercased]?.preferredFontSizeRaw {
                self.preferredFontSize = AppFontSize.from(rawValue: fontRaw)
            }
            self.healthKitConnected = users[lowercased]?.healthKitConnected ?? false
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

    private func persistFontSize(_ size: AppFontSize) {
        preferredFontSize = size
        UserDefaults.standard.set(size.rawValue, forKey: lastPreferredFontSizeKey)
    }

    /// Registration; `preferredLanguageCode` and `preferredFontSize` are stored when the account is created.
    func signUp(
        email: String,
        password: String,
        preferredLanguageCode: String,
        preferredFontSize: AppFontSize = .default
    ) -> SignUpResult {
        var users = self.users
        let lowercased = email.lowercased()
        if users[lowercased] != nil {
            return .failure(L10n.string(.accountExists, languageCode: preferredLanguageCode))
        }
        users[lowercased] = UserRecord(
            password: password,
            hasConsented: false,
            preferredLanguageCode: preferredLanguageCode,
            preferredFontSizeRaw: preferredFontSize.rawValue
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
        self.healthKitConnected = user.healthKitConnected
        persistLanguageCode(user.preferredLanguageCode)
        persistFontSize(AppFontSize.from(rawValue: user.preferredFontSizeRaw))
        UserDefaults.standard.set(lowercased, forKey: "lastUser")
        return true
    }

    func logOut() {
        self.email = ""
        self.isLoggedIn = false
        self.hasConsented = false
        self.healthKitConnected = false
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

    /// Update Apple Health connection flag for the current user.
    /// `true` means DocuCare will attach a health snapshot to AI requests when possible.
    func setHealthKitConnected(_ connected: Bool) {
        let key = email.lowercased()
        guard !key.isEmpty else {
            self.healthKitConnected = connected
            return
        }
        var users = self.users
        if var user = users[key] {
            user.healthKitConnected = connected
            users[key] = user
            self.users = users
        }
        self.healthKitConnected = connected
    }

    /// Update font size for the current user (and UI).
    func setPreferredFontSize(_ size: AppFontSize) {
        let key = email.lowercased()
        guard !key.isEmpty else {
            persistFontSize(size)
            return
        }
        var users = self.users
        if var user = users[key] {
            user.preferredFontSizeRaw = size.rawValue
            users[key] = user
            self.users = users
        }
        persistFontSize(size)
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
                self?.healthKitConnected = self?.users[lowercased]?.healthKitConnected ?? false
                if let code = self?.users[lowercased]?.preferredLanguageCode {
                    self?.persistLanguageCode(code)
                }
                if let fontRaw = self?.users[lowercased]?.preferredFontSizeRaw {
                    self?.persistFontSize(AppFontSize.from(rawValue: fontRaw))
                }
                completion(true)
            } else {
                completion(false)
            }
        }
    }
}
