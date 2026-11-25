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
                    ProgressView("Đang tải danh bạ bạn bè...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredFriends.isEmpty {
                    emptyContactsState
                } else {
                    List {
                        if let unfriendError {
                            Section {
                                Text(unfriendError)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }

                        if !onlineFriends.isEmpty {
                            Section("Đang hoạt động (\(onlineFriends.count))") {
                                ForEach(onlineFriends) { friend in
                                    friendRow(friend)
                                }
                            }
                        }

                        if !offlineFriends.isEmpty {
                            Section("Bạn bè (\(offlineFriends.count))") {
                                ForEach(offlineFriends) { friend in
                                    friendRow(friend)
                                }
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
                    }
                    .accessibilityLabel("Tìm và thêm bạn bè")
                }
            }
            .confirmationDialog(
                friendPendingUnfriend.map {
                    "Hủy kết bạn với \"\($0.displayName)\"? Hai bạn sẽ trở về trạng thái chưa kết bạn và có thể kết bạn lại bất cứ lúc nào."
                } ?? "Hủy kết bạn?",
                isPresented: Binding(
                    get: { friendPendingUnfriend != nil },
                    set: { if !$0 { friendPendingUnfriend = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let target = friendPendingUnfriend {
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
                }
                Button("Đóng", role: .cancel) {
                    friendPendingUnfriend = nil
                }
            }
            .sheet(isPresented: $showAddFriendSheet) {
                AddFriendSheet(
                    settings: settings,
                    chatStore: chatStore
                )
            }
        }
    }

    private func friendRow(_ friend: FriendResponse) -> some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    _ = await chatStore.startOrOpenPrivateChat(with: friend)
                }
            } label: {
                HStack(spacing: 12) {
                    AvatarView(
                        name: friend.displayName,
                        avatarURL: settings.resolveAssetURL(friend.avatarUrl),
                        size: 48,
                        isOnline: friend.isOnline ?? false,
                        presenceStatus: friend.presenceStatus
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(friend.displayName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("@\(friend.username) • \(ChatDateFormatter.formatPresenceStatus(isOnline: friend.isOnline, presenceStatus: friend.presenceStatus, lastSeen: friend.lastSeen))")
                            .font(.caption)
                            .foregroundStyle(ChatDateFormatter.presenceTintColor(isOnline: friend.isOnline, presenceStatus: friend.presenceStatus))
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "bubble.right.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.chatBLNPrimary)
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                friendPendingUnfriend = friend
            } label: {
                Image(systemName: "person.badge.minus")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(8)
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
                }
                .buttonStyle(.borderedProminent)
                .tint(.chatBLNPrimary)
            }
        }
    }
}
