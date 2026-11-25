import SwiftUI

struct ConversationInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let conversation: ConversationItemResponse
    let messages: [MessageDto]
    let settings: AppSettings
    @Bindable var chatStore: ChatStoreViewModel
    var onDeleteConversation: (() async throws -> Void)? = nil

    @State private var showDeleteConfirm: Bool = false
    @State private var showUnfriendConfirm: Bool = false
    @State private var isDeleting: Bool = false
    @State private var isProcessingFriendship: Bool = false
    @State private var actionNotice: String?
    @State private var deleteError: String?

    private var liveConversation: ConversationItemResponse {
        chatStore.conversation(for: conversation.id) ?? conversation
    }

    private var groupMembers: [GroupMemberDto] {
        chatStore.groupMembersByConversation[conversation.id] ?? liveConversation.members ?? []
    }

    private var sharedMediaMessages: [MessageDto] {
        messages.reversed().filter { msg in
            let kind = msg.normalizedAttachmentKind
            return (kind == "IMAGE" || kind == "VIDEO") && settings.resolveAssetURL(msg.attachmentUrl) != nil
        }
    }

    private var sharedFileMessages: [MessageDto] {
        messages.reversed().filter { msg in
            msg.normalizedAttachmentKind == "FILE" && settings.resolveAssetURL(msg.attachmentUrl) != nil
        }
    }

    private let mediaColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 10) {
                        AvatarView(
                            name: liveConversation.displayName,
                            avatarURL: settings.resolveAssetURL(liveConversation.avatarUrl),
                            size: 80,
                            isGroup: liveConversation.isGroup,
                            isOnline: liveConversation.isGroup ? nil : (liveConversation.isOnline ?? false)
                        )

                        Text(liveConversation.displayName)
                            .font(.title3.weight(.bold))
                            .multilineTextAlignment(.center)

                        Text(statusSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(liveConversation.isOnline == true && !liveConversation.isGroup ? Color.green : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                if let actionNotice {
                    Section {
                        Label(actionNotice, systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                }

                if liveConversation.isGroup {
                    Section("Thành viên nhóm (\(groupMembers.count))") {
                        if groupMembers.isEmpty {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Đang tải danh sách thành viên...")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(groupMembers) { member in
                                groupMemberRow(member)
                            }
                        }
                    }
                } else {
                    Section("Thông tin liên hệ") {
                        if let username = liveConversation.targetUsername, !username.isEmpty {
                            LabeledContent("Username", value: "@\(username)")
                        }
                        if let email = liveConversation.email, !email.isEmpty {
                            LabeledContent("Email", value: email)
                        }
                        if let phone = liveConversation.phone, !phone.isEmpty {
                            LabeledContent("Điện thoại", value: phone)
                        }
                        if let gender = liveConversation.gender, !gender.isEmpty {
                            LabeledContent("Giới tính", value: gender)
                        }
                        if let dob = liveConversation.dob, !dob.isEmpty {
                            LabeledContent("Ngày sinh", value: dob)
                        }
                        if let bio = liveConversation.bio, !bio.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tiểu sử")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(bio)
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("Ảnh & Video đã chia sẻ (\(sharedMediaMessages.count))") {
                    if sharedMediaMessages.isEmpty {
                        Text("Chưa có ảnh hoặc video nào trong cuộc trò chuyện này.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: mediaColumns, spacing: 8) {
                            ForEach(sharedMediaMessages) { item in
                                if let url = settings.resolveAssetURL(item.attachmentUrl) {
                                    Button {
                                        openURL(url)
                                    } label: {
                                        ZStack {
                                            if item.normalizedAttachmentKind == "IMAGE" {
                                                AsyncImage(url: url) { phase in
                                                    switch phase {
                                                    case .success(let image):
                                                        image
                                                            .resizable()
                                                            .scaledToFill()
                                                    default:
                                                        Color(.tertiarySystemGroupedBackground)
                                                    }
                                                }
                                            } else {
                                                Color.black.opacity(0.82)
                                                Image(systemName: "play.circle.fill")
                                                    .font(.title2)
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .frame(height: 92)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Tệp đính kèm (\(sharedFileMessages.count))") {
                    if sharedFileMessages.isEmpty {
                        Text("Chưa có tệp tài liệu nào được chia sẻ.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sharedFileMessages) { fileMsg in
                            if let url = settings.resolveAssetURL(fileMsg.attachmentUrl) {
                                Button {
                                    openURL(url)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "doc.fill")
                                            .foregroundStyle(Color.chatBLNPrimary)
                                            .frame(width: 28)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(fileMsg.attachmentName ?? "Tệp đính kèm")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)

                                            if let size = fileMsg.attachmentSize, !size.isEmpty {
                                                Text(size)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer()

                                        Image(systemName: "arrow.up.right.square")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                Section {
                    if let deleteError {
                        Text(deleteError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if !liveConversation.isGroup, let targetId = liveConversation.targetUserId {
                        if liveConversation.isFriend != false {
                            Button(role: .destructive) {
                                showUnfriendConfirm = true
                            } label: {
                                HStack(spacing: 10) {
                                    if isProcessingFriendship {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "person.badge.minus")
                                    }
                                    Text("Hủy kết bạn")
                                        .fontWeight(.semibold)
                                }
                            }
                            .disabled(isProcessingFriendship)
                        } else if liveConversation.friendshipStatus?.uppercased() == "PENDING" {
                            Label("Đã gửi lời mời kết bạn", systemImage: "clock.fill")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        } else {
                            Button {
                                Task {
                                    await sendReFriendRequest(targetId: targetId)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    if isProcessingFriendship {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "person.badge.plus")
                                    }
                                    Text("Kết bạn lại")
                                        .fontWeight(.semibold)
                                }
                            }
                            .disabled(isProcessingFriendship)
                        }
                    }

                    if onDeleteConversation != nil {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack(spacing: 10) {
                                if isDeleting {
                                    ProgressView()
                                } else {
                                    Image(systemName: "trash.fill")
                                }
                                Text(isDeleting ? "Đang xóa..." : "Xóa lịch sử trò chuyện")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(isDeleting)
                    }
                }
            }
            .confirmationDialog(
                "Hủy kết bạn với \"\(liveConversation.displayName)\"? Hai bạn sẽ trở về trạng thái chưa kết bạn và có thể kết bạn lại bất cứ lúc nào.",
                isPresented: $showUnfriendConfirm,
                titleVisibility: .visible
            ) {
                Button("Hủy kết bạn", role: .destructive) {
                    guard let targetId = liveConversation.targetUserId else { return }
                    Task {
                        await executeUnfriend(targetId: targetId)
                    }
                }
                Button("Đóng", role: .cancel) {}
            }
            .confirmationDialog(
                "Xóa cuộc trò chuyện và toàn bộ lịch sử tin nhắn với \"\(liveConversation.displayName)\"?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Xóa lịch sử trò chuyện", role: .destructive) {
                    guard let onDeleteConversation else { return }
                    isDeleting = true
                    deleteError = nil
                    Task {
                        do {
                            try await onDeleteConversation()
                            dismiss()
                        } catch {
                            deleteError = error.localizedDescription
                        }
                        isDeleting = false
                    }
                }
                Button("Huỷ", role: .cancel) {}
            }
            .navigationTitle("Chi tiết hội thoại")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                if liveConversation.isGroup {
                    await chatStore.loadConversationMembers(conversationId: liveConversation.id)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func groupMemberRow(_ member: GroupMemberDto) -> some View {
        let isMe = member.username.lowercased() == chatStore.currentUsername.lowercased()
        let matchedFriend = chatStore.friends.first(where: { $0.id == member.id })

        return HStack(spacing: 12) {
            AvatarView(
                name: member.displayName,
                avatarURL: settings.resolveAssetURL(member.avatarUrl),
                size: 42,
                isOnline: member.isOnline ?? false
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if isMe {
                        Text("(Bạn)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 6) {
                    Text("@\(member.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(member.isAdmin ? "Quản trị viên" : "Thành viên")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(member.isAdmin ? Color.chatBLNPrimary : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            member.isAdmin
                                ? Color.chatBLNPrimary.opacity(0.14)
                                : Color(.tertiarySystemFill),
                            in: Capsule()
                        )
                }
            }

            Spacer()

            if !isMe {
                if let matchedFriend {
                    Button {
                        dismiss()
                        Task {
                            _ = await chatStore.startOrOpenPrivateChat(with: matchedFriend)
                        }
                    } label: {
                        Image(systemName: "bubble.right.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.chatBLNPrimary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Nhắn tin riêng với \(member.displayName)")
                } else {
                    Button {
                        Task {
                            await sendReFriendRequest(targetId: member.id, customName: member.displayName)
                        }
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.subheadline)
                            .foregroundStyle(Color.chatBLNPrimary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Kết bạn với \(member.displayName)")
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func executeUnfriend(targetId: Int64) async {
        isProcessingFriendship = true
        deleteError = nil
        actionNotice = nil
        do {
            try await chatStore.unfriend(userId: targetId)
            actionNotice = "Đã hủy kết bạn. Bạn có thể kết bạn lại bất cứ lúc nào."
        } catch {
            deleteError = error.localizedDescription
        }
        isProcessingFriendship = false
    }

    private func sendReFriendRequest(targetId: Int64, customName: String? = nil) async {
        isProcessingFriendship = true
        deleteError = nil
        actionNotice = nil
        do {
            try await chatStore.sendFriendRequest(to: targetId)
            actionNotice = "Đã gửi lời mời kết bạn tới \(customName ?? liveConversation.displayName)."
        } catch {
            deleteError = error.localizedDescription
        }
        isProcessingFriendship = false
    }

    private var statusSubtitle: String {
        if liveConversation.isGroup {
            let count = groupMembers.isEmpty ? (liveConversation.memberCount ?? 0) : groupMembers.count
            return count > 0 ? "\(count) thành viên" : "Nhóm trò chuyện"
        }
        return ChatDateFormatter.formatPresenceStatus(
            isOnline: liveConversation.isOnline,
            lastSeen: liveConversation.lastSeen
        )
    }
}
