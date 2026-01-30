//
//  InAppNotificationService.swift
//  lambdas-xi-chapter
//
//  Manages in-app popup notifications that appear on any screen.
//  §12.2 Push notifications, §14 Notification architecture.
//  Debug: Works alongside APNs for when app is in foreground.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Notification Types

/// Types of in-app notifications
/// Debug: Each type has different styling and navigation behavior
enum InAppNotificationType: String, Codable {
    case newMessage = "new_message"
    case bountyCreated = "bounty_created"
    case bountyApplication = "bounty_application"
    case bountyAccepted = "bounty_accepted"
    case bountyCompleted = "bounty_completed"
    
    /// Icon for this notification type
    var iconName: String {
        switch self {
        case .newMessage: return "message.fill"
        case .bountyCreated: return "plus.circle.fill"
        case .bountyApplication: return "person.badge.plus"
        case .bountyAccepted: return "checkmark.circle.fill"
        case .bountyCompleted: return "flag.checkered"
        }
    }
    
    /// Color for this notification type
    var color: Color {
        switch self {
        case .newMessage: return .appPrimary
        case .bountyCreated: return .green
        case .bountyApplication: return .orange
        case .bountyAccepted: return .blue
        case .bountyCompleted: return .purple
        }
    }
}

// MARK: - Notification Model

/// Represents an in-app notification to be displayed
/// Debug: Contains all info for display and navigation
struct InAppNotification: Identifiable, Equatable {
    let id: UUID
    let type: InAppNotificationType
    let title: String
    let message: String
    let timestamp: Date
    
    /// Optional navigation destination
    let chatId: UUID?
    let bountyId: UUID?
    let senderId: UUID?
    let senderName: String?
    let senderPhotoURL: URL?
    
    init(
        id: UUID = UUID(),
        type: InAppNotificationType,
        title: String,
        message: String,
        timestamp: Date = Date(),
        chatId: UUID? = nil,
        bountyId: UUID? = nil,
        senderId: UUID? = nil,
        senderName: String? = nil,
        senderPhotoURL: URL? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.chatId = chatId
        self.bountyId = bountyId
        self.senderId = senderId
        self.senderName = senderName
        self.senderPhotoURL = senderPhotoURL
    }
    
    static func == (lhs: InAppNotification, rhs: InAppNotification) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - In-App Notification Service

/// Central service for managing in-app notification popups
/// Debug: Displays banners on any screen, auto-dismisses after timeout
@MainActor
final class InAppNotificationService: ObservableObject {
    static let shared = InAppNotificationService()
    
    // MARK: - Published Properties
    
    /// Current notification to display (nil = no notification)
    /// Debug: Only one notification shown at a time
    @Published private(set) var currentNotification: InAppNotification?
    
    /// Whether the notification banner is visible
    @Published private(set) var isVisible: Bool = false
    
    /// Navigation trigger for when user taps notification
    @Published var navigateToChat: UUID?
    @Published var navigateToBounty: UUID?
    @Published var navigateToMessages: Bool = false
    
    /// Chat ID to suppress notifications for (when user is viewing that chat)
    /// Debug: Set this when entering a chat, clear when leaving
    var suppressedChatId: UUID?
    
    /// Whether the Messages screen (list) is currently visible
    /// Debug: Suppress notifications when user is viewing the list
    var isMessagesScreenVisible: Bool = false
    
    // MARK: - Private Properties
    
    /// Auto-dismiss timer
    private var dismissTimer: Timer?
    
    /// Queue of pending notifications
    private var notificationQueue: [InAppNotification] = []
    
    /// Duration to show notification before auto-dismiss (seconds)
    private let displayDuration: TimeInterval = 4.0
    
    /// Subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        debugLog("InAppNotificationService: init")
        setupRealtimeObservers()
    }
    
    // MARK: - Setup
    
    /// Setup observers for RealtimeService events
    /// Debug: Automatically converts realtime events to notifications
    private func setupRealtimeObservers() {
        // Observe incoming messages
        RealtimeService.shared.$incomingMessage
            .compactMap { $0 }
            .sink { [weak self] message in
                self?.handleIncomingMessage(message)
            }
            .store(in: &cancellables)
        
        // Observe bounty events
        RealtimeService.shared.$bountyEvent
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.handleBountyEvent(event)
            }
            .store(in: &cancellables)
        
