import Foundation
import Observation

enum MainAppTab: Hashable, Sendable {
    case conversations
    case contacts
    case requests
    case profile
}

enum UserFriendshipRelation: Equatable, Sendable {
    case friend
    case sentPending
    case receivedPending(friendshipId: Int64)
    case none
}

@MainActor
@Observable
final class ChatStoreViewModel {
    let settings: AppSettings
    let apiClient: APIClient
    private let stompClient: StompWebSocketClient

    var selectedTab: MainAppTab = .conversations
    var navigationPath: [ConversationItemResponse] = []

    var conversations: [ConversationItemResponse] = []
    var messagesByConversation: [Int64: [MessageDto]] = [:]
    var groupMembersByConversation: [Int64: [GroupMemberDto]] = [:]
    var hasMoreByConversation: [Int64: Bool] = [:]
    var oldestMessageIdByConversation: [Int64: Int64] = [:]
    var unreadCountByConversation: [Int64: Int] = [:]

    var friends: [FriendResponse] = []
    var receivedRequests: [FriendshipResponse] = []
    var sentRequests: [FriendshipResponse] = []

    var isRealtimeConnected: Bool = false
    var isLoadingConversations: Bool = false
    var isLoadingFriends: Bool = false
    var isLoadingRequests: Bool = false
    var loadingMessagesConversationIds: Set<Int64> = []
    var uploadingConversationIds: Set<Int64> = []
    var errorBanner: String?

    private(set) var currentUsername: String = ""
    private var activeConversationId: Int64?

    init(settings: AppSettings, apiClient: APIClient) {
        self.settings = settings
        self.apiClient = apiClient
        self.stompClient = StompWebSocketClient(settings: settings)
        wireRealtimeCallbacks()
    }

    var totalUnreadMessages: Int {
        unreadCountByConversation.values.reduce(0, +)
    }

    func bootstrapSession(token: String, currentUsername: String) async {
        self.currentUsername = currentUsername
        if settings.presenceMode == .offline {
            stompClient.disconnect()
            _ = try? await apiClient.logout()
        } else {
            stompClient.subscribe(topic: "/topic/presence")
            stompClient.subscribe(topic: "/topic/users/\(currentUsername)")
            stompClient.subscribe(topic: "/topic/users/\(currentUsername)/deletions")
            stompClient.subscribe(topic: "/topic/friendships/\(currentUsername)")
            stompClient.connect(token: token)
        }

        async let conversationsLoad: Void = loadConversations()
        async let friendsLoad: Void = loadFriends()
        async let requestsLoad: Void = loadFriendRequests()
        _ = await (conversationsLoad, friendsLoad, requestsLoad)
    }

    func setUserPresenceMode(_ mode: UserPresenceMode) async {
        settings.presenceMode = mode
        if mode == .offline {
            stompClient.disconnect()
            isRealtimeConnected = false
            _ = try? await apiClient.logout()
        } else {
            if !isRealtimeConnected {
                reconnectRealtimeIfAuthenticated()
            }
            await loadConversations()
        }
    }

    func reconnectRealtimeIfAuthenticated() {
        guard let token = KeychainService.readToken(), !token.isEmpty, !currentUsername.isEmpty else {
            return
        }
        guard settings.presenceMode != .offline else {
            stompClient.disconnect()
            isRealtimeConnected = false
            return
        }
        stompClient.disconnect()
        stompClient.subscribe(topic: "/topic/presence")
        stompClient.subscribe(topic: "/topic/users/\(currentUsername)")
        stompClient.subscribe(topic: "/topic/users/\(currentUsername)/deletions")
        stompClient.subscribe(topic: "/topic/friendships/\(currentUsername)")
        if let activeId = activeConversationId {
            stompClient.subscribe(topic: "/topic/conversations/\(activeId)")
        }
        stompClient.connect(token: token)
    }

    func resetSession() {
        stompClient.disconnect()
        conversations = []
        messagesByConversation = [:]
        groupMembersByConversation = [:]
        hasMoreByConversation = [:]
        oldestMessageIdByConversation = [:]
        unreadCountByConversation = [:]
        friends = []
        receivedRequests = []
        sentRequests = []
        navigationPath = []
        selectedTab = .conversations
        activeConversationId = nil
        currentUsername = ""
        isRealtimeConnected = false
        errorBanner = nil
    }

