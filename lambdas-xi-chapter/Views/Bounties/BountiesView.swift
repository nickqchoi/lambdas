//
//  BountiesView.swift
//  lambdas-xi-chapter
//
//  Bounty feed §9: list bounties, create, apply, accept, complete.
//

import SwiftUI

struct BountiesView: View {
    @StateObject private var bountyService = BountyService.shared
    @StateObject private var auth = AuthService.shared
    
    @State private var bounties: [Bounty] = []
    @State private var isLoading = false
    @State private var showCreateBounty = false
    @State private var selectedBounty: Bounty?
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("Loading bounties...")
                } else if bounties.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("No bounties yet")
                            .font(.headline)
                        Text("Create the first one!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(bounties) { bounty in
                                BountyCardView(bounty: bounty) {
                                    selectedBounty = bounty
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Bounties")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateBounty = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateBounty) {
                CreateBountyView { loadBounties() }
            }
            .sheet(item: $selectedBounty) { bounty in
                BountyDetailView(bounty: bounty) { loadBounties() }
            }
            .task {
                loadBounties()
            }
        }
    }
    
    private func loadBounties() {
        isLoading = true
        Task {
            let result = await bountyService.fetchBounties()
            await MainActor.run {
                bounties = result
                isLoading = false
            }
        }
    }
}

struct BountyCardView: View {
    let bounty: Bounty
    let onTap: () -> Void
    
    var statusColor: Color {
        switch bounty.status {
        case .open: return .green
        case .inProgress: return .orange
        case .completed: return .gray
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(bounty.title)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Text(bounty.status.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.2))
                        .cornerRadius(6)
                }
                