        debugLog("InAppNotificationService: realtime observers setup")
    }
    
    // MARK: - Event Handlers
    
    /// Handle incoming message from RealtimeService
    /// Debug: Creates notification for new messages
    private func handleIncomingMessage(_ message: Message) {
        Task {
            debugLog("InAppNotificationService: handling incoming message \(message.id)")
            
            // Skip notification if user is viewing this chat OR the messages list
            if suppressedChatId == message.chatId || isMessagesScreenVisible {
                debugLog("InAppNotificationService: suppressed notification (chat: \(message.chatId), list visible: \(isMessagesScreenVisible))")
                return
            }
            
            // Fetch sender profile to get name and photo
            // Note: This adds a slight delay but is necessary for the UI requirement
            let profile = await ProfileService.shared.fetchProfile(id: message.senderId)
            let senderName = profile?.fullName ?? "Someone"
            let senderPhotoURL = profile?.profilePhotoURL.flatMap { URL(string: $0) }
            
            // Create notification
            let notification = InAppNotification(
                type: .newMessage,
                title: senderName,
                message: message.body.prefix(50) + (message.body.count > 50 ? "..." : ""),
                chatId: message.chatId,
                senderId: message.senderId,
                senderName: senderName,
                senderPhotoURL: senderPhotoURL
            )
            
            await MainActor.run {
                showNotification(notification)
            }
        }
    }
    
    /// Handle bounty event from RealtimeService
    /// Debug: Creates notification for bounty events
    private func handleBountyEvent(_ event: BountyEvent) {
        debugLog("InAppNotificationService: handling bounty event \(event.type)")
        
        let (title, message) = notificationContent(for: event)
        
        let notificationType: InAppNotificationType
        switch event.type {
        case .created:
            notificationType = .bountyCreated
        case .applicationReceived:
            notificationType = .bountyApplication
        case .accepted:
            notificationType = .bountyAccepted
        case .completed:
            notificationType = .bountyCompleted
        }
        
        // Map actor info to sender info for UI
        let notification = InAppNotification(
            type: notificationType,
            title: title,
            message: message,
            bountyId: event.bountyId,
            senderId: event.actorId,
            senderName: event.actorName,
            senderPhotoURL: event.actorPhotoURL
        )
        
        showNotification(notification)
    }
    
    /// Generate notification content for bounty event
    private func notificationContent(for event: BountyEvent) -> (title: String, message: String) {
        switch event.type {
        case .created:
            let creatorName = event.actorName ?? "Someone"
            return ("New Bounty Created", "\(creatorName) - \(event.bountyTitle)")
        case .applicationReceived:
            let applicantName = event.actorName ?? "Someone"
            return ("New Application", "\(applicantName) applied to \"\(event.bountyTitle)\"")
        case .accepted:
            // Check if current user is the accepted applicant or the creator
            let currentUserId = RealtimeService.shared.currentUserProfileId
            
            if let acceptedId = event.acceptedApplicantId, acceptedId == currentUserId {
                return ("Application Accepted!", "Your application for \"\(event.bountyTitle)\" was accepted")
            } else {
                return ("Bounty Started", "You accepted an applicant for \"\(event.bountyTitle)\"")
            }
        case .completed:
            return ("Bounty Completed", "\"\(event.bountyTitle)\" has been marked complete")
        }
    }
    
    // MARK: - Public Methods
    
    /// Show a notification (queues if another is showing)
    /// Debug: Handles animation and auto-dismiss
    func showNotification(_ notification: InAppNotification) {
        debugLog("InAppNotificationService: showing notification \(notification.type)")
        
        if isVisible {
            // Queue the notification
            notificationQueue.append(notification)
            debugLog("InAppNotificationService: queued notification, queue size: \(notificationQueue.count)")
            return
        }
        
        // Show immediately
        currentNotification = notification
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isVisible = true
        }
        
        // Start auto-dismiss timer
        startDismissTimer()
    }
    
    /// Dismiss the current notification
    /// Debug: Also shows next queued notification if any
    func dismissCurrent() {
        debugLog("InAppNotificationService: dismissing current notification")
        
        dismissTimer?.invalidate()
        dismissTimer = nil
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = false
        }
        
        // Clear after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.currentNotification = nil
            self?.showNextQueued()
        }
    }
    
    /// Handle tap on notification
    /// Debug: Triggers navigation and dismisses
    func handleTap() {
        guard let notification = currentNotification else { return }
        
        debugLog("InAppNotificationService: notification tapped, type: \(notification.type)")
        
        // Trigger navigation based on type
        switch notification.type {
        case .newMessage:
            if let chatId = notification.chatId {
                navigateToChat = chatId
            } else {
                navigateToMessages = true
            }
        case .bountyCreated, .bountyApplication, .bountyAccepted, .bountyCompleted:
            if let bountyId = notification.bountyId {
                navigateToBounty = bountyId
            }
        }
        
        dismissCurrent()
    }
    
    /// Clear navigation triggers (call after handling navigation)
    func clearNavigationTriggers() {
        navigateToChat = nil
        navigateToBounty = nil
        navigateToMessages = false
    }
    
    // MARK: - Private Methods
    
    /// Start the auto-dismiss timer
    private func startDismissTimer() {
        dismissTimer?.invalidate()
        // Capture weak reference to avoid Swift 6 concurrency issues
        dismissTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                strongSelf.dismissCurrent()
            }
        }
    }
    
    /// Show next queued notification
    private func showNextQueued() {
        guard !notificationQueue.isEmpty else { return }
        
        let next = notificationQueue.removeFirst()
        debugLog("InAppNotificationService: showing next queued notification")
        showNotification(next)
    }
    
    // MARK: - Manual Notification Creation
    
    /// Create and show a message notification manually
    /// Debug: Use when you need to show notification outside of realtime events
    func showMessageNotification(senderName: String, messagePreview: String, chatId: UUID) {
        let notification = InAppNotification(
            type: .newMessage,
            title: senderName,
            message: messagePreview,
            chatId: chatId
        )
        showNotification(notification)
    }
    
    /// Create and show a bounty notification manually
    func showBountyNotification(title: String, message: String, bountyId: UUID, type: InAppNotificationType) {
        let notification = InAppNotification(
            type: type,
            title: title,
            message: message,
            bountyId: bountyId
        )
        showNotification(notification)
    }
}
