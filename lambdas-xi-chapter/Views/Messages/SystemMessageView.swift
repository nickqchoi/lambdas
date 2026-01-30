//
//  BountyMessageView.swift
//  lambdas-xi-chapter
//
//  Inline interactive bounty card for chat stream.
//  Replaces "Bounty started" text with full bounty context.
//

import SwiftUI

struct BountyMessageBubble: View {
    let message: Message
    let bounty: Bounty? // Optional because it might be loading
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                if let bounty = bounty {
                    // Loaded State
                    HStack {
                        Image(systemName: "list.bullet.clipboard.fill")
                            .foregroundStyle(.blue)
                        Text(bounty.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                        Text(bounty.status.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor(for: bounty.status).opacity(0.2))
                            .cornerRadius(6)
                    }
                    
                    Text(bounty.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    // Loading/Error State
                    HStack {
                        Image(systemName: "list.bullet.clipboard.fill")
                            .foregroundStyle(.gray)
                        Text("Loading bounty details...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal) // Add horizontal padding to match message bubbles somewhat (or center it)
        .frame(maxWidth: .infinity) // Allow it to stretch
    }
    
    private func statusColor(for status: BountyStatus) -> Color {
        switch status {
        case .open: return .appPrimary
        case .inProgress: return .orange
        case .completed: return .green
        }
    }
}

#Preview {
    VStack {
        // Loaded
        BountyMessageBubble(
            message: Message(chatId: UUID(), senderId: UUID(), body: "", type: .system),
            bounty: Bounty(
                title: "Fix Login Bug",
                description: "Users cannot login when using email.",
                creatorId: UUID()
            ),
            onTap: {}
        )
        
        // Loading
        BountyMessageBubble(
            message: Message(chatId: UUID(), senderId: UUID(), body: "", type: .system),
            bounty: nil,
            onTap: {}
        )
    }
    .padding()
}
