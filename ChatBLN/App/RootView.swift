import SwiftUI

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var settings: AppSettings
    @Bindable var authViewModel: AuthViewModel
    @Bindable var chatStore: ChatStoreViewModel

    var body: some View {
        Group {
            if authViewModel.isRestoringSession {
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.chatBLNPrimary)
                            .frame(width: 52, height: 52)

                        Image(systemName: "bubble.left.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .accessibilityHidden(true)

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
        .animation(reduceMotion ? .linear(duration: 0.12) : .snappy(duration: 0.22), value: authViewModel.isAuthenticated)
        .task {
            await authViewModel.restoreSessionIfAvailable()
        }
    }
}
