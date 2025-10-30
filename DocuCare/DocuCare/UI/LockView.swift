//
//  LockView.swift
//  DocuCare
//
//  Created by Ansh D on 8/14/25.
//

import SwiftUI

struct LockView: View {
    @EnvironmentObject private var lock: AppLockManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44, weight: .semibold))
            Text("Locked")
                .font(.title2).bold()
            Text("Use Face ID to unlock your reports.")
                .foregroundStyle(.secondary)
            Button {
                lock.unlock()
            } label: {
                Label("Unlock with Face ID", systemImage: "faceid")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .onAppear { lock.unlock() }
    }
}
