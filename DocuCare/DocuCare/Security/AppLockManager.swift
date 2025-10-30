//
//  AppLockManager.swift
//  DocuCare
//
//  Created by Ansh D on 8/14/25.
//

import Foundation
import LocalAuthentication
import Combine

final class AppLockManager: ObservableObject {
    @Published var isLocked: Bool = true

    func unlock() {
        let context = LAContext()
        var err: NSError?
        let reason = "Unlock to access your medical reports."

        // Use .deviceOwnerAuthentication to allow biometrics or passcode fallback
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                DispatchQueue.main.async { self.isLocked = !success }
            }
        }
    }

    func lock() { isLocked = true }
}