                Text(bounty.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                FlowLayout(spacing: 6) {
                    ForEach(bounty.skillTags) { skill in
                        Text(skill.label)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(6)
                    }
                }
                
                HStack {
                    if let effort = bounty.estimatedEffort {
                        Label(effort.rawValue, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let deadline = bounty.deadline {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(deadline, format: .dateTime.month().day())
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct CreateBountyView: View {
    @StateObject private var bountyService = BountyService.shared
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var auth = AuthService.shared
    @Environment(\.dismiss) var dismiss
    
    let onCreated: () -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var effort: EstimatedEffort = .short
    @State private var deadline: Date?
    @State private var selectedSkills: [Skill] = []
    @State private var customSkill = ""
    @State private var showDeadlinePicker = false
    @State private var errorMessage: String?
    @State private var isSaving = false
    
    let predefinedSkills = PredefinedSkill.allCases
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("e.g. Help with resume review", text: $title)
                }
                
                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }
                
                Section("Estimated Effort") {
                    Picker("Effort", selection: $effort) {
                        ForEach(EstimatedEffort.allCases, id: \.self) { effort in
                            Text(effort.rawValue).tag(effort)
                        }
                    }
                }
                
                Section("Deadline (optional)") {
                    Toggle("Set deadline", isOn: $showDeadlinePicker)
                    if showDeadlinePicker, let d = deadline {
                        DatePicker("Deadline", selection: Binding(get: { d }, set: { deadline = $0 }), displayedComponents: .date)
                    } else if showDeadlinePicker {
                        DatePicker("Deadline", selection: Binding(get: { Date() }, set: { deadline = $0 }), displayedComponents: .date)
                    }
                }
                
                Section("Skills") {
                    ForEach(predefinedSkills, id: \.self) { predefined in
                        let skill = Skill(label: predefined.rawValue, isPredefined: true)
                        Toggle(predefined.rawValue, isOn: Binding(
                            get: { selectedSkills.contains(where: { $0.label == predefined.rawValue }) },
                            set: { on in
                                if on {
                                    if !selectedSkills.contains(where: { $0.label == predefined.rawValue }) {
                                        selectedSkills.append(skill)
                                    }
                                } else {
                                    selectedSkills.removeAll { $0.label == predefined.rawValue }
                                }
                            }
                        ))
                    }
                }
                
                Section("Custom Skill (optional)") {
                    HStack {
                        TextField("e.g. Excel", text: $customSkill)
                        if !customSkill.isEmpty {
                            Button("Add") {
                                let trimmed = customSkill.trimmingCharacters(in: .whitespaces)
                                let skill = Skill(label: trimmed, isPredefined: false)
                                if !selectedSkills.contains(where: { $0.label == trimmed }) {
                                    selectedSkills.append(skill)
                                }
                                customSkill = ""
                            }
                        }
                    }
                    ForEach(selectedSkills.filter { !$0.isPredefined }) { skill in
                        HStack {
                            Text(skill.label)
                            Spacer()
                            Button(role: .destructive) {
                                selectedSkills.removeAll { $0.id == skill.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                        }
                    }
                }
                
                if let err = errorMessage {
                    Section {
                        Text(err).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Create Bounty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { save() }
                        .disabled(isSaving)
                }
            }
        }
    }
    
    private func save() {
        errorMessage = nil
        guard let user = auth.currentUser else { return }
        
        let t = title.trimmingCharacters(in: .whitespaces)
        let d = description.trimmingCharacters(in: .whitespaces)
        
        if t.isEmpty || d.isEmpty {
            errorMessage = "Title and description are required"
            return
        }
        if selectedSkills.isEmpty {
            errorMessage = "Select at least one skill"
            return
        }
        
        isSaving = true
        Task {
            // Fetch user's profile to get profile ID for legacy creatorId
            let profile = await profileService.fetchProfile(clerkUserId: user.clerkId)
            let profileId = profile?.id ?? UUID() // Fallback to new UUID if profile not found
            
            let bounty = Bounty(
                id: UUID(),
                title: t,
                description: d,
                skillTags: selectedSkills,
                estimatedEffort: effort,
                deadline: showDeadlinePicker ? deadline : nil,
                creatorId: profileId,
                clerkCreatorId: user.clerkId,
                status: .open
            )
            bountyService.createBounty(bounty)
            await MainActor.run {
                isSaving = false
                onCreated()
                dismiss()
            }
        }
    }
}

struct BountyDetailView: View {
    let bounty: Bounty
    let onUpdate: () -> Void
    
    @StateObject private var bountyService = BountyService.shared
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var auth = AuthService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var applications: [BountyApplication] = []
    @State private var creatorProfile: Profile?
    @State private var showApplySheet = false
    @State private var applicationMessage = ""
    
    var isCreator: Bool {
        auth.currentUser?.clerkId == bounty.clerkCreatorId
    }
    
    var hasApplied: Bool {
        guard let clerkId = auth.currentUser?.clerkId else { return false }
        return applications.contains { $0.clerkApplicantId == clerkId }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status
                    HStack {
                        Text(bounty.status.rawValue)
                            .font(.headline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(statusColor.opacity(0.2))
                            .cornerRadius(8)
                        Spacer()
                    }
                    
                    // Title
                    Text(bounty.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Description
                    Text(bounty.description)
                        .font(.body)
                    
                    Divider()
                    
                    // Details
                    VStack(alignment: .leading, spacing: 12) {
                        if let effort = bounty.estimatedEffort {
                            HStack {
                                Image(systemName: "clock")
                                Text("Effort: \(effort.rawValue)")
                            }
                            .font(.subheadline)
                        }
                        
                        if let deadline = bounty.deadline {
                            HStack {
                                Image(systemName: "calendar")
                                Text("Deadline: \(deadline, format: .dateTime.month().day().year())")
                            }
                            .font(.subheadline)
                        }
                    }
                    
                    // Skills
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Skills")
                            .font(.headline)
                        FlowLayout(spacing: 8) {
                            ForEach(bounty.skillTags) { skill in
                                Text(skill.label)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Creator
                    if let creator = creatorProfile {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Posted by")
                                .font(.headline)
                            HStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Text(creator.fullName.prefix(1))
                                            .font(.headline)
                                    }
                                VStack(alignment: .leading) {
                                    Text(creator.fullName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(creator.roleTag.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    
                    // Applications (for creator)
                    if isCreator && !applications.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Applications (\(applications.count))")
                                .font(.headline)
                            ForEach(applications) { app in
                                ApplicationRow(application: app, bounty: bounty, onUpdate: onUpdate)
                            }
                        }
                    }
                    
                    // Apply button
                    if !isCreator && bounty.status == .open && !hasApplied {
                        Button {
                            showApplySheet = true
                        } label: {
                            Text("Apply for this Bounty")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                        }
                    } else if !isCreator && hasApplied {
                        Text("You've already applied")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                    
                    // Mark complete (for creator, when in progress)
                    if isCreator && bounty.status == .inProgress {
                        Button {
                            bountyService.markBountyComplete(bountyId: bounty.id)
                            onUpdate()
                            dismiss()
                        } label: {
                            Text("Mark as Completed")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Bounty Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showApplySheet) {
                ApplyToBountyView(bounty: bounty) {
                    loadApplications()
                }
            }
            .task {
                loadCreator()
                loadApplications()
            }
        }
    }
    
    private var statusColor: Color {
        switch bounty.status {
        case .open: return .green
        case .inProgress: return .orange
        case .completed: return .gray
        }
    }
    
    private func loadCreator() {
        Task {
            let profile = await profileService.fetchProfile(id: bounty.creatorId)
            await MainActor.run { creatorProfile = profile }
        }
    }
    
    private func loadApplications() {
        Task {
            let apps = await bountyService.fetchApplications(bountyId: bounty.id)
            await MainActor.run { applications = apps }
        }
    }
}

struct ApplicationRow: View {
    let application: BountyApplication
    let bounty: Bounty
    let onUpdate: () -> Void
    
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var bountyService = BountyService.shared
    @State private var applicantProfile: Profile?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let profile = applicantProfile {
                HStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 35, height: 35)
                        .overlay {
                            Text(profile.fullName.prefix(1))
                                .font(.subheadline)
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.fullName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(profile.roleTag.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    
                    if bounty.status == .open {
                        Button("Accept") {
                            bountyService.acceptApplication(bountyId: bounty.id, applicationId: application.id, applicantId: application.applicantId)
                            onUpdate()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                
                if let message = application.message, !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 43)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .task {
            let profile = await profileService.fetchProfile(id: application.applicantId)
            await MainActor.run { applicantProfile = profile }
        }
    }
}

struct ApplyToBountyView: View {
    let bounty: Bounty
    let onApplied: () -> Void
    
    @StateObject private var bountyService = BountyService.shared
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var auth = AuthService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var message = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Message to bounty creator (optional)") {
                    TextEditor(text: $message)
                        .frame(minHeight: 100)
                }
                
                Section {
                    Text("By applying, the bounty creator will be able to see your profile and message.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Apply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { apply() }
                        .disabled(isSaving)
                }
            }
        }
    }
    
    private func apply() {
        guard let user = auth.currentUser else { return }
        isSaving = true
        Task {
            // Fetch user's profile to get profile ID for legacy applicantId
            let profile = await profileService.fetchProfile(clerkUserId: user.clerkId)
            let profileId = profile?.id ?? UUID() // Fallback to new UUID if profile not found
            
            let app = BountyApplication(
                id: UUID(),
                bountyId: bounty.id,
                applicantId: profileId,
                clerkApplicantId: user.clerkId,
                message: message.trimmingCharacters(in: .whitespaces),
                appliedAt: Date()
            )
            bountyService.applyToBounty(application: app)
            await MainActor.run {
                isSaving = false
                onApplied()
                dismiss()
            }
        }
    }
}

#Preview {
    BountiesView()
}
