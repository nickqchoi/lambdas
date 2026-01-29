//
//  BountyService.swift
//  lambdas-xi-chapter
//
//  Bounty service §16.2, §9. Supabase when configured; else mock. Accept flow §11.
//

import Foundation
import Combine
import Supabase

final class BountyService: ObservableObject {
    static let shared = BountyService()

    @Published private(set) var bounties: [Bounty] = []
    @Published private(set) var applications: [BountyApplication] = []

    private init() { debugLog("BountyService: init") }

    func fetchBounties() async -> [Bounty] {
        if let c = SupabaseConfig.client {
            do {
                let list: [Bounty] = try await c.from("bounties").select().execute().value
                return list.sorted { $0.updatedAt > $1.updatedAt }
            } catch {
                debugLog("BountyService: fetchBounties \(error)")
                return []
            }
        }
        return bounties.sorted { $0.updatedAt > $1.updatedAt }
    }

    func createBounty(_ b: Bounty) {
        var b = b
        b.updatedAt = Date()
        if let c = SupabaseConfig.client {
            Task {
                do {
                    try await c.from("bounties").insert(b).execute()
                    await MainActor.run { bounties.insert(b, at: 0) }
                    debugLog("BountyService: created \(b.id)")
                } catch { debugLog("BountyService: create \(error)") }
            }
        } else {
            bounties.append(b)
            debugLog("BountyService: created \(b.id) (mock)")
        }
    }

    func applyToBounty(application: BountyApplication) {
        if let c = SupabaseConfig.client {
            Task {
                do {
                    try await c.from("bounty_applications").insert(application).execute()
                    await MainActor.run { applications.append(application) }
                    debugLog("BountyService: applied \(application.id)")
                } catch { debugLog("BountyService: apply \(error)") }
            }
        } else {
            applications.append(application)
            debugLog("BountyService: applied \(application.id) (mock)")
        }
    }

    func fetchApplications(bountyId: UUID) async -> [BountyApplication] {
        if let c = SupabaseConfig.client {
            do {
                let list: [BountyApplication] = try await c.from("bounty_applications").select().eq("bounty_id", value: bountyId).execute().value
                return list.sorted { $0.appliedAt > $1.appliedAt }
            } catch { return [] }
        }
        return applications.filter { $0.bountyId == bountyId }.sorted { $0.appliedAt > $1.appliedAt }
    }

    private struct BountyAcceptUpdate: Encodable { let status: String; let accepted_applicant_id: UUID; let updated_at: String }

    /// §11 Step 1. Accept applicant → In Progress; creates chat via MessagingService.
    func acceptApplication(bountyId: UUID, applicationId: UUID, applicantId: UUID) {
        Task {
            if let c = SupabaseConfig.client {
                do {
                    let upd = BountyAcceptUpdate(status: BountyStatus.inProgress.rawValue, accepted_applicant_id: applicantId, updated_at: ISO8601DateFormatter().string(from: Date()))
                    try await c.from("bounties").update(upd).eq("id", value: bountyId).execute()
                    try await c.from("bounty_applications").update(["status": ApplicationStatus.accepted.rawValue]).eq("id", value: applicationId).execute()
                    if let bounty = bounties.first(where: { $0.id == bountyId }) {
                        _ = await MessagingService.shared.createChat(participant1: bounty.creatorId, participant2: applicantId, bountyId: bountyId)
                    }
                } catch { debugLog("BountyService: acceptApplication \(error)") }
            } else {
                guard var b = bounties.first(where: { $0.id == bountyId }), b.status == .open,
                      applications.contains(where: { $0.id == applicationId }) else { return }
                b.status = .inProgress
                b.acceptedApplicantId = applicantId
                b.updatedAt = Date()
                if let i = bounties.firstIndex(where: { $0.id == bountyId }) { bounties[i] = b }
                if let j = applications.firstIndex(where: { $0.id == applicationId }) { applications[j].status = .accepted }
                _ = await MessagingService.shared.createChat(participant1: b.creatorId, participant2: applicantId, bountyId: bountyId)
            }
        }
    }

    func markBountyComplete(bountyId: UUID) {
        if let c = SupabaseConfig.client {
            Task {
                // Debug: Explicitly discard result, we handle state locally
                _ = try? await c.from("bounties").update(["status": BountyStatus.completed.rawValue, "updated_at": ISO8601DateFormatter().string(from: Date())]).eq("id", value: bountyId).execute()
                await MainActor.run {
                    if let i = bounties.firstIndex(where: { $0.id == bountyId }) {
                        bounties[i].status = .completed
                        bounties[i].updatedAt = Date()
                    }
                }
                debugLog("BountyService: completed \(bountyId)")
            }
        } else {
            guard var b = bounties.first(where: { $0.id == bountyId }) else { return }
            b.status = .completed
            b.updatedAt = Date()
            if let i = bounties.firstIndex(where: { $0.id == bountyId }) { bounties[i] = b }
        }
    }

    func fetchBounty(id: UUID) async -> Bounty? {
        if let c = SupabaseConfig.client {
            return try? await c.from("bounties").select().eq("id", value: id).single().execute().value
        }
        return bounties.first { $0.id == id }
    }

    func seedMockBounties(currentUserId: UUID) {
        guard bounties.isEmpty else { return }
        let b1 = Bounty(
            title: "Design chapter rush flyer",
            description: "Need a flyer for spring rush. Brand colors and logo will be provided. Should match our brand style.",
            skillTags: [Skill(label: "Graphic Design", isPredefined: true)],
            estimatedEffort: .short,
            creatorId: currentUserId,
            status: .open
        )
        let b2 = Bounty(
            title: "Resume review",
            description: "Looking for someone in consulting or finance to review my resume before recruitment starts. Need feedback on formatting and content.",
            skillTags: [Skill(label: "Writing", isPredefined: true)],
            estimatedEffort: .quick,
            creatorId: UUID(),
            status: .open
        )
        let b3 = Bounty(
            title: "Help with Excel model",
            description: "Building a financial model for a case competition. Need someone good with Excel formulas and pivot tables.",
            skillTags: [Skill(label: "Data / Excel", isPredefined: true)],
            estimatedEffort: .medium,
            creatorId: UUID(),
            status: .open
        )
        bounties = [b1, b2, b3]
        debugLog("BountyService: seeded \(bounties.count) mock bounties")
    }
}
