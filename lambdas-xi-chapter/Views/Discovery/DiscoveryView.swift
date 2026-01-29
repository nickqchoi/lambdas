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
            VStack {
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
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(profiles) { profile in
                                ProfileCardView(profile: profile)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Discovery")
            .toolbar {
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
    @State private var showProfile = false
    @State private var showMessage = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Profile photo placeholder
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Text(profile.fullName.prefix(1))
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                
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
                    showMessage = true
                } label: {
                    Text("Message")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .sheet(isPresented: $showProfile) {
            ProfileDetailView(profile: profile)
        }
        .sheet(isPresented: $showMessage) {
            // TODO: Open chat with this user
            Text("Start chat with \(profile.fullName)")
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
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay {
                                Text(profile.fullName.prefix(1))
                                    .font(.largeTitle)
                                    .fontWeight(.semibold)
                            }
                        
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
