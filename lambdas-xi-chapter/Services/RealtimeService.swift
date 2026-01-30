//
//  RealtimeService.swift
//  lambdas-xi-chapter
//
//  Central service managing Supabase Realtime subscriptions for instant messaging.
//  §12 Real-time messaging, §11 Bounty notifications.
//  Debug: WebSocket connections for live message/bounty updates.
//

import Foundation
import Combine
import Supabase
import Realtime

// MARK: - Bounty Event Types

/// Events that can occur on bounties, used for in-app notifications
/// Debug: Each event type triggers a specific notification
enum BountyEventType: String, Codable {
    case created = "bounty_created"
    case applicationReceived = "bounty_application"
    case accepted = "bounty_accepted"
    case completed = "bounty_completed"
}

/// Represents a bounty-related event for notifications
/// Debug: Contains all info needed to display notification and navigate
struct BountyEvent: Identifiable, Equatable {
    let id: UUID
    let type: BountyEventType
    let bountyId: UUID
    let bountyTitle: String
    let actorId: UUID?      // Who triggered the event (e.g. applicant)
    let actorName: String?
    let actorPhotoURL: URL?
    let acceptedApplicantId: UUID? // Added to distinguish who was accepted
    let timestamp: Date
    
    static func == (lhs: BountyEvent, rhs: BountyEvent) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Realtime Service

/// Central service for all Supabase Realtime subscriptions
/// Debug: Manages WebSocket channels for messages and bounty events
@MainActor
final class RealtimeService: ObservableObject {
    static let shared = RealtimeService()
    
    // MARK: - Published Properties
    
    /// Latest incoming message (triggers UI updates)
    /// Debug: Set when a new message arrives via WebSocket
    @Published private(set) var incomingMessage: Message?
    
    /// Latest bounty event (triggers notifications)
    /// Debug: Set when bounty create/apply/accept/complete occurs
    @Published private(set) var bountyEvent: BountyEvent?
    
    /// Typing indicators by chat ID
    /// Debug: Maps chatId -> [userId] of users currently typing
    @Published private(set) var typingUsers: [UUID: Set<UUID>] = [:]
    
    /// Connection status for debugging
    @Published private(set) var isConnected: Bool = false
    
    // MARK: - Private Properties
    
    /// Active message channel subscriptions by chat ID
    /// Debug: One channel per open chat
    private var messageChannels: [UUID: RealtimeChannelV2] = [:]
    
    /// Global bounty events channel
    /// Debug: Single channel for all bounty-related events
    private var bountyChannel: RealtimeChannelV2?
    
    /// Typing indicator channels by chat ID
    /// Debug: Ephemeral broadcast channels for typing status
    private var typingChannels: [UUID: RealtimeChannelV2] = [:]
    
    /// Timers to auto-clear typing indicators
    private var typingTimers: [UUID: [UUID: Timer]] = [:]
    
    /// Current user's profile ID for filtering
    private(set) var currentUserProfileId: UUID?
    
    // MARK: - Initialization
    
    private init() {
        debugLog("RealtimeService: init")
    }
    
    /// Broadcast a locally sent message to subscribers (so UI updates immediately)
    func broadcastLocalMessage(_ message: Message) {
        self.incomingMessage = message
    }
    
    // MARK: - Setup
    
    /// Set the current user's profile ID for filtering events
    /// Debug: Must be called after authentication
    func setCurrentUser(profileId: UUID) {
        debugLog("RealtimeService: setCurrentUser profileId=\(profileId)")
        self.currentUserProfileId = profileId
    }
    
    /// Global channel for all messages
    private var globalMessageChannel: RealtimeChannelV2?
    
    /// Subscribe to ALL new messages for the current user
    /// Debug: This enables notifications to work anywhere in the app
    func subscribeToAllMessages() async {
        guard let client = SupabaseConfig.client else {
            debugLog("RealtimeService: subscribeToAllMessages - no Supabase client")
            return
        }
        
        if globalMessageChannel != nil {
            debugLog("RealtimeService: already subscribed to global messages")
            return
        }
        
        debugLog("RealtimeService: subscribing to global messages")
        
        // Listen for ALL message inserts (we filter by checking if user is a participant)
        let channel = client.realtimeV2.channel("global-messages")
        
        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages"
        )
        
        await channel.subscribe()
        globalMessageChannel = channel
        isConnected = true
        
        debugLog("RealtimeService: subscribed to global messages")
        
        // Listen for all message insertions
        Task { [weak self] in
            for await insertion in insertions {
                await self?.handleGlobalMessageInsertion(insertion)
            }
        }
    }
    
