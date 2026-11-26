import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private struct FullScreenImageItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct InvitePreviewSheetItem: Identifiable {
    let code: String
    var id: String { code }
}

struct ChatRoomView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let conversationId: Int64
    let fallbackConversation: ConversationItemResponse
    @Bindable var settings: AppSettings
    @Bindable var chatStore: ChatStoreViewModel

    @State private var draftText: String = ""
    @State private var isSearchBarVisible: Bool = false
    @State private var inChatSearchQuery: String = ""
    @State private var showEmojiSheet: Bool = false
    @State private var showInfoSheet: Bool = false
    @State private var invitePreviewSheetItem: InvitePreviewSheetItem?

    @State private var showPhotoPicker: Bool = false
    @State private var showVideoPicker: Bool = false
    @State private var showFileImporter: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedVideoItem: PhotosPickerItem?

    @State private var fullScreenImage: FullScreenImageItem?
    @State private var isSendingText: Bool = false
    @State private var roomErrorMessage: String?
    @State private var isSelectingMessages: Bool = false
    @State private var selectedMessageIds: Set<Int64> = []
    @State private var pendingDeleteMessageIds: [Int64] = []
    @State private var showDeleteMessageDialog: Bool = false
    @State private var isDeletingMessages: Bool = false

    private var conversation: ConversationItemResponse {
        chatStore.conversation(for: conversationId) ?? fallbackConversation
    }

    private var allMessages: [MessageDto] {
        chatStore.messagesByConversation[conversationId] ?? []
    }

    private var visibleMessages: [MessageDto] {
        let query = inChatSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isSearchBarVisible, !query.isEmpty else {
            return allMessages
        }
        return allMessages.filter { msg in
            msg.content.lowercased().contains(query) ||
            (msg.attachmentName?.lowercased().contains(query) == true) ||
            msg.sender.displayName.lowercased().contains(query)
        }
    }

    private var isUploadingAttachment: Bool {
        chatStore.uploadingConversationIds.contains(conversationId)
    }

    private var pendingJoinBadgeCount: Int {
        guard conversation.isGroup, conversation.canCurrentUserManageGroupRequests else { return 0 }
        if let loaded = chatStore.groupJoinRequestsByConversation[conversationId] {
            return loaded.count
        }
        return max(0, conversation.pendingJoinRequestCount ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isSearchBarVisible {
                inChatSearchHeader
                Divider()
            }

            if let roomErrorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color(.systemRed))
                        .accessibilityHidden(true)

                    Text(roomErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(Color(.systemRed))
                        .lineLimit(2)

                    Spacer()

                    Button {
                        self.roomErrorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Đóng thông báo lỗi")
                }
                .padding(.horizontal, 16)
                .background(Color(.secondarySystemGroupedBackground))
                .overlay(alignment: .bottom) {
                    Divider()
                }
            }

            messagesScrollArea
                .environment(\.openURL, OpenURLAction { url in
                    if let code = GroupInviteLinkParser.extractInviteCodeFromMessageText(url.absoluteString) {
                        invitePreviewSheetItem = InvitePreviewSheetItem(code: code)
                        return .handled
                    }
                    return .systemAction
                })
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                if isSelectingMessages {
                    selectionBottomBar
                } else if conversation.isUnfriendedPrivate {
                    unfriendedBottomBar
                } else {
                    ChatComposerBar(
                        draftText: $draftText,
                        isUploadingAttachment: isUploadingAttachment,
                        isSendingText: isSendingText,
                        onPickPhoto: { showPhotoPicker = true },
                        onPickVideo: { showVideoPicker = true },
                        onPickFile: { showFileImporter = true },
                        onOpenEmoji: { showEmojiSheet = true },
                        onSend: {
                            Task { await sendCurrentDraft() }
                        }
                    )
                }
            }
            .background(.bar)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                headerTitleButton
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isSelectingMessages {
                    Button("Xong") {
                        toggleWithMotion {
                            isSelectingMessages = false
                            selectedMessageIds.removeAll()
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                } else {
                    Menu {
                        Button {
                            showInfoSheet = true
                        } label: {
                            if pendingJoinBadgeCount > 0 {
                                Label(
                                    conversation.isGroup
                                        ? "Thông tin nhóm (\(pendingJoinBadgeCount) chờ duyệt)"
                                        : "Thông tin hội thoại",
                                    systemImage: "info.circle"
                                )
                            } else {
                                Label(
                                    conversation.isGroup ? "Thông tin nhóm" : "Thông tin hội thoại",
                                    systemImage: "info.circle"
                                )
                            }
                        }

                        Button {
                            toggleWithMotion {
                                isSearchBarVisible.toggle()
                                if !isSearchBarVisible {
                                    inChatSearchQuery = ""
                                }
                            }
                        } label: {
                            Label(
                                isSearchBarVisible ? "Đóng tìm kiếm" : "Tìm tin nhắn",
                                systemImage: "magnifyingglass"
                            )
                        }

                        Button {
                            toggleWithMotion {
                                isSelectingMessages = true
                            }
                        } label: {
                            Label("Chọn nhiều tin nhắn", systemImage: "checkmark.circle")
                        }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "ellipsis")
                                .font(.body.weight(.semibold))
                                .frame(minWidth: 32, minHeight: 32)
                            if pendingJoinBadgeCount > 0 {
                                Circle()
                                    .fill(Color(.systemOrange))
                                    .frame(width: 8, height: 8)
                                    .offset(x: 1, y: 1)
                            }
                        }
                    }
                    .accessibilityLabel(
                        pendingJoinBadgeCount > 0
                            ? "Tùy chọn cuộc trò chuyện, có \(pendingJoinBadgeCount) yêu cầu tham gia chờ duyệt"
                            : "Tùy chọn cuộc trò chuyện"
                    )
                }
            }
        }
        .alert(
            pendingDeleteMessageIds.count == 1
                ? "Xóa tin nhắn này?"
                : "Xóa \(pendingDeleteMessageIds.count) tin nhắn đã chọn?",
            isPresented: $showDeleteMessageDialog
        ) {
            if canDeletePendingForEveryone {
                Button("Thu hồi với mọi người", role: .destructive) {
                    Task {
                        await executeDeleteMessages(mode: "FOR_EVERYONE")
                    }
                }
            }
            Button("Xóa ở phía tôi", role: .destructive) {
                Task {
                    await executeDeleteMessages(mode: "FOR_ME")
                }
            }
            Button("Hủy", role: .cancel) {
                pendingDeleteMessageIds = []
            }
        } message: {
            if !canDeletePendingForEveryone && conversation.isGroup {
                Text("Trong nhóm, thành viên chỉ thu hồi với mọi người được tin nhắn do chính mình gửi.")
            }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .photosPicker(
            isPresented: $showVideoPicker,
            selection: $selectedVideoItem,
            matching: .videos,
            photoLibrary: .shared()
        )
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await handlePickedDocument(result)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await handlePickedMediaItem(newItem, fallbackMime: "image/jpeg", fallbackExtension: "jpg")
                selectedPhotoItem = nil
            }
        }
        .onChange(of: selectedVideoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await handlePickedMediaItem(newItem, fallbackMime: "video/mp4", fallbackExtension: "mp4")
                selectedVideoItem = nil
            }
        }
        .sheet(isPresented: $showEmojiSheet) {
            EmojiPickerSheet { emoji in
                draftText.append(emoji)
            }
        }
        .sheet(isPresented: $showInfoSheet) {
            ConversationInfoSheet(
                conversation: conversation,
                messages: allMessages,
                settings: settings,
                chatStore: chatStore,
                onDeleteConversation: {
                    try await chatStore.deleteConversation(conversationId: conversationId)
                }
            )
        }
        .sheet(item: $invitePreviewSheetItem) { item in
            JoinGroupSheet(
                settings: settings,
                chatStore: chatStore,
                initialInput: item.code
            )
        }
        .fullScreenCover(item: $fullScreenImage) { item in
            FullScreenImageViewer(imageURL: item.url)
        }
        .task(id: conversationId) {
            await chatStore.enterChatRoom(conversationId: conversationId)
        }
        .onDisappear {
            chatStore.leaveChatRoom(conversationId: conversationId)
        }
    }

    // MARK: - Subviews

    private func toggleWithMotion(_ updates: () -> Void) {
        if reduceMotion {
            updates()
        } else {
            withAnimation(.snappy(duration: 0.2)) {
                updates()
            }
        }
    }

    private var headerTitleButton: some View {
        Button {
            showInfoSheet = true
        } label: {
            HStack(spacing: 8) {
                AvatarView(
                    name: conversation.displayName,
                    avatarURL: settings.resolveAssetURL(conversation.avatarUrl),
                    size: 32,
                    isGroup: conversation.isGroup,
                    isOnline: conversation.isGroup ? nil : (conversation.isOnline ?? false),
                    presenceStatus: conversation.presenceStatus
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(conversation.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 4) {
                        Image(
                            systemName: conversation.isGroup
                                ? conversation.resolvedGroupVisibility.iconName
                                : ChatDateFormatter.presenceSymbolName(
                                    isOnline: conversation.isOnline,
                                    presenceStatus: conversation.presenceStatus
                                )
                        )
                        .font(.system(size: 10, weight: .medium))

                        Text(subtitleStatusText)
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .foregroundStyle(
                        conversation.isGroup
                            ? .secondary
                            : ChatDateFormatter.presenceTintColor(
                                isOnline: conversation.isOnline,
                                presenceStatus: conversation.presenceStatus
                            )
                    )
                }
                .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Mở chi tiết cuộc trò chuyện")
    }

    private var subtitleStatusText: String {
        if conversation.isGroup {
            let loadedCount = chatStore.groupMembersByConversation[conversationId]?.count
            let count = loadedCount ?? conversation.memberCount ?? 0
            let visibilityLabel = conversation.resolvedGroupVisibility.shortTitle
            if count > 0 {
                return "\(visibilityLabel) · \(count) thành viên"
            }
            return "Nhóm \(visibilityLabel.lowercased())"
        }
        return ChatDateFormatter.formatPresenceStatus(
            isOnline: conversation.isOnline,
            presenceStatus: conversation.presenceStatus,
            lastSeen: conversation.lastSeen
        )
    }

    private var inChatSearchHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField("Tìm nội dung hoặc tên tệp...", text: $inChatSearchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !inChatSearchQuery.isEmpty {
                Button {
                    inChatSearchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Xóa từ khoá tìm kiếm")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
    }

    private var messagesScrollArea: some View {
        let displayed = visibleMessages
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if chatStore.hasMoreByConversation[conversationId] == true,
                       inChatSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            Task {
                                await chatStore.loadOlderMessages(conversationId: conversationId)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if chatStore.loadingMessagesConversationIds.contains(conversationId) {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.up")
                                }
                                Text("Tải tin nhắn cũ hơn")
                                    .font(.footnote.weight(.medium))
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color(.separator).opacity(0.4), lineWidth: 0.5)
                            )
                        }
                        .padding(.bottom, 12)
                    }

                    if chatStore.loadingMessagesConversationIds.contains(conversationId) && allMessages.isEmpty {
                        skeletonMessagesPlaceholder
                    } else if displayed.isEmpty {
                        ContentUnavailableView(
                            isSearchBarVisible && !inChatSearchQuery.isEmpty
                                ? "Không khớp tin nhắn nào"
                                : "Chưa có tin nhắn",
                            systemImage: isSearchBarVisible && !inChatSearchQuery.isEmpty
                                ? "magnifyingglass"
                                : "bubble.left",
                            description: Text(
                                isSearchBarVisible && !inChatSearchQuery.isEmpty
                                    ? "Thử từ khoá khác trong cuộc trò chuyện."
                                    : "Gửi tin nhắn đầu tiên hoặc chia sẻ ảnh, video, tài liệu."
                            )
                        )
                        .padding(.top, 48)
                    } else {
                        ForEach(Array(displayed.enumerated()), id: \.element.id) { index, msg in
                            let isOutgoing = msg.sender.username.lowercased() == chatStore.currentUsername.lowercased()
                            let prevSameSender = index > 0 &&
                                displayed[index - 1].sender.username.lowercased() == msg.sender.username.lowercased()
                            let nextSameSender = (index + 1) < displayed.count &&
                                displayed[index + 1].sender.username.lowercased() == msg.sender.username.lowercased()

                            MessageBubbleView(
                                message: msg,
                                isOutgoing: isOutgoing,
                                settings: settings,
                                showSenderHeader: !prevSameSender,
                                isLastInSenderGroup: !nextSameSender,
                                isSelectionMode: isSelectingMessages,
                                isSelected: selectedMessageIds.contains(msg.id),
                                onToggleSelect: {
                                    if selectedMessageIds.contains(msg.id) {
                                        selectedMessageIds.remove(msg.id)
                                    } else {
                                        selectedMessageIds.insert(msg.id)
                                    }
                                },
                                onStartMultiSelect: {
                                    toggleWithMotion {
                                        isSelectingMessages = true
                                        selectedMessageIds.insert(msg.id)
                                    }
                                },
                                onRequestDeleteSingle: {
                                    pendingDeleteMessageIds = [msg.id]
                                    showDeleteMessageDialog = true
                                },
                                onTapImage: { url in
                                    fullScreenImage = FullScreenImageItem(url: url)
                                },
                                onOpenGroupInvite: { code in
                                    invitePreviewSheetItem = InvitePreviewSheetItem(code: code)
                                }
                            )
                            .padding(.top, prevSameSender ? 3 : 10)
                            .id(msg.id)
                        }
                    }

                    Color.clear
                        .frame(height: 4)
                        .id("CHAT_BOTTOM_ANCHOR")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: allMessages.last?.id) { _, _ in
                if reduceMotion {
                    proxy.scrollTo("CHAT_BOTTOM_ANCHOR", anchor: .bottom)
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("CHAT_BOTTOM_ANCHOR", anchor: .bottom)
                    }
                }
            }
            .onAppear {
                proxy.scrollTo("CHAT_BOTTOM_ANCHOR", anchor: .bottom)
            }
        }
    }

    private var skeletonMessagesPlaceholder: some View {
        VStack(spacing: 14) {
            ForEach(0..<4, id: \.self) { idx in
                HStack {
                    if idx.isMultiple(of: 2) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .frame(width: 210, height: 46)
                        Spacer()
                    } else {
                        Spacer()
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.tertiarySystemFill))
                            .frame(width: 190, height: 46)
                    }
                }
            }
        }
        .padding(.top, 16)
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityLabel("Đang tải lịch sử tin nhắn")
    }

    private var canDeletePendingForEveryone: Bool {
        guard !pendingDeleteMessageIds.isEmpty else { return false }
        if !conversation.isGroup || conversation.isCurrentUserGroupAdmin {
            return true
        }
        let idSet = Set(pendingDeleteMessageIds)
        let selected = allMessages.filter { idSet.contains($0.id) }
        return !selected.isEmpty && selected.allSatisfy {
            $0.sender.username.lowercased() == chatStore.currentUsername.lowercased()
        }
    }

    private var selectionBottomBar: some View {
        HStack(spacing: 12) {
            Button {
                let visibleIds = Set(visibleMessages.map(\.id))
                if !visibleIds.isEmpty && visibleIds.isSubset(of: selectedMessageIds) {
                    selectedMessageIds.subtract(visibleIds)
                } else {
                    selectedMessageIds.formUnion(visibleIds)
                }
            } label: {
                Text(
                    !visibleMessages.isEmpty && Set(visibleMessages.map(\.id)).isSubset(of: selectedMessageIds)
                        ? "Bỏ chọn"
                        : "Chọn tất cả"
                )
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
            }

            Spacer()

            Text("Đã chọn \(selectedMessageIds.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer()

            Button(role: .destructive) {
                pendingDeleteMessageIds = Array(selectedMessageIds)
                showDeleteMessageDialog = true
            } label: {
                HStack(spacing: 5) {
                    if isDeletingMessages {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "trash")
                    }
                    Text("Xóa (\(selectedMessageIds.count))")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                .frame(minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(.systemRed))
            .disabled(selectedMessageIds.isEmpty || isDeletingMessages)

            Button("Xong") {
                toggleWithMotion {
                    isSelectingMessages = false
                    selectedMessageIds.removeAll()
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func executeDeleteMessages(mode: String) async {
        let ids = pendingDeleteMessageIds
        guard !ids.isEmpty else { return }
        isDeletingMessages = true
        defer { isDeletingMessages = false }
        do {
            try await chatStore.deleteMessages(
                conversationId: conversationId,
                messageIds: ids,
                mode: mode
            )
            pendingDeleteMessageIds = []
            selectedMessageIds.subtract(ids)
            if selectedMessageIds.isEmpty {
                isSelectingMessages = false
            }
        } catch {
            roomErrorMessage = error.localizedDescription
        }
    }

    private var unfriendedBottomBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Hai bạn hiện không còn là bạn bè. Kết bạn lại để tiếp tục gửi tin nhắn.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if conversation.friendshipStatus?.uppercased() == "PENDING" {
                Label("Đã gửi", systemImage: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chatBLNPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            } else if let targetId = conversation.targetUserId {
                Button {
                    Task {
                        do {
                            try await chatStore.sendFriendRequest(to: targetId)
                        } catch {
                            roomErrorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Label("Kết bạn lại", systemImage: "person.badge.plus")
                        .font(.footnote.weight(.semibold))
                        .frame(minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.chatBLNPrimary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Actions

    private func sendCurrentDraft() async {
        let outgoing = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !outgoing.isEmpty else { return }

        isSendingText = true
        roomErrorMessage = nil
        let backup = draftText
        draftText = ""

        do {
            try await chatStore.sendTextMessage(conversationId: conversationId, text: outgoing)
        } catch {
            draftText = backup
            roomErrorMessage = error.localizedDescription
        }
        isSendingText = false
    }

    private func handlePickedMediaItem(
        _ item: PhotosPickerItem,
        fallbackMime: String,
        fallbackExtension: String
    ) async {
        roomErrorMessage = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else {
                roomErrorMessage = "Không thể đọc dữ liệu phương tiện đã chọn."
                return
            }

            if data.count > 50 * 1024 * 1024 {
                roomErrorMessage = "Dung lượng tệp vượt quá giới hạn 50 MB."
                return
            }

            let contentType = item.supportedContentTypes.first
            var uploadData = data
            var mimeType = contentType?.preferredMIMEType ?? fallbackMime
            var ext = (contentType?.preferredFilenameExtension ?? fallbackExtension).lowercased()

            if ext == "heic" || ext == "heif" || mimeType.contains("heic") || mimeType.contains("heif") {
                if let uiImage = UIImage(data: data),
                   let jpegData = uiImage.jpegData(compressionQuality: 0.85) {
                    uploadData = jpegData
                    mimeType = "image/jpeg"
                    ext = "jpg"
                }
            }

            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "media_\(timestamp).\(ext)"
            let caption = draftText
            draftText = ""

            try await chatStore.uploadAndSendAttachment(
                conversationId: conversationId,
                data: uploadData,
                fileName: fileName,
                mimeType: mimeType,
                caption: caption
            )
        } catch {
            roomErrorMessage = error.localizedDescription
        }
    }

    private func handlePickedDocument(_ result: Result<[URL], any Error>) async {
        roomErrorMessage = nil
        do {
            let urls = try result.get()
            guard let fileURL = urls.first else { return }

            let accessing = fileURL.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: fileURL)
            if data.count > 50 * 1024 * 1024 {
                roomErrorMessage = "Dung lượng tệp vượt quá giới hạn 50 MB."
                return
            }

            let fileName = fileURL.lastPathComponent.isEmpty ? "attachment.bin" : fileURL.lastPathComponent
            let utType = UTType(filenameExtension: fileURL.pathExtension)
            let mimeType = utType?.preferredMIMEType ?? "application/octet-stream"
            let caption = draftText
            draftText = ""

            try await chatStore.uploadAndSendAttachment(
                conversationId: conversationId,
                data: data,
                fileName: fileName,
                mimeType: mimeType,
                caption: caption
            )
        } catch {
            roomErrorMessage = error.localizedDescription
        }
    }
}

private struct ChatComposerBar: View {
    @Binding var draftText: String
    let isUploadingAttachment: Bool
    let isSendingText: Bool
    let onPickPhoto: () -> Void
    let onPickVideo: () -> Void
    let onPickFile: () -> Void
    let onOpenEmoji: () -> Void
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    private var canSend: Bool {
        !isSendingText && !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 4) {
            if isUploadingAttachment {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Đang tải tệp đính kèm lên máy chủ...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
            }

            HStack(alignment: .bottom, spacing: 4) {
                Menu {
                    Button(action: onPickPhoto) {
                        Label("Chọn gửi ảnh", systemImage: "photo")
                    }
                    Button(action: onPickVideo) {
                        Label("Chọn gửi video", systemImage: "video")
                    }
                    Divider()
                    Button(action: onPickFile) {
                        Label("Đính kèm tệp", systemImage: "paperclip")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.chatBLNPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .disabled(isUploadingAttachment)
                .accessibilityLabel("Đính kèm ảnh, video hoặc tệp")

                Button {
                    isFocused = false
                    onOpenEmoji()
                } label: {
                    Image(systemName: "face.smiling")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Chèn biểu tượng cảm xúc")

                TextField("Tin nhắn", text: $draftText, axis: .vertical)
                    .font(.body)
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        Color(.tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )

                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canSend ? Color.chatBLNPrimary : Color(.tertiaryLabel))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("Gửi tin nhắn")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}

private struct FullScreenImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let imageURL: URL
    @State private var zoomScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(zoomScale)
                            .gesture(
                                MagnifyGesture()
                                    .onChanged { value in
                                        zoomScale = min(max(value.magnification, 1.0), 4.0)
                                    }
                                    .onEnded { _ in
                                        if zoomScale < 1.05 {
                                            if reduceMotion {
                                                zoomScale = 1.0
                                            } else {
                                                withAnimation(.spring(duration: 0.22)) {
                                                    zoomScale = 1.0
                                                }
                                            }
                                        }
                                    }
                            )
                            .onTapGesture(count: 2) {
                                let target: CGFloat = zoomScale > 1.0 ? 1.0 : 2.2
                                if reduceMotion {
                                    zoomScale = target
                                } else {
                                    withAnimation(.spring(duration: 0.22)) {
                                        zoomScale = target
                                    }
                                }
                            }
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    case .failure:
                        Label("Không thể tải ảnh", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Đóng trình xem ảnh")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}
