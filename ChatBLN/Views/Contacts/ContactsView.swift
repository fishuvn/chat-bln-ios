import SwiftUI

struct ContactsView: View {
    @Bindable var settings: AppSettings
    @Bindable var chatStore: ChatStoreViewModel

    @State private var searchText: String = ""
    @State private var showAddFriendSheet: Bool = false
    @State private var friendPendingUnfriend: FriendResponse?
    @State private var unfriendError: String?

    private var onlineFriends: [FriendResponse] {
        filteredFriends.filter { $0.isOnline == true }
    }

    private var offlineFriends: [FriendResponse] {
        filteredFriends.filter { $0.isOnline != true }
    }

    private var filteredFriends: [FriendResponse] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else {
            return chatStore.friends
        }
        return chatStore.friends.filter { friend in
            friend.displayName.lowercased().contains(keyword) ||
            friend.username.lowercased().contains(keyword)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if chatStore.isLoadingFriends && chatStore.friends.isEmpty {
                    skeletonContactsList
                } else if filteredFriends.isEmpty {
                    emptyContactsState
                } else {
                    List {
                        if let unfriendError {
                            Section {
                                Label(unfriendError, systemImage: "exclamationmark.triangle.fill")
                                    .font(.footnote)
                                    .foregroundStyle(Color(.systemRed))
                            }
                        }

                        if !onlineFriends.isEmpty {
                            Section {
                                ForEach(onlineFriends) { friend in
                                    friendRow(friend)
                                }
                            } header: {
                                Text("Đang hoạt động (\(onlineFriends.count))")
                                    .monospacedDigit()
                            }
                        }

                        if !offlineFriends.isEmpty {
                            Section {
                                ForEach(offlineFriends) { friend in
                                    friendRow(friend)
                                }
                            } header: {
                                Text("Bạn bè (\(offlineFriends.count))")
                                    .monospacedDigit()
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Danh bạ")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Tìm bạn bè theo tên hoặc @username"
            )
            .refreshable {
                await chatStore.loadFriends()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddFriendSheet = true
                    } label: {
                        Label("Kết bạn", systemImage: "person.badge.plus")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Tìm và thêm bạn bè")
                }
            }
            .alert(
                "Hủy kết bạn?",
                isPresented: Binding(
                    get: { friendPendingUnfriend != nil },
                    set: { if !$0 { friendPendingUnfriend = nil } }
                ),
                presenting: friendPendingUnfriend
            ) { target in
                Button("Huỷ", role: .cancel) {
                    friendPendingUnfriend = nil
                }
                Button("Hủy kết bạn", role: .destructive) {
                    friendPendingUnfriend = nil
                    Task {
                        do {
                            unfriendError = nil
                            try await chatStore.unfriend(userId: target.id)
                        } catch {
                            unfriendError = error.localizedDescription
                        }
                    }
                }
            } message: { target in
                Text("Hủy kết bạn với \"\(target.displayName)\"? Hai bạn sẽ trở về trạng thái chưa kết bạn và có thể kết bạn lại bất cứ lúc nào.")
            }
            .sheet(isPresented: $showAddFriendSheet) {
                AddFriendSheet(
                    settings: settings,
                    chatStore: chatStore
                )
            }
        }
    }

    private var skeletonContactsList: some View {
        List(0..<5, id: \.self) { _ in
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Trần Hoàng Minh")
                        .font(.body.weight(.medium))
                    Text("@tranminh · Trực tuyến")
                        .font(.caption)
                }
            }
            .padding(.vertical, 2)
            .redacted(reason: .placeholder)
        }
        .listStyle(.insetGrouped)
        .allowsHitTesting(false)
        .accessibilityLabel("Đang tải danh bạ bạn bè")
    }

    private func friendRow(_ friend: FriendResponse) -> some View {
        let statusLabel = ChatDateFormatter.formatPresenceStatus(
            isOnline: friend.isOnline,
            presenceStatus: friend.presenceStatus,
            lastSeen: friend.lastSeen
        )
        let statusSymbol = ChatDateFormatter.presenceSymbolName(
            isOnline: friend.isOnline,
            presenceStatus: friend.presenceStatus
        )
        let statusTint = ChatDateFormatter.presenceTintColor(
            isOnline: friend.isOnline,
            presenceStatus: friend.presenceStatus
        )

        return HStack(spacing: 8) {
            Button {
                Task {
                    _ = await chatStore.startOrOpenPrivateChat(with: friend)
                }
            } label: {
                HStack(spacing: 12) {
                    AvatarView(
                        name: friend.displayName,
                        avatarURL: settings.resolveAssetURL(friend.avatarUrl),
                        size: 46,
                        isOnline: friend.isOnline ?? false,
                        presenceStatus: friend.presenceStatus
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(friend.displayName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        HStack(spacing: 4) {
                            Text("@\(friend.username)")
                                .foregroundStyle(.secondary)
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Image(systemName: statusSymbol)
                                .foregroundStyle(statusTint)
                            Text(statusLabel)
                                .foregroundStyle(statusTint)
                        }
                        .font(.caption)
                        .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "bubble.right")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.chatBLNPrimary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Mở cuộc trò chuyện riêng")

            Button(role: .destructive) {
                friendPendingUnfriend = friend
            } label: {
                Image(systemName: "person.badge.minus")
                    .font(.subheadline)
                    .foregroundStyle(Color(.systemRed))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Hủy kết bạn với \(friend.displayName)")
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                friendPendingUnfriend = friend
            } label: {
                Label("Hủy kết bạn", systemImage: "person.badge.minus")
            }
        }
        .contextMenu {
            Button {
                Task {
                    _ = await chatStore.startOrOpenPrivateChat(with: friend)
                }
            } label: {
                Label("Nhắn tin", systemImage: "bubble.right")
            }

            Button(role: .destructive) {
                friendPendingUnfriend = friend
            } label: {
                Label("Hủy kết bạn", systemImage: "person.badge.minus")
            }
        }
    }

    @ViewBuilder
    private var emptyContactsState: some View {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ContentUnavailableView {
                Label("Danh bạ đang trống", systemImage: "person.2")
            } description: {
                Text("Tìm kiếm bạn bè bằng tên hiển thị hoặc @username để bắt đầu kết nối.")
            } actions: {
                Button {
                    showAddFriendSheet = true
                } label: {
                    Label("Thêm bạn bè", systemImage: "person.badge.plus")
                        .frame(minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(.chatBLNPrimary)
            }
        }
    }
}
