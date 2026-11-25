import SwiftUI

struct RootView: View {
    @Bindable var settings: AppSettings
    @Bindable var authViewModel: AuthViewModel
    @Bindable var chatStore: ChatStoreViewModel

    var body: some View {
        Group {
            if authViewModel.isRestoringSession {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(Color.chatBLNPrimary)
                    ProgressView("Đang khôi phục phiên đăng nhập...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else if authViewModel.isAuthenticated {
                MainTabView(
                    settings: settings,
                    authViewModel: authViewModel,
                    chatStore: chatStore
                )
                .task(id: authViewModel.sessionToken) {
                    if let token = authViewModel.sessionToken,
                       let username = authViewModel.currentProfile?.username ?? settings.cachedUser?.username {
                        await chatStore.bootstrapSession(token: token, currentUsername: username)
                    }
                }
            } else {
                LoginView(
                    settings: settings,
                    authViewModel: authViewModel
                )
            }
        }
        .animation(.snappy(duration: 0.25), value: authViewModel.isAuthenticated)
        .task {
            await authViewModel.restoreSessionIfAvailable()
        }
    }
}