    /// Handle incoming message from global subscription
    /// Debug: Checks if message is for current user and publishes notification
    private func handleGlobalMessageInsertion(_ action: InsertAction) async {
        do {
            let jsonData = try JSONEncoder().encode(action.record)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let message = try decoder.decode(Message.self, from: jsonData)
            
            // Don't notify for our own messages
            if message.senderId == currentUserProfileId {
                debugLog("RealtimeService: ignoring own message in global")
                return
            }
            
            debugLog("RealtimeService: global message received id=\(message.id)")
            
            // Check if user is a participant in this chat
            // (RLS should already filter this, but double-check)
            guard let client = SupabaseConfig.client,
                  let myProfileId = currentUserProfileId else { return }
            
            struct CP: Decodable { let user_id: UUID }
            let participants: [CP] = (try? await client.from("chat_participants")
                .select("user_id")
                .eq("chat_id", value: message.chatId)
                .execute().value) ?? []
            
            let isParticipant = participants.contains { $0.user_id == myProfileId }
            
            if isParticipant {
                debugLog("RealtimeService: publishing incoming message from global id=\(message.id)")
                await MainActor.run {
                    self.incomingMessage = message
                }
            }
            
        } catch {
            debugLog("RealtimeService: failed to decode global message - \(error)")
        }
    }
    
    // MARK: - Message Subscriptions
    
    /// Subscribe to real-time messages for a specific chat
    /// Debug: Creates WebSocket channel listening for INSERT on messages table
    func subscribeToChat(chatId: UUID) async {
        guard let client = SupabaseConfig.client else {
            debugLog("RealtimeService: subscribeToChat - no Supabase client")
            return
        }
        
        // Don't duplicate subscriptions
        if messageChannels[chatId] != nil {
            debugLog("RealtimeService: already subscribed to chat \(chatId)")
            return
        }
        
        debugLog("RealtimeService: subscribing to chat \(chatId)")
        
        let channel = client.realtimeV2.channel("messages:\(chatId)")
        
        // Listen for new message inserts
        // Note: The postgresChange API may show deprecation warnings but is still functional
        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "chat_id=eq.\(chatId)"
        )
        
        // Subscribe to the channel (async, no throw)
        await channel.subscribe()
        
        // Store the channel
        messageChannels[chatId] = channel
        isConnected = true
        
        debugLog("RealtimeService: subscribed to chat \(chatId)")
        
