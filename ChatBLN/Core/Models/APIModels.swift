import Foundation

// MARK: - Health & Generic Responses

struct HealthResponse: Codable, Hashable, Sendable {
    let status: String
    let message: String?
}

struct LogoutResponse: Codable, Hashable, Sendable {
    let status: String?
}

struct DeleteConversationResponse: Codable, Hashable, Sendable {
    let deleted: Bool?
    let conversationId: Int64?
}

struct UnfriendResponse: Codable, Hashable, Sendable {
    let unfriended: Bool?
    let targetUserId: Int64?
}

struct CancelFriendRequestResponse: Codable, Hashable, Sendable {
    let cancelled: Bool?
    let friendshipId: Int64?
}

struct FriendshipEventDto: Codable, Hashable, Sendable {
    let type: String?
    let actorUserId: Int64?
    let targetUserId: Int64?
}

struct GroupMemberDto: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let username: String
    let fullName: String?
    var avatarUrl: String?
    let role: String?
    var isOnline: Bool?
    var lastSeen: String?
    let joinedAt: String?

    var displayName: String {
        let trimmed = fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? username : trimmed
    }

    var isAdmin: Bool {
        (role ?? "").uppercased() == "ADMIN"
    }
}

struct DeleteMessagesRequest: Codable, Hashable, Sendable {
    let messageIds: [Int64]
    let mode: String
}

struct DeleteMessagesResponse: Codable, Hashable, Sendable {
    let conversationId: Int64
    let mode: String?
    let deletedIds: [Int64]
    let lastMessage: String?
    let lastMessageSenderName: String?
    let lastMessageSenderUsername: String?
    let lastMessageTime: String?
}

struct APIErrorResponse: Codable, Hashable, Sendable {
    let status: Int?
    let error: String?
    let message: String?
}

struct EmptyRequestBody: Codable, Hashable, Sendable {}

// MARK: - Auth DTOs

struct LoginRequest: Codable, Hashable, Sendable {
    let username: String
    let password: String
}

struct RegisterRequest: Codable, Hashable, Sendable {
    let username: String
    let password: String
    let fullName: String
    let email: String?
    let phone: String?
    let gender: String?
    let dob: String?
    let bio: String?
}

struct AuthResponse: Codable, Hashable, Sendable {
    let id: Int64
    let username: String
    let fullName: String?
    let token: String
    let tokenType: String?
}

// MARK: - User Profile & Search DTOs

struct UserProfileResponse: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let username: String
    var fullName: String?
    var email: String?
    var phone: String?
    var gender: String?
    var dob: String?
    var bio: String?
    var avatarUrl: String?
    var isOnline: Bool?
    var lastSeen: String?

    var displayName: String {
        let trimmed = fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? username : trimmed
    }
}

struct UpdateProfileRequest: Codable, Hashable, Sendable {
    let fullName: String?
    let email: String?
    let phone: String?
    let gender: String?
    let dob: String?
    let bio: String?
    let avatarUrl: String?
}

struct UserSearchResponse: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let username: String
    let fullName: String?
    let avatarUrl: String?
    var isOnline: Bool?
    var isFriend: Bool?
    var friendshipStatus: String?

    var displayName: String {
        let trimmed = fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? username : trimmed
    }
}

// MARK: - Conversation DTOs

struct ConversationItemResponse: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    var name: String?
    let type: String
    var avatarUrl: String?
    var isOnline: Bool?
    let targetUserId: Int64?
    var targetUsername: String?
    var email: String?
    var phone: String?
    var gender: String?
    var dob: String?
    var bio: String?
    var lastSeen: String?
    var lastMessage: String?
    var lastMessageSenderName: String?
    var lastMessageSenderUsername: String?
    var lastMessageTime: String?
    var currentUserRole: String? = nil
    var memberCount: Int? = nil
    var members: [GroupMemberDto]? = nil
    var isFriend: Bool? = nil
    var friendshipStatus: String? = nil

    var isGroup: Bool {
        type.uppercased() == "GROUP"
    }

    var isCurrentUserGroupAdmin: Bool {
        (currentUserRole ?? "").uppercased() == "ADMIN"
    }

    var isUnfriendedPrivate: Bool {
        !isGroup && isFriend == false
    }

    var displayName: String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
        if let targetUsername, !targetUsername.isEmpty {
            return targetUsername
        }
        return "Hội thoại #\(id)"
    }
}

