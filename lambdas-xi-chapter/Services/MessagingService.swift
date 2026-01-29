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
    func createChat(participant1: UUID, participant2: UUID, bountyId: UUID? = nil) async -> Chat? {
        if let c = SupabaseConfig.client {
            do {
                struct ChatInsert: Encodable { let bounty_id: UUID?; enum CodingKeys: String, CodingKey { case bounty_id } }
                struct ChatRow: Decodable { let id: UUID; let bounty_id: UUID?; let created_at: Date; let updated_at: Date; let last_message_at: Date? }
                let inserted: ChatRow = try await c.from("chats").insert(ChatInsert(bounty_id: bountyId)).select().single().execute().value
                struct Part: Encodable { let chat_id: UUID; let user_id: UUID }
                try await c.from("chat_participants").insert([Part(chat_id: inserted.id, user_id: participant1), Part(chat_id: inserted.id, user_id: participant2)]).execute()
                let chat = Chat(id: inserted.id, participantIds: [participant1, participant2], bountyId: inserted.bounty_id, createdAt: inserted.created_at, updatedAt: inserted.updated_at, lastMessageAt: inserted.last_message_at)
                await MainActor.run { chats.append(chat) }
                return chat
            } catch { debugLog("MessagingService: createChat \(error)"); return nil }
        }
        let chat = Chat(participantIds: [participant1, participant2], bountyId: bountyId)
        chats.append(chat)
        return chat
    }

    func chat(between u1: UUID, and u2: UUID, bountyId: UUID? = nil) -> Chat? {
        chats.first { Set($0.participantIds) == [u1, u2] && $0.bountyId == bountyId }
    }

    func chat(id: UUID) -> Chat? { chats.first { $0.id == id } }

    func sendMessage(chatId: UUID, senderId: UUID, body: String) {
        let m = Message(chatId: chatId, senderId: senderId, body: body)
        if let c = SupabaseConfig.client {
            Task {
                // Debug: Explicitly discard result, we handle state locally
                _ = try? await c.from("messages").insert(m).execute()
                await MainActor.run {
                    messages.append(m)
                    if let i = chats.firstIndex(where: { $0.id == chatId }) { chats[i].lastMessageAt = m.sentAt; chats[i].updatedAt = m.sentAt }
                }
            }
        } else {
            messages.append(m)
            if let i = chats.firstIndex(where: { $0.id == chatId }) { chats[i].lastMessageAt = m.sentAt; chats[i].updatedAt = m.sentAt }
        }
    }

    func messages(for chatId: UUID) async -> [Message] {
        if let c = SupabaseConfig.client {
            let list: [Message] = (try? await c.from("messages").select().eq("chat_id", value: chatId).order("sent_at").execute().value) ?? []
            return list
        }
        return messages.filter { $0.chatId == chatId }.sorted { $0.sentAt < $1.sentAt }
    }

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
            return list.sorted { ($0.lastMessageAt ?? $0.createdAt) > ($1.lastMessageAt ?? $1.createdAt) }
        }
        return chats.filter { $0.participantIds.contains(forUserId) }.sorted { ($0.lastMessageAt ?? $0.createdAt) > ($1.lastMessageAt ?? $1.createdAt) }
    }

    private struct CP2: Decodable { let user_id: UUID }
}
