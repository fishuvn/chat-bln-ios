import SwiftUI
import UIKit

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
    @State private var showRegenerateInviteConfirm: Bool = false
    @State private var memberPendingLeaderTransfer: GroupMemberDto?

    @State private var isDeleting: Bool = false
    @State private var isProcessingFriendship: Bool = false
    @State private var isUpdatingVisibility: Bool = false
    @State private var isRegeneratingInvite: Bool = false
    @State private var processingMemberIds: Set<Int64> = []
    @State private var processingJoinRequestIds: Set<Int64> = []

    @State private var actionNotice: String?
    @State private var deleteError: String?

    private var liveConversation: ConversationItemResponse {
        chatStore.conversation(for: conversation.id) ?? conversation
    }

    private var sortedGroupMembers: [GroupMemberDto] {
        let raw = chatStore.groupMembersByConversation[conversation.id] ?? liveConversation.members ?? []
        return raw.sorted { lhs, rhs in
            if lhs.resolvedRole.sortPriority != rhs.resolvedRole.sortPriority {
                return lhs.resolvedRole.sortPriority < rhs.resolvedRole.sortPriority
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private var pendingJoinRequests: [GroupJoinRequestDto] {
        chatStore.groupJoinRequestsByConversation[conversation.id] ?? []
    }

    private var effectivePendingCount: Int {
        if chatStore.groupJoinRequestsByConversation[conversation.id] != nil {
            return pendingJoinRequests.count
        }
        return max(0, liveConversation.pendingJoinRequestCount ?? 0)
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
                headerSection

                if let actionNotice {
                    Section {
                        Label(actionNotice, systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color(.systemGreen))
                    }
                }

                if let deleteError {
                    Section {
                        Label(deleteError, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color(.systemRed))
                    }
                }

                if liveConversation.isGroup {
                    groupInviteAndVisibilitySection

                    if liveConversation.canCurrentUserManageGroupRequests &&
                        (liveConversation.resolvedGroupVisibility == .privateGroup || !pendingJoinRequests.isEmpty) {
                        pendingJoinRequestsSection
                    }

                    Section("Thành viên nhóm (\(sortedGroupMembers.count))") {
                        if sortedGroupMembers.isEmpty {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Đang tải danh sách thành viên...")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(sortedGroupMembers) { member in
                                groupMemberRow(member)
                            }
                        }
                    }
                } else {
                    privateContactDetailsSection
                }

                sharedMediaSection

                sharedFilesSection

                dangerZoneSection
            }
            .listStyle(.insetGrouped)
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
                dangerConfirmationTitle,
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(dangerActionButtonTitle, role: .destructive) {
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
            .confirmationDialog(
                "Tạo mã mời nhóm mới? Đường link mời cũ sẽ bị vô hiệu hoá ngay lập tức.",
                isPresented: $showRegenerateInviteConfirm,
                titleVisibility: .visible
            ) {
                Button("Đổi mã mời mới", role: .destructive) {
                    Task {
                        await executeRegenerateInviteCode()
                    }
                }
                Button("Huỷ", role: .cancel) {}
            }
            .alert(
                "Chuyển quyền Trưởng nhóm?",
                isPresented: Binding(
                    get: { memberPendingLeaderTransfer != nil },
                    set: { if !$0 { memberPendingLeaderTransfer = nil } }
                ),
                presenting: memberPendingLeaderTransfer
            ) { targetMember in
                Button("Chuyển quyền", role: .destructive) {
                    Task {
                        await executeTransferLeadership(to: targetMember)
                    }
                }
                Button("Huỷ", role: .cancel) {
                    memberPendingLeaderTransfer = nil
                }
            } message: { targetMember in
                Text("Bạn sẽ chuyển quyền Trưởng nhóm cho \(targetMember.displayName) (@\(targetMember.username)) và trở thành Thành viên.")
            }
            .navigationTitle(liveConversation.isGroup ? "Thông tin nhóm" : "Chi tiết hội thoại")
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
                    if chatStore.conversation(for: liveConversation.id)?.canCurrentUserManageGroupRequests == true {
                        await chatStore.loadGroupJoinRequests(conversationId: liveConversation.id)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header & Group Badges

    private var headerSection: some View {
        Section {
            VStack(spacing: 10) {
                AvatarView(
                    name: liveConversation.displayName,
                    avatarURL: settings.resolveAssetURL(liveConversation.avatarUrl),
                    size: 76,
                    isGroup: liveConversation.isGroup,
                    isOnline: liveConversation.isGroup ? nil : (liveConversation.isOnline ?? false),
                    presenceStatus: liveConversation.presenceStatus
                )

                Text(liveConversation.displayName)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)

                HStack(spacing: 5) {
                    if !liveConversation.isGroup {
                        Image(
                            systemName: ChatDateFormatter.presenceSymbolName(
                                isOnline: liveConversation.isOnline,
                                presenceStatus: liveConversation.presenceStatus
                            )
                        )
                        .font(.caption)
                    }

                    Text(statusSubtitle)
                        .font(.subheadline)
                }
                .foregroundStyle(
                    liveConversation.isGroup
                        ? .secondary
                        : ChatDateFormatter.presenceTintColor(
                            isOnline: liveConversation.isOnline,
                            presenceStatus: liveConversation.presenceStatus
                        )
                )

                if liveConversation.isGroup {
                    HStack(spacing: 8) {
                        let visibility = liveConversation.resolvedGroupVisibility
                        let isPublic = visibility == .publicGroup
                        Label(visibility.title, systemImage: visibility.iconName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isPublic ? Color(.systemGreen) : Color(.secondaryLabel))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.tertiarySystemFill), in: Capsule())

                        roleBadgeView(for: liveConversation.resolvedGroupRole)
                    }

                    if liveConversation.canCurrentUserManageGroupRequests && effectivePendingCount > 0 {
                        Label("\(effectivePendingCount) yêu cầu tham gia chờ duyệt", systemImage: "person.crop.circle.badge.clock")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color(.systemOrange))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color(.systemOrange).opacity(0.14), in: Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Share Invite Link & Group Visibility

    private var groupInviteAndVisibilitySection: some View {
        Section {
            if liveConversation.isCurrentUserGroupAdmin {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Quyền riêng tư nhóm")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if isUpdatingVisibility {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    Picker(
                        "Quyền riêng tư nhóm",
                        selection: Binding(
                            get: { liveConversation.resolvedGroupVisibility },
                            set: { newVisibility in
                                guard newVisibility != liveConversation.resolvedGroupVisibility else { return }
                                Task {
                                    await executeVisibilityChange(newVisibility)
                                }
                            }
                        )
                    ) {
                        ForEach(GroupVisibility.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isUpdatingVisibility)
                }
                .padding(.vertical, 4)
            }

            if let inviteCode = liveConversation.inviteCode, !inviteCode.isEmpty {
                let shareURLString = GroupInviteLinkParser.shareURLString(for: inviteCode)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Liên kết mời tham gia nhóm")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(shareURLString)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    HStack(spacing: 8) {
                        Button {
                            UIPasteboard.general.string = shareURLString
                            deleteError = nil
                            actionNotice = "Đã sao chép liên kết mời nhóm vào bộ nhớ tạm."
                        } label: {
                            Label("Sao chép", systemImage: "doc.on.doc")
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(.chatBLNPrimary)

                        if let shareURL = URL(string: shareURLString) {
                            ShareLink(
                                item: shareURL,
                                message: Text("Mời bạn tham gia nhóm \"\(liveConversation.displayName)\" trên Chat BLN")
                            ) {
                                Label("Chia sẻ", systemImage: "square.and.arrow.up")
                                    .font(.footnote.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 36)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        if liveConversation.canCurrentUserManageGroupRequests {
                            Button {
                                showRegenerateInviteConfirm = true
                            } label: {
                                if isRegeneratingInvite {
                                    ProgressView()
                                        .controlSize(.small)
                                        .frame(minHeight: 36)
                                } else {
                                    Label("Đổi link", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.footnote.weight(.semibold))
                                        .frame(minHeight: 36)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(isRegeneratingInvite)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Liên kết mời & Chế độ nhóm")
        } footer: {
            Text(liveConversation.resolvedGroupVisibility.helperCaption)
        }
    }

    // MARK: - Pending Join Requests (Admin & Deputy)

    private var pendingJoinRequestsSection: some View {
        Section("Yêu cầu tham gia chờ duyệt (\(pendingJoinRequests.count))") {
            if pendingJoinRequests.isEmpty {
                Text("Hiện không có yêu cầu tham gia nào đang chờ phê duyệt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(pendingJoinRequests) { req in
                    let isBusy = processingJoinRequestIds.contains(req.id)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            AvatarView(
                                name: req.displayName,
                                avatarURL: settings.resolveAssetURL(req.avatarUrl),
                                size: 42
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(req.displayName)
                                    .font(.subheadline.weight(.semibold))
                                Text("@\(req.username)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            let createdLabel = ChatDateFormatter.formatConversationTime(req.createdAt)
                            if !createdLabel.isEmpty {
                                Text(createdLabel)
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        HStack(spacing: 10) {
                            Button {
                                Task {
                                    await handleApproveJoinRequest(req)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if isBusy {
                                        ProgressView()
                                            .controlSize(.mini)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "checkmark")
                                    }
                                    Text("Duyệt")
                                        .font(.footnote.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity, minHeight: 36)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(.chatBLNPrimary)
                            .disabled(isBusy)

                            Button(role: .destructive) {
                                Task {
                                    await handleRejectJoinRequest(req)
                                }
                            } label: {
                                Text("Từ chối")
                                    .font(.footnote.weight(.medium))
                                    .frame(maxWidth: .infinity, minHeight: 36)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(isBusy)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Private Contact Info

    private var privateContactDetailsSection: some View {
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

    // MARK: - Shared Media & Files

    private var sharedMediaSection: some View {
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
                                                Color(.tertiarySystemFill)
                                            }
                                        }
                                    } else {
                                        Color(.secondarySystemFill)
                                        Image(systemName: "play.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(.primary)
                                    }
                                }
                                .frame(height: 92)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                item.normalizedAttachmentKind == "IMAGE"
                                    ? "Mở ảnh đã chia sẻ"
                                    : "Mở video đã chia sẻ"
                            )
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var sharedFilesSection: some View {
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
                                Image(systemName: "doc.text")
                                    .foregroundStyle(Color.chatBLNPrimary)
                                    .frame(width: 28)
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fileMsg.attachmentName ?? "Tệp đính kèm")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    if let size = fileMsg.attachmentSize, !size.isEmpty {
                                        Text(size)
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                            .frame(minHeight: 44)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Danger Zone

    private var dangerConfirmationTitle: String {
        if liveConversation.isGroup {
            if liveConversation.isCurrentUserGroupAdmin {
                return "Giải tán nhóm \"\(liveConversation.displayName)\"? Toàn bộ thành viên và lịch sử tin nhắn sẽ bị xóa vĩnh viễn."
            }
            return "Bạn có chắc muốn rời khỏi nhóm \"\(liveConversation.displayName)\"?"
        }
        return "Xóa cuộc trò chuyện và toàn bộ lịch sử tin nhắn với \"\(liveConversation.displayName)\"?"
    }

    private var dangerActionButtonTitle: String {
        if liveConversation.isGroup {
            return liveConversation.isCurrentUserGroupAdmin ? "Giải tán nhóm" : "Rời khỏi nhóm"
        }
        return "Xóa lịch sử trò chuyện"
    }

    private var dangerZoneSection: some View {
        Section {
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
                        .frame(minHeight: 44)
                    }
                    .disabled(isProcessingFriendship)
                } else if liveConversation.friendshipStatus?.uppercased() == "PENDING" {
                    Label("Đã gửi lời mời kết bạn", systemImage: "clock")
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
                        .frame(minHeight: 44)
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
                            Image(
                                systemName: liveConversation.isGroup
                                    ? (liveConversation.isCurrentUserGroupAdmin ? "trash" : "rectangle.portrait.and.arrow.right")
                                    : "trash"
                            )
                        }
                        Text(isDeleting ? "Đang xử lý..." : dangerActionButtonTitle)
                            .fontWeight(.semibold)
                    }
                    .frame(minHeight: 44)
                }
                .disabled(isDeleting)
            }
        }
    }

    // MARK: - Member Row & Role Management

    private func roleBadgeView(for role: GroupRole) -> some View {
        let fg: Color = {
            switch role {
            case .admin:
                return Color(.systemOrange)
            case .deputy:
                return .chatBLNPrimary
            case .member:
                return .secondary
            }
        }()

        let bg: Color = {
            switch role {
            case .admin:
                return Color(.systemOrange).opacity(0.14)
            case .deputy:
                return Color.chatBLNPrimary.opacity(0.12)
            case .member:
                return Color(.tertiarySystemFill)
            }
        }()

        return Label(role.title, systemImage: role.iconName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg, in: Capsule())
    }

    private func groupMemberRow(_ member: GroupMemberDto) -> some View {
        let isMe = member.username.lowercased() == chatStore.currentUsername.lowercased()
        let matchedFriend = chatStore.friends.first(where: { $0.id == member.id })
        let isMemberBusy = processingMemberIds.contains(member.id)

        return HStack(spacing: 12) {
            AvatarView(
                name: member.displayName,
                avatarURL: settings.resolveAssetURL(member.avatarUrl),
                size: 42,
                isOnline: member.isOnline ?? false,
                presenceStatus: member.presenceStatus
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

                    roleBadgeView(for: member.resolvedRole)
                }
            }

            Spacer()

            if isMemberBusy {
                ProgressView()
                    .controlSize(.small)
            } else if !isMe {
                HStack(spacing: 2) {
                    if let matchedFriend {
                        Button {
                            dismiss()
                            Task {
                                _ = await chatStore.startOrOpenPrivateChat(with: matchedFriend)
                            }
                        } label: {
                            Image(systemName: "bubble.right")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.chatBLNPrimary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
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
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.chatBLNPrimary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Kết bạn với \(member.displayName)")
                    }

                    if liveConversation.isCurrentUserGroupAdmin {
                        Menu {
                            if member.isDeputy {
                                Button {
                                    Task {
                                        await executeRoleChange(for: member, newRole: .member)
                                    }
                                } label: {
                                    Label("Gỡ Phó nhóm", systemImage: "shield.slash")
                                }
                            } else {
                                Button {
                                    Task {
                                        await executeRoleChange(for: member, newRole: .deputy)
                                    }
                                } label: {
                                    Label("Bổ nhiệm Phó nhóm", systemImage: "shield.lefthalf.filled")
                                }
                            }

                            Divider()

                            Button(role: .destructive) {
                                memberPendingLeaderTransfer = member
                            } label: {
                                Label("Chuyển quyền Trưởng nhóm", systemImage: "crown")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Quản lý vai trò của \(member.displayName)")
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Async Handlers

    private func executeVisibilityChange(_ newVisibility: GroupVisibility) async {
        isUpdatingVisibility = true
        deleteError = nil
        actionNotice = nil
        do {
            try await chatStore.updateGroupVisibility(
                conversationId: liveConversation.id,
                visibility: newVisibility
            )
            actionNotice = "Đã chuyển sang chế độ \(newVisibility.title)."
        } catch {
            deleteError = error.localizedDescription
        }
        isUpdatingVisibility = false
    }

    private func executeRegenerateInviteCode() async {
        isRegeneratingInvite = true
        deleteError = nil
        actionNotice = nil
        do {
            let newCode = try await chatStore.regenerateGroupInviteCode(conversationId: liveConversation.id)
            UIPasteboard.general.string = GroupInviteLinkParser.shareURLString(for: newCode)
            actionNotice = "Đã tạo mã mời mới và sao chép link vào bộ nhớ tạm."
        } catch {
            deleteError = error.localizedDescription
        }
        isRegeneratingInvite = false
    }

    private func executeRoleChange(for member: GroupMemberDto, newRole: GroupRole) async {
        processingMemberIds.insert(member.id)
        defer { processingMemberIds.remove(member.id) }
        deleteError = nil
        actionNotice = nil

        do {
            try await chatStore.updateGroupMemberRole(
                conversationId: liveConversation.id,
                targetUserId: member.id,
                role: newRole
            )
            actionNotice = newRole == .deputy
                ? "Đã bổ nhiệm \(member.displayName) làm Phó nhóm."
                : "Đã gỡ quyền Phó nhóm của \(member.displayName)."
        } catch {
            deleteError = error.localizedDescription
        }
    }

    private func executeTransferLeadership(to member: GroupMemberDto) async {
        processingMemberIds.insert(member.id)
        defer { processingMemberIds.remove(member.id) }
        memberPendingLeaderTransfer = nil
        deleteError = nil
        actionNotice = nil

        do {
            try await chatStore.transferGroupLeadership(
                conversationId: liveConversation.id,
                newLeaderUserId: member.id
            )
            actionNotice = "Đã chuyển quyền Trưởng nhóm cho \(member.displayName)."
        } catch {
            deleteError = error.localizedDescription
        }
    }

    private func handleApproveJoinRequest(_ request: GroupJoinRequestDto) async {
        processingJoinRequestIds.insert(request.id)
        defer { processingJoinRequestIds.remove(request.id) }
        deleteError = nil
        actionNotice = nil

        do {
            try await chatStore.approveGroupJoinRequest(
                conversationId: liveConversation.id,
                requestId: request.id
            )
            actionNotice = "Đã duyệt \(request.displayName) vào nhóm."
        } catch {
            deleteError = error.localizedDescription
        }
    }

    private func handleRejectJoinRequest(_ request: GroupJoinRequestDto) async {
        processingJoinRequestIds.insert(request.id)
        defer { processingJoinRequestIds.remove(request.id) }
        deleteError = nil
        actionNotice = nil

        do {
            try await chatStore.rejectGroupJoinRequest(
                conversationId: liveConversation.id,
                requestId: request.id
            )
            actionNotice = "Đã từ chối yêu cầu của \(request.displayName)."
        } catch {
            deleteError = error.localizedDescription
        }
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
            let count = sortedGroupMembers.isEmpty ? (liveConversation.memberCount ?? 0) : sortedGroupMembers.count
            return count > 0 ? "\(count) thành viên" : "Nhóm trò chuyện"
        }
        return ChatDateFormatter.formatPresenceStatus(
            isOnline: liveConversation.isOnline,
            presenceStatus: liveConversation.presenceStatus,
            lastSeen: liveConversation.lastSeen
        )
    }
}
