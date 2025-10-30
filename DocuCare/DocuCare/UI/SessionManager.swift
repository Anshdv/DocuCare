import Foundation
import Combine

final class SessionManager: ObservableObject {
    @Published var isLoggedIn: Bool {
        didSet { UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn") }
    }
    @Published var email: String = ""

    static let shared = SessionManager()

    private init() {
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        self.email = UserDefaults.standard.string(forKey: "lastUser") ?? ""
    }

    enum SignUpResult {
        case success
        case failure(String)
    }

    // Registration logic
    func signUp(email: String, password: String) -> SignUpResult {
        var users = UserDefaults.standard.dictionary(forKey: "users") as? [String: String] ?? [:]
        let lowercased = email.lowercased()
        if users[lowercased] != nil {
            return .failure("An account with this email already exists.")
        }
        users[lowercased] = password
        UserDefaults.standard.set(users, forKey: "users")
        return .success
    }

    // Universal log in logic
    func logIn(email: String, password: String) -> Bool {
        let users = UserDefaults.standard.dictionary(forKey: "users") as? [String: String] ?? [:]
        let lowercased = email.lowercased()
        if let stored = users[lowercased], stored == password {
            self.email = email
            self.isLoggedIn = true
            UserDefaults.standard.set(lowercased, forKey: "lastUser")
            return true
        }
        return false
    }

    func logOut() {
        self.email = ""
        self.isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: "lastUser")
    }

    /// Call this on app launch to auto-login with biometrics if a last user exists
    func attemptBiometricLogin(completion: @escaping (Bool) -> Void) {
        guard let lastUser = UserDefaults.standard.string(forKey: "lastUser") else {
            completion(false)
            return
        }
        BiometricAuth.authenticateUser { [weak self] success, error in
            if success {
                self?.email = lastUser
                self?.isLoggedIn = true
                completion(true)
            } else {
                completion(false)
            }
        }
    }
}
