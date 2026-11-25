import SwiftUI

struct ContactsView: View {
    @Bindable var settings: AppSettings
    @Bindable var chatStore: ChatStoreViewModel

    @State private var searchText: String = ""
    @State private var showAddFriendSheet: Bool = false

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
            .sheet(isPresented: $showAddFriendSheet) {
                AddFriendSheet(
                    settings: settings,
                    chatStore: chatStore
                )
            }
        }
    }

    private func friendRow(_ friend: FriendResponse) -> some View {
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
                    isOnline: friend.isOnline ?? false
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(friend.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("@\(friend.username) • \(ChatDateFormatter.formatPresenceStatus(isOnline: friend.isOnline, lastSeen: friend.lastSeen))")
                        .font(.caption)
                        .foregroundStyle(friend.isOnline == true ? Color.green : .secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "bubble.right.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.chatBLNPrimary)
            }
            .padding(.vertical, 2)
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
