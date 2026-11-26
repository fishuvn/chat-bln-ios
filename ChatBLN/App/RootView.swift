import SwiftUI

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var settings: AppSettings
    @Bindable var authViewModel: AuthViewModel
    @Bindable var chatStore: ChatStoreViewModel
    @State private var updateChecker = AppUpdateChecker.shared

    var body: some View {
        VStack(spacing: 0) {
            if updateChecker.shouldShowBanner, let info = updateChecker.latestInfo {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(Color.chatBLNPrimary)
                    Text("Có bản cập nhật mới \(info.latestTag)")
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Button("Xem & Tải") {
                        updateChecker.showUpdateSheet = true
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.chatBLNPrimary)

                    Button {
                        updateChecker.bannerDismissed = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Đóng thông báo cập nhật")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground))
                Divider()
            }

            Group {
                if authViewModel.isRestoringSession {
                    VStack(spacing: 14) {
                        ChatBLNBrandMark(size: 60)

                        ProgressView("Đang khôi phục phiên đăng nhập...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else if authViewModel.isAuthenticated {
                    let activeUsername = authViewModel.currentProfile?.username ?? settings.cachedUser?.username ?? ""
                    MainTabView(
                        settings: settings,
                        authViewModel: authViewModel,
                        chatStore: chatStore
                    )
                    .task(id: "\(authViewModel.sessionToken ?? "")|\(activeUsername)|\(settings.normalizedBaseURL)") {
                        if let token = authViewModel.sessionToken, !token.isEmpty, !activeUsername.isEmpty {
                            await chatStore.bootstrapSession(token: token, currentUsername: activeUsername)
                        }
                    }
                } else {
                    LoginView(
                        settings: settings,
                        authViewModel: authViewModel
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(reduceMotion ? .linear(duration: 0.12) : .snappy(duration: 0.22), value: authViewModel.isAuthenticated)
        .sheet(isPresented: $updateChecker.showUpdateSheet) {
            if let info = updateChecker.latestInfo {
                UpdateDetailsSheet(info: info)
            }
        }
        .task {
            await authViewModel.restoreSessionIfAvailable()
        }
        .task {
            await updateChecker.checkForUpdates(openSheetIfDone: false)
        }
    }
}
