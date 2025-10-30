import SwiftUI
import SwiftData

@main
struct MedicalSummaryApp: App {
    @StateObject private var appLock = AppLockManager()
    @StateObject private var session = SessionManager.shared
    @State private var checkingBiometric = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if checkingBiometric {
                    ProgressView("Authenticating…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                } else if session.isLoggedIn {
                    ContentView()
                        .environmentObject(appLock)
                        .environmentObject(session)
                        .blur(radius: appLock.isLocked ? 12 : 0)

                    if appLock.isLocked {
                        LockView()
                            .environmentObject(appLock)
                            .transition(.opacity)
                    }
                } else {
                    LoginView()
                        .environmentObject(session)
                }
            }
            .onAppear {
                // Only check biometrics if not already logged in
                if !session.isLoggedIn,
                   UserDefaults.standard.string(forKey: "lastUser") != nil {
                    session.attemptBiometricLogin { _ in
                        checkingBiometric = false
                    }
                } else {
                    checkingBiometric = false
                }
            }
        }
        .modelContainer(makeModelContainer())
    }
}

// Helper function for safer SwiftData load
func makeModelContainer() -> ModelContainer {
    do {
        return try ModelContainer(for: MedicalReport.self)
    } catch {
        print("Failed to load SwiftData ModelContainer:", error)
        fatalError("SwiftData ModelContainer load failed: \(error)")
    }
}
