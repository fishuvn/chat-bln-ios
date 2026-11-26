import SwiftUI

struct FriendRequestsView: View {
    @Bindable var settings: AppSettings
    @Bindable var chatStore: ChatStoreViewModel

    private enum RequestSegment: String, CaseIterable, Identifiable {
        case received = "Đã nhận"
        case sent = "Đã gửi"

        var id: String { rawValue }
    }

    @State private var selectedSegment: RequestSegment = .received
    @State private var processingIds: Set<Int64> = []
    @State private var feedbackMessage: String?
    @State private var isFeedbackError: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Loại lời mời", selection: $selectedSegment) {
                    Text("Đã nhận (\(chatStore.receivedRequests.count))")
                        .monospacedDigit()
                        .tag(RequestSegment.received)
                    Text("Đã gửi (\(chatStore.sentRequests.count))")
                        .monospacedDigit()
                        .tag(RequestSegment.sent)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if let feedbackMessage {
                    HStack(spacing: 8) {
                        Image(
                            systemName: isFeedbackError
                                ? "exclamationmark.triangle.fill"
                                : "checkmark.circle.fill"
                        )
                        .foregroundStyle(isFeedbackError ? Color(.systemRed) : Color(.systemGreen))
                        .accessibilityHidden(true)

                        Text(feedbackMessage)
                            .font(.footnote)
                            .foregroundStyle(isFeedbackError ? Color(.systemRed) : .primary)

                        Spacer()

                        Button {
                            self.feedbackMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Đóng thông báo")
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 6)
                    .background(Color(.secondarySystemGroupedBackground))
                    .overlay(alignment: .bottom) {
                        Divider()
                    }
                }

                contentList
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Lời mời")
            .refreshable {
                await chatStore.loadFriendRequests()
            }
        }
    }

    @ViewBuilder
    private var contentList: some View {
        switch selectedSegment {
        case .received:
            if chatStore.receivedRequests.isEmpty {
                ContentUnavailableView(
                    "Không có lời mời mới",
                    systemImage: "envelope.open",
                    description: Text("Khi có người gửi lời mời kết bạn cho bạn, lời mời sẽ hiển thị tại đây.")
                )
            } else {
                List(chatStore.receivedRequests) { req in
                    receivedRequestRow(req)
                }
                .listStyle(.insetGrouped)
            }

        case .sent:
            if chatStore.sentRequests.isEmpty {
                ContentUnavailableView(
                    "Chưa gửi lời mời nào",
                    systemImage: "paperplane",
                    description: Text("Các lời mời kết bạn đang chờ phản hồi sẽ được liệt kê tại đây.")
                )
            } else {
                List(chatStore.sentRequests) { req in
                    sentRequestRow(req)
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private func receivedRequestRow(_ request: FriendshipResponse) -> some View {
        let isBusy = processingIds.contains(request.id)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AvatarView(
                    name: request.requesterDisplayName,
                    avatarURL: settings.resolveAssetURL(request.requesterAvatarUrl),
                    size: 48
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(request.requesterDisplayName)
                        .font(.body.weight(.semibold))

                    if let username = request.requesterUsername, !username.isEmpty {
                        Text("@\(username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    let createdTime = ChatDateFormatter.formatConversationTime(request.createdAt)
                    if !createdTime.isEmpty {
                        Text("Gửi lúc \(createdTime)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    Task {
                        await handleAccept(request)
                    }
                } label: {
                    Text("Chấp nhận")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.borderedProminent)
                .tint(.chatBLNPrimary)
                .disabled(isBusy)

                Button(role: .destructive) {
                    Task {
                        await handleReject(request)
                    }
                } label: {
                    Text("Từ chối")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)
            }
        }
        .padding(.vertical, 4)
    }

    private func sentRequestRow(_ request: FriendshipResponse) -> some View {
        let isBusy = processingIds.contains(request.id)

        return HStack(spacing: 12) {
            AvatarView(
                name: request.addresseeDisplayName,
                avatarURL: settings.resolveAssetURL(request.addresseeAvatarUrl),
                size: 46
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(request.addresseeDisplayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if let username = request.addresseeUsername, !username.isEmpty {
                    Text("@\(username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                let createdTime = ChatDateFormatter.formatConversationTime(request.createdAt)
                Text(createdTime.isEmpty ? "Đang chờ xác nhận" : "Đã gửi · \(createdTime)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button(role: .destructive) {
                Task {
                    await handleCancelSent(request)
                }
            } label: {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Thu hồi")
                        .font(.caption.weight(.semibold))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(minHeight: 36)
            .disabled(isBusy)
        }
        .padding(.vertical, 4)
    }

    private func handleAccept(_ request: FriendshipResponse) async {
        processingIds.insert(request.id)
        defer { processingIds.remove(request.id) }

        do {
            try await chatStore.acceptFriendRequest(request.id)
            isFeedbackError = false
            feedbackMessage = "Đã chấp nhận lời mời của \(request.requesterDisplayName)."
        } catch {
            isFeedbackError = true
            feedbackMessage = error.localizedDescription
        }
    }

    private func handleReject(_ request: FriendshipResponse) async {
        processingIds.insert(request.id)
        defer { processingIds.remove(request.id) }

        do {
            try await chatStore.rejectFriendRequest(request.id)
            isFeedbackError = false
            feedbackMessage = "Đã từ chối lời mời kết bạn."
        } catch {
            isFeedbackError = true
            feedbackMessage = error.localizedDescription
        }
    }

    private func handleCancelSent(_ request: FriendshipResponse) async {
        processingIds.insert(request.id)
        defer { processingIds.remove(request.id) }

        do {
            try await chatStore.cancelSentFriendRequest(request.id)
            isFeedbackError = false
            feedbackMessage = "Đã thu hồi lời mời kết bạn tới \(request.addresseeDisplayName)."
        } catch {
            isFeedbackError = true
            feedbackMessage = error.localizedDescription
        }
    }
}
