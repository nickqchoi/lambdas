//
//  ProfileView.swift
//  lambdas-xi-chapter
//
//  Own profile view: display and edit.
//  Debug: Uses Clerk user ID for profile operations
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var auth = AuthService.shared
    @StateObject private var unlock = UnlockService.shared
    
    @State private var profile: Profile?
    @State private var isLoading = false
    @State private var showEditProfile = false
    @State private var showLogoutAlert = false
    @State private var showResetLockAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading profile...")
                } else if let p = profile {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Header
                            HStack {
                                AvatarView(
                                    photoURL: p.profilePhotoURL,
                                    initials: p.fullName,
                                    size: 80
                                )
                                mapInitials(p)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(p.fullName)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                    
                                    // Debug: Show username from profile
                                    if !p.username.isEmpty {
                                        Text("@\(p.username)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Text(p.roleTag.rawValue)
                                        .font(.subheadline)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(p.roleTag == .alumni ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2))
                                        .cornerRadius(6)
                                }
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 12) {
                                InfoRow(label: "Email", value: auth.currentUser?.email ?? "")
                                InfoRow(label: "Chapter Class", value: p.chapterClass)
                                InfoRow(label: "Graduation Year", value: p.graduationYear)
                                InfoRow(label: "Major/Industry", value: p.majorOrIndustry)
                            }
                            .padding(.horizontal)
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Skills")
                                    .font(.headline)
                                FlowLayout(spacing: 8) {
                                    ForEach(p.skills) { skill in
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
                                Text(p.shortBio)
                                    .font(.body)
                            }
                            .padding(.horizontal)
                            
                            Divider()
                            
                            // Edit button
                            Button {
                                showEditProfile = true
                            } label: {
                                Text("Edit Profile")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            
                            // Logout button
                            Button(role: .destructive) {
                                showLogoutAlert = true
                            } label: {
                                Text("Sign Out")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .foregroundStyle(.red)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            
                            // Debug: Reset app lock for testing
                            #if DEBUG
                            Divider()
                                .padding(.vertical, 8)
                            
                            Text("Debug Options")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            
                            Button {
                                showResetLockAlert = true
                            } label: {
                                Text("Reset App Lock (Test HELLOPANDA)")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange.opacity(0.1))
                                    .foregroundStyle(.orange)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            #endif
                        }
                        .padding(.vertical)
                    }
                } else {
                    Text("Profile not found")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("My Profile")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image.appLogo
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                }
            }
            .sheet(isPresented: $showEditProfile) {
                if let p = profile {
                    EditProfileView(profile: p) { loadProfile() }
                }
            }
            .alert("Sign Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    auth.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Reset App Lock", isPresented: $showResetLockAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    // Debug: Reset unlock and sign out to test full flow
                    auth.signOut()
                    unlock.resetUnlock()
                    debugLog("ProfileView: reset app lock for testing")
                }
            } message: {
                Text("This will sign you out and require the HELLOPANDA invite code again. Use for testing.")
            }
            .task {
                loadProfile()
            }
        }
    }
    
    private func mapInitials(_ p: Profile) -> some View {
        EmptyView() // Placeholder to match structure change if needed or just use AvatarView
    }
    
    /// Load profile using Clerk user ID
    /// Debug: Fetches profile from Supabase using clerk_user_id
    private func loadProfile() {
        guard let clerkId = auth.currentUser?.clerkId else { 
            debugLog("ProfileView: no clerkId, cannot load profile")
            return 
        }
        isLoading = true
        Task {
            let p = await profileService.fetchProfile(clerkUserId: clerkId)
            await MainActor.run {
                profile = p
                isLoading = false
                debugLog("ProfileView: profile loaded for \(clerkId)")
            }
        }
    }
}

/// Edit profile view
/// Debug: Uses existing profile's clerkUserId for updates
struct EditProfileView: View {
    let profile: Profile
    let onSaved: () -> Void
    
    @StateObject private var profileService = ProfileService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var fullName: String
    @State private var chapterClass: String
    @State private var roleTag: RoleTag
    @State private var graduationYear: String
    @State private var majorOrIndustry: String
    @State private var selectedSkills: [Skill]
    @State private var customSkill = ""
    @State private var shortBio: String
    @State private var errorMessage: String?
    @State private var isSaving = false
    
    // Photo Selection
    @State private var selectedItem: PhotosPickerItem?
    @State private var profilePhotoURL: String?
    @State private var isUploadingPhoto = false
    
