//
//  AppLockView.swift
//  lambdas-xi-chapter
//
//  App lock on first launch §4.1. App branding, "Enter Invite Code", Unlock. HELLOPANDA.
//

import SwiftUI

struct AppLockView: View {
    @StateObject private var unlock = UnlockService.shared
    @State private var code: String = ""
    @State private var errorMessage: String?
    @State private var isUnlocking = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // §4.1 App branding
            VStack(spacing: 8) {
                Image.appLogo
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                
                Text("Lambdas Xi Chapter")
                    .appHeaderFont()
                    .multilineTextAlignment(.center)
                
                Text("Private, invite-only")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
            }

            // §4.1 Text input: "Enter Invite Code"
            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter Invite Code", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .disabled(isUnlocking)
                    .onSubmit { unlockTapped() }

                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: 320)

            // §4.1 Button: "Unlock"
            Button(action: unlockTapped) {
                if isUnlocking {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: 200)
                } else {
                    Text("Unlock")
                        .frame(maxWidth: 200)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isUnlocking || code.isEmpty)

            Spacer()
        }
        .padding()
    }

    private func unlockTapped() {
        errorMessage = nil
        isUnlocking = true
        Task {
            let (success, err) = await unlock.validate(code: code)
            await MainActor.run {
                isUnlocking = false
                if success { debugLog("AppLockView: unlock success") }
                else { errorMessage = err; debugLog("AppLockView: unlock failed, \(err ?? "")") }
            }
        }
    }
}

#Preview {
    AppLockView()
}
