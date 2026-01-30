//
//  DiscoveryView.swift
//  lambdas-xi-chapter
//
//  Discovery feed §8: profile cards with filters (role, skills, grad year).
//

import SwiftUI

struct DiscoveryView: View {
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var auth = AuthService.shared
    
    @State private var profiles: [Profile] = []
    @State private var isLoading = false
    
    // Filters
    @State private var roleFilter: RoleTag?
    @State private var skillsFilter: [String] = []
    @State private var graduationFilter = ""
    @State private var showFilters = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading profiles...")
                } else if profiles.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("No profiles found")
                            .font(.headline)
                        Text("Try adjusting your filters")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                // Invisible anchor for scrolling to top
                                Color.clear
                                    .frame(height: 1)
                                    .id("top")
                                
                                ForEach(profiles) { profile in
                                    ProfileCardView(profile: profile)
                                }
                            }
                            .padding()
                        }
                        .refreshable {
                            loadProfiles()
                            // Small delay to allow UI to update then scroll
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            withAnimation {
                                proxy.scrollTo("top", anchor: .top)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Discovery")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image.appLogo
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showFilters.toggle()
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                DiscoveryFiltersView(
                    roleFilter: $roleFilter,
                    skillsFilter: $skillsFilter,
                    graduationFilter: $graduationFilter,
                    onApply: { loadProfiles() }
                )
            }
            .task {
                loadProfiles()
            }
        }
    }
    
    private func loadProfiles() {
        guard let clerkUserId = auth.currentUser?.clerkId else { return }
        isLoading = true
        Task {
            let result = await profileService.discoveryProfiles(
                excludingClerkUserId: clerkUserId,
                roleFilter: roleFilter,
                skillsFilter: skillsFilter,
                graduationFilter: graduationFilter
            )
            await MainActor.run {
                profiles = result
                isLoading = false
            }
        }
    }
}

struct ProfileCardView: View {
    let profile: Profile
    @StateObject private var auth = AuthService.shared
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var messagingService = MessagingService.shared
    
    @State private var showProfile = false
    @State private var showMessage = false
    @State private var chatToOpen: Chat?
    @State private var isCreatingChat = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Profile photo
                AvatarView(
                    photoURL: profile.profilePhotoURL,
                    initials: profile.fullName,
                    size: 50
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.fullName)
                        .font(.headline)
                    HStack(spacing: 8) {
                        Text(profile.roleTag.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(profile.roleTag == .alumni ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2))
                            .cornerRadius(4)
                        Text(profile.graduationYear)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Skills
            FlowLayout(spacing: 6) {
                ForEach(profile.skills) { skill in
                    Text(skill.label)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(6)
                }
            }
            
            // Bio preview
            Text(profile.shortBio)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            // Actions
            HStack(spacing: 12) {
                Button {
                    showProfile = true
                } label: {
                    Text("View Profile")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button {
                    startChat()
                } label: {
                    HStack {
                        if isCreatingChat {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Message")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCreatingChat)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .sheet(isPresented: $showProfile) {
            ProfileDetailView(profile: profile)
        }
        .sheet(item: $chatToOpen) { chat in
            ChatDetailView(chat: chat)
        }
    }
    
    /// Start or open existing chat with this profile
    private func startChat() {
        debugLog("ProfileCardView: startChat tapped for profile \(profile.id)")
        
        guard let clerkId = auth.currentUser?.clerkId else {
            debugLog("ProfileCardView: no clerkId, aborting")
            return
        }
        
        debugLog("ProfileCardView: current user clerkId = \(clerkId)")
        isCreatingChat = true
        
        Task {
            // Get current user's profile ID
            debugLog("ProfileCardView: fetching my profile...")
            guard let myProfile = await profileService.fetchProfile(clerkUserId: clerkId) else {
                debugLog("ProfileCardView: failed to fetch my profile, aborting")
                await MainActor.run { isCreatingChat = false }
                return
            }
            
            debugLog("ProfileCardView: my profile id = \(myProfile.id)")
            debugLog("ProfileCardView: target profile id = \(profile.id)")
            
            // Check if chat already exists (checks DB, not just memory cache)
            if let existingChat = await messagingService.findExistingChat(participant1: myProfile.id, participant2: profile.id) {
                debugLog("ProfileCardView: found existing chat \(existingChat.id)")
                await MainActor.run {
                    chatToOpen = existingChat
                    isCreatingChat = false
                }
                return
            }
            
            debugLog("ProfileCardView: no existing chat, creating new one...")
            
            // Get or create chat with clerk_user_ids for RLS policy
            let newChat = await messagingService.getOrCreateChat(
                participant1: myProfile.id,
                participant2: profile.id,
                clerkUserId1: clerkId,
                clerkUserId2: profile.clerkUserId
            )
            
            if let chat = newChat {
                debugLog("ProfileCardView: created chat \(chat.id)")
            } else {
                debugLog("ProfileCardView: failed to create chat (nil returned)")
            }
            
            await MainActor.run {
                chatToOpen = newChat
                isCreatingChat = false
                debugLog("ProfileCardView: chatToOpen set to \(String(describing: newChat?.id))")
            }
        }
    }
}

// Simple flow layout for skills
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

struct DiscoveryFiltersView: View {
    @Binding var roleFilter: RoleTag?
    @Binding var skillsFilter: [String]
    @Binding var graduationFilter: String
    let onApply: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Role") {
                    Picker("Filter by role", selection: $roleFilter) {
                        Text("All").tag(nil as RoleTag?)
                        ForEach(RoleTag.allCases, id: \.self) { role in
                            Text(role.rawValue).tag(role as RoleTag?)
                        }
                    }
                }
                
                Section("Graduation Year") {
                    TextField("e.g. 2025", text: $graduationFilter)
                        .keyboardType(.numberPad)
                }
                
                Section("Skills") {
                    Text("Skills filter coming soon")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ProfileDetailView: View {
    let profile: Profile
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        AvatarView(
                            photoURL: profile.profilePhotoURL,
                            initials: profile.fullName,
                            size: 80
                        )
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(profile.fullName)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(profile.roleTag.rawValue)
                                .font(.subheadline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(profile.roleTag == .alumni ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2))
                                .cornerRadius(6)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(label: "Chapter Class", value: profile.chapterClass)
                        InfoRow(label: "Graduation Year", value: profile.graduationYear)
                        InfoRow(label: "Major/Industry", value: profile.majorOrIndustry)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Skills")
                            .font(.headline)
                        FlowLayout(spacing: 8) {
                            ForEach(profile.skills) { skill in
                                Text(skill.label)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bio")
                            .font(.headline)
                        Text(profile.shortBio)
                            .font(.body)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
    }
}

#Preview {
    DiscoveryView()
}
