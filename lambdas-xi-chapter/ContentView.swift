//
//  ContentView.swift
//  lambdas-xi-chapter
//
//  Root router: AppLock §4 → Auth §5 → Profile §6.1 → Main (placeholder).
//  Debug: Uses Clerk authentication and Clerk user IDs
//

import SwiftUI

struct ContentView: View {
    @StateObject private var unlock = UnlockService.shared
    @StateObject private var auth = AuthService.shared
    @StateObject private var profileService = ProfileService.shared
    @State private var profileComplete: Bool = false
    @State private var profileChecked: Bool = false

    var body: some View {
        Group {
            // Debug: App flow: Unlock → Auth → Profile → Main
            if !unlock.isUnlocked {
                // Step 1: Invite code unlock
                AppLockView()
            } else if !isAuthenticated {
                // Step 2: Clerk authentication (handles verification states internally)
                AuthView()
            } else if !profileComplete {
                // Step 3: Profile setup (first time users)
                ProfileSetupView()
            } else {
                // Step 4: Main app
                MainTabView()
                    .withNotificationBanner()
                    .withNotificationBanner()
                    .onAppear {
                        // Debug: Only seed mock data if Supabase is NOT configured
                        if SupabaseConfig.client == nil, let clerkId = auth.currentUser?.clerkId {
                            debugLog("ContentView: seeding mock data for development")
                            profileService.seedMockProfiles(currentClerkUserId: clerkId)
                            // Note: BountyService and NewsService need similar updates for Clerk IDs
                            NewsService.shared.seedMockNews()
                        }
                    }
            }
        }
        .tint(Color.appPrimary) // Global tint color
        .task(id: auth.currentUser?.clerkId) {
            // Debug: Fetch profile when user changes
            await checkProfileCompletion()
        }
        .onChange(of: profileService.profileSaveComplete) { _, newValue in
            // Debug: Re-check profile after save
            guard newValue else { return }
            Task {
                await checkProfileCompletion()
                debugLog("ContentView: profile re-checked after save, complete=\(profileComplete)")
            }
        }
        .onChange(of: auth.authState) { _, newState in
            // Debug: Handle auth state changes
            if case .unauthenticated = newState {
                profileComplete = false
                profileChecked = false
                debugLog("ContentView: user signed out, reset profile state")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Check if user is fully authenticated (not just in verification flow)
    /// Debug: Returns true only when user has completed auth flow
    private var isAuthenticated: Bool {
        if case .authenticated = auth.authState {
            return true
        }
        return false
    }
    
    // MARK: - Profile Check
    
    /// Check if current user's profile is complete
    /// Debug: Fetches profile from Supabase and validates required fields
    private func checkProfileCompletion() async {
        guard let clerkId = auth.currentUser?.clerkId else {
            // Debug: No user, reset profile state
            profileComplete = false
            profileChecked = true
            debugLog("ContentView: no user, profile not complete")
            // Ensure we clean up realtime subscriptions if no user
            await RealtimeService.shared.unsubscribeFromAll()
            return
        }
        
        debugLog("ContentView: checking profile for clerk_user_id: \(clerkId)")
        
        // Fetch profile from Supabase (or cache)
        let profile = await profileService.fetchProfile(clerkUserId: clerkId)
        
        if let p = profile {
            profileComplete = profileService.isProfileComplete(p)
            debugLog("ContentView: profile found, complete=\(profileComplete)")
            
            // Setup RealtimeService now that we have a profile ID
            await setupRealtime(profile: p)
        } else {
            // No profile exists yet
            profileComplete = false
            debugLog("ContentView: no profile found, needs setup")
        }
        
        profileChecked = true
    }
    
    // MARK: - Realtime Setup
    
    /// Setup RealtimeService with current user's profile
    /// Debug: Ensures subscriptions are established only after we know who the user is
    private func setupRealtime(profile: Profile) async {
        debugLog("ContentView: setting up realtime for profile \(profile.id)")
        
        // 1. Set current user ID for filtering
        RealtimeService.shared.setCurrentUser(profileId: profile.id)
        
        // 2. Subscribe to bounty events
        await RealtimeService.shared.subscribeToBountyEvents()
        
        // 3. Subscribe to global messages
        await RealtimeService.shared.subscribeToAllMessages()
        
        debugLog("ContentView: realtime setup complete")
    }
}

#Preview {
    ContentView()
}
