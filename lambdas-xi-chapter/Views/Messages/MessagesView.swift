//
//  MessagesView.swift
//  lambdas-xi-chapter
//
//  Messages list §12: chats with bounty context when linked.
//  Real-time messaging with Supabase Realtime §12.
//  Photo attachments support with Supabase Storage.
//

import SwiftUI
import PhotosUI
import Combine

struct MessagesView: View {
    @StateObject private var messagingService = MessagingService.shared
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var realtimeService = RealtimeService.shared
    @StateObject private var auth = AuthService.shared
    
    @State private var chats: [Chat] = []
    @State private var isLoading = false
    @State private var selectedChat: Chat?
    @State private var cancellables = Set<AnyCancellable>()
    @ObservedObject private var notificationService = InAppNotificationService.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                    .refreshable {
                        await loadChats()
                    }
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image.appLogo
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                }
            }
            .onChange(of: notificationService.navigateToChat) { _, _ in
                Task {
                    await checkForPendingNavigation()
                }
            }
            .sheet(item: $selectedChat) { chat in
                ChatDetailView(chat: chat)
            }
            .task {
                setupRealtimeObservers()
                await loadChats()
                await checkForPendingNavigation()
            }
            .onAppear {
                InAppNotificationService.shared.isMessagesScreenVisible = true
            }
            .onDisappear {
                InAppNotificationService.shared.isMessagesScreenVisible = false
            }
        }
    }
    
    private func loadChats() async {
        guard let user = auth.currentUser else { return }
        isLoading = true
        
        // Get profile to get UUID for legacy messaging
        let profile = await profileService.fetchProfile(clerkUserId: user.clerkId)
        guard let profileId = profile?.id else {
            await MainActor.run { isLoading = false }
            return
        }
        
        // Note: RealtimeService setup is now handled in ContentView
        
        let result = await messagingService.chats(forUserId: profileId)
        await MainActor.run {
            chats = result
            isLoading = false
        }
    }
    
    /// Setup observers for real-time message updates
    /// Debug: Refreshes chat list when new messages arrive
    private func setupRealtimeObservers() {
        realtimeService.$incomingMessage
            .compactMap { $0 }
            .sink { [self] message in
                // Update the chat's last message timestamp
                if let index = chats.firstIndex(where: { $0.id == message.chatId }) {
                    chats[index].lastMessageAt = message.sentAt
                    // Sort to move updated chat to top
                    chats.sort { ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast) }
                }
            }
            .store(in: &cancellables)
    }
    
    /// Check if there is a pending navigation request
    private func checkForPendingNavigation() async {
        guard let chatId = notificationService.navigateToChat else { return }
        
        debugLog("MessagesView: checking pending navigation for \(chatId)")
        
        // If chat is not in list, reload to make sure we have it (e.g. just created)
        if !chats.contains(where: { $0.id == chatId }) {
            await loadChats()
        }
        
        if let chat = chats.first(where: { $0.id == chatId }) {
            await MainActor.run {
                selectedChat = chat
                // Clear the navigation trigger
                notificationService.navigateToChat = nil
            }
        } else {
            debugLog("MessagesView: chat \(chatId) not found even after reload")
        }
    }
}

struct ChatRowView: View {
    let chat: Chat
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var messagingService = MessagingService.shared
    @StateObject private var realtimeService = RealtimeService.shared
    @StateObject private var auth = AuthService.shared
    @StateObject private var bountyService = BountyService.shared
    
    @State private var otherUserProfile: Profile?
    @State private var currentUserProfileId: UUID?
    @State private var lastMessage: Message?
    @State private var bounty: Bounty?
    
    var otherUserId: UUID? {
        guard let myProfileId = currentUserProfileId else { return nil }
        return chat.otherParticipantId(currentUserId: myProfileId)
    }
    
