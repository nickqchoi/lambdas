//
//  ProfileService.swift
//  lambdas-xi-chapter
//
//  User/profile service §16.2. Supabase when configured; else mock. Profile gating §6.1.
//  Debug: Uses Clerk user IDs for profile lookups and RLS compliance
//

import Foundation
import Combine
import Supabase

/// Profile service for user profile management
/// Debug: Profiles are keyed by Clerk user ID for Clerk authentication integration
final class ProfileService: ObservableObject {
    static let shared = ProfileService()

    // MARK: - Published Properties
    
    /// Cached profiles keyed by Clerk user ID
    /// Debug: Use clerkUserId as key for consistency with RLS
    @Published private var profiles: [String: Profile] = [:]
    
    /// Flag to signal profile save completion
    /// Debug: Used to trigger UI updates after save
    @Published var profileSaveComplete: Bool = false

    // MARK: - Initialization
    
    private init() { 
        debugLog("ProfileService: init with Clerk user ID keying") 
    }
    
    // MARK: - State Management
    
    /// Reset the profile save flag
    /// Debug: Call before initiating a new save operation
    func resetProfileSaveFlag() {
        profileSaveComplete = false
        debugLog("ProfileService: profileSaveComplete reset to false")
    }
    
    /// Clear all cached profiles
    /// Debug: Call on sign out to clear user data
    func clearCache() {
        profiles.removeAll()
        profileSaveComplete = false
        debugLog("ProfileService: cache cleared")
    }

    // MARK: - Profile Retrieval

    /// Get cached profile by Clerk user ID
    /// Debug: Returns nil if not cached; use fetchProfile to load from Supabase
    func getProfile(clerkUserId: String) -> Profile? { 
        profiles[clerkUserId] 
    }
    
    /// Get cached profile by profile UUID
    /// Debug: Searches all cached profiles for matching ID
    func getProfile(id: UUID) -> Profile? { 
        profiles.values.first { $0.id == id } 
    }

    /// Fetches profile from Supabase by Clerk user ID and caches it
    /// Debug: Use this to load profile for current user or other users
    func fetchProfile(clerkUserId: String) async -> Profile? {
        guard !clerkUserId.isEmpty else {
            debugLog("ProfileService: fetchProfile called with empty clerkUserId")
            return nil
        }
        
        if let c = SupabaseConfig.client {
            do {
                // Debug: Query by clerk_user_id column
                let p: Profile = try await c.from("profiles")
                    .select()
                    .eq("clerk_user_id", value: clerkUserId)
                    .single()
                    .execute()
                    .value
                
                await MainActor.run { profiles[clerkUserId] = p }
                debugLog("ProfileService: fetched profile for clerk_user_id: \(clerkUserId)")
                return p
            } catch { 
                debugLog("ProfileService: fetchProfile error for \(clerkUserId) - \(error)")
                return nil 
            }
        }
        
        // Mock: return cached profile
        return profiles[clerkUserId]
    }
    
    /// Fetches profile from Supabase by profile UUID
    /// Debug: Use for loading other users' profiles by their profile ID
    func fetchProfile(id: UUID) async -> Profile? {
        if let c = SupabaseConfig.client {
            do {
                let p: Profile = try await c.from("profiles")
                    .select()
                    .eq("id", value: id)
                    .single()
                    .execute()
                    .value
                
                await MainActor.run { profiles[p.clerkUserId] = p }
                debugLog("ProfileService: fetched profile by id: \(id)")
                return p
            } catch {
                debugLog("ProfileService: fetchProfile by id error - \(error)")
                return nil
            }
        }
        return profiles.values.first { $0.id == id }
    }

    // MARK: - Profile Validation
    
    /// Check if profile has all required fields filled
    /// Debug: Use for profile gating before allowing app access
    func isProfileComplete(_ p: Profile) -> Bool {
        let isComplete = !p.fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && !p.chapterClass.trimmingCharacters(in: .whitespaces).isEmpty
            && !p.graduationYear.trimmingCharacters(in: .whitespaces).isEmpty
            && !p.majorOrIndustry.trimmingCharacters(in: .whitespaces).isEmpty
            && p.skills.count >= 2 && p.skills.count <= 5
            && !p.shortBio.trimmingCharacters(in: .whitespaces).isEmpty
        
        debugLog("ProfileService: isProfileComplete = \(isComplete) for \(p.clerkUserId)")
        return isComplete
    }

    // MARK: - Profile Saving
    
