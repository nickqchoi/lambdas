//
//  KeychainService.swift
//  lambdas-xi-chapter
//
//  Encrypted token storage per §5.3, §17.1. Uses iOS Keychain.
//

import Foundation
import Security

/// Keychain wrapper for auth tokens. §5.3 Encrypted token storage (iOS Keychain).
final class KeychainService {
    static let shared = KeychainService()

    private let serviceName = "lambdas-xi-chapter"
    private let tokenAccount = "authToken"
    private let refreshTokenAccount = "refreshToken"

    private init() {}

    // MARK: - Token Storage

    func saveAuthToken(_ token: String) {
        save(key: tokenAccount, value: token)
        debugLog("KeychainService: auth token saved")
    }

    func getAuthToken() -> String? {
        get(key: tokenAccount)
    }

    func saveRefreshToken(_ token: String) {
        save(key: refreshTokenAccount, value: token)
        debugLog("KeychainService: refresh token saved")
    }

    func getRefreshToken() -> String? {
        get(key: refreshTokenAccount)
    }

    func clearTokens() {
        delete(key: tokenAccount)
        delete(key: refreshTokenAccount)
        debugLog("KeychainService: tokens cleared")
    }

    // MARK: - Generic Keychain Operations

    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]
        // Remove existing before add (upsert)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            debugLog("KeychainService: save failed for \(key), status=\(status)")
        }
    }

    private func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