    // MARK: - Conversations

    func loadConversations() async {
        isLoadingConversations = true
        defer { isLoadingConversations = false }

        do {
            let fetched = try await apiClient.getConversations()
            conversations = fetched
            for item in fetched where item.isGroup {
                if let embedded = item.members, !embedded.isEmpty {
                    groupMembersByConversation[item.id] = embedded
                }
            }
            errorBanner = nil
        } catch {
            if conversations.isEmpty {
                errorBanner = error.localizedDescription
            }
        }
    }

    func openConversation(_ conversation: ConversationItemResponse) {
        unreadCountByConversation[conversation.id] = 0
        selectedTab = .conversations
        navigationPath = [conversation]
    }

    func startOrOpenPrivateChat(with friend: FriendResponse) async -> ConversationItemResponse? {
        if let existing = conversations.first(where: { !$0.isGroup && $0.targetUserId == friend.id }) {
            openConversation(existing)
            return existing
        }

        do {
            let created = try await apiClient.createPrivateConversation(targetUserId: friend.id)
            await loadConversations()
            if let matched = conversations.first(where: { $0.id == created.id }) {
                openConversation(matched)
                return matched
            }
            let synthesized = ConversationItemResponse(
                id: created.id,
                name: friend.displayName,
                type: created.type,
                avatarUrl: friend.avatarUrl,
                isOnline: friend.isOnline,
                targetUserId: friend.id,
                targetUsername: friend.username,
                email: nil,
                phone: nil,
                gender: nil,
                dob: nil,
                bio: nil,
                lastSeen: friend.lastSeen,
                lastMessage: nil,
                lastMessageSenderName: nil,
                lastMessageSenderUsername: nil,
                lastMessageTime: created.createdAt
            )
            conversations.insert(synthesized, at: 0)
            openConversation(synthesized)
            return synthesized
        } catch {
            errorBanner = error.localizedDescription
            return nil
        }
    }

    func createGroupChat(name: String, memberIds: [Int64]) async -> ConversationItemResponse? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !memberIds.isEmpty else {
            errorBanner = "Vui lòng nhập tên nhóm và chọn ít nhất 1 thành viên."
            return nil
        }

