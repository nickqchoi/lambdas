//
//  Chat.swift
//  lambdas-xi-chapter
//
//  One-to-one chat §12. Bounty-linked chats include context header §12.2, §11 Step 4.
//  Debug: Uses clerk_user_id in chat_participants for RLS
//  Debug: Uses clerk_sender_id in messages for RLS
//

import Foundation

// MARK: - Chat

/// One-to-one chat between two users
/// Debug: Participant Clerk IDs are stored in chat_participants table
struct Chat: Identifiable {
    var id: UUID
    var participantIds: [UUID]              // Legacy UUID references for profile lookups
    var clerkParticipantIds: [String]       // Clerk user IDs for RLS (format: user_xxxxx)
    var bountyId: UUID?                     // If created from bounty acceptance §11 Step 3
    var createdAt: Date
    var updatedAt: Date
    var lastMessageAt: Date?

    /// Debug: Initialize chat with participant IDs
    init(
        id: UUID = UUID(),
        participantIds: [UUID],
        clerkParticipantIds: [String] = [],
        bountyId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastMessageAt: Date? = nil
    ) {
        self.id = id
        self.participantIds = participantIds
        self.clerkParticipantIds = clerkParticipantIds
        self.bountyId = bountyId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastMessageAt = lastMessageAt
    }

    /// Other participant from current user's perspective (UUID)
    /// Debug: Use for profile lookups
    func otherParticipantId(currentUserId: UUID) -> UUID? {
        participantIds.first { $0 != currentUserId }
    }
    
    /// Other participant from current user's perspective (Clerk ID)
    /// Debug: Use for Clerk-based operations
    func otherClerkParticipantId(currentClerkUserId: String) -> String? {
        clerkParticipantIds.first { $0 != currentClerkUserId }
    }
}

// MARK: - Message

/// Chat message
/// Debug: clerk_sender_id is used in Supabase RLS policies
struct Message: Identifiable {
    var id: UUID
    var chatId: UUID
    var senderId: UUID                  // Legacy UUID reference for profile lookups
    var clerkSenderId: String           // Clerk user ID for RLS (format: user_xxxxx)
    var body: String
    var sentAt: Date

    /// Debug: Initialize message with both senderId and clerkSenderId
    init(
        id: UUID = UUID(),
        chatId: UUID,
        senderId: UUID,
        clerkSenderId: String = "",
        body: String,
        sentAt: Date = Date()
    ) {
        self.id = id
        self.chatId = chatId
        self.senderId = senderId
        self.clerkSenderId = clerkSenderId
        self.body = body
        self.sentAt = sentAt
    }
}
