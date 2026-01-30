//
//  MessagingService.swift
//  lambdas-xi-chapter
//
//  Messaging §12. One-to-one, text-only. Bounty-linked chats §11 Step 4. Supabase or mock.
//

import Foundation
import Combine
import Supabase

final class MessagingService: ObservableObject {
    static let shared = MessagingService()

    @Published private(set) var chats: [Chat] = []
    @Published private(set) var messages: [Message] = []

    private init() { debugLog("MessagingService: init") }

    /// Creates chat; when Supabase: inserts into chats + chat_participants.
    /// Debug: participant1 and participant2 are profile UUIDs
    /// Get existing chat or create new one. enforcing 1:1 uniqueness per pair.
    /// Debug: If chat exists, updates its bounty_id to the new value.
    func getOrCreateChat(participant1: UUID, participant2: UUID, bountyId: UUID? = nil, clerkUserId1: String? = nil, clerkUserId2: String? = nil) async -> Chat? {
        // 1. Check for ANY existing chat between these two users
        if let existing = await findExistingChat(participant1: participant1, participant2: participant2) {
            debugLog("MessagingService: reusing existing chat \(existing.id)")
            
            // If a new bounty is associated, update the chat's bounty_id
            if let newBountyId = bountyId, existing.bountyId != newBountyId {
                await updateChatBounty(chatId: existing.id, bountyId: newBountyId)
                
                // Return updated copy
                var updated = existing
                updated.bountyId = newBountyId
                return updated
            }
            
            return existing
        }
        
        // 2. Create new chat if none exists
        if let c = SupabaseConfig.client {
            do {
                struct ChatInsert: Encodable { let bounty_id: UUID?; enum CodingKeys: String, CodingKey { case bounty_id } }
                struct ChatRow: Decodable { let id: UUID; let bounty_id: UUID?; let created_at: Date; let updated_at: Date; let last_message_at: Date? }
                let inserted: ChatRow = try await c.from("chats").insert(ChatInsert(bounty_id: bountyId)).select().single().execute().value
                
                // Insert chat participants with both user_id (UUID) and clerk_user_id (text for RLS)
                struct Part: Encodable { 
                    let chat_id: UUID
                    let user_id: UUID
                    let clerk_user_id: String?
                }
                let participants = [
                    Part(chat_id: inserted.id, user_id: participant1, clerk_user_id: clerkUserId1),
                    Part(chat_id: inserted.id, user_id: participant2, clerk_user_id: clerkUserId2)
                ]
                try await c.from("chat_participants").insert(participants).execute()
                
                let chat = Chat(id: inserted.id, participantIds: [participant1, participant2], bountyId: inserted.bounty_id, createdAt: inserted.created_at, updatedAt: inserted.updated_at, lastMessageAt: inserted.last_message_at)
                await MainActor.run { chats.append(chat) }
                debugLog("MessagingService: createChat success, id=\(inserted.id)")
                return chat
            } catch { debugLog("MessagingService: createChat \(error)"); return nil }
        }
        let chat = Chat(participantIds: [participant1, participant2], bountyId: bountyId)
        chats.append(chat)
        return chat
    }
    
    private func updateChatBounty(chatId: UUID, bountyId: UUID) async {
        guard let c = SupabaseConfig.client else { return }
        do {
            try await c.from("chats").update(["bounty_id": bountyId]).eq("id", value: chatId).execute()
        } catch {
            debugLog("MessagingService: failed to update chat bounty \(error)")
        }
    }
    
    /// Check if chat exists between two users - checks in-memory first, then DB
    /// Debug: Prevents duplicate chats by checking Supabase
    /// Check if ANY chat exists between two users
    func findExistingChat(participant1: UUID, participant2: UUID) async -> Chat? {
        // First check local cache
        // Note: We ignore bountyId for matching - we want ONE chat per pair
        if let cached = chats.first(where: { 
            $0.participantIds.contains(participant1) && 
            $0.participantIds.contains(participant2) 
        }) {
            return cached
        }
        
        // Then check Supabase
        guard let c = SupabaseConfig.client else { return nil }
        
        do {
            // Find all chats where participant1 is a member
            struct CP: Decodable { let chat_id: UUID }
            let p1Chats: [CP] = try await c.from("chat_participants").select("chat_id").eq("user_id", value: participant1).execute().value
            
            guard !p1Chats.isEmpty else { return nil }
            
            // Find if any of those chats also have participant2
            let chatIds = p1Chats.map(\.chat_id)
            let p2InSameChats: [CP] = try await c.from("chat_participants")
                .select("chat_id")
                .eq("user_id", value: participant2)
                .in("chat_id", values: chatIds)
                .execute().value
            
            // Should be at most one, but take first
            if let match = p2InSameChats.first {
                let chatDetails: Chat? = try? await c.from("chats")
                    .select()
                    .eq("id", value: match.chat_id)
                    .single()
                    .execute().value
                
                if let chat = chatDetails {
                    var mutableChat = chat
                    mutableChat.participantIds = [participant1, participant2]
                    await MainActor.run { 
                        if !self.chats.contains(where: { $0.id == chat.id }) {
                            self.chats.append(mutableChat)
                        }
                    }
                    return mutableChat
                }
            }
        } catch {
            debugLog("MessagingService: findExistingChat error \(error)")
        }
        return nil
    }

