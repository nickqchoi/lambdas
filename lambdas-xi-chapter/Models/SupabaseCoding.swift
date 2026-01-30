//
//  SupabaseCoding.swift
//  lambdas-xi-chapter
//
//  CodingKeys and custom Codable for Supabase/PostgREST snake_case columns.
//  .cursorrules: comments for readability.
//

import Foundation

// MARK: - Skill
// DB stores {label, is_predefined} in jsonb; id is generated on decode.
extension Skill: Codable {
    enum SkillCodingKeys: String, CodingKey { case label, is_predefined }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: SkillCodingKeys.self)
        id = UUID()
        label = try c.decode(String.self, forKey: .label)
        isPredefined = try c.decode(Bool.self, forKey: .is_predefined)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: SkillCodingKeys.self)
        try c.encode(label, forKey: .label)
        try c.encode(isPredefined, forKey: .is_predefined)
    }
}

// MARK: - Profile
// Debug: Profile now uses clerk_user_id for Clerk authentication integration
extension Profile: Codable {
    enum ProfileCodingKeys: String, CodingKey {
        case id, clerk_user_id, username, full_name, chapter_class, role_tag, graduation_year, major_or_industry
        case skills, short_bio, profile_photo_url, created_at, updated_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ProfileCodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        // Debug: clerk_user_id is the Clerk user ID (format: user_xxxxx)
        clerkUserId = try c.decodeIfPresent(String.self, forKey: .clerk_user_id) ?? ""
        username = try c.decodeIfPresent(String.self, forKey: .username) ?? ""
        fullName = try c.decode(String.self, forKey: .full_name)
        chapterClass = try c.decode(String.self, forKey: .chapter_class)
        roleTag = try c.decode(RoleTag.self, forKey: .role_tag)
        graduationYear = try c.decode(String.self, forKey: .graduation_year)
        majorOrIndustry = try c.decode(String.self, forKey: .major_or_industry)
        skills = try c.decode([Skill].self, forKey: .skills)
        shortBio = try c.decode(String.self, forKey: .short_bio)
        profilePhotoURL = try c.decodeIfPresent(String.self, forKey: .profile_photo_url)
        createdAt = try c.decode(Date.self, forKey: .created_at)
        updatedAt = try c.decode(Date.self, forKey: .updated_at)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: ProfileCodingKeys.self)
        try c.encode(id, forKey: .id)
        // Debug: clerk_user_id must be set for RLS policies to work
        try c.encode(clerkUserId, forKey: .clerk_user_id)
        try c.encode(username, forKey: .username)
        try c.encode(fullName, forKey: .full_name)
        try c.encode(chapterClass, forKey: .chapter_class)
        try c.encode(roleTag, forKey: .role_tag)
        try c.encode(graduationYear, forKey: .graduation_year)
        try c.encode(majorOrIndustry, forKey: .major_or_industry)
        try c.encode(skills, forKey: .skills)
        try c.encode(shortBio, forKey: .short_bio)
        try c.encodeIfPresent(profilePhotoURL, forKey: .profile_photo_url)
        try c.encode(createdAt, forKey: .created_at)
        try c.encode(updatedAt, forKey: .updated_at)
    }
}

// MARK: - Bounty
// Debug: Bounty now uses clerk_creator_id for Clerk authentication integration
extension Bounty: Codable {
    enum BountyCodingKeys: String, CodingKey {
        case id, title, description, skill_tags, estimated_effort, deadline
        case creator_id, clerk_creator_id, status, accepted_applicant_id, created_at, updated_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: BountyCodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decode(String.self, forKey: .description)
        skillTags = try c.decode([Skill].self, forKey: .skill_tags)
        estimatedEffort = try c.decodeIfPresent(EstimatedEffort.self, forKey: .estimated_effort)
        deadline = try c.decodeIfPresent(Date.self, forKey: .deadline)
        creatorId = try c.decode(UUID.self, forKey: .creator_id)
        // Debug: clerk_creator_id is the Clerk user ID for RLS
        clerkCreatorId = try c.decodeIfPresent(String.self, forKey: .clerk_creator_id) ?? ""
        status = try c.decode(BountyStatus.self, forKey: .status)
        acceptedApplicantId = try c.decodeIfPresent(UUID.self, forKey: .accepted_applicant_id)
        createdAt = try c.decode(Date.self, forKey: .created_at)
        updatedAt = try c.decode(Date.self, forKey: .updated_at)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: BountyCodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(description, forKey: .description)
        try c.encode(skillTags, forKey: .skill_tags)
        try c.encodeIfPresent(estimatedEffort, forKey: .estimated_effort)
        try c.encodeIfPresent(deadline, forKey: .deadline)
        try c.encode(creatorId, forKey: .creator_id)
        // Debug: clerk_creator_id must be set for RLS policies
        try c.encode(clerkCreatorId, forKey: .clerk_creator_id)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(acceptedApplicantId, forKey: .accepted_applicant_id)
        try c.encode(createdAt, forKey: .created_at)
        try c.encode(updatedAt, forKey: .updated_at)
    }
}

