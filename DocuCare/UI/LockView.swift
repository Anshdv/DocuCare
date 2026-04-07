//
//  LockView.swift
//  DocuCare
//
//  Created by Ansh D on 8/14/25.
//

import SwiftUI

struct LockView: View {
    @EnvironmentObject private var lock: AppLockManager
    @EnvironmentObject private var session: SessionManager

    private var lang: String { session.effectiveLanguageCode() }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44, weight: .semibold))
            Text(L10n.string(.locked, languageCode: lang))
                .font(.title2).bold()
            Text(L10n.string(.useFaceIDToUnlock, languageCode: lang))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                lock.unlock(localizedReason: L10n.string(.unlockToAccessReports, languageCode: lang))
            } label: {
                Label(L10n.string(.unlockWithFaceID, languageCode: lang), systemImage: "faceid")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .onAppear {
            lock.unlock(localizedReason: L10n.string(.unlockToAccessReports, languageCode: lang))
        }
    }
}