    func chat(between u1: UUID, and u2: UUID, bountyId: UUID? = nil) -> Chat? {
        // Ignore bountyId to default to existing chat
        chats.first { Set($0.participantIds) == [u1, u2] }
    }

    func chat(id: UUID) -> Chat? { chats.first { $0.id == id } }

    /// Send a message with optional image attachment
    /// Debug: imageURL comes from ImageUploadService after uploading to Supabase Storage
    /// Send a message with optional image attachment
    /// Debug: imageURL comes from ImageUploadService after uploading to Supabase Storage
    /// Type defaults to .text
    func sendMessage(chatId: UUID, senderId: UUID, body: String, imageURL: URL? = nil, clerkSenderId: String? = nil, type: MessageType = .text, metadata: [String: String]? = nil) {
        let m = Message(
            id: UUID(),
            chatId: chatId, 
            senderId: senderId, 
            clerkSenderId: clerkSenderId ?? "", 
            body: body, 
            imageURL: imageURL,
            type: type,
            sentAt: Date(),
            metadata: metadata
        )
        if let c = SupabaseConfig.client {
            Task {
                // Debug: Explicitly discard result, we handle state locally
                // Real-time subscription will handle updates for other users
                do {
                    _ = try await c.from("messages").insert(m).execute()
                    debugLog("MessagingService: sendMessage success")
                } catch {
                    debugLog("MessagingService: sendMessage error: \(error)")
                }
                await MainActor.run {
                    messages.append(m)
                    if let i = chats.firstIndex(where: { $0.id == chatId }) { chats[i].lastMessageAt = m.sentAt; chats[i].updatedAt = m.sentAt }
                    // Broadcast locally so list views update
                    RealtimeService.shared.broadcastLocalMessage(m)

                }
            }
        } else {
            messages.append(m)
            if let i = chats.firstIndex(where: { $0.id == chatId }) { chats[i].lastMessageAt = m.sentAt; chats[i].updatedAt = m.sentAt }
            // Broadcast locally so list views update
            RealtimeService.shared.broadcastLocalMessage(m)
        }
    }

    func messages(for chatId: UUID) async -> [Message] {
        if let c = SupabaseConfig.client {
            let list: [Message] = (try? await c.from("messages").select().eq("chat_id", value: chatId).order("sent_at").execute().value) ?? []
            return list
        }
        return messages.filter { $0.chatId == chatId }.sorted { $0.sentAt < $1.sentAt }
    }

    /// Fetch all chats for a user and cache them
    /// Debug: Queries chat_participants table by user_id
    func chats(forUserId: UUID) async -> [Chat] {
        if let c = SupabaseConfig.client {
            struct CP: Decodable { let chat_id: UUID }
            let rows: [CP] = (try? await c.from("chat_participants").select("chat_id").eq("user_id", value: forUserId).execute().value) ?? []
            let ids = rows.map(\.chat_id)
            guard !ids.isEmpty else { return [] }
            var list: [Chat] = (try? await c.from("chats").select().in("id", values: ids).execute().value) ?? []
            for i in list.indices {
                let parts: [CP2] = (try? await c.from("chat_participants").select("user_id").eq("chat_id", value: list[i].id).execute().value) ?? []
                list[i].participantIds = parts.map(\.user_id)
            }
            // Cache the loaded chats
            await MainActor.run {
                for chat in list {
                    if !self.chats.contains(where: { $0.id == chat.id }) {
                        self.chats.append(chat)
                    }
                }
            }
            return list.sorted { ($0.lastMessageAt ?? $0.createdAt) > ($1.lastMessageAt ?? $1.createdAt) }
        }
        return chats.filter { $0.participantIds.contains(forUserId) }.sorted { ($0.lastMessageAt ?? $0.createdAt) > ($1.lastMessageAt ?? $1.createdAt) }
    }

    private struct CP2: Decodable { let user_id: UUID }
}
