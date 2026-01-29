//
//  MessagesView.swift
//  lambdas-xi-chapter
//
//  Messages list §12: chats with bounty context when linked.
//

import SwiftUI

struct MessagesView: View {
    @StateObject private var messagingService = MessagingService.shared
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var auth = AuthService.shared
    
    @State private var chats: [Chat] = []
    @State private var isLoading = false
    @State private var selectedChat: Chat?
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("Loading messages...")
                } else if chats.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "message")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("No messages yet")
                            .font(.headline)
                        Text("Start a conversation from Discovery or Bounties")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(chats) { chat in
                        Button {
                            selectedChat = chat
                        } label: {
                            ChatRowView(chat: chat)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Messages")
            .sheet(item: $selectedChat) { chat in
                ChatDetailView(chat: chat)
            }
            .task {
                loadChats()
            }
        }
    }
    
    private func loadChats() {
        guard let user = auth.currentUser else { return }
        isLoading = true
        Task {
            // Get profile to get UUID for legacy messaging
            let profile = await profileService.fetchProfile(clerkUserId: user.clerkId)
            guard let profileId = profile?.id else {
                await MainActor.run { isLoading = false }
                return
            }
            
            let result = await messagingService.chats(forUserId: profileId)
            await MainActor.run {
                chats = result
                isLoading = false
            }
        }
    }
}

struct ChatRowView: View {
    let chat: Chat
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var auth = AuthService.shared
    
    @State private var otherUserProfile: Profile?
    @State private var currentUserProfileId: UUID?
    
    var otherUserId: UUID? {
        guard let myProfileId = currentUserProfileId else { return nil }
        return chat.otherParticipantId(currentUserId: myProfileId)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay {
                    if let profile = otherUserProfile {
                        Text(profile.fullName.prefix(1))
                            .font(.headline)
                    }
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(otherUserProfile?.fullName ?? "Loading...")
                    .font(.headline)
                
                if chat.bountyId != nil {
                    HStack {
                        Image(systemName: "list.bullet.clipboard.fill")
                            .font(.caption)
                        Text("Bounty Chat")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Text("Tap to open chat")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if let lastMessageAt = chat.lastMessageAt {
                Text(lastMessageAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .task {
            // First, get current user's profile ID
            guard let user = auth.currentUser else { return }
            let myProfile = await profileService.fetchProfile(clerkUserId: user.clerkId)
            await MainActor.run { currentUserProfileId = myProfile?.id }
            
            // Then get other user's profile
            guard let otherId = otherUserId else { return }
            let profile = await profileService.fetchProfile(id: otherId)
            await MainActor.run { otherUserProfile = profile }
        }
    }
}

struct ChatDetailView: View {
    let chat: Chat
    
    @StateObject private var messagingService = MessagingService.shared
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var bountyService = BountyService.shared
    @StateObject private var auth = AuthService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var messages: [Message] = []
    @State private var newMessageText = ""
    @State private var otherUserProfile: Profile?
    @State private var bounty: Bounty?
    @State private var currentUserProfileId: UUID?
    
    var otherUserId: UUID? {
        guard let myProfileId = currentUserProfileId else { return nil }
        return chat.otherParticipantId(currentUserId: myProfileId)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Bounty context header (§11 Step 4)
                if let b = bounty {
                    BountyContextHeader(bounty: b)
                }
                
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(message: message, isCurrentUser: message.senderId == currentUserProfileId)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                
                // Input
                HStack(spacing: 12) {
                    TextField("Type a message", text: $newMessageText)
                        .textFieldStyle(.roundedBorder)
                    
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(newMessageText.isEmpty ? Color.gray : Color.blue)
                            .clipShape(Circle())
                    }
                    .disabled(newMessageText.isEmpty)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle(otherUserProfile?.fullName ?? "Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                // First load current user's profile ID
                await loadCurrentUser()
                // Then load other data
                loadOtherUser()
                loadMessages()
                if let bountyId = chat.bountyId {
                    loadBounty(bountyId: bountyId)
                }
            }
        }
    }
    
    private func loadCurrentUser() async {
        guard let user = auth.currentUser else { return }
        let myProfile = await profileService.fetchProfile(clerkUserId: user.clerkId)
        await MainActor.run { currentUserProfileId = myProfile?.id }
    }
    
    private func loadOtherUser() {
        Task {
            guard let otherId = otherUserId else { return }
            let profile = await profileService.fetchProfile(id: otherId)
            await MainActor.run { otherUserProfile = profile }
        }
    }
    
    private func loadMessages() {
        Task {
            let msgs = await messagingService.messages(for: chat.id)
            await MainActor.run { messages = msgs }
        }
    }
    
    private func loadBounty(bountyId: UUID) {
        Task {
            let b = await bountyService.fetchBounty(id: bountyId)
            await MainActor.run { bounty = b }
        }
    }
    
    private func sendMessage() {
        guard let user = auth.currentUser,
              let profileId = currentUserProfileId else { return }
        let text = newMessageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        
        messagingService.sendMessage(chatId: chat.id, senderId: profileId, body: text)
        
        // Add message to local array immediately for instant feedback
        let msg = Message(
            id: UUID(),
            chatId: chat.id,
            senderId: profileId,
            clerkSenderId: user.clerkId,
            body: text,
            sentAt: Date()
        )
        messages.append(msg)
        newMessageText = ""
    }
}

struct BountyContextHeader: View {
    let bounty: Bounty
    @State private var showBountyDetail = false
    
    var body: some View {
        Button {
            showBountyDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "list.bullet.clipboard.fill")
                        .foregroundStyle(.blue)
                    Text(bounty.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(bounty.status.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.2))
                        .cornerRadius(6)
                }
                
                Text(bounty.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showBountyDetail) {
            BountyDetailView(bounty: bounty) { }
        }
    }
    
    var statusColor: Color {
        switch bounty.status {
        case .open: return .green
        case .inProgress: return .orange
        case .completed: return .gray
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            Text(message.body)
                .font(.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                .foregroundStyle(isCurrentUser ? .white : .primary)
                .cornerRadius(16)
            
            if !isCurrentUser { Spacer() }
        }
    }
}

#Preview {
    MessagesView()
}
