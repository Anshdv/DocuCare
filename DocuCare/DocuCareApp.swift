import SwiftUI
import SwiftData

@main
struct MedicalSummaryApp: App {
    @StateObject private var appLock = AppLockManager()
    @StateObject private var session = SessionManager.shared
    @State private var checkingBiometric = true

    var body: some Scene {
        WindowGroup {
            rootContent
                .dynamicTypeSize(session.preferredFontSize.dynamicTypeSize)
        }
        .modelContainer(makeModelContainer())
    }

    @ViewBuilder
    private var rootContent: some View {
        ZStack {
            if checkingBiometric {
                ZStack {
                    AppBackgroundView()
                    ProgressView(L10n.string(.authenticating, languageCode: session.effectiveLanguageCode()))
                        .foregroundStyle(AppTheme.softText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if session.isLoggedIn {
                if session.hasConsented {
                    ContentView()
                        .environmentObject(appLock)
                        .environmentObject(session)
                        .blur(radius: appLock.isLocked ? 12 : 0)

                    if appLock.isLocked {
                        LockView()
                            .environmentObject(appLock)
                            .environmentObject(session)
                            .transition(.opacity)
                    }
                } else {
                    ConsentAndPrivacyView(languageCode: session.effectiveLanguageCode()) {
                        session.recordConsent()
                    }
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
}

// Helper function for safer SwiftData load
func makeModelContainer() -> ModelContainer {
    do {
        return try ModelContainer(
            for: MedicalReport.self,
            DailyLesson.self,
            LessonStreak.self,
            CalendarEvent.self,
            MedicationSchedule.self,
            MedicationLog.self
        )
    } catch {
        print("Failed to load SwiftData ModelContainer:", error)
        fatalError("SwiftData ModelContainer load failed: \(error)")
    }
}