    /// Save or update profile to Supabase
    /// Debug: Uses upsert to insert or update, clerk_user_id is used for RLS
    func saveProfile(_ profile: Profile) {
        var p = profile
        p.updatedAt = Date()
        
        // Debug: Ensure clerk_user_id is set
        guard !p.clerkUserId.isEmpty else {
            debugLog("ProfileService: saveProfile failed - clerkUserId is empty")
            return
        }
        
        // Reset flag first to ensure onChange triggers
        profileSaveComplete = false
        
        if let c = SupabaseConfig.client {
            Task {
                do {
                    // Debug: Upsert using id as conflict target
                    try await c.from("profiles").upsert(p).execute()
                    await MainActor.run {
                        profiles[p.clerkUserId] = p
                        // Set to true to trigger ContentView.onChange
                        profileSaveComplete = true
                    }
                    debugLog("ProfileService: upserted profile for clerk_user_id: \(p.clerkUserId)")
                } catch { 
                    debugLog("ProfileService: upsert failed - \(error)") 
                    await MainActor.run {
                        profileSaveComplete = false
                    }
                }
            }
        } else {
            // Mock mode
            profiles[p.clerkUserId] = p
            // Small delay to ensure state updates properly
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                await MainActor.run {
                    profileSaveComplete = true
                    debugLog("ProfileService: saved profile (mock) for clerk_user_id: \(p.clerkUserId)")
                }
            }
        }
    }

    // MARK: - Profile Photo Upload
    
    /// Upload profile photo to Supabase Storage
    /// Returns public URL of the uploaded image
    func uploadProfilePhoto(data: Data, clerkUserId: String) async throws -> String {
        guard let c = SupabaseConfig.client else {
            // Mock: return a placeholder
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return "https://via.placeholder.com/150"
        }
        
        // Define file path: avatars/{clerkUserId}.jpg
        // Using a timestamp to avoid caching issues if they update it
        let fileName = "avatars/\(clerkUserId)_\(Int(Date().timeIntervalSince1970)).jpg"
        let fileOptions = FileOptions(cacheControl: "3600", upsert: true)
        
        do {
            _ = try await c.storage
                .from("profile-photos")
                .upload(fileName, data: data, options: fileOptions)
            
            // Get public URL
            // Manually construct URL to avoid API version issues
            // Format: https://<project-ref>.supabase.co/storage/v1/object/public/<bucket>/<path>
            guard let supabaseURL = SupabaseConfig.url else {
                debugLog("ProfileService: no Supabase URL configured")
                throw URLError(.badURL)
            }
            let publicURL = supabaseURL.appendingPathComponent("storage/v1/object/public/profile-photos/\(fileName)")
            
            debugLog("ProfileService: uploaded photo to \(publicURL.absoluteString)")
            return publicURL.absoluteString
        } catch {
            debugLog("ProfileService: upload failed - \(error)")
            throw error
        }
    }

    // MARK: - Discovery
    
    /// Discovery feed §8.1. Fetches profiles with optional filters.
    /// Debug: Excludes current user and applies role/skills/graduation filters
    func discoveryProfiles(
        excludingClerkUserId: String?,
        roleFilter: RoleTag?,
        skillsFilter: [String],
        graduationFilter: String?
    ) async -> [Profile] {
        if let c = SupabaseConfig.client {
            do {
                var q = c.from("profiles").select()
                if let r = roleFilter { q = q.eq("role_tag", value: r.rawValue) }
                let list: [Profile] = try await q.execute().value
                var out = list
                
                // Filter out current user
                if let ex = excludingClerkUserId { 
                    out = out.filter { $0.clerkUserId != ex } 
                }
                
                // Filter by skills
                if !skillsFilter.isEmpty {
                    out = out.filter { p in
                        skillsFilter.contains { s in 
                            p.skills.contains { $0.label.localizedCaseInsensitiveContains(s) } 
                        }
                    }
                }
                
                // Filter by graduation year
                if let g = graduationFilter, !g.isEmpty { 
                    out = out.filter { $0.graduationYear.localizedCaseInsensitiveContains(g) } 
                }
                
                debugLog("ProfileService: discovery returned \(out.count) profiles")
                return out.sorted { ($0.updatedAt, $0.fullName) > ($1.updatedAt, $1.fullName) }
            } catch {
                debugLog("ProfileService: discovery failed - \(error)")
                return []
            }
        }
        
        // Mock mode: filter in-memory cache
        var list = Array(profiles.values)
        if let ex = excludingClerkUserId { list = list.filter { $0.clerkUserId != ex } }
        if let r = roleFilter { list = list.filter { $0.roleTag == r } }
        if !skillsFilter.isEmpty { 
            list = list.filter { p in 
                skillsFilter.contains { s in 
                    p.skills.contains { $0.label.localizedCaseInsensitiveContains(s) } 
                } 
            } 
        }
        if let g = graduationFilter, !g.isEmpty { 
            list = list.filter { $0.graduationYear.localizedCaseInsensitiveContains(g) } 
        }
        return list.sorted { ($0.updatedAt, $0.fullName) > ($1.updatedAt, $1.fullName) }
    }

    // MARK: - Mock Data
    
    /// Seed mock profiles for development/testing
    /// Debug: Creates sample profiles with mock Clerk user IDs
    func seedMockProfiles(currentClerkUserId: String) {
        let p1 = Profile(
            clerkUserId: "user_mock_alex",
            username: "alex_chen",
            fullName: "Alex Chen",
            chapterClass: "Spring '18",
            roleTag: .alumni,
            graduationYear: "2018",
            majorOrIndustry: "Computer Science",
            skills: [
                Skill(label: "Web Development", isPredefined: true),
                Skill(label: "Marketing", isPredefined: true),
                Skill(label: "Startups", isPredefined: false)
            ],
            shortBio: "Former PM at a startup. Happy to help with product and eng career advice."
        )
        
        let p2 = Profile(
            clerkUserId: "user_mock_jordan",
            username: "jordan_smith",
            fullName: "Jordan Smith",
            chapterClass: "Fall '21",
            roleTag: .active,
            graduationYear: "2025",
            majorOrIndustry: "Business",
            skills: [
                Skill(label: "Graphic Design", isPredefined: true),
                Skill(label: "Photography", isPredefined: true)
            ],
            shortBio: "Active member. I do design and photo for chapter events."
        )
        
        let p3 = Profile(
            clerkUserId: "user_mock_morgan",
            username: "morgan_taylor",
            fullName: "Morgan Taylor",
            chapterClass: "Fall '19",
            roleTag: .alumni,
            graduationYear: "2023",
            majorOrIndustry: "Finance",
            skills: [
                Skill(label: "Data / Excel", isPredefined: true),
                Skill(label: "Financial modeling", isPredefined: false)
            ],
            shortBio: "Working in IB. Can help with resumes and interview prep."
        )
        
        for p in [p1, p2, p3] where p.clerkUserId != currentClerkUserId { 
            profiles[p.clerkUserId] = p 
        }
        debugLog("ProfileService: seeded \(profiles.count) mock profiles")
    }
}
