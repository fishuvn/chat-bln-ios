import SwiftUI

struct ConversationsListView: View {
    @Bindable var settings: AppSettings
    @Bindable var authViewModel: AuthViewModel
    @Bindable var chatStore: ChatStoreViewModel

    @State private var searchText: String = ""
    @State private var showNewConversationSheet: Bool = false
    @State private var showJoinGroupSheet: Bool = false

    private var filteredConversations: [ConversationItemResponse] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else {
            return chatStore.conversations
        }
        return chatStore.conversations.filter { item in
            item.displayName.lowercased().contains(keyword) ||
            (item.lastMessage?.lowercased().contains(keyword) == true) ||
            (item.targetUsername?.lowercased().contains(keyword) == true)
        }
    }

    var body: some View {
        NavigationStack(path: $chatStore.navigationPath) {
            VStack(spacing: 0) {
                if let errorBanner = chatStore.errorBanner {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color(.systemOrange))
                            .accessibilityHidden(true)

                        Text(errorBanner)
                            .font(.footnote)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Spacer()

                        Button("Tải lại") {
                            Task {
                                await chatStore.loadConversations()
                            }
                        }
                        .font(.footnote.weight(.semibold))
                        .frame(minHeight: 44)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemGroupedBackground))
                    .overlay(alignment: .bottom) {
                        Divider()
                    }
                }

                Group {
                    if chatStore.isLoadingConversations && chatStore.conversations.isEmpty {
                        skeletonConversationList
                    } else if filteredConversations.isEmpty {
                        emptyConversationsView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(filteredConversations) { item in
                            NavigationLink(value: item) {
                                ConversationRowView(
                                    item: item,
                                    currentUsername: chatStore.currentUsername,
                                    unreadCount: chatStore.unreadCountByConversation[item.id, default: 0],
                                    avatarURL: settings.resolveAssetURL(item.avatarUrl)
                                )
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task {
                                        try? await chatStore.deleteConversation(conversationId: item.id)
                                    }
                                } label: {
                                    Label(
                                        item.isGroup
                                            ? (item.isCurrentUserGroupAdmin ? "Giải tán" : "Rời nhóm")
                                            : "Xóa",
                                        systemImage: item.isGroup && !item.isCurrentUserGroupAdmin
                                            ? "rectangle.portrait.and.arrow.right"
                                            : "trash"
                                    )
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Đoạn chat")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Tìm cuộc trò chuyện, tin nhắn..."
            )
            .refreshable {
                await chatStore.loadConversations()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    presenceToolbarMenu
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showJoinGroupSheet = true
                    } label: {
                        Image(systemName: "link.badge.plus")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Tham gia nhóm bằng link hoặc mã mời")

                    Button {
                        showNewConversationSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Tạo cuộc trò chuyện mới")
                }
            }
            .navigationDestination(for: ConversationItemResponse.self) { conversation in
                ChatRoomView(
                    conversationId: conversation.id,
                    fallbackConversation: conversation,
                    settings: settings,
                    chatStore: chatStore
                )
            }
            .sheet(isPresented: $showNewConversationSheet) {
                NewConversationSheet(
                    settings: settings,
                    chatStore: chatStore,
                    onRequestJoinByInvite: {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showJoinGroupSheet = true
                        }
                    }
                )
            }
            .sheet(isPresented: $showJoinGroupSheet) {
                JoinGroupSheet(
                    settings: settings,
                    chatStore: chatStore
                )
            }
        }
    }

    // MARK: - Compact Presence Toolbar Menu (Redundant Icon + Color + Text)

    private var effectiveMode: UserPresenceMode {
        settings.presenceMode
    }

    private var presenceToolbarMenu: some View {
        Menu {
            Section("Trạng thái hoạt động của bạn") {
                ForEach(UserPresenceMode.allCases) { mode in
                    Button {
                        Task {
                            await chatStore.setUserPresenceMode(mode)
                        }
                    } label: {
                        Label(
                            mode.title,
                            systemImage: settings.presenceMode == mode ? "checkmark" : mode.iconName
                        )
                    }
                }
            }

            Section {
                Button {
                    Task {
                        chatStore.reconnectRealtimeIfAuthenticated()
                        await chatStore.loadConversations()
                    }
                } label: {
                    Label("Đồng bộ lại kết nối", systemImage: "arrow.clockwise")
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: chatStore.isRealtimeConnected ? effectiveMode.iconName : "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(chatStore.isRealtimeConnected ? effectiveMode.dotColor : Color(.systemOrange))

                Text(chatStore.isRealtimeConnected ? effectiveMode.shortTitle : "Đang kết nối")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minHeight: 36)
            .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .accessibilityLabel("Trạng thái hoạt động")
        .accessibilityValue(chatStore.isRealtimeConnected ? effectiveMode.title : "Đang kết nối lại máy chủ")
    }

    // MARK: - Redacted Skeleton Loader

    private var skeletonConversationList: some View {
        List(0..<6, id: \.self) { _ in
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Nguyễn Văn Minh Anh")
                            .font(.body.weight(.semibold))
                        Spacer()
                        Text("10:42")
                            .font(.caption.monospacedDigit())
                    }
                    Text("Tin nhắn gần nhất đang được tải từ máy chủ...")
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 4)
            .redacted(reason: .placeholder)
        }
        .listStyle(.plain)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Đang tải danh sách cuộc trò chuyện")
    }

    // MARK: - Empty States

    @ViewBuilder
    private var emptyConversationsView: some View {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ContentUnavailableView {
                Label("Chưa có cuộc trò chuyện", systemImage: "bubble.left.and.bubble.right")
            } description: {
                Text("Bắt đầu nhắn tin riêng với bạn bè, tạo nhóm mới hoặc tham gia nhóm qua mã mời.")
            } actions: {
                VStack(spacing: 10) {
                    Button {
                        showNewConversationSheet = true
                    } label: {
                        Label("Tạo cuộc trò chuyện", systemImage: "square.and.pencil")
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.chatBLNPrimary)

                    Button {
                        showJoinGroupSheet = true
                    } label: {
                        Label("Tham gia nhóm bằng mã mời", systemImage: "link.badge.plus")
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

private struct ConversationRowView: View {
    let item: ConversationItemResponse
    let currentUsername: String
    let unreadCount: Int
    let avatarURL: URL?

    private var pendingJoinCount: Int {
        guard item.isGroup, item.canCurrentUserManageGroupRequests else { return 0 }
        return max(0, item.pendingJoinRequestCount ?? 0)
    }

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(
                name: item.displayName,
                avatarURL: avatarURL,
                size: 48,
                isGroup: item.isGroup,
                isOnline: item.isGroup ? nil : (item.isOnline ?? false),
                presenceStatus: item.presenceStatus
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    if item.isGroup, item.groupVisibility != nil {
                        Image(systemName: item.resolvedGroupVisibility.iconName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }

                    Text(item.displayName)
                        .font(.body.weight(unreadCount > 0 ? .semibold : .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if let timeLabel = formattedTime, !timeLabel.isEmpty {
                        Text(timeLabel)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(unreadCount > 0 ? Color.chatBLNPrimary : .secondary)
                    }
                }

                HStack(spacing: 6) {
                    Text(previewLine)
                        .font(.subheadline)
                        .foregroundStyle(unreadCount > 0 ? .primary : .secondary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if pendingJoinCount > 0 {
                        Label("\(pendingJoinCount)", systemImage: "person.crop.circle.badge.clock")
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color(.systemOrange))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color(.systemOrange).opacity(0.14), in: Capsule())
                    }

                    if unreadCount > 0 {
                        Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.chatBLNPrimary, in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts: [String] = []
        if !item.isGroup {
            parts.append(
                ChatDateFormatter.formatPresenceStatus(
                    isOnline: item.isOnline,
                    presenceStatus: item.presenceStatus,
                    lastSeen: item.lastSeen
                )
            )
        }
        if unreadCount > 0 {
            parts.append("\(unreadCount) tin nhắn chưa đọc")
        }
        if pendingJoinCount > 0 {
            parts.append("\(pendingJoinCount) yêu cầu tham gia chờ duyệt")
        }
        return parts.joined(separator: ", ")
    }

    private var formattedTime: String? {
        ChatDateFormatter.formatConversationTime(item.lastMessageTime)
    }

    private var previewLine: String {
        guard let last = item.lastMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
              !last.isEmpty else {
            return item.isGroup ? "Nhóm trò chuyện mới" : "Bắt đầu cuộc trò chuyện"
        }

        if let senderUser = item.lastMessageSenderUsername,
           !currentUsername.isEmpty,
           senderUser.lowercased() == currentUsername.lowercased() {
            return "Bạn: \(last)"
        }

        if item.isGroup,
           let senderName = item.lastMessageSenderName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !senderName.isEmpty {
            return "\(senderName): \(last)"
        }

        return last
    }
}