    init(profile: Profile, onSaved: @escaping () -> Void) {
        self.profile = profile
        self.onSaved = onSaved
        _fullName = State(initialValue: profile.fullName)
        _chapterClass = State(initialValue: profile.chapterClass)
        _roleTag = State(initialValue: profile.roleTag)
        _graduationYear = State(initialValue: profile.graduationYear)
        _majorOrIndustry = State(initialValue: profile.majorOrIndustry)
        _selectedSkills = State(initialValue: profile.skills)
        _shortBio = State(initialValue: profile.shortBio)
        _profilePhotoURL = State(initialValue: profile.profilePhotoURL)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Photo Upload Section
                Section {
                    HStack {
                        Spacer()
                        VStack {
                            AvatarView(
                                photoURL: profilePhotoURL,
                                initials: fullName,
                                size: 100
                            )
                            
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Text(profilePhotoURL == nil ? "Add Photo" : "Change Photo")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .disabled(isUploadingPhoto)
                            
                            if isUploadingPhoto {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                
                // Debug: Show username (read-only)
                if !profile.username.isEmpty {
                    Section {
                        HStack {
                            Text("Username")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("@\(profile.username)")
                        }
                    } footer: {
                        Text("Username cannot be changed")
                    }
                }
                
                Section("Full Name") {
                    TextField("Full Name", text: $fullName)
                }
                Section("Chapter Class") {
                    TextField("e.g. Fall '21", text: $chapterClass)
                }
                Section("Role") {
                    Picker("Role", selection: $roleTag) {
                        ForEach(RoleTag.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Graduation Year") {
                    TextField("e.g. 2025", text: $graduationYear)
                        .keyboardType(.numberPad)
                }
                Section("Major or Industry") {
                    TextField("e.g. Computer Science, Finance", text: $majorOrIndustry)
                }
                
                Section {
                    ForEach(PredefinedSkill.allCases, id: \.self) { s in
                        let sk = Skill(label: s.rawValue, isPredefined: true)
                        Toggle(isOn: bindingForSkill(sk)) { Text(s.rawValue) }
                    }
                } header: { Text("Skills (select 2–3)") }
                
                Section("Custom Skill (optional)") {
                    HStack {
                        TextField("e.g. Startups, Consulting", text: $customSkill)
                        if !customSkill.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button("Add") {
                                let s = Skill(label: customSkill.trimmingCharacters(in: .whitespaces), isPredefined: false)
                                if !selectedSkills.contains(where: { $0.label == s.label }) {
                                    selectedSkills.append(s)
                                    customSkill = ""
                                }
                            }
                        }
                    }
                    ForEach(selectedSkills.filter { !$0.isPredefined }) { s in
                        HStack {
                            Text(s.label)
                            Spacer()
                            Button(role: .destructive) {
                                selectedSkills.removeAll { $0.id == s.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                        }
                    }
                }
                
                Section("Short Bio") {
                    TextEditor(text: $shortBio)
                        .frame(minHeight: 100)
                }
                
                if let err = errorMessage {
                    Section {
                        Text(err).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving || isUploadingPhoto)
                }
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    guard let data = try? await newItem?.loadTransferable(type: Data.self) else { return }
                    // Use profile's clerkUserId
                    let userId = profile.clerkUserId
                    
                    isUploadingPhoto = true
                    do {
                        let url = try await profileService.uploadProfilePhoto(data: data, clerkUserId: userId)
                        await MainActor.run {
                            profilePhotoURL = url
                            isUploadingPhoto = false
                        }
                    } catch {
                        await MainActor.run {
                            errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                            isUploadingPhoto = false
                        }
                    }
                }
            }
        }
    }
    
    private func bindingForSkill(_ sk: Skill) -> Binding<Bool> {
        Binding(
            get: { selectedSkills.contains { $0.id == sk.id } || selectedSkills.contains { $0.label == sk.label } },
            set: { on in
                if on {
                    if !selectedSkills.contains(where: { $0.label == sk.label }) { selectedSkills.append(sk) }
                } else {
                    selectedSkills.removeAll { $0.label == sk.label }
                }
            }
        )
    }
    
    /// Save profile updates
    /// Debug: Uses profile's existing clerkUserId (not from auth)
    private func save() {
        errorMessage = nil
        
        if selectedSkills.count < 2 {
            errorMessage = "Please select at least 2 skills."
            return
        }
        if selectedSkills.count > 5 {
            errorMessage = "Please select at most 5 skills."
            return
        }
        
        // Debug: Create updated profile using existing profile's IDs
        var updatedProfile = profile
        updatedProfile.fullName = fullName.trimmingCharacters(in: .whitespaces)
        updatedProfile.chapterClass = chapterClass.trimmingCharacters(in: .whitespaces)
        updatedProfile.roleTag = roleTag
        updatedProfile.graduationYear = graduationYear.trimmingCharacters(in: .whitespaces)
        updatedProfile.majorOrIndustry = majorOrIndustry.trimmingCharacters(in: .whitespaces)
        updatedProfile.skills = selectedSkills
        updatedProfile.shortBio = shortBio.trimmingCharacters(in: .whitespaces)
        updatedProfile.profilePhotoURL = profilePhotoURL
        
        if !profileService.isProfileComplete(updatedProfile) {
            errorMessage = "Please fill in all required fields."
            return
        }
        
        isSaving = true
        profileService.saveProfile(updatedProfile)
        isSaving = false
        debugLog("EditProfileView: saved profile for clerk_user_id: \(profile.clerkUserId)")
        onSaved()
        dismiss()
    }
}

#Preview {
    ProfileView()
}
