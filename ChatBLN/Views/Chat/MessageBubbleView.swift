import AVKit
import SwiftUI
import UIKit

struct MessageBubbleView: View {
    let message: MessageDto
    let isOutgoing: Bool
    let settings: AppSettings
    var onTapImage: ((URL) -> Void)?

    @Environment(\.openURL) private var openURL
    @State private var videoPlayer: AVPlayer?

    private var attachmentURL: URL? {
        settings.resolveAssetURL(message.attachmentUrl)
    }

    private var kind: String {
        message.normalizedAttachmentKind
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

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOutgoing {
                Spacer(minLength: 48)
            } else {
                AvatarView(
                    name: message.sender.displayName,
                    avatarURL: settings.resolveAssetURL(message.sender.avatarUrl),
                    size: 30
                )
            }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
                if !isOutgoing {
                    Text(message.sender.displayName)
                        .font(.caption.weight(.semibold))
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
                        .foregroundStyle(isOutgoing ? Color.white : Color.primary)
                        .tint(isOutgoing ? Color.white : Color.chatBLNPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    if let link = extractedLink, kind != "IMAGE", kind != "VIDEO", kind != "FILE" {
                        linkPreviewCard(link: link)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    isOutgoing ? Color.chatBLNPrimary : Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = message.content
                    } label: {
                        Label("Sao chép nội dung", systemImage: "doc.on.doc")
                    }

                    if let attachmentURL {
                        Button {
                            openURL(attachmentURL)
                        } label: {
                            Label("Mở liên kết tệp", systemImage: "safari")
                        }
                    }
                }

                let timeString = ChatDateFormatter.formatMessageTime(message.createdAt)
                if !timeString.isEmpty {
                    Text(timeString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }

            if !isOutgoing {
                Spacer(minLength: 48)
            }
        }
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
                            .fill(Color.black.opacity(0.08))
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
        .accessibilityLabel("Xem ảnh toàn màn hình")
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
    }

    private func fileAttachmentCard(url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isOutgoing ? Color.white.opacity(0.2) : Color.chatBLNPrimary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isOutgoing ? Color.white : Color.chatBLNPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(message.attachmentName ?? "Tệp đính kèm")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isOutgoing ? Color.white : Color.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let size = message.attachmentSize, !size.isEmpty {
                        Text(size)
                            .font(.caption2)
                            .foregroundStyle(isOutgoing ? Color.white.opacity(0.82) : Color.secondary)
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.up.right.square")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(isOutgoing ? Color.white.opacity(0.9) : Color.secondary)
            }
            .padding(10)
            .frame(maxWidth: 250)
            .background(
                isOutgoing ? Color.black.opacity(0.14) : Color(.tertiarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private func linkPreviewCard(link: ExtractedMessageLink) -> some View {
        Button {
            openURL(link.url)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "link.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isOutgoing ? Color.white : Color.chatBLNPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(link.label)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(isOutgoing ? Color.white : Color.primary)
                        .lineLimit(1)

                    Text(link.host)
                        .font(.caption2)
                        .foregroundStyle(isOutgoing ? Color.white.opacity(0.8) : Color.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isOutgoing ? Color.white.opacity(0.8) : Color.secondary)
            }
            .padding(9)
            .frame(maxWidth: 250)
            .background(
                isOutgoing ? Color.black.opacity(0.14) : Color(.tertiarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}
