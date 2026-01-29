//
//  SupabaseConfig.swift
//  lambdas-xi-chapter
//
//  Reads Supabase URL and anon key from Info.plist. Integrates with Clerk
//  for authentication - Clerk session tokens are injected into Supabase requests.
//  If both Supabase and Clerk are configured, uses real backend with Clerk auth.
//

import Foundation
import Supabase
import Clerk

/// Supabase configuration with Clerk authentication integration.
/// Keys in Info.plist: SupabaseURL, SupabaseAnonKey, ClerkPublishableKey.
/// Debug: Clerk tokens are automatically injected into Supabase requests for RLS
enum SupabaseConfig {
    // MARK: - Info.plist Keys
    private static let urlKey = "SupabaseURL"
    private static let anonKeyPlistKey = "SupabaseAnonKey"

    // MARK: - URL Configuration
    
    /// Supabase project URL from Info.plist
    /// Debug: Must be https scheme
    static var url: URL? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: urlKey) as? String,
              !s.trimmingCharacters(in: .whitespaces).isEmpty,
              let u = URL(string: s.trimmingCharacters(in: .whitespaces)),
              u.scheme == "https"
        else { 
            let raw = Bundle.main.object(forInfoDictionaryKey: urlKey) as? String
            debugLog("SupabaseConfig: URL error. Raw value: '\(raw ?? "nil")'")
            return nil 
        }
        debugLog("SupabaseConfig: URL loaded successfully: \(u.absoluteString)")
        return u
    }

    /// URL for Edge Functions (if needed)
    /// Debug: Base URL + /functions/v1/
    static var functionsBaseURL: URL? {
        guard let base = url?.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        else { return nil }
        return URL(string: "\(base)/functions/v1")
    }

    // MARK: - API Key
    
    /// Supabase anon key from Info.plist
    /// Debug: Used for public API access, RLS controls actual permissions
    static var supabaseAnonKey: String? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: anonKeyPlistKey) as? String,
              !s.trimmingCharacters(in: .whitespaces).isEmpty
        else { 
            let raw = Bundle.main.object(forInfoDictionaryKey: anonKeyPlistKey) as? String
            debugLog("SupabaseConfig: Anon key error. Raw value: '\(raw ?? "nil")'")
            return nil 
        }
        let key = s.trimmingCharacters(in: .whitespaces)
        debugLog("SupabaseConfig: Anon key loaded (length: \(key.count))")
        return key
    }

    // MARK: - Configuration Status
    
    /// True when both Supabase URL and anon key are valid; use real backend.
    /// Debug: Check this before attempting Supabase operations
    static var isConfigured: Bool {
        url != nil && supabaseAnonKey != nil
    }
    
    /// True when both Supabase and Clerk are configured for full functionality
    /// Debug: Best experience requires both services configured
    static var isFullyConfigured: Bool {
        isConfigured && ClerkConfig.isConfigured
    }

    // MARK: - Supabase Client
    
    /// Shared Supabase client with Clerk token injection.
    /// Debug: Nil when not configured. Call initialize() at app launch.
    static private(set) var client: SupabaseClient?

    /// Call from app init. Creates client with Clerk token injection.
    /// Debug: Clerk tokens are automatically fetched for each Supabase request
    static func initialize() {
        guard let u = url, let k = supabaseAnonKey else {
            debugLog("SupabaseConfig: not configured, using mock services")
            return
        }
        
        // Create Supabase client with Clerk session token injection
        // Debug: accessToken closure is called for each authenticated request
        client = SupabaseClient(
            supabaseURL: u,
            supabaseKey: k,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    // Inject Clerk session token for Supabase RLS policies
                    // Debug: This enables auth.jwt() ->> 'sub' in RLS
                    accessToken: {
                        // Get Clerk session on MainActor (Clerk is MainActor-isolated)
                        let session = await MainActor.run { Clerk.shared.session }
                        guard let session = session else {
                            // Debug log on MainActor
                            await MainActor.run { debugLog("SupabaseConfig: no Clerk session for access token") }
                            return nil
                        }
                        
                        do {
                            // getToken() returns TokenResource, extract the jwt string
                            let tokenResource = try await session.getToken()
                            let jwtString = tokenResource?.jwt
                            await MainActor.run { debugLog("SupabaseConfig: injected Clerk token (length: \(jwtString?.count ?? 0))") }
                            return jwtString
                        } catch {
                            await MainActor.run { debugLog("SupabaseConfig: failed to get Clerk token - \(error)") }
                            return nil
                        }
                    }
                )
            )
        )
        
        debugLog("SupabaseConfig: client created for \(u.host ?? "") with Clerk auth")
    }
    
    // MARK: - Helper Methods
    
    /// Refresh the Supabase client (call if Clerk session changes)
    /// Debug: Use after sign-in/sign-out to ensure fresh token
    static func refreshClient() {
        debugLog("SupabaseConfig: refreshing client")
        initialize()
    }
}
