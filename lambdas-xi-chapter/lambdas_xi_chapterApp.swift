//
//  lambdas_xi_chapterApp.swift
//  lambdas-xi-chapter
//
//  Created by Nicholas Choi on 25/01/2026.
//  Debug: Initializes Clerk and Supabase at app launch
//

import SwiftUI
import Clerk

@main
struct lambdas_xi_chapterApp: App {
    // Debug: Reference to shared Clerk instance for environment injection
    @State private var clerk = Clerk.shared
    
    init() {
        // Debug: Initialize Supabase first (Clerk will be initialized async)
        // Note: Supabase client uses Clerk token injection, so order matters
        debugLog("App: init - starting Supabase initialization")
        SupabaseConfig.initialize()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Debug: Inject Clerk into SwiftUI environment
                .environment(\.clerk, clerk)
                .task {
                    // Debug: Initialize Clerk asynchronously at app start
                    debugLog("App: task - starting Clerk initialization")
                    await ClerkConfig.initialize()
                    debugLog("App: task - Clerk initialization complete")
                }
        }
    }
}
