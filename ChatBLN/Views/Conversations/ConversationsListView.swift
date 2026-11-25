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
                presenceControlHeader

                if let errorBanner = chatStore.errorBanner {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.14))
                }

                Group {
                    if chatStore.isLoadingConversations && chatStore.conversations.isEmpty {
                        ProgressView("Đang tải danh sách trò chuyện...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                                        systemImage: "trash"
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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showJoinGroupSheet = true
                    } label: {
                        Image(systemName: "link.badge.plus")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("Tham gia nhóm bằng link hoặc mã mời")

                    Button {
                        showNewConversationSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .fontWeight(.semibold)
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

    private var effectiveDotColor: Color {
        if settings.presenceMode == .offline {
            return UserPresenceMode.offline.dotColor
        }
        return chatStore.isRealtimeConnected ? settings.presenceMode.dotColor : .orange
    }

    private var effectiveStatusText: String {
        if settings.presenceMode == .offline {
            return "Ẩn trạng thái (Ngoại tuyến)"
        }
        if !chatStore.isRealtimeConnected {
            return "\(settings.presenceMode.shortTitle) · Đang kết nối..."
        }
        return settings.presenceMode.title
    }

    private var presenceControlHeader: some View {
        HStack(spacing: 10) {
            Menu {
                Section("Đặt trạng thái hoạt động của bạn") {
                    ForEach(UserPresenceMode.allCases) { mode in
                        Button {
                            Task {
                                await chatStore.setUserPresenceMode(mode)
                            }
                        } label: {
                            Label(
                                mode.title,
                                systemImage: settings.presenceMode == mode ? "checkmark.circle.fill" : mode.iconName
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
                        Label("Đồng bộ lại hội thoại & kết nối", systemImage: "arrow.clockwise")
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(effectiveDotColor)
                        .frame(width: 10, height: 10)

                    Text(effectiveStatusText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            }
            .accessibilityLabel("Đổi trạng thái hoạt động, hiện tại \(effectiveStatusText)")

            Spacer()

            Button {
                Task {
                    await chatStore.loadConversations()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(Color(.secondarySystemGroupedBackground), in: Circle())
            }
            .disabled(chatStore.isLoadingConversations)
            .accessibilityLabel("Tải lại danh sách cuộc trò chuyện")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var emptyConversationsView: some View {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ContentUnavailableView {
                Label("Chưa có cuộc trò chuyện nào", systemImage: "bubble.left.and.bubble.right")
            } description: {
                Text("Bắt đầu nhắn tin riêng với bạn bè, tạo nhóm mới hoặc tham gia nhóm qua link mời.")
            } actions: {
                VStack(spacing: 10) {
                    Button {
                        showNewConversationSheet = true
                    } label: {
                        Label("Tạo cuộc trò chuyện", systemImage: "plus.bubble.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.chatBLNPrimary)

                    Button {
                        showJoinGroupSheet = true
                    } label: {
                        Label("Tham gia nhóm bằng link / mã mời", systemImage: "link.badge.plus")
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
                size: 52,
                isGroup: item.isGroup,
                isOnline: item.isGroup ? nil : (item.isOnline ?? false),
                presenceStatus: item.presenceStatus
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if item.isGroup, item.groupVisibility != nil {
                        Image(systemName: item.resolvedGroupVisibility.iconName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(item.displayName)
                        .font(.body.weight(unreadCount > 0 ? .bold : .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if let timeLabel = formattedTime, !timeLabel.isEmpty {
                        Text(timeLabel)
                            .font(.caption)
                            .foregroundStyle(unreadCount > 0 ? Color.chatBLNPrimary : .secondary)
                    }
                }

                HStack(spacing: 6) {
                    Text(previewLine)
                        .font(.subheadline)
                        .fontWeight(unreadCount > 0 ? .medium : .regular)
                        .foregroundStyle(unreadCount > 0 ? .primary : .secondary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if pendingJoinCount > 0 {
                        Text("\(pendingJoinCount) chờ duyệt")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.14), in: Capsule())
                    }

                    if unreadCount > 0 {
                        Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.chatBLNPrimary, in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
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
