import SwiftUI

struct NewConversationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: AppSettings
    @Bindable var chatStore: ChatStoreViewModel
    var onRequestJoinByInvite: (() -> Void)? = nil

    private enum ComposeMode: String, CaseIterable, Identifiable {
        case direct = "Tin nhắn riêng"
        case group = "Tạo nhóm"

        var id: String { rawValue }
    }

    @State private var mode: ComposeMode = .direct
    @State private var filterKeyword: String = ""
    @State private var groupName: String = ""
    @State private var groupVisibility: GroupVisibility = .privateGroup
    @State private var selectedMemberIds: Set<Int64> = []
    @State private var isSubmitting: Bool = false
    @State private var showJoinGroupSheet: Bool = false
    @State private var localError: String?

    private var filteredFriends: [FriendResponse] {
        let trimmed = filterKeyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return chatStore.friends }
        return chatStore.friends.filter { friend in
            friend.displayName.lowercased().contains(trimmed) ||
            friend.username.lowercased().contains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Loại hội thoại", selection: $mode) {
                    ForEach(ComposeMode.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if let localError {
                    Label(localError, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                List {
                    Section {
                        Button {
                            if let onRequestJoinByInvite {
                                dismiss()
                                onRequestJoinByInvite()
                            } else {
                                showJoinGroupSheet = true
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.chatBLNPrimary.opacity(0.14))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "link.badge.plus")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.chatBLNPrimary)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Tham gia nhóm bằng link / mã mời")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("Dán link /join/grp_... hoặc nhập mã mời")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    if mode == .group {
                        Section {
                            TextField("Nhập tên nhóm (ví dụ: Nhóm Đồ Án iOS)", text: $groupName)

                            Picker("Quyền riêng tư", selection: $groupVisibility) {
                                ForEach(GroupVisibility.allCases) { option in
                                    Label(option.title, systemImage: option.iconName)
                                        .tag(option)
                                }
                            }
                            .pickerStyle(.segmented)

                            if selectedMemberIds.isEmpty {
                                Text("Chưa chọn thành viên ban đầu — bạn vẫn có thể tạo nhóm ngay và mời qua link.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Đã chọn \(selectedMemberIds.count) thành viên ban đầu")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.chatBLNPrimary)
                            }
                        } header: {
                            Text("Thông tin & Quyền riêng tư nhóm")
                        } footer: {
                            Text(groupVisibility.helperCaption)
                        }
                    }

                    Section(mode == .direct ? "Chọn bạn bè để nhắn tin" : "Thêm thành viên từ danh bạ (tuỳ chọn)") {
                        if filteredFriends.isEmpty {
                            ContentUnavailableView(
                                chatStore.friends.isEmpty ? "Chưa có bạn bè" : "Không tìm thấy kết quả",
                                systemImage: "person.2.slash",
                                description: Text(
                                    chatStore.friends.isEmpty
                                        ? (mode == .group
                                            ? "Bạn vẫn có thể nhấn Tạo nhóm rồi gửi link mời cho mọi người."
                                            : "Hãy sang mục Danh bạ để tìm và kết bạn trước khi bắt đầu trò chuyện.")
                                        : "Thử nhập tên hoặc username khác."
                                )
                            )
                        } else {
                            ForEach(filteredFriends) { friend in
                                friendRow(friend)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .searchable(text: $filterKeyword, prompt: "Lọc bạn bè theo tên hoặc @username")
            .navigationTitle("Trò chuyện mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") {
                        dismiss()
                    }
                }
                if mode == .group {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Tạo nhóm") {
                            Task {
                                await submitCreateGroup()
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(
                            isSubmitting ||
                            groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }
                }
            }
            .sheet(isPresented: $showJoinGroupSheet) {
                JoinGroupSheet(
                    settings: settings,
                    chatStore: chatStore
                )
            }
            .task {
                if chatStore.friends.isEmpty {
                    await chatStore.loadFriends()
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func friendRow(_ friend: FriendResponse) -> some View {
        Button {
            if mode == .direct {
                Task {
                    await startPrivateChat(with: friend)
                }
            } else {
                if selectedMemberIds.contains(friend.id) {
                    selectedMemberIds.remove(friend.id)
                } else {
                    selectedMemberIds.insert(friend.id)
                }
            }
        } label: {
            HStack(spacing: 12) {
                AvatarView(
                    name: friend.displayName,
                    avatarURL: settings.resolveAssetURL(friend.avatarUrl),
                    size: 44,
                    isOnline: friend.isOnline ?? false,
                    presenceStatus: friend.presenceStatus
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("@\(friend.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if mode == .group {
                    Image(systemName: selectedMemberIds.contains(friend.id) ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selectedMemberIds.contains(friend.id) ? Color.chatBLNPrimary : .secondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .disabled(isSubmitting)
    }

    private func startPrivateChat(with friend: FriendResponse) async {
        isSubmitting = true
        localError = nil
        let created = await chatStore.startOrOpenPrivateChat(with: friend)
        isSubmitting = false
        if created != nil {
            dismiss()
        } else {
            localError = chatStore.errorBanner ?? "Không thể mở cuộc trò chuyện."
        }
    }

    private func submitCreateGroup() async {
        isSubmitting = true
        localError = nil
        let created = await chatStore.createGroupChat(
            name: groupName,
            memberIds: Array(selectedMemberIds),
            visibility: groupVisibility
        )
        isSubmitting = false
        if created != nil {
            dismiss()
        } else {
            localError = chatStore.errorBanner ?? "Không thể tạo nhóm trò chuyện."
        }
    }
}
