//
//  User.swift
//  lambdas-xi-chapter
//
//  User and Profile domain models. Humanized profiles per spec §6, §8.1.
//  Debug: User model uses Clerk user ID (string format: user_xxxxx)
//  Debug: Profile model includes clerk_user_id for Supabase RLS
//

import Foundation

// MARK: - Role Tag (Alumni / Active) — §6.2

/// User role in the chapter
/// Debug: Used for filtering in Discovery view
enum RoleTag: String, Codable, CaseIterable {
    case alumni = "Alumni"
    case active = "Active"
}

// MARK: - Skill

/// Predefined tags §6.3.1 + custom free-text §6.3.2. Codable in SupabaseCoding (DB: label, is_predefined).
/// Debug: Skills are stored as JSONB in Supabase profiles table
struct Skill: Identifiable, Hashable {
    let id: UUID
    var label: String
    /// True if from predefined set; false if custom
    var isPredefined: Bool

    init(id: UUID = UUID(), label: String, isPredefined: Bool = false) {
        self.id = id
        self.label = label
        self.isPredefined = isPredefined
    }
}

/// Predefined skill tags per §6.3.1
/// Debug: These are the standard skills users can select
enum PredefinedSkill: String, CaseIterable {
    case graphicDesign = "Graphic Design"
    case webDevelopment = "Web Development"
    case videoEditing = "Video Editing"
    case socialMedia = "Social Media"
    case marketing = "Marketing"
    case writing = "Writing"
    case photography = "Photography"
    case dataExcel = "Data / Excel"
    case errandsInPerson = "Errands / In-Person Help"
}

// MARK: - Profile

/// All required fields per §6.2. Stored per user; gating rule §6.1. Codable in SupabaseCoding.
/// Debug: Profile is linked to Clerk user via clerk_user_id (used in RLS policies)
struct Profile: Identifiable {
    var id: UUID                    // Primary key in Supabase
    var clerkUserId: String         // Clerk user ID (format: user_xxxxx) for RLS
    var username: String            // Unique username for display
    var fullName: String
    var chapterClass: String        // "Chapter class (text)"
    var roleTag: RoleTag
    var graduationYear: String
    var majorOrIndustry: String
    var skills: [Skill]             // 2–3 per §6.2
    var shortBio: String
    var profilePhotoURL: String?    // Optional; for Discovery card
    var createdAt: Date
    var updatedAt: Date

    /// Debug: Initialize profile with Clerk user ID
    init(
        id: UUID = UUID(),
        clerkUserId: String,
        username: String = "",
        fullName: String = "",
        chapterClass: String = "",
        roleTag: RoleTag = .active,
        graduationYear: String = "",
        majorOrIndustry: String = "",
        skills: [Skill] = [],
        shortBio: String = "",
        profilePhotoURL: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.clerkUserId = clerkUserId
        self.username = username
        self.fullName = fullName
        self.chapterClass = chapterClass
        self.roleTag = roleTag
        self.graduationYear = graduationYear
        self.majorOrIndustry = majorOrIndustry
        self.skills = skills
        self.shortBio = shortBio
        self.profilePhotoURL = profilePhotoURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Bio preview for Discovery card §8.1 (first ~80 chars)
    /// Debug: Truncates long bios for card display
    var bioPreview: String {
        let trimmed = shortBio.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 80 { return trimmed }
        return String(trimmed.prefix(77)) + "..."
    }
}

// MARK: - User

/// Auth-linked user from Clerk authentication.
/// Debug: clerkId is the primary identifier (format: user_xxxxx)
/// Debug: This ID is used in Supabase RLS as auth.jwt() ->> 'sub'
struct User: Identifiable, Codable, Equatable {
    /// Clerk user ID (format: user_xxxxx)
    /// Debug: This is the 'sub' claim in Clerk JWT tokens
    var clerkId: String
    
    /// Display username
    var username: String
    
    /// User's verified email address
    var email: String
    
    /// Associated profile ID in Supabase (if profile exists)
    var profileId: UUID?
    
    /// When the user was created
    var createdAt: Date
    
    /// Identifiable conformance uses clerkId
    /// Debug: Since clerkId is string, we generate a deterministic UUID for SwiftUI
    var id: String { clerkId }

    /// Debug: Initialize user from Clerk authentication
    init(
        clerkId: String,
        username: String,
        email: String = "",
        profileId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.clerkId = clerkId
        self.username = username
        self.email = email
        self.profileId = profileId
        self.createdAt = createdAt
    }
    
    /// Equatable: compare by Clerk ID
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.clerkId == rhs.clerkId
    }
}