    var statusColor: Color {
        guard let bounty = bounty else { return .secondary }
        switch bounty.status {
        case .open: return .appPrimary
        case .inProgress: return .orange
        case .completed: return .green
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(
                photoURL: otherUserProfile?.profilePhotoURL,
                initials: otherUserProfile?.fullName ?? "",
                size: 50
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(otherUserProfile?.fullName ?? "Loading...")
                    .font(.headline)
                
                // Show last message preview or bounty indicator
                if let lastMsg = lastMessage {
                    Text(lastMsg.preview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    } else if let bounty = bounty {
                        HStack(spacing: 6) {
                            Image(systemName: "list.bullet.clipboard.fill")
                                .font(.caption)
                            
                            Text(bounty.status.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.2))
                        .foregroundStyle(statusColor)
                        .cornerRadius(4)
                    } else if chat.bountyId != nil {
                        // Loading state or fallback
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
            
            // Load last message for preview
            let messages = await messagingService.messages(for: chat.id)
            await MainActor.run { lastMessage = messages.last }
            
            // Load bounty if exists
            if let bountyId = chat.bountyId {
                let b = await bountyService.fetchBounty(id: bountyId)
                await MainActor.run { bounty = b }
            }
        }
        // Observe incoming messages to update last message preview in real-time
        .onReceive(realtimeService.$incomingMessage.compactMap { $0 }) { message in
            if message.chatId == chat.id {
                lastMessage = message
            }
        }
    }
}

// MARK: - Chat Detail View

struct ChatDetailView: View {
    let chat: Chat
    
    @StateObject private var messagingService = MessagingService.shared
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var bountyService = BountyService.shared
    @StateObject private var realtimeService = RealtimeService.shared
    @StateObject private var auth = AuthService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var messages: [Message] = []
    @State private var newMessageText = ""
    @State private var otherUserProfile: Profile?
    @State private var bounty: Bounty? // Current active bounty
    @State private var loadedBounties: [UUID: Bounty] = [:] // Cache for historical bounties
    @State private var currentUserProfileId: UUID?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showBountyDetail = false // State for bounty sheet
    @State private var selectedBountyToView: Bounty? // Bounty to show in sheet
    
    // Photo picker state
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isUploadingImage = false
    @State private var showImagePicker = false
    
    // Typing indicator state
    @State private var typingDebounceTask: Task<Void, Never>?
    
    var otherUserId: UUID? {
        guard let myProfileId = currentUserProfileId else { return nil }
        return chat.otherParticipantId(currentUserId: myProfileId)
    }
    
    /// Whether the other user is currently typing
    var isOtherUserTyping: Bool {
        guard let otherId = otherUserId else { return false }
        return realtimeService.typingUsers[chat.id]?.contains(otherId) == true
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                if message.type == .system {
                                    // Use new BountyMessageBubble for system messages
                                    BountyMessageBubble(
                                        message: message,
                                        bounty: resolveBounty(for: message),
                                        onTap: {
                                            if let bountyIdStr = message.metadata?["bountyId"],
                                               let bountyId = UUID(uuidString: bountyIdStr) {
                                                Task {
                                                    if let b = await bountyService.fetchBounty(id: bountyId) {
                                                        await MainActor.run {
                                                            selectedBountyToView = b
                                                        }
                                                    }
                                                }
                                            } else if let bountyId = chat.bountyId {
                                                Task {
                                                    if let b = await bountyService.fetchBounty(id: bountyId) {
                                                        await MainActor.run {
                                                            selectedBountyToView = b
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    )
                                    .id(message.id)
                                    .task {
                                        // Redundant check: ensure bounty is loaded if metadata exists
                                        // This handles cases where realtime insert might have raced with view update
                                        if let idStr = message.metadata?["bountyId"],
                                           let bountyId = UUID(uuidString: idStr),
                                           loadedBounties[bountyId] == nil {
                                            debugLog("MessagesView: bubble triggering load for \(bountyId)")
                                            loadBounty(bountyId: bountyId)
                                        }
                                    }
                                } else {
                                    MessageBubble(
                                        message: message,
                                        isCurrentUser: message.senderId == currentUserProfileId
                                    )
                                    .id(message.id)
                                }
                            }
                            
                            // Typing indicator
                            if isOtherUserTyping {
                                TypingIndicator()
                                    .id("typingIndicator")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: isOtherUserTyping) { _, isTyping in
                        if isTyping {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
                
                // Input area with photo attachment button
                inputArea
            }
            .navigationTitle(otherUserProfile?.fullName ?? "Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                // Suppress notifications for this chat while viewing
                InAppNotificationService.shared.suppressedChatId = chat.id
                
                await loadCurrentUser()
                loadOtherUser()
                loadMessages()
                if let bountyId = chat.bountyId {
                    loadBounty(bountyId: bountyId)
                }
                // Subscribe to real-time updates for this chat
                await subscribeToChat()
            }
            .onDisappear {
                // Clear notification suppression
                InAppNotificationService.shared.suppressedChatId = nil
                
                // Unsubscribe when leaving the view
                Task {
                    await realtimeService.unsubscribeFromChat(chatId: chat.id)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await loadSelectedImage(from: newItem)
                }
            }
            .sheet(item: $selectedBountyToView) { bounty in
                BountyDetailView(bounty: bounty) {
                    // Refresh if needed
                    if let bountyId = chat.bountyId {
                        loadBounty(bountyId: bountyId)
                    }
                }
            }
        }
        .withNotificationBanner() // Ensure notifications show over chat sheet
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        VStack(spacing: 0) {
            // Selected image preview
            if let image = selectedImage {
                selectedImagePreview(image)
            }
            
            // Input row
            HStack(spacing: 12) {
                // Photo picker button
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 20))
                        .foregroundColor(.appPrimary)
                }
                
                // Text field
                TextField("Type a message", text: $newMessageText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: newMessageText) { _, _ in
                        sendTypingIndicator()
                    }
                
                // Send button
                Button {
                    Task { await sendMessage() }
                } label: {
                    if isUploadingImage {
                        ProgressView()
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(canSend ? Color.appPrimary : Color.gray)
                            .clipShape(Circle())
                    }
                }
                .disabled(!canSend || isUploadingImage)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    private var canSend: Bool {
        !newMessageText.trimmingCharacters(in: .whitespaces).isEmpty || selectedImage != nil
    }
    
    // MARK: - Selected Image Preview
    
    @ViewBuilder
    private func selectedImagePreview(_ image: UIImage) -> some View {
        HStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: 100)
                .cornerRadius(8)
            
            Spacer()
            
            Button {
                selectedImage = nil
                selectedPhotoItem = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title2)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Private Methods
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if isOtherUserTyping {
            withAnimation {
                proxy.scrollTo("typingIndicator", anchor: .bottom)
            }
        } else if let last = messages.last {
            withAnimation {
                proxy.scrollTo(last.id, anchor: .bottom)
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
            await MainActor.run { 
                messages = msgs
                loadHistoricalBounties(messages: msgs)
            }
        }
    }
    
    /// Resolve which bounty to show for a message (metadata > chat.bountyId)
    private func resolveBounty(for message: Message) -> Bounty? {
        // 1. Try metadata
        if let idStr = message.metadata?["bountyId"],
           let id = UUID(uuidString: idStr),
           let cached = loadedBounties[id] {
            return cached
        }
        
        // 2. Fallback to current chat bounty if it matches
        // (Only strictly correct if this message belongs to the current bounty)
        if let current = bounty, message.metadata == nil {
            return current
        }
        
        return nil
    }
    
    private func loadBounty(bountyId: UUID) {
        debugLog("MessagesView: loadBounty \(bountyId)")
        Task {
            let b = await bountyService.fetchBounty(id: bountyId)
            await MainActor.run { 
                bounty = b 
                if let b = b {
                    debugLog("MessagesView: loaded bounty \(b.id) - \(b.title)")
                    loadedBounties[b.id] = b
                } else {
                    debugLog("MessagesView: failed to load bounty \(bountyId)")
                }
            }
        }
    }
    
    /// Load bounties referenced in message history
    private func loadHistoricalBounties(messages: [Message]) {
        let bountyIds = messages.compactMap { msg -> UUID? in
            guard let str = msg.metadata?["bountyId"] else { return nil }
            return UUID(uuidString: str)
        }
        
        // Fetch unique IDs not yet loaded
        let uniqueIds = Set(bountyIds).subtracting(loadedBounties.keys)
        
        for id in uniqueIds {
            Task {
                if let b = await bountyService.fetchBounty(id: id) {
                    await MainActor.run {
                        loadedBounties[id] = b
                    }
                }
            }
        }
    }
    
    /// Subscribe to real-time messages for this chat
    private func subscribeToChat() async {
        await realtimeService.subscribeToChat(chatId: chat.id)
        await realtimeService.subscribeToTypingIndicators(chatId: chat.id)
        
        // Observe incoming messages
        realtimeService.$incomingMessage
            .compactMap { $0 }
            .filter { $0.chatId == chat.id }
            .sink { message in
                // Add message if not already present
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                    
                    // If system message has bounty metadata, load it
                    if let idStr = message.metadata?["bountyId"],
                       let bountyId = UUID(uuidString: idStr) {
                        debugLog("MessagesView: realtime msg has bountyId \(bountyId)")
                        loadBounty(bountyId: bountyId)
                    } else {
                        debugLog("MessagesView: realtime msg missing bountyId metadata")
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /// Load selected image from photo picker
    private func loadSelectedImage(from item: PhotosPickerItem?) async {
        guard let item = item else {
            await MainActor.run { selectedImage = nil }
            return
        }
        
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            await MainActor.run { selectedImage = image }
        }
    }
    
    /// Send typing indicator (debounced)
    private func sendTypingIndicator() {
        typingDebounceTask?.cancel()
        typingDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            await realtimeService.sendTypingIndicator(chatId: chat.id)
        }
    }
    
    /// Send the message (with optional image)
    private func sendMessage() async {
        guard let _ = auth.currentUser,
              let profileId = currentUserProfileId else { return }
        
        let text = newMessageText.trimmingCharacters(in: .whitespaces)
        let image = selectedImage
        
        // Clear input immediately for responsiveness
        await MainActor.run {
            newMessageText = ""
            selectedImage = nil
            selectedPhotoItem = nil
        }
        
        // Upload image if present
        var imageURL: URL? = nil
        if let image = image {
            await MainActor.run { isUploadingImage = true }
            do {
                imageURL = try await ImageUploadService.shared.uploadChatImage(image, chatId: chat.id)
            } catch {
                debugLog("ChatDetailView: failed to upload image - \(error)")
            }
            await MainActor.run { isUploadingImage = false }
        }
        
        // Only send if there's text or image
        guard !text.isEmpty || imageURL != nil else { return }
        
        // Send the message
        messagingService.sendMessage(chatId: chat.id, senderId: profileId, body: text, imageURL: imageURL)
            
        // No need to append manually anymore - MessagingService broadcasts it locally
    }
}



// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    
    @State private var showFullScreenImage = false
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Image attachment
                if let imageURL = message.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 200, height: 150)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 200, maxHeight: 300)
                                .cornerRadius(12)
                                .onTapGesture {
                                    showFullScreenImage = true
                                }
                        case .failure:
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                                .frame(width: 200, height: 150)
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
                // Text body (only show if not empty)
                if !message.body.isEmpty {
                    Text(message.body)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isCurrentUser ? Color.appPrimary : Color(.systemGray5))
                        .foregroundStyle(isCurrentUser ? .white : .primary)
                        .cornerRadius(16)
                }
            }
            
            if !isCurrentUser { Spacer() }
        }
        .fullScreenCover(isPresented: $showFullScreenImage) {
            if let imageURL = message.imageURL {
                FullScreenImageView(imageURL: imageURL)
            }
        }
    }
}

// MARK: - Full Screen Image View

struct FullScreenImageView: View {
    let imageURL: URL
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                default:
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .onTapGesture {
            dismiss()
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animationPhase = 0
    
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationPhase == index ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.4), value: animationPhase)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray5))
            .cornerRadius(16)
            
            Spacer()
        }
        .onReceive(timer) { _ in
            animationPhase = (animationPhase + 1) % 3
        }
    }
}

#Preview {
    MessagesView()
}
