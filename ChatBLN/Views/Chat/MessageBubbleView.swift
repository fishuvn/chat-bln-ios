import AVKit
import SwiftUI
import UIKit

struct MessageBubbleView: View {
    let message: MessageDto
    let isOutgoing: Bool
    let settings: AppSettings
    var showSenderHeader: Bool = true
    var isLastInSenderGroup: Bool = true
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onToggleSelect: (() -> Void)? = nil
    var onStartMultiSelect: (() -> Void)? = nil
    var onRequestDeleteSingle: (() -> Void)? = nil
    var onTapImage: ((URL) -> Void)?
    var onOpenGroupInvite: ((String) -> Void)? = nil

    @Environment(\.openURL) private var openURL
    @State private var videoPlayer: AVPlayer?

    private var attachmentURL: URL? {
        settings.resolveAssetURL(message.attachmentUrl)
    }

    private var kind: String {
        message.normalizedAttachmentKind
    }

    private var invitedGroupCode: String? {
        if let fromText = GroupInviteLinkParser.extractInviteCodeFromMessageText(message.content) {
            return fromText
        }
        if kind == "LINK", let fromAttachment = GroupInviteLinkParser.extractInviteCodeFromMessageText(message.attachmentUrl) {
            return fromAttachment
        }
        return nil
    }

    private var extractedLink: ExtractedMessageLink? {
        if kind == "LINK",
           let raw = message.attachmentUrl,
           let url = URL(string: raw) {
            let host = MarkdownMessageFormatter.cleanHost(from: url)
            let label = message.attachmentName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? host
            return ExtractedMessageLink(label: label.isEmpty ? host : label, url: url, host: host)
        }
        return MarkdownMessageFormatter.extractFirstLink(from: message.content)
    }

    private var shouldShowTextBody: Bool {
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if (kind == "IMAGE" || kind == "VIDEO" || kind == "FILE"), message.isAutoAttachmentCaption {
            return false
        }
        return true
    }

    private var bubbleShape: UnevenRoundedRectangle {
        let std: CGFloat = 16
        let tail: CGFloat = isLastInSenderGroup ? 4 : 16
        if isOutgoing {
            return UnevenRoundedRectangle(
                topLeadingRadius: std,
                bottomLeadingRadius: std,
                bottomTrailingRadius: tail,
                topTrailingRadius: std,
                style: .continuous
            )
        } else {
            return UnevenRoundedRectangle(
                topLeadingRadius: std,
                bottomLeadingRadius: tail,
                bottomTrailingRadius: std,
                topTrailingRadius: std,
                style: .continuous
            )
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if isSelectionMode {
                Button {
                    onToggleSelect?()
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.chatBLNPrimary : .secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSelected ? "Bỏ chọn tin nhắn" : "Chọn tin nhắn")
            }

            HStack(alignment: .bottom, spacing: 8) {
                if isOutgoing {
                    Spacer(minLength: 44)
                } else if isLastInSenderGroup {
                    AvatarView(
                        name: message.sender.displayName,
                        avatarURL: settings.resolveAssetURL(message.sender.avatarUrl),
                        size: 28
                    )
                    .accessibilityHidden(true)
                } else {
                    Color.clear
                        .frame(width: 28, height: 28)
                        .accessibilityHidden(true)
                }

                VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 3) {
                    if !isOutgoing && showSenderHeader {
                        Text(message.sender.displayName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if kind == "IMAGE", let imageURL = attachmentURL {
                            imageAttachmentView(url: imageURL)
                        } else if kind == "VIDEO", let videoURL = attachmentURL {
                            videoAttachmentView(url: videoURL)
                        } else if kind == "FILE", let fileURL = attachmentURL {
                            fileAttachmentCard(url: fileURL)
                        }

                        if shouldShowTextBody {
                            Text(
                                MarkdownMessageFormatter.makeAttributedString(
                                    from: message.content,
                                    isOutgoing: isOutgoing
                                )
                            )
                            .font(.body)
                            .foregroundStyle(isOutgoing ? Color.white : Color(.label))
                            .tint(isOutgoing ? Color.white : Color.chatBLNPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                        if let inviteCode = invitedGroupCode {
                            groupInviteActionCard(inviteCode: inviteCode)
                        } else if let link = extractedLink, kind != "IMAGE", kind != "VIDEO", kind != "FILE" {
                            linkPreviewCard(link: link)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        isOutgoing ? Color.chatBLNPrimary : Color(.secondarySystemGroupedBackground),
                        in: bubbleShape
                    )
                    .overlay {
                        if !isOutgoing {
                            bubbleShape
                                .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
                        }
                    }
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                        } label: {
                            Label("Sao chép nội dung", systemImage: "doc.on.doc")
                        }

                        if let inviteCode = invitedGroupCode, let onOpenGroupInvite {
                            Button {
                                onOpenGroupInvite(inviteCode)
                            } label: {
                                Label("Xem nhóm mời", systemImage: "person.2")
                            }
                        } else if let attachmentURL {
                            Button {
                                openURL(attachmentURL)
                            } label: {
                                Label("Mở liên kết tệp", systemImage: "safari")
                            }
                        }

                        if let onStartMultiSelect {
                            Button {
                                onStartMultiSelect()
                            } label: {
                                Label("Chọn nhiều tin nhắn...", systemImage: "checkmark.circle")
                            }
                        }

                        if let onRequestDeleteSingle {
                            Divider()
                            Button(role: .destructive) {
                                onRequestDeleteSingle()
                            } label: {
                                Label("Xóa dòng tin nhắn", systemImage: "trash")
                            }
                        }
                    }

                    if isLastInSenderGroup {
                        let timeString = ChatDateFormatter.formatMessageTime(message.createdAt)
                        if !timeString.isEmpty {
                            Text(timeString)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                        }
                    }
                }

                if !isOutgoing {
                    Spacer(minLength: 44)
                }
            }
            .allowsHitTesting(!isSelectionMode)
        }
        .padding(.vertical, isSelectionMode ? 2 : 0)
        .padding(.horizontal, isSelectionMode ? 4 : 0)
        .background(
            isSelected ? Color.chatBLNPrimary.opacity(0.1) : Color.clear,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onToggleSelect?()
            }
        }
    }

