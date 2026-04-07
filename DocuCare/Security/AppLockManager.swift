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

    func unlock(localizedReason: String) {
        let context = LAContext()
        var err: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: localizedReason) { success, _ in
                DispatchQueue.main.async { self.isLocked = !success }
            }
        }
    }

    func lock() { isLocked = true }
}
