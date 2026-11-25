import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

private struct FullScreenImageItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct ChatRoomView: View {
    let conversationId: Int64
    let fallbackConversation: ConversationItemResponse
    @Bindable var settings: AppSettings
    @Bindable var chatStore: ChatStoreViewModel

    @State private var draftText: String = ""
    @State private var isSearchBarVisible: Bool = false
    @State private var inChatSearchQuery: String = ""
    @State private var showEmojiSheet: Bool = false
    @State private var showInfoSheet: Bool = false

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
    @FocusState private var isComposerFocused: Bool

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

    var body: some View {
        VStack(spacing: 0) {
            if isSearchBarVisible {
                inChatSearchHeader
                Divider()
            }

            if let roomErrorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(roomErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        self.roomErrorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.08))
            }

            messagesScrollArea

            Divider()

            if isSelectingMessages {
                selectionBottomBar
            } else if conversation.isUnfriendedPrivate {
                unfriendedBottomBar
            } else {
                composerBar
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                headerTitleButton
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        isSelectingMessages.toggle()
                        if !isSelectingMessages {
                            selectedMessageIds.removeAll()
                        }
                    }
                } label: {
                    Image(systemName: isSelectingMessages ? "checkmark.circle.fill" : "checkmark.circle")
                }
                .accessibilityLabel("Chọn nhiều tin nhắn")

                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        isSearchBarVisible.toggle()
                        if !isSearchBarVisible {
                            inChatSearchQuery = ""
                        }
                    }
                } label: {
                    Image(systemName: isSearchBarVisible ? "magnifyingglass.circle.fill" : "magnifyingglass")
                }
                .accessibilityLabel("Tìm trong cuộc trò chuyện")

                Button {
                    showInfoSheet = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("Thông tin cuộc trò chuyện")
            }
        }
        .confirmationDialog(
            pendingDeleteMessageIds.count == 1
                ? "Chọn cách xóa dòng tin nhắn này"
                : "Chọn cách xóa \(pendingDeleteMessageIds.count) tin nhắn đã chọn",
            isPresented: $showDeleteMessageDialog,
            titleVisibility: .visible
        ) {
            if canDeletePendingForEveryone {
                Button("Thu hồi / Xóa với mọi người", role: .destructive) {
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
            Button("Huỷ", role: .cancel) {
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
                    isOnline: conversation.isGroup ? nil : (conversation.isOnline ?? false)
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(conversation.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(subtitleStatusText)
                        .font(.caption2)
                        .foregroundStyle(conversation.isOnline == true ? Color.green : .secondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var subtitleStatusText: String {
        if conversation.isGroup {
            let loadedCount = chatStore.groupMembersByConversation[conversationId]?.count
            let count = loadedCount ?? conversation.memberCount ?? 0
            return count > 0 ? "\(count) thành viên" : "Nhóm trò chuyện"
        }
        return ChatDateFormatter.formatPresenceStatus(
            isOnline: conversation.isOnline,
            lastSeen: conversation.lastSeen
        )
    }

    private var inChatSearchHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Tìm nội dung hoặc tên tệp...", text: $inChatSearchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !inChatSearchQuery.isEmpty {
                Button {
                    inChatSearchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    private var messagesScrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
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
                                    Image(systemName: "arrow.up.circle")
                                }
                                Text("Tải tin nhắn cũ hơn")
                                    .font(.footnote.weight(.medium))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                        }
                        .padding(.top, 4)
                    }

                    if chatStore.loadingMessagesConversationIds.contains(conversationId) && allMessages.isEmpty {
                        ProgressView("Đang tải lịch sử tin nhắn...")
                            .padding(.top, 48)
                    } else if visibleMessages.isEmpty {
                        ContentUnavailableView(
                            isSearchBarVisible && !inChatSearchQuery.isEmpty
                                ? "Không khớp tin nhắn nào"
                                : "Chưa có tin nhắn",
                            systemImage: isSearchBarVisible && !inChatSearchQuery.isEmpty
                                ? "magnifyingglass"
                                : "hand.wave.fill",
                            description: Text(
                                isSearchBarVisible && !inChatSearchQuery.isEmpty
                                    ? "Thử từ khoá khác trong cuộc trò chuyện."
                                    : "Hãy gửi lời chào đầu tiên hoặc chia sẻ ảnh, video, tài liệu."
                            )
                        )
                        .padding(.top, 48)
                    } else {
                        ForEach(visibleMessages) { msg in
                            let isOutgoing = msg.sender.username.lowercased() == chatStore.currentUsername.lowercased()
                            MessageBubbleView(
                                message: msg,
                                isOutgoing: isOutgoing,
                                settings: settings,
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
                                    withAnimation(.snappy(duration: 0.2)) {
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
                                }
                            )
                            .id(msg.id)
                        }
                    }

                    Color.clear
                        .frame(height: 2)
                        .id("CHAT_BOTTOM_ANCHOR")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: allMessages.last?.id) { _, _ in
                withAnimation(.easeOut(duration: 0.22)) {
                    proxy.scrollTo("CHAT_BOTTOM_ANCHOR", anchor: .bottom)
                }
            }
            .onAppear {
                proxy.scrollTo("CHAT_BOTTOM_ANCHOR", anchor: .bottom)
            }
        }
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
            }

            Spacer()

            Text("Đã chọn \(selectedMessageIds.count)")
                .font(.subheadline.weight(.medium))
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
                        Image(systemName: "trash.fill")
                    }
                    Text("Xóa (\(selectedMessageIds.count))")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(selectedMessageIds.isEmpty || isDeletingMessages)

            Button("Xong") {
                withAnimation(.snappy(duration: 0.2)) {
                    isSelectingMessages = false
                    selectedMessageIds.removeAll()
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
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

            Text("Hai bạn hiện không còn là bạn bè. Hãy kết bạn lại để tiếp tục gửi tin nhắn.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if conversation.friendshipStatus?.uppercased() == "PENDING" {
                Text("Đã gửi lời mời")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chatBLNPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.chatBLNPrimary.opacity(0.12), in: Capsule())
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
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.chatBLNPrimary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private var composerBar: some View {
        VStack(spacing: 6) {
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

            HStack(alignment: .bottom, spacing: 8) {
                attachmentMenuButton

                Button {
                    isComposerFocused = false
                    showEmojiSheet = true
                } label: {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.chatBLNPrimary)
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Mở bảng biểu tượng cảm xúc")

                TextField("Nhập tin nhắn hoặc [Nhãn](https://...)", text: $draftText, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($isComposerFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )

                Button {
                    Task {
                        await sendCurrentDraft()
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSendDraft ? Color.chatBLNPrimary : Color(.systemGray3))
                        .frame(width: 40, height: 40)
                }
                .disabled(!canSendDraft)
                .accessibilityLabel("Gửi tin nhắn")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
    }

    private var attachmentMenuButton: some View {
        Menu {
            Button {
                showPhotoPicker = true
            } label: {
                Label("Chọn gửi ảnh", systemImage: "photo.on.rectangle")
            }

            Button {
                showVideoPicker = true
            } label: {
                Label("Chọn gửi video", systemImage: "video.fill")
            }

            Divider()

            Button {
                showFileImporter = true
            } label: {
                Label("Đính kèm tệp", systemImage: "paperclip")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(Color.chatBLNPrimary)
                .frame(width: 40, height: 40)
        }
        .disabled(isUploadingAttachment)
        .accessibilityLabel("Menu đính kèm ảnh, video hoặc tệp")
    }

    private var canSendDraft: Bool {
        !isSendingText && !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            let mimeType = contentType?.preferredMIMEType ?? fallbackMime
            let ext = contentType?.preferredFilenameExtension ?? fallbackExtension
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "media_\(timestamp).\(ext)"
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

private struct FullScreenImageViewer: View {
    @Environment(\.dismiss) private var dismiss
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
                                        withAnimation(.spring(duration: 0.25)) {
                                            if zoomScale < 1.05 {
                                                zoomScale = 1.0
                                            }
                                        }
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(duration: 0.25)) {
                                    zoomScale = zoomScale > 1.0 ? 1.0 : 2.2
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
                    }
                    .accessibilityLabel("Đóng trình xem ảnh")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}
