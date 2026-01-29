//
//  UnlockService.swift
//  lambdas-xi-chapter
//
//  App lock §4.1. Invite code HELLOPANDA. Server-side via RPC when Supabase configured;
//  client-side only when mock. UserDefaults §15.3 for isUnlocked.
//

import Combine
import Foundation
import Supabase

final class UnlockService: ObservableObject {
    static let shared = UnlockService()

    private let validInviteCode = "HELLOPANDA"
    private let defaults = UserDefaults.standard
    private let keyUnlocked = "lambdas_xi_invite_unlocked"

    @Published var isUnlocked: Bool {
        didSet {
            defaults.set(isUnlocked, forKey: keyUnlocked)
            debugLog("UnlockService: isUnlocked=\(isUnlocked)")
        }
    }

    private init() {
        // Load initial value from UserDefaults
        self.isUnlocked = defaults.bool(forKey: keyUnlocked)
    }

    /// Validates code. When Supabase configured: RPC validate_invite_code §4.1 server-side.
    /// Otherwise client-side only (HELLOPANDA). Returns (success, errorMessage).
    func validate(code: String) async -> (success: Bool, error: String?) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return (false, "Please enter an invite code.") }

        if let client = SupabaseConfig.client {
            do {
                let valid: Bool = try await client.rpc("validate_invite_code", params: ["p_code": trimmed]).execute().value
                if valid {
                    await MainActor.run { isUnlocked = true }
                    debugLog("UnlockService: RPC validate_invite_code ok")
                    return (true, nil)
                }
            } catch {
                debugLog("UnlockService: RPC failed \(error)")
                return (false, "Could not validate. Please try again.")
            }
            return (false, "Invalid invite code. Please try again.")
        }

        // Mock: client-side only §4.1
        if trimmed.uppercased() == validInviteCode.uppercased() {
            isUnlocked = true
            return (true, nil)
        }
        return (false, "Invalid invite code. Please try again.")
    }

    func resetUnlock() {
        isUnlocked = false
        defaults.removeObject(forKey: keyUnlocked)
        debugLog("UnlockService: reset")
    }
}
