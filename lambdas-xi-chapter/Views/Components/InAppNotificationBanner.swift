//
//  InAppNotificationBanner.swift
//  lambdas-xi-chapter
//
//  Floating notification banner that appears on any screen.
//  §12.2 Push notifications, §14 Notification architecture.
//  Debug: Overlays on top of all content, slides in from top.
//

import SwiftUI

// MARK: - In-App Notification Banner

/// Floating banner that displays in-app notifications on any screen
/// Debug: Observes InAppNotificationService for notifications to display
struct InAppNotificationBanner: View {
    @ObservedObject private var service = InAppNotificationService.shared
    
    /// Offset for drag gesture
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        ZStack(alignment: .top) {
            // Invisible spacer to position content
            Color.clear.frame(height: 0)
            
            // Banner content
            if service.isVisible, let notification = service.currentNotification {
                notificationCard(notification)
                    .offset(y: service.isVisible ? max(0, dragOffset) : -200)
                    .gesture(dragGesture)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: service.isVisible)
                    .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Notification Card
    
    @ViewBuilder
    private func notificationCard(_ notification: InAppNotification) -> some View {
        HStack(spacing: DesignSystem.Padding.small) {
            // Icon or Avatar
            if let photoURL = notification.senderPhotoURL {
                AvatarView(
                    photoURL: photoURL.absoluteString,
                    initials: notification.senderName ?? "",
                    size: 44
                )
            } else {
                ZStack {
                    Circle()
                        .fill(notification.type.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: notification.type.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(notification.type.color)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(notification.message)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
            }
            
            Spacer(minLength: 0)
            
            // Dismiss button
            Button {
                service.dismissCurrent()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, DesignSystem.Padding.standard)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.appPrimary.opacity(0.95),
                            Color.appPrimary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, DesignSystem.Padding.standard)
        .contentShape(Rectangle())
        .onTapGesture {
            service.handleTap()
        }
    }
    
    // MARK: - Drag Gesture
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only allow upward drag (negative translation)
                if value.translation.height < 0 {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                // Dismiss if dragged up enough
                if value.translation.height < -50 {
                    service.dismissCurrent()
                }
                dragOffset = 0
            }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        // Background
        Color.appBackground.ignoresSafeArea()
        
        VStack {
            Text("Main Content")
                .foregroundColor(.white)
        }
        
        // Notification overlay
        InAppNotificationBanner()
    }
    .onAppear {
        // Show a test notification
        let notification = InAppNotification(
            type: .newMessage,
            title: "John Doe",
            message: "Hey, are you available to help with the website project?",
            chatId: UUID()
        )
        InAppNotificationService.shared.showNotification(notification)
    }
}
