//
//  ProfileSetupView.swift
//  lambdas-xi-chapter
//
//  Profile onboarding §6. All required fields §6.2. Skills: predefined §6.3.1 + custom §6.3.2.
//  Gating: must complete before accessing app §6.1.
//  Debug: Uses Clerk user ID for profile creation
//

import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var auth = AuthService.shared

    @State private var fullName = ""
    @State private var chapterClass = ""
    @State private var roleTag: RoleTag = .active
    @State private var graduationYear = ""
    @State private var majorOrIndustry = ""
    @State private var selectedSkills: [Skill] = []
    @State private var customSkill = ""
    @State private var shortBio = ""
    @State private var errorMessage: String?
    @State private var isSaving = false
    
    // Photo Selection
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var profilePhotoURL: String?
    @State private var isUploadingPhoto = false

    var body: some View {
        NavigationStack {
            Form {
                // Photo Upload Section
                Section {
                    HStack {
                        Spacer()
                        VStack {
                            AvatarView(
                                image: selectedImage,
                                photoURL: profilePhotoURL,
                                initials: fullName.isEmpty ? (auth.currentUser?.username ?? "U") : fullName,
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
                
                // Debug: Show username from Clerk
                if let user = auth.currentUser, !user.username.isEmpty {
                    Section {
                        HStack {
                            Text("Username")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("@\(user.username)")
                                .fontWeight(.medium)
                        }
                    } header: {
                        Text("Account")
                    } footer: {
                        Text("Your username was set during registration")
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

                // §6.3.1 Predefined + §6.3.2 Custom
                Section {
                    ForEach(PredefinedSkill.allCases, id: \.self) { s in
                        let sk = Skill(label: s.rawValue, isPredefined: true)
                        Toggle(isOn: bindingForSkill(sk)) { Text(s.rawValue) }
                    }
                } header: { Text("Skills (select 2–3)") } footer: { Text("Pick 2–3 from the list. You can add one custom skill below.") }

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
                            Button(role: .destructive) { selectedSkills.removeAll { $0.id == s.id } } label: { Image(systemName: "xmark.circle.fill") }
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
            .navigationTitle("Complete Your Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving || isUploadingPhoto)
                }
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    guard let data = try? await newItem?.loadTransferable(type: Data.self),
                          let userId = auth.currentUser?.clerkId
                    else { return }
                    
                    // Set local image immediately for optimistic UI
                    if let uiImage = UIImage(data: data) {
                        await MainActor.run { selectedImage = uiImage }
                    }
                    
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

    // MARK: - Skill Binding
    
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

    // MARK: - Save Profile
    
    /// Save profile to Supabase
    /// Debug: Uses Clerk user ID (clerkId) for profile association
    private func save() {
        errorMessage = nil
        let skills = selectedSkills
        
        // Validation
        if skills.count < 2 {
            errorMessage = "Please select at least 2 skills."
            debugLog("ProfileSetupView: validation failed - not enough skills")
            return
        }
        if skills.count > 5 {
            errorMessage = "Please select at most 5 skills."
            debugLog("ProfileSetupView: validation failed - too many skills")
            return
        }
        
        // Get current Clerk user
        guard let user = auth.currentUser else {
            errorMessage = "No authenticated user. Please sign in again."
            debugLog("ProfileSetupView: no current user")
            return
        }
        
        // Debug: Create profile with Clerk user ID
        let profile = Profile(
            clerkUserId: user.clerkId,  // Clerk user ID for RLS
            username: user.username,     // Username from Clerk
            fullName: fullName.trimmingCharacters(in: .whitespaces),
            chapterClass: chapterClass.trimmingCharacters(in: .whitespaces),
            roleTag: roleTag,
            graduationYear: graduationYear.trimmingCharacters(in: .whitespaces),
            majorOrIndustry: majorOrIndustry.trimmingCharacters(in: .whitespaces),
            skills: skills,
            shortBio: shortBio.trimmingCharacters(in: .whitespaces),
            profilePhotoURL: profilePhotoURL // Include photo URL
        )
        
        // Validate completeness
        if !profileService.isProfileComplete(profile) {
            errorMessage = "Please fill in all required fields."
            debugLog("ProfileSetupView: profile incomplete")
            return
        }
        
        // Save
        isSaving = true
        profileService.saveProfile(profile)
        // ProfileService will set profileSaveComplete=true, triggering ContentView to re-check
        isSaving = false
        debugLog("ProfileSetupView: profile save initiated for clerk_user_id: \(user.clerkId)")
    }
}

#Preview {
    ProfileSetupView()
}