        do {
            let created = try await apiClient.createGroupConversation(name: trimmedName, memberIds: memberIds)
            await loadConversations()
            if let matched = conversations.first(where: { $0.id == created.id }) {
                openConversation(matched)
                return matched
            }
            let synthesized = ConversationItemResponse(
                id: created.id,
                name: created.name ?? trimmedName,
                type: "GROUP",
                avatarUrl: nil,
                isOnline: nil,
                targetUserId: nil,
                targetUsername: nil,
                email: nil,
                phone: nil,
                gender: nil,
                dob: nil,
                bio: nil,
                lastSeen: nil,
                lastMessage: nil,
                lastMessageSenderName: nil,
                lastMessageSenderUsername: nil,
                lastMessageTime: created.createdAt
            )
            conversations.insert(synthesized, at: 0)
            openConversation(synthesized)
            return synthesized
        } catch {
            errorBanner = error.localizedDescription
            return nil
        }
    }

    func conversation(for id: Int64) -> ConversationItemResponse? {
        conversations.first(where: { $0.id == id })
    }

    func deleteConversation(conversationId: Int64) async throws {
        _ = try await apiClient.deleteConversation(conversationId: conversationId)
        stompClient.unsubscribe(topic: "/topic/conversations/\(conversationId)")
        conversations.removeAll { $0.id == conversationId }
        messagesByConversation.removeValue(forKey: conversationId)
        groupMembersByConversation.removeValue(forKey: conversationId)
        hasMoreByConversation.removeValue(forKey: conversationId)
        oldestMessageIdByConversation.removeValue(forKey: conversationId)
        unreadCountByConversation.removeValue(forKey: conversationId)
        if activeConversationId == conversationId {
            activeConversationId = nil
        }
        navigationPath.removeAll { $0.id == conversationId }
    }

    func deleteMessages(
        conversationId: Int64,
        messageIds: [Int64],
        mode: String
    ) async throws {
        let res = try await apiClient.deleteMessages(
            conversationId: conversationId,
            messageIds: messageIds,
            mode: mode
        )
        handleIncomingMessageDeletion(res)
    }

    // MARK: - Messages & Attachments

    func enterChatRoom(conversationId: Int64) async {
        activeConversationId = conversationId
        unreadCountByConversation[conversationId] = 0
        stompClient.subscribe(topic: "/topic/conversations/\(conversationId)")
        if conversation(for: conversationId)?.isGroup == true {
            Task {
                await loadConversationMembers(conversationId: conversationId)
            }
        }
        await loadInitialMessages(conversationId: conversationId)
    }

    func loadConversationMembers(conversationId: Int64) async {
        do {
            let members = try await apiClient.getConversationMembers(conversationId: conversationId)
            groupMembersByConversation[conversationId] = members
            if let idx = conversations.firstIndex(where: { $0.id == conversationId }) {
                conversations[idx].members = members
                conversations[idx].memberCount = members.count
            }
        } catch {
            // Giữ danh sách sẵn có nếu mất mạng tạm thời
        }
    }

    func leaveChatRoom(conversationId: Int64) {
        if activeConversationId == conversationId {
            activeConversationId = nil
        }
        stompClient.unsubscribe(topic: "/topic/conversations/\(conversationId)")
    }

    func loadInitialMessages(conversationId: Int64) async {
        loadingMessagesConversationIds.insert(conversationId)
        defer { loadingMessagesConversationIds.remove(conversationId) }

        do {
            let history = try await apiClient.getMessages(conversationId: conversationId, limit: 30)
            messagesByConversation[conversationId] = history.messages
            hasMoreByConversation[conversationId] = history.hasMore
            if let oldest = history.oldestMessageId {
                oldestMessageIdByConversation[conversationId] = oldest
            } else {
                oldestMessageIdByConversation.removeValue(forKey: conversationId)
            }
        } catch {
            errorBanner = error.localizedDescription
        }
    }

    func loadOlderMessages(conversationId: Int64) async {
        guard hasMoreByConversation[conversationId] == true,
              let oldestId = oldestMessageIdByConversation[conversationId],
              !loadingMessagesConversationIds.contains(conversationId) else {
            return
        }

        loadingMessagesConversationIds.insert(conversationId)
        defer { loadingMessagesConversationIds.remove(conversationId) }

        do {
            let history = try await apiClient.getMessages(
                conversationId: conversationId,
                before: oldestId,
                limit: 30
            )
            var current = messagesByConversation[conversationId] ?? []
            let existingIds = Set(current.map(\.id))
            let newOlder = history.messages.filter { !existingIds.contains($0.id) }
            current.insert(contentsOf: newOlder, at: 0)
            messagesByConversation[conversationId] = current
            hasMoreByConversation[conversationId] = history.hasMore
            if let nextOldest = history.oldestMessageId {
                oldestMessageIdByConversation[conversationId] = nextOldest
            } else {
                oldestMessageIdByConversation.removeValue(forKey: conversationId)
            }
        } catch {
            errorBanner = error.localizedDescription
        }
    }

    func sendTextMessage(conversationId: Int64, text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let extractedLink = MarkdownMessageFormatter.extractFirstLink(from: trimmed)
        let payload = SendMessageRequest(
            content: trimmed,
            attachmentUrl: extractedLink?.url.absoluteString,
            attachmentType: extractedLink != nil ? "LINK" : nil,
            attachmentName: extractedLink?.label,
            attachmentSize: nil
        )

        let sent = try await apiClient.sendMessage(conversationId: conversationId, payload: payload)
        appendMessageAndPromoteConversation(sent)
    }

    func uploadAndSendAttachment(
        conversationId: Int64,
        data: Data,
        fileName: String,
        mimeType: String,
        caption: String
    ) async throws {
        uploadingConversationIds.insert(conversationId)
        defer { uploadingConversationIds.remove(conversationId) }

        let uploaded = try await apiClient.uploadFile(data: data, fileName: fileName, mimeType: mimeType)
        let prefix: String
        switch uploaded.kind.uppercased() {
        case "IMAGE":
            prefix = "[Hình ảnh]"
        case "VIDEO":
            prefix = "[Video]"
        default:
            prefix = "[Tệp]"
        }

        let cleanCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalContent = cleanCaption.isEmpty ? "\(prefix) \(uploaded.fileName)" : cleanCaption

        let payload = SendMessageRequest(
            content: finalContent,
            attachmentUrl: uploaded.url,
            attachmentType: uploaded.kind,
            attachmentName: uploaded.fileName,
            attachmentSize: uploaded.fileSize
        )

        let sent = try await apiClient.sendMessage(conversationId: conversationId, payload: payload)
        appendMessageAndPromoteConversation(sent)
    }

    // MARK: - Friends & Requests

    func loadFriends() async {
        isLoadingFriends = true
        defer { isLoadingFriends = false }
        if let list = try? await apiClient.getFriends() {
            friends = list
        }
    }

    func loadFriendRequests() async {
        isLoadingRequests = true
        defer { isLoadingRequests = false }

        async let receivedTask = apiClient.getReceivedFriendRequests()
        async let sentTask = apiClient.getSentFriendRequests()

        if let received = try? await receivedTask {
            receivedRequests = received.filter { $0.status.uppercased() == "PENDING" }
        }
        if let sent = try? await sentTask {
            sentRequests = sent.filter { $0.status.uppercased() == "PENDING" }
        }
    }

    func searchUsers(keyword: String) async throws -> [UserSearchResponse] {
        let clean = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^@+", with: "", options: .regularExpression)
        guard !clean.isEmpty else { return [] }
        let results = try await apiClient.searchUsers(keyword: clean)
            .filter { $0.username.lowercased() != currentUsername.lowercased() }

        let clearedUserIds = Set(
            results
                .filter { $0.isFriend != true && ($0.friendshipStatus ?? "").uppercased() != "PENDING" }
                .map(\.id)
        )
        if !clearedUserIds.isEmpty {
            sentRequests.removeAll { clearedUserIds.contains($0.addresseeId) }
            receivedRequests.removeAll { clearedUserIds.contains($0.requesterId) }
        }
        return results
    }

    func friendshipRelation(for user: UserSearchResponse) -> UserFriendshipRelation {
        if user.isFriend == true || user.friendshipStatus?.uppercased() == "ACCEPTED" {
            return .friend
        }
        if friends.contains(where: { $0.id == user.id || $0.username.lowercased() == user.username.lowercased() }) {
            return .friend
        }
        if let incoming = receivedRequests.first(where: { $0.requesterId == user.id }) {
            return .receivedPending(friendshipId: incoming.id)
        }
        if user.friendshipStatus?.uppercased() == "PENDING" ||
            sentRequests.contains(where: { $0.addresseeId == user.id }) {
            return .sentPending
        }
        return .none
    }

    func sendFriendRequest(to userId: Int64) async throws {
        let created = try await apiClient.sendFriendRequest(targetUserId: userId)
        if !sentRequests.contains(where: { $0.id == created.id }) {
            sentRequests.insert(created, at: 0)
        }
        for idx in conversations.indices {
            if !conversations[idx].isGroup && conversations[idx].targetUserId == userId {
                conversations[idx].friendshipStatus = "PENDING"
            }
        }
    }

    func unfriend(userId: Int64) async throws {
        _ = try await apiClient.unfriend(targetUserId: userId)
        friends.removeAll { $0.id == userId }
        receivedRequests.removeAll { $0.requesterId == userId }
        sentRequests.removeAll { $0.addresseeId == userId }
        for idx in conversations.indices {
            if !conversations[idx].isGroup && conversations[idx].targetUserId == userId {
                conversations[idx].isFriend = false
                conversations[idx].friendshipStatus = nil
            }
        }
    }

    func acceptFriendRequest(_ friendshipId: Int64) async throws {
        _ = try await apiClient.acceptFriendRequest(friendshipId: friendshipId)
        receivedRequests.removeAll { $0.id == friendshipId }
        await loadFriends()
        await loadConversations()
    }

    func rejectFriendRequest(_ friendshipId: Int64) async throws {
        _ = try await apiClient.rejectFriendRequest(friendshipId: friendshipId)
        receivedRequests.removeAll { $0.id == friendshipId }
    }

    // MARK: - Realtime Event Handling

    private func wireRealtimeCallbacks() {
        stompClient.onConnectionStateChanged = { [weak self] connected in
            self?.isRealtimeConnected = connected
        }

        stompClient.onMessageReceived = { [weak self] dto in
            self?.handleIncomingRealtimeMessage(dto)
        }

        stompClient.onMessageDeletionReceived = { [weak self] ev in
            self?.handleIncomingMessageDeletion(ev)
        }

        stompClient.onFriendshipReceived = { [weak self] _ in
            guard let self else { return }
            Task {
                async let f: Void = self.loadFriends()
                async let r: Void = self.loadFriendRequests()
                async let c: Void = self.loadConversations()
                _ = await (f, r, c)
            }
        }

        stompClient.onPresenceReceived = { [weak self] event in
            self?.handleIncomingPresence(event)
        }
    }

    private func handleIncomingRealtimeMessage(_ dto: MessageDto) {
        let existedConversation = conversations.contains(where: { $0.id == dto.conversationId })
        appendMessageAndPromoteConversation(dto)

        let isFromMe = dto.sender.username.lowercased() == currentUsername.lowercased()
        if !isFromMe, activeConversationId != dto.conversationId {
            unreadCountByConversation[dto.conversationId, default: 0] += 1
        }

        if !existedConversation {
            Task {
                await loadConversations()
            }
        }
    }

    private func appendMessageAndPromoteConversation(_ dto: MessageDto) {
        var messages = messagesByConversation[dto.conversationId] ?? []
        if !messages.contains(where: { $0.id == dto.id }) {
            messages.append(dto)
            messagesByConversation[dto.conversationId] = messages
        }

        if let index = conversations.firstIndex(where: { $0.id == dto.conversationId }) {
            var updated = conversations.remove(at: index)
            updated.lastMessage = dto.content
            updated.lastMessageSenderName = dto.sender.displayName
            updated.lastMessageSenderUsername = dto.sender.username
            updated.lastMessageTime = dto.createdAt
            conversations.insert(updated, at: 0)
        }
    }

    private func handleIncomingMessageDeletion(_ ev: DeleteMessagesResponse) {
        let idSet = Set(ev.deletedIds)
        if var list = messagesByConversation[ev.conversationId] {
            list.removeAll { idSet.contains($0.id) }
            messagesByConversation[ev.conversationId] = list
        }
        if let index = conversations.firstIndex(where: { $0.id == ev.conversationId }) {
            conversations[index].lastMessage = ev.lastMessage
            conversations[index].lastMessageSenderName = ev.lastMessageSenderName
            conversations[index].lastMessageSenderUsername = ev.lastMessageSenderUsername
            if let lastTime = ev.lastMessageTime {
                conversations[index].lastMessageTime = lastTime
            }
        }
    }

    private func handleIncomingPresence(_ event: PresenceEvent) {
        let onlineFlag = event.isOnline ?? false
        for index in conversations.indices {
            guard !conversations[index].isGroup else { continue }
            let matchesId = conversations[index].targetUserId == event.userId
            let matchesUsername = conversations[index].targetUsername?.lowercased() == event.username.lowercased()
            if matchesId || matchesUsername {
                conversations[index].isOnline = onlineFlag
                if let lastSeen = event.lastSeen {
                    conversations[index].lastSeen = lastSeen
                }
            }
        }

        for index in friends.indices {
            if friends[index].id == event.userId ||
                friends[index].username.lowercased() == event.username.lowercased() {
                friends[index].isOnline = onlineFlag
                if let lastSeen = event.lastSeen {
                    friends[index].lastSeen = lastSeen
                }
            }
        }

        for (convId, var members) in groupMembersByConversation {
            var updatedAny = false
            for idx in members.indices {
                if members[idx].id == event.userId {
                    members[idx].isOnline = onlineFlag
                    if let lastSeen = event.lastSeen {
                        members[idx].lastSeen = lastSeen
                    }
                    updatedAny = true
                }
            }
            if updatedAny {
                groupMembersByConversation[convId] = members
            }
        }
    }
}