// MARK: - BountyApplication
// Debug: BountyApplication now uses clerk_applicant_id for Clerk authentication integration
extension BountyApplication: Codable {
    enum BountyApplicationCodingKeys: String, CodingKey {
        case id, bounty_id, applicant_id, clerk_applicant_id, message, status, applied_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: BountyApplicationCodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        bountyId = try c.decode(UUID.self, forKey: .bounty_id)
        applicantId = try c.decode(UUID.self, forKey: .applicant_id)
        // Debug: clerk_applicant_id is the Clerk user ID for RLS
        clerkApplicantId = try c.decodeIfPresent(String.self, forKey: .clerk_applicant_id) ?? ""
        message = try c.decodeIfPresent(String.self, forKey: .message)
        status = try c.decode(ApplicationStatus.self, forKey: .status)
        appliedAt = try c.decode(Date.self, forKey: .applied_at)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: BountyApplicationCodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(bountyId, forKey: .bounty_id)
        try c.encode(applicantId, forKey: .applicant_id)
        // Debug: clerk_applicant_id must be set for RLS policies
        try c.encode(clerkApplicantId, forKey: .clerk_applicant_id)
        try c.encodeIfPresent(message, forKey: .message)
        try c.encode(status, forKey: .status)
        try c.encode(appliedAt, forKey: .applied_at)
    }
}

// MARK: - Chat
// chats table has id, bounty_id, created_at, updated_at, last_message_at.
// participantIds come from chat_participants; service fetches and sets.
extension Chat: Codable {
    enum ChatCodingKeys: String, CodingKey {
        case id, bounty_id, created_at, updated_at, last_message_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ChatCodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        participantIds = []  // Populated from chat_participants by service
        clerkParticipantIds = []  // Populated from chat_participants by service
        bountyId = try c.decodeIfPresent(UUID.self, forKey: .bounty_id)
        createdAt = try c.decode(Date.self, forKey: .created_at)
        updatedAt = try c.decode(Date.self, forKey: .updated_at)
        lastMessageAt = try c.decodeIfPresent(Date.self, forKey: .last_message_at)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: ChatCodingKeys.self)
        try c.encode(id, forKey: .id)
        // participantIds stored in chat_participants table, not encoded here
        try c.encodeIfPresent(bountyId, forKey: .bounty_id)
        try c.encode(createdAt, forKey: .created_at)
        try c.encode(updatedAt, forKey: .updated_at)
        try c.encodeIfPresent(lastMessageAt, forKey: .last_message_at)
    }
}

// MARK: - Message
// Debug: Message now uses clerk_sender_id for Clerk authentication integration
// Debug: Added image_url for photo attachments
extension Message: Codable {
    enum MessageCodingKeys: String, CodingKey {
        case id, chat_id, sender_id, clerk_sender_id, body, image_url, sent_at, message_type, metadata
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: MessageCodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        chatId = try c.decode(UUID.self, forKey: .chat_id)
        senderId = try c.decode(UUID.self, forKey: .sender_id)
        // Debug: clerk_sender_id is the Clerk user ID for RLS
        clerkSenderId = try c.decodeIfPresent(String.self, forKey: .clerk_sender_id) ?? ""
        body = try c.decode(String.self, forKey: .body)
        // Debug: image_url is optional, from Supabase Storage
        imageURL = try c.decodeIfPresent(URL.self, forKey: .image_url)
        sentAt = try c.decode(Date.self, forKey: .sent_at)
        // Debug: decode type, default to text if missing
        type = try c.decodeIfPresent(MessageType.self, forKey: .message_type) ?? .text
        // Debug: decode metadata
        metadata = try c.decodeIfPresent([String: String].self, forKey: .metadata)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: MessageCodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(chatId, forKey: .chat_id)
        try c.encode(senderId, forKey: .sender_id)
        // Debug: clerk_sender_id must be set for RLS policies
        try c.encode(clerkSenderId, forKey: .clerk_sender_id)
        try c.encode(body, forKey: .body)
        // Debug: Only encode image_url if present
        try c.encodeIfPresent(imageURL, forKey: .image_url)
        try c.encode(sentAt, forKey: .sent_at)
        // Debug: encode type
        try c.encode(type, forKey: .message_type)
        // Debug: encode metadata
        try c.encodeIfPresent(metadata, forKey: .metadata)
    }
}

// MARK: - NewsPost
extension NewsPost: Codable {
    enum NewsPostCodingKeys: String, CodingKey {
        case id, title, body, image_url, pdf_url, author_name, published_at, created_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: NewsPostCodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        body = try c.decodeIfPresent(String.self, forKey: .body)
        imageURL = try c.decodeIfPresent(String.self, forKey: .image_url)
        pdfURL = try c.decodeIfPresent(String.self, forKey: .pdf_url)
        authorName = try c.decodeIfPresent(String.self, forKey: .author_name)
        publishedAt = try c.decode(Date.self, forKey: .published_at)
        createdAt = try c.decode(Date.self, forKey: .created_at)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: NewsPostCodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(body, forKey: .body)
        try c.encodeIfPresent(imageURL, forKey: .image_url)
        try c.encodeIfPresent(pdfURL, forKey: .pdf_url)
        try c.encodeIfPresent(authorName, forKey: .author_name)
        try c.encode(publishedAt, forKey: .published_at)
        try c.encode(createdAt, forKey: .created_at)
    }
}
