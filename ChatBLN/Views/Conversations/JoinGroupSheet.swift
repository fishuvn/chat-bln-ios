import SwiftUI
import UIKit

struct JoinGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: AppSettings
    @Bindable var chatStore: ChatStoreViewModel
    var initialInput: String? = nil

    @State private var inviteInput: String = ""
    @State private var preview: GroupInvitePreviewResponse?
    @State private var isLoadingPreview: Bool = false
    @State private var isJoining: Bool = false
    @State private var errorMessage: String?
    @State private var successBanner: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "https://chat-bln.fishu.io.vn/join/grp_xxx hoặc grp_xxx",
                        text: $inviteInput,
                        axis: .vertical
                    )
                    .lineLimit(1...3)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.subheadline.monospaced())
                    .onChange(of: inviteInput) { _, _ in
                        errorMessage = nil
                    }

                    HStack(spacing: 12) {
                        Button {
                            if let pasted = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                               !pasted.isEmpty {
                                inviteInput = pasted
                                Task {
                                    await loadPreview()
                                }
                            }
                        } label: {
                            Label("Dán link / mã", systemImage: "doc.on.clipboard")
                                .font(.subheadline.weight(.medium))
                                .frame(minHeight: 36)
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button {
                            Task {
                                await loadPreview()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if isLoadingPreview {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "magnifyingglass")
                                }
                                Text("Kiểm tra nhóm")
                                    .fontWeight(.semibold)
                            }
                            .frame(minHeight: 36)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.chatBLNPrimary)
                        .disabled(isLoadingPreview)
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("Link mời hoặc mã nhóm")
                } footer: {
                    Text("Dán đường dẫn https://chat-bln.fishu.io.vn/join/grp_... hoặc nhập trực tiếp mã mời bắt đầu bằng grp_.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color(.systemRed))
                    }
                }

                if let successBanner {
                    Section {
                        Label(successBanner, systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color(.systemGreen))
                    }
                }

                if let preview {
                    Section("Thông tin nhóm mời") {
                        VStack(spacing: 14) {
                            AvatarView(
                                name: preview.name,
                                avatarURL: nil,
                                size: 64,
                                isGroup: true
                            )

                            VStack(spacing: 6) {
                                Text(preview.name)
                                    .font(.title3.weight(.bold))
                                    .multilineTextAlignment(.center)

                                HStack(spacing: 8) {
                                    visibilityBadge(preview.resolvedVisibility)

                                    Label("\(preview.memberCount) thành viên", systemImage: "person.2")
                                        .font(.caption.weight(.medium).monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(Color(.tertiarySystemFill), in: Capsule())
                                }

                                Text("Mã mời: \(preview.inviteCode)")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.tertiary)
                            }

                            Text(preview.resolvedVisibility.helperCaption)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 6)

                            joinActionButton(for: preview)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Tham gia nhóm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        dismiss()
                    }
                }
            }
            .task {
                if let initialInput,
                   !initialInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   inviteInput.isEmpty {
                    inviteInput = initialInput
                    await loadPreview()
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func visibilityBadge(_ visibility: GroupVisibility) -> some View {
        let isPublic = visibility == .publicGroup
        return Label(visibility.title, systemImage: visibility.iconName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isPublic ? Color(.systemGreen) : Color(.secondaryLabel))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color(.tertiarySystemFill), in: Capsule())
    }

    @ViewBuilder
    private func joinActionButton(for item: GroupInvitePreviewResponse) -> some View {
        if item.isAlreadyJoined {
            Button {
                Task {
                    await openJoinedConversation(conversationId: item.conversationId)
                }
            } label: {
                Label("Mở nhóm trò chuyện", systemImage: "bubble.left.and.bubble.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.chatBLNPrimary)
        } else if item.isPendingApproval {
            Label("Đã gửi yêu cầu · Đang chờ Trưởng / Phó nhóm duyệt", systemImage: "clock.badge.checkmark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(.systemOrange))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            let isPublic = item.resolvedVisibility == .publicGroup
            Button {
                Task {
                    await executeJoin(using: item)
                }
            } label: {
                HStack(spacing: 8) {
                    if isJoining {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: isPublic ? "arrow.right.circle.fill" : "paperplane.fill")
                    }
                    Text(isPublic ? "Tham gia nhóm ngay" : "Gửi yêu cầu tham gia")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.chatBLNPrimary)
            .disabled(isJoining)
        }
    }

    private func loadPreview() async {
        errorMessage = nil
        successBanner = nil
        isLoadingPreview = true
        defer { isLoadingPreview = false }

        do {
            preview = try await chatStore.previewGroupInvite(rawInput: inviteInput)
        } catch {
            preview = nil
            errorMessage = error.localizedDescription
        }
    }

    private func executeJoin(using item: GroupInvitePreviewResponse) async {
        errorMessage = nil
        successBanner = nil
        isJoining = true
        defer { isJoining = false }

        do {
            let res = try await chatStore.joinGroupByInvite(inviteCode: item.inviteCode)
            switch res.normalizedStatus {
            case "JOINED", "ALREADY_MEMBER":
                await openJoinedConversation(conversationId: res.conversationId)
            case "PENDING_APPROVAL":
                var updated = item
                updated.joinStatus = "PENDING"
                preview = updated
                successBanner = res.message ?? "Đã gửi yêu cầu tham gia nhóm. Vui lòng chờ Trưởng nhóm hoặc Phó nhóm phê duyệt."
            default:
                successBanner = res.message ?? "Đã xử lý yêu cầu tham gia nhóm."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openJoinedConversation(conversationId: Int64) async {
        if chatStore.conversation(for: conversationId) == nil {
            await chatStore.loadConversations()
        }
        if let target = chatStore.conversation(for: conversationId) {
            dismiss()
            chatStore.openConversation(target)
        } else {
            dismiss()
        }
    }
}
