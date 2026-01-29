//
//  ClerkConfig.swift
//  lambdas-xi-chapter
//
//  Clerk authentication configuration. Reads publishable key from Info.plist.
//  Initializes Clerk SDK for authentication flows.
//

import Foundation
import Clerk

/// Clerk configuration. Key in Info.plist: ClerkPublishableKey
/// Debug: Provides centralized Clerk initialization and status checking
enum ClerkConfig {
    // MARK: - Info.plist Keys
    private static let publishableKeyPlistKey = "ClerkPublishableKey"
    
    // MARK: - Configuration Properties
    
    /// Clerk publishable key from Info.plist
    /// Debug: Returns nil if key is missing or empty
    static var publishableKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: publishableKeyPlistKey) as? String,
              !key.trimmingCharacters(in: .whitespaces).isEmpty,
              key.hasPrefix("pk_") // Clerk keys always start with pk_
        else {
            debugLog("ClerkConfig: publishable key not found or invalid in Info.plist")
            return nil
        }
        return key.trimmingCharacters(in: .whitespaces)
    }
    
    /// True when publishable key is valid; use real Clerk authentication
    /// Debug: Check this before attempting Clerk operations
    static var isConfigured: Bool {
        publishableKey != nil
    }
    
    /// Shared Clerk instance reference
    /// Debug: Access Clerk.shared directly for user/session data
    static var clerk: Clerk {
        Clerk.shared
    }
    
    // MARK: - Initialization
    
    /// Call from app init. Configures Clerk with publishable key from Info.plist.
    /// Debug: Must be called before any Clerk operations
    @MainActor
    static func initialize() async {
        guard let key = publishableKey else {
            debugLog("ClerkConfig: not configured, Clerk authentication disabled")
            debugLog("ClerkConfig: add ClerkPublishableKey to Info.plist to enable")
            return
        }
        
        // Configure Clerk with the publishable key
        clerk.configure(publishableKey: key)
        debugLog("ClerkConfig: configured with key \(key.prefix(20))...")
        
        // Load Clerk to restore any existing session
        do {
            try await clerk.load()
            if let user = clerk.user {
                debugLog("ClerkConfig: loaded with existing user: \(user.id)")
            } else {
                debugLog("ClerkConfig: loaded, no existing session")
            }
        } catch {
            debugLog("ClerkConfig: failed to load - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Session Token
    
    /// Get the current Clerk session token for Supabase authentication
    /// Debug: Returns nil if no active session
    @MainActor
    static func getSessionToken() async -> String? {
        guard let session = clerk.session else {
            debugLog("ClerkConfig: no active session for token")
            return nil
        }
        
        do {
            // getToken() returns TokenResource, extract the jwt string
            let tokenResource = try await session.getToken()
            let jwtString = tokenResource?.jwt
            debugLog("ClerkConfig: got session token (length: \(jwtString?.count ?? 0))")
            return jwtString
        } catch {
            debugLog("ClerkConfig: failed to get session token - \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - User Info
    
    /// Current Clerk user ID (sub claim)
    /// Debug: This is the ID used in Supabase RLS policies (auth.jwt() ->> 'sub')
    @MainActor
    static var currentUserId: String? {
        clerk.user?.id
    }
    
    /// Current user's primary email address
    /// Debug: Returns the first verified email from Clerk
    @MainActor
    static var currentUserEmail: String? {
        clerk.user?.primaryEmailAddress?.emailAddress
    }
    
    /// Current user's username
    /// Debug: Returns username from Clerk user object
    @MainActor
    static var currentUsername: String? {
        clerk.user?.username
    }
    
    /// Check if user is currently signed in
    /// Debug: Use for conditional UI rendering
    @MainActor
    static var isSignedIn: Bool {
        clerk.user != nil
    }
}