        // Listen for insertions in a separate task
        Task { [weak self] in
            for await insertion in insertions {
                await self?.handleMessageInsertion(insertion, chatId: chatId)
            }
        }
    }
    
    /// Handle incoming message insertion
    /// Debug: Parses the Postgres change and publishes to UI
    private func handleMessageInsertion(_ action: InsertAction, chatId: UUID) async {
        debugLog("RealtimeService: received message insertion for chat \(chatId)")
        
        do {
            // Decode the message from the change record using AnyJSON
            let jsonData = try JSONEncoder().encode(action.record)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let message = try decoder.decode(Message.self, from: jsonData)
            
            // Don't notify for our own messages
            if message.senderId == currentUserProfileId {
                debugLog("RealtimeService: ignoring own message")
                return
            }
            
            debugLog("RealtimeService: publishing incoming message id=\(message.id)")
            self.incomingMessage = message
            
        } catch {
            debugLog("RealtimeService: failed to decode message - \(error)")
        }
    }
    
    /// Unsubscribe from a specific chat
    /// Debug: Call when leaving chat view to clean up resources
    func unsubscribeFromChat(chatId: UUID) async {
        guard let channel = messageChannels[chatId] else {
            debugLog("RealtimeService: no subscription for chat \(chatId)")
            return
        }
        
        debugLog("RealtimeService: unsubscribing from chat \(chatId)")
        await channel.unsubscribe()
        messageChannels.removeValue(forKey: chatId)
        
        // Also clean up typing channel if exists
        if let typingChannel = typingChannels[chatId] {
            await typingChannel.unsubscribe()
            typingChannels.removeValue(forKey: chatId)
        }
        
        // Clear typing timers
        typingTimers[chatId]?.values.forEach { $0.invalidate() }
        typingTimers.removeValue(forKey: chatId)
        typingUsers.removeValue(forKey: chatId)
    }
    
    // MARK: - Bounty Event Subscriptions
    
    /// Subscribe to all bounty-related events for notifications
    /// Debug: Listens for INSERT on bounties, bounty_applications
    func subscribeToBountyEvents() async {
        guard let client = SupabaseConfig.client else {
            debugLog("RealtimeService: subscribeToBountyEvents - no Supabase client")
            return
        }
        
        if bountyChannel != nil {
            debugLog("RealtimeService: already subscribed to bounty events")
            return
        }
        
        debugLog("RealtimeService: subscribing to bounty events")
        
        let channel = client.realtimeV2.channel("bounty-events")
        
        // Listen for new bounties
        let newBounties = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "bounties"
        )
        
        // Listen for new applications
        let newApplications = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "bounty_applications"
        )
        
        // Listen for bounty status updates (accepted, completed)
        let bountyUpdates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "bounties"
        )
        
        // Subscribe (async, no throw)
        await channel.subscribe()
        bountyChannel = channel
        
        debugLog("RealtimeService: subscribed to bounty events")
        
        // Handle new bounties
        Task { [weak self] in
            for await insertion in newBounties {
                await self?.handleNewBounty(insertion)
            }
        }
        
        // Handle new applications
        Task { [weak self] in
            for await insertion in newApplications {
                await self?.handleNewApplication(insertion)
            }
        }
        
        // Handle bounty updates
        Task { [weak self] in
            for await update in bountyUpdates {
                await self?.handleBountyUpdate(update)
            }
        }
    }
    
    /// Handle new bounty creation
    private func handleNewBounty(_ action: InsertAction) async {
        debugLog("RealtimeService: new bounty created")
        
        // Extract values from AnyJSON record
        let record = action.record
        
        guard let creatorIdJSON = record["creator_id"],
              case .string(let creatorIdStr) = creatorIdJSON,
              let creatorUUID = UUID(uuidString: creatorIdStr) else {
            return
        }
        
        // Don't notify creator of their own bounty
        if creatorUUID == currentUserProfileId {
            debugLog("RealtimeService: ignoring own bounty creation")
            return
        }
        
        var bountyId = UUID()
        if let idJSON = record["id"], case .string(let idStr) = idJSON {
            bountyId = UUID(uuidString: idStr) ?? UUID()
        }
        
        var title = "New Bounty"
        if let titleJSON = record["title"], case .string(let titleStr) = titleJSON {
            title = titleStr
        }
        
        // Fetch creator profile for notification
        let creatorProfile = await ProfileService.shared.fetchProfile(id: creatorUUID)
        
        let event = BountyEvent(
            id: UUID(),
            type: .created,
            bountyId: bountyId,
            bountyTitle: title,
            actorId: creatorUUID,
            actorName: creatorProfile?.fullName,
            actorPhotoURL: URL(string: creatorProfile?.profilePhotoURL ?? ""),
            acceptedApplicantId: nil,
            timestamp: Date()
        )
        
        self.bountyEvent = event
    }
    
    /// Handle new bounty application
    private func handleNewApplication(_ action: InsertAction) async {
        debugLog("RealtimeService: new bounty application")
        
        let record = action.record
        
        var bountyId = UUID()
        if let idJSON = record["bounty_id"], case .string(let idStr) = idJSON {
            bountyId = UUID(uuidString: idStr) ?? UUID()
        }
        
        var applicantId = UUID()
        if let appJSON = record["applicant_id"], case .string(let appStr) = appJSON {
            applicantId = UUID(uuidString: appStr) ?? UUID()
        }
        
        // Fetch bounty to check creator
        let bountyService = BountyService.shared
        let bounty = await bountyService.fetchBounty(id: bountyId)
        
        guard let bounty = bounty else { return }
        
        // ONLY notify the creator of the bounty
        guard bounty.creatorId == currentUserProfileId else {
            debugLog("RealtimeService: ignoring application (not creator)")
            return
        }
        
        // Fetch applicant profile
        let applicantProfile = await ProfileService.shared.fetchProfile(id: applicantId)
        
        let event = BountyEvent(
            id: UUID(),
            type: .applicationReceived,
            bountyId: bountyId,
            bountyTitle: bounty.title,
            actorId: applicantId,
            actorName: applicantProfile?.fullName,
            actorPhotoURL: URL(string: applicantProfile?.profilePhotoURL ?? ""),
            acceptedApplicantId: nil,
            timestamp: Date()
        )
        
        self.bountyEvent = event
    }
    
    /// Handle bounty status updates (accepted, completed)
    private func handleBountyUpdate(_ action: UpdateAction) async {
        debugLog("RealtimeService: bounty updated")
        
        let record = action.record
        
        guard let statusJSON = record["status"], case .string(let status) = statusJSON else {
            return
        }
        
        var bountyId = UUID()
        if let idJSON = record["id"], case .string(let idStr) = idJSON {
            bountyId = UUID(uuidString: idStr) ?? UUID()
        }
        
        var title = "Bounty"
        if let titleJSON = record["title"], case .string(let titleStr) = titleJSON {
            title = titleStr
        }
        
        let eventType: BountyEventType
        switch status {
        case "In Progress":
            eventType = .accepted
        case "Completed":
            eventType = .completed
        default:
            return
        }
        
        // Fetch full bounty details to get acceptedApplicantId and creatorId
        let bountyService = BountyService.shared
        let bounty = await bountyService.fetchBounty(id: bountyId)
        
        let event = BountyEvent(
            id: UUID(),
            type: eventType,
            bountyId: bountyId,
            bountyTitle: title,
            actorId: nil,
            actorName: nil,
            actorPhotoURL: nil,
            acceptedApplicantId: bounty?.acceptedApplicantId,
            timestamp: Date()
        )
        
        self.bountyEvent = event
    }
    
    // MARK: - Typing Indicators
    
    /// Subscribe to typing indicators for a chat
    /// Debug: Uses Broadcast channel (ephemeral, not stored)
    func subscribeToTypingIndicators(chatId: UUID) async {
        guard let client = SupabaseConfig.client else { return }
        
        if typingChannels[chatId] != nil { return }
        
        debugLog("RealtimeService: subscribing to typing indicators for chat \(chatId)")
        
        let channel = client.realtimeV2.channel("typing:\(chatId)")
        
        let broadcast = channel.broadcastStream(event: "typing")
        
        // Subscribe (async, no throw)
        await channel.subscribe()
        typingChannels[chatId] = channel
        
        Task { [weak self] in
            for await message in broadcast {
                await self?.handleTypingBroadcast(message, chatId: chatId)
            }
        }
    }
    
    /// Handle incoming typing broadcast
    private func handleTypingBroadcast(_ message: JSONObject, chatId: UUID) async {
        guard let userIdJSON = message["user_id"],
              case .string(let userIdString) = userIdJSON,
              let userId = UUID(uuidString: userIdString),
              userId != currentUserProfileId else {
            return
        }
        
        debugLog("RealtimeService: user \(userId) is typing in chat \(chatId)")
        
        // Add to typing users
        if typingUsers[chatId] == nil {
            typingUsers[chatId] = []
        }
        typingUsers[chatId]?.insert(userId)
        
        // Clear existing timer for this user
        typingTimers[chatId]?[userId]?.invalidate()
        
        // Set timer to remove typing indicator after 3 seconds
        if typingTimers[chatId] == nil {
            typingTimers[chatId] = [:]
        }
        
        // Capture userId for timer closure to satisfy Swift 6 concurrency
        let capturedUserId = userId
        let capturedChatId = chatId
        typingTimers[chatId]?[capturedUserId] = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                strongSelf.typingUsers[capturedChatId]?.remove(capturedUserId)
            }
        }
    }
    
    /// Send typing indicator to other users in the chat
    /// Debug: Called when user is typing in the text field
    func sendTypingIndicator(chatId: UUID) async {
        guard let channel = typingChannels[chatId],
              let userId = currentUserProfileId else {
            return
        }
        
        debugLog("RealtimeService: sending typing indicator for chat \(chatId)")
        
        // broadcast is async but doesn't throw in current SDK
        await channel.broadcast(
            event: "typing",
            message: ["user_id": AnyJSON.string(userId.uuidString)]
        )
    }
    
    // MARK: - Cleanup
    
    /// Unsubscribe from all channels
    /// Debug: Call on logout or app termination
    func unsubscribeFromAll() async {
        debugLog("RealtimeService: unsubscribing from all channels")
        
        // Unsubscribe from message channels
        for (chatId, channel) in messageChannels {
            await channel.unsubscribe()
            debugLog("RealtimeService: unsubscribed from chat \(chatId)")
        }
        messageChannels.removeAll()
        
        // Unsubscribe from typing channels
        for (_, channel) in typingChannels {
            await channel.unsubscribe()
        }
        typingChannels.removeAll()
        
        // Clear typing timers
        for timers in typingTimers.values {
            timers.values.forEach { $0.invalidate() }
        }
        typingTimers.removeAll()
        typingUsers.removeAll()
        
        // Unsubscribe from bounty channel
        if let channel = bountyChannel {
            await channel.unsubscribe()
            bountyChannel = nil
        }
        
        isConnected = false
        currentUserProfileId = nil
        
        debugLog("RealtimeService: all channels unsubscribed")
    }
}
