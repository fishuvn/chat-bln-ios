import SwiftUI

struct ConversationInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let conversation: ConversationItemResponse
    let messages: [MessageDto]
    let settings: AppSettings

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
                            name: conversation.displayName,
                            avatarURL: settings.resolveAssetURL(conversation.avatarUrl),
                            size: 80,
                            isGroup: conversation.isGroup,
                            isOnline: conversation.isGroup ? nil : (conversation.isOnline ?? false)
                        )

                        Text(conversation.displayName)
                            .font(.title3.weight(.bold))
                            .multilineTextAlignment(.center)

                        Text(statusSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(conversation.isOnline == true ? Color.green : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                if !conversation.isGroup {
                    Section("Thông tin liên hệ") {
                        if let username = conversation.targetUsername, !username.isEmpty {
                            LabeledContent("Username", value: "@\(username)")
                        }
                        if let email = conversation.email, !email.isEmpty {
                            LabeledContent("Email", value: email)
                        }
                        if let phone = conversation.phone, !phone.isEmpty {
                            LabeledContent("Điện thoại", value: phone)
                        }
                        if let gender = conversation.gender, !gender.isEmpty {
                            LabeledContent("Giới tính", value: gender)
                        }
                        if let dob = conversation.dob, !dob.isEmpty {
                            LabeledContent("Ngày sinh", value: dob)
                        }
                        if let bio = conversation.bio, !bio.isEmpty {
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
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var statusSubtitle: String {
        if conversation.isGroup {
            return "Nhóm trò chuyện"
        }
        return ChatDateFormatter.formatPresenceStatus(
            isOnline: conversation.isOnline,
            lastSeen: conversation.lastSeen
        )
    }
}