struct CreatePrivateConversationRequest: Codable, Hashable, Sendable {
    let targetUserId: Int64
}

struct CreateGroupConversationRequest: Codable, Hashable, Sendable {
    let name: String
    let memberIds: [Int64]
}

struct ConversationResponse: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let name: String?
    let type: String
    let createdById: Int64?
    let createdAt: String?

    var isGroup: Bool {
        type.uppercased() == "GROUP"
    }
}

// MARK: - Message & Upload DTOs

struct SenderDto: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let username: String
    let fullName: String?
    let avatarUrl: String?

    var displayName: String {
        let trimmed = fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? username : trimmed
    }
}

struct MessageDto: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let conversationId: Int64
    let sender: SenderDto
    let content: String
    let attachmentUrl: String?
    let attachmentType: String?
    let attachmentName: String?
    let attachmentSize: String?
    let createdAt: String?

    var normalizedAttachmentKind: String {
        (attachmentType ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    var isAutoAttachmentCaption: Bool {
        guard let attachmentName, !attachmentName.isEmpty else { return false }
        let candidates = [
            "[Hình ảnh] \(attachmentName)",
            "[Video] \(attachmentName)",
            "[Tệp] \(attachmentName)"
        ]
        return candidates.contains(content.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

struct MessageHistoryResponse: Codable, Hashable, Sendable {
    let conversationId: Int64
    let conversationType: String?
    let messages: [MessageDto]
    let size: Int
    let hasMore: Bool
    let oldestMessageId: Int64?
}

struct SendMessageRequest: Codable, Hashable, Sendable {
    let content: String
    let attachmentUrl: String?
    let attachmentType: String?
    let attachmentName: String?
    let attachmentSize: String?

    init(
        content: String,
        attachmentUrl: String? = nil,
        attachmentType: String? = nil,
        attachmentName: String? = nil,
        attachmentSize: String? = nil
    ) {
        self.content = content
        self.attachmentUrl = attachmentUrl
        self.attachmentType = attachmentType
        self.attachmentName = attachmentName
        self.attachmentSize = attachmentSize
    }
}

struct UploadResponse: Codable, Hashable, Sendable {
    let url: String
    let fileName: String
    let fileSize: String
    let contentType: String
    let kind: String
}

// MARK: - Friends & Realtime Presence DTOs

struct FriendResponse: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let username: String
    let fullName: String?
    var avatarUrl: String?
    var isOnline: Bool?
    var lastSeen: String?

    var displayName: String {
        let trimmed = fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? username : trimmed
    }
}

struct FriendshipResponse: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let requesterId: Int64
    let requesterUsername: String?
    let requesterFullName: String?
    let requesterAvatarUrl: String?
    let addresseeId: Int64
    let addresseeUsername: String?
    let addresseeFullName: String?
    let addresseeAvatarUrl: String?
    var status: String
    let createdAt: String?

    var requesterDisplayName: String {
        let trimmed = requesterFullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        if let requesterUsername, !requesterUsername.isEmpty { return requesterUsername }
        return "Người dùng #\(requesterId)"
    }

    var addresseeDisplayName: String {
        let trimmed = addresseeFullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        if let addresseeUsername, !addresseeUsername.isEmpty { return addresseeUsername }
        return "Người nhận #\(addresseeId)"
    }
}

struct SendFriendRequestPayload: Codable, Hashable, Sendable {
    let targetUserId: Int64
}

struct PresenceEvent: Codable, Hashable, Sendable {
    let userId: Int64
    let username: String
    let isOnline: Bool?
    let lastSeen: String?
}
