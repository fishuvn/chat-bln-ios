import SwiftUI

struct ConversationsListView: View {
    @Bindable var settings: AppSettings
    @Bindable var authViewModel: AuthViewModel
    @Bindable var chatStore: ChatStoreViewModel

    @State private var searchText: String = ""
    @State private var showNewConversationSheet: Bool = false

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
            Group {
                if chatStore.isLoadingConversations && chatStore.conversations.isEmpty {
                    ProgressView("Đang tải danh sách trò chuyện...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredConversations.isEmpty {
                    emptyConversationsView
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
                    }
                    .listStyle(.plain)
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
                    realtimeStatusBadge
                }
                ToolbarItem(placement: .topBarTrailing) {
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
                    chatStore: chatStore
                )
            }
        }
    }

    private var realtimeStatusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(chatStore.isRealtimeConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(chatStore.isRealtimeConnected ? "Trực tuyến" : "Đang nối lại")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var emptyConversationsView: some View {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ContentUnavailableView {
                Label("Chưa có cuộc trò chuyện nào", systemImage: "bubble.left.and.bubble.right")
            } description: {
                Text("Bắt đầu nhắn tin riêng với bạn bè hoặc tạo nhóm trò chuyện mới.")
            } actions: {
                Button {
                    showNewConversationSheet = true
                } label: {
                    Label("Tạo cuộc trò chuyện", systemImage: "plus.bubble.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.chatBLNPrimary)
            }
        }
    }
}

private struct ConversationRowView: View {
    let item: ConversationItemResponse
    let currentUsername: String
    let unreadCount: Int
    let avatarURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(
                name: item.displayName,
                avatarURL: avatarURL,
                size: 52,
                isGroup: item.isGroup,
                isOnline: item.isGroup ? nil : (item.isOnline ?? false)
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
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

                HStack(spacing: 8) {
                    Text(previewLine)
                        .font(.subheadline)
                        .fontWeight(unreadCount > 0 ? .medium : .regular)
                        .foregroundStyle(unreadCount > 0 ? .primary : .secondary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

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
