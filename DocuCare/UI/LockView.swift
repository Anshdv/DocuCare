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
        ZStack {
            AppBackgroundView()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(L10n.string(.locked, languageCode: lang))
                    .font(.title2).bold()
                    .foregroundStyle(AppTheme.softText)
                Text(L10n.string(.useFaceIDToUnlock, languageCode: lang))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                Button {
                    lock.unlock(localizedReason: L10n.string(.unlockToAccessReports, languageCode: lang))
                } label: {
                    Label(L10n.string(.unlockWithFaceID, languageCode: lang), systemImage: "faceid")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .id(session.localizationRevision)
            .padding(22)
            .appCardStyle()
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            lock.unlock(localizedReason: L10n.string(.unlockToAccessReports, languageCode: lang))
        }
    }
}