    private func groupInviteActionCard(inviteCode: String) -> some View {
        Button {
            onOpenGroupInvite?(inviteCode)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.2.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isOutgoing ? Color.white : Color.chatBLNPrimary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Lời mời tham gia nhóm")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(isOutgoing ? Color.white : Color(.label))
                        .lineLimit(1)

                    Text("Xem nhóm mời · \(inviteCode)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(isOutgoing ? Color.white.opacity(0.85) : Color(.secondaryLabel))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Text("Xem")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isOutgoing ? Color.chatBLNPrimary : Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        isOutgoing ? Color.white : Color.chatBLNPrimary,
                        in: Capsule()
                    )
            }
            .padding(10)
            .frame(maxWidth: 265, minHeight: 44)
            .background(
                isOutgoing ? Color.black.opacity(0.14) : Color(.tertiarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Xem nhóm mời mã \(inviteCode)")
    }

    private func imageAttachmentView(url: URL) -> some View {
        Button {
            onTapImage?(url)
        } label: {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 240, maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.tertiarySystemFill))
                            .frame(width: 210, height: 160)
                        ProgressView()
                    }
                case .failure:
                    HStack(spacing: 8) {
                        Image(systemName: "photo.badge.exclamationmark")
                        Text("Không tải được ảnh")
                            .font(.footnote)
                    }
                    .foregroundStyle(isOutgoing ? .white : .secondary)
                    .padding(8)
                @unknown default:
                    EmptyView()
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Xem ảnh đính kèm toàn màn hình")
    }

    private func videoAttachmentView(url: URL) -> some View {
        VideoPlayer(player: videoPlayer)
            .frame(width: 240, height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onAppear {
                if videoPlayer == nil {
                    videoPlayer = AVPlayer(url: url)
                }
            }
            .onDisappear {
                videoPlayer?.pause()
            }
            .accessibilityLabel("Trình phát video đính kèm")
    }

    private func fileAttachmentCard(url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isOutgoing ? Color.white.opacity(0.2) : Color(.tertiarySystemFill))
                        .frame(width: 40, height: 40)
                    Image(systemName: "doc.text")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isOutgoing ? Color.white : Color.chatBLNPrimary)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(message.attachmentName ?? "Tệp đính kèm")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isOutgoing ? Color.white : Color(.label))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let size = message.attachmentSize, !size.isEmpty {
                        Text(size)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(isOutgoing ? Color.white.opacity(0.82) : Color(.secondaryLabel))
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(isOutgoing ? Color.white.opacity(0.9) : Color(.secondaryLabel))
                    .accessibilityHidden(true)
            }
            .padding(10)
            .frame(maxWidth: 250, minHeight: 44)
            .background(
                isOutgoing ? Color.black.opacity(0.14) : Color(.tertiarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mở tệp đính kèm \(message.attachmentName ?? "")")
    }

    private func linkPreviewCard(link: ExtractedMessageLink) -> some View {
        Button {
            openURL(link.url)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isOutgoing ? Color.white : Color.chatBLNPrimary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(link.label)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(isOutgoing ? Color.white : Color(.label))
                        .lineLimit(1)

                    Text(link.host)
                        .font(.caption2)
                        .foregroundStyle(isOutgoing ? Color.white.opacity(0.8) : Color(.secondaryLabel))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isOutgoing ? Color.white.opacity(0.8) : Color(.secondaryLabel))
                    .accessibilityHidden(true)
            }
            .padding(10)
            .frame(maxWidth: 250, minHeight: 44)
            .background(
                isOutgoing ? Color.black.opacity(0.14) : Color(.tertiarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mở liên kết \(link.label) trên \(link.host)")
    }
}
