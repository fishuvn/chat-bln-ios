import SwiftUI

struct AddFriendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: AppSettings
    @Bindable var chatStore: ChatStoreViewModel

    @State private var searchKeyword: String = ""
    @State private var results: [UserSearchResponse] = []
    @State private var isSearching: Bool = false
    @State private var processingUserIds: Set<Int64> = []
    @State private var statusBanner: String?
    @State private var isBannerError: Bool = false

    private var trimmedKeyword: String {
        searchKeyword
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^@+", with: "", options: .regularExpression)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let statusBanner {
                    HStack(spacing: 8) {
                        Image(systemName: isBannerError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(isBannerError ? Color.red : Color.green)
                        Text(statusBanner)
                            .font(.footnote)
                            .foregroundStyle(isBannerError ? Color.red : Color.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background((isBannerError ? Color.red : Color.green).opacity(0.1))
                }

                // Ẩn hoàn toàn danh sách người dùng hệ thống cho tới khi nhập từ khoá tìm kiếm
                if trimmedKeyword.isEmpty {
                    ContentUnavailableView(
                        "Tìm bạn bè trên Chat BLN",
                        systemImage: "magnifyingglass.circle",
                        description: Text("Nhập tên hiển thị hoặc @username vào ô tìm kiếm phía trên để tra cứu người dùng.")
                    )
                } else if isSearching && results.isEmpty {
                    ProgressView("Đang tìm kiếm người dùng...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: searchKeyword)
                } else {
                    List(results) { user in
                        userSearchRow(user)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .searchable(
                text: $searchKeyword,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Nhập tên hoặc @username..."
            )
            .onSubmit(of: .search) {
                Task {
                    await executeSearch(for: trimmedKeyword)
                }
            }
            .task(id: trimmedKeyword) {
                if trimmedKeyword.isEmpty {
                    results = []
                    isSearching = false
                    return
                }
                isSearching = true
                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled else { return }
                await executeSearch(for: trimmedKeyword)
            }
            .onChange(of: chatStore.sentRequests) { _, _ in
                guard !trimmedKeyword.isEmpty else { return }
                Task {
                    await executeSearch(for: trimmedKeyword)
                }
            }
            .onChange(of: chatStore.friends) { _, _ in
                guard !trimmedKeyword.isEmpty else { return }
                Task {
                    await executeSearch(for: trimmedKeyword)
                }
            }
            .navigationTitle("Thêm bạn bè")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func userSearchRow(_ user: UserSearchResponse) -> some View {
        let relation = chatStore.friendshipRelation(for: user)
        let isBusy = processingUserIds.contains(user.id)

        return HStack(spacing: 12) {
            AvatarView(
                name: user.displayName,
                avatarURL: settings.resolveAssetURL(user.avatarUrl),
                size: 46,
                isOnline: user.isOnline ?? false,
                presenceStatus: user.presenceStatus
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)

                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            switch relation {
            case .friend:
                Label("Bạn bè", systemImage: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemFill), in: Capsule())

            case .sentPending:
                if let sentId = chatStore.sentRequests.first(where: { $0.addresseeId == user.id })?.id {
                    Button(role: .destructive) {
                        Task {
                            await cancelSentRequest(friendshipId: sentId, user: user)
                        }
                    } label: {
                        if isBusy {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Thu hồi")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isBusy)
                } else {
                    Text("Đã gửi")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chatBLNPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.chatBLNPrimary.opacity(0.12), in: Capsule())
                }

            case .receivedPending(let friendshipId):
                Button("Chấp nhận") {
                    Task {
                        await acceptIncomingRequest(friendshipId: friendshipId, user: user)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.chatBLNPrimary)
                .disabled(isBusy)

            case .none:
                Button {
                    Task {
                        await sendRequest(to: user)
                    }
                } label: {
                    if isBusy {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Kết bạn", systemImage: "plus")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.chatBLNPrimary)
                .disabled(isBusy)
            }
        }
        .padding(.vertical, 2)
    }

    private func executeSearch(for keyword: String) async {
        guard !keyword.isEmpty else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        do {
            results = try await chatStore.searchUsers(keyword: keyword)
        } catch {
            isBannerError = true
            statusBanner = error.localizedDescription
        }
        isSearching = false
    }

    private func sendRequest(to user: UserSearchResponse) async {
        processingUserIds.insert(user.id)
        defer { processingUserIds.remove(user.id) }

        do {
            try await chatStore.sendFriendRequest(to: user.id)
            if let idx = results.firstIndex(where: { $0.id == user.id }) {
                results[idx].friendshipStatus = "PENDING"
            }
            isBannerError = false
            statusBanner = "Đã gửi lời mời kết bạn tới \(user.displayName)."
        } catch {
            isBannerError = true
            statusBanner = error.localizedDescription
        }
    }

    private func acceptIncomingRequest(friendshipId: Int64, user: UserSearchResponse) async {
        processingUserIds.insert(user.id)
        defer { processingUserIds.remove(user.id) }

        do {
            try await chatStore.acceptFriendRequest(friendshipId)
            if let idx = results.firstIndex(where: { $0.id == user.id }) {
                results[idx].isFriend = true
                results[idx].friendshipStatus = "ACCEPTED"
            }
            isBannerError = false
            statusBanner = "Bạn và \(user.displayName) đã trở thành bạn bè!"
        } catch {
            isBannerError = true
            statusBanner = error.localizedDescription
        }
    }

    private func cancelSentRequest(friendshipId: Int64, user: UserSearchResponse) async {
        processingUserIds.insert(user.id)
        defer { processingUserIds.remove(user.id) }

        do {
            try await chatStore.cancelSentFriendRequest(friendshipId)
            if let idx = results.firstIndex(where: { $0.id == user.id }) {
                results[idx].friendshipStatus = nil
            }
            isBannerError = false
            statusBanner = "Đã thu hồi lời mời kết bạn tới \(user.displayName)."
        } catch {
            isBannerError = true
            statusBanner = error.localizedDescription
        }
    }
}
