//
//  Bounty.swift
//  lambdas-xi-chapter
//
//  Bounty model per §9. Status: Open, In Progress, Completed. §9.2, §11.
//  Debug: Uses clerk_creator_id for Clerk authentication with Supabase RLS
//

import Foundation

// MARK: - Bounty Status

/// Bounty lifecycle status
/// Debug: Status transitions: Open -> In Progress -> Completed
enum BountyStatus: String, Codable, CaseIterable {
    case open = "Open"
    case inProgress = "In Progress"
    case completed = "Completed"
}

// MARK: - Estimated Effort

/// Estimated time to complete bounty (for UX; stored as string)
/// Debug: Helps users filter and decide on bounties
enum EstimatedEffort: String, Codable, CaseIterable {
    case quick = "Quick (< 1 hr)"
    case short = "Short (1–3 hrs)"
    case medium = "Medium (half day)"
    case long = "Long (full day+)"
}

// MARK: - Bounty

/// Bounty/task that users can post and apply for
/// Debug: clerk_creator_id is used in Supabase RLS policies
struct Bounty: Identifiable {
    var id: UUID
    var title: String
    var description: String
    var skillTags: [Skill]
    var estimatedEffort: EstimatedEffort?
    var deadline: Date?
    var creatorId: UUID                 // Legacy UUID reference (for profile lookups)
    var clerkCreatorId: String          // Clerk user ID for RLS (format: user_xxxxx)
    var status: BountyStatus
    var createdAt: Date
    var updatedAt: Date
    /// Set when creator accepts an applicant §11 Step 1
    var acceptedApplicantId: UUID?

    /// Debug: Initialize bounty with both creatorId and clerkCreatorId
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        skillTags: [Skill] = [],
        estimatedEffort: EstimatedEffort? = nil,
        deadline: Date? = nil,
        creatorId: UUID,
        clerkCreatorId: String = "",
        status: BountyStatus = .open,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        acceptedApplicantId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.skillTags = skillTags
        self.estimatedEffort = estimatedEffort
        self.deadline = deadline
        self.creatorId = creatorId
        self.clerkCreatorId = clerkCreatorId
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.acceptedApplicantId = acceptedApplicantId
    }
}

// MARK: - Bounty Application §10

/// Application submitted by a user for a bounty
/// Debug: clerk_applicant_id is used in Supabase RLS policies
struct BountyApplication: Identifiable {
    var id: UUID
    var bountyId: UUID
    var applicantId: UUID               // Legacy UUID reference (for profile lookups)
    var clerkApplicantId: String        // Clerk user ID for RLS (format: user_xxxxx)
    var message: String?
    var appliedAt: Date
    var status: ApplicationStatus

    /// Debug: Initialize application with both applicantId and clerkApplicantId
    init(
        id: UUID = UUID(),
        bountyId: UUID,
        applicantId: UUID,
        clerkApplicantId: String = "",
        message: String? = nil,
        appliedAt: Date = Date(),
        status: ApplicationStatus = .pending
    ) {
        self.id = id
        self.bountyId = bountyId
        self.applicantId = applicantId
        self.clerkApplicantId = clerkApplicantId
        self.message = message
        self.appliedAt = appliedAt
        self.status = status
    }
}

/// Application status
/// Debug: Status transitions: Pending -> Accepted/Rejected
enum ApplicationStatus: String, Codable {
    case pending = "Pending"
    case accepted = "Accepted"
    case rejected = "Rejected"
}
