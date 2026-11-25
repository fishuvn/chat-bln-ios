import SwiftUI

@main
struct ChatBLNApp: App {
    @State private var settings: AppSettings
    @State private var authViewModel: AuthViewModel
    @State private var chatStore: ChatStoreViewModel

    init() {
        let appSettings = AppSettings()
        let apiClient = APIClient(settings: appSettings)
        let authVM = AuthViewModel(settings: appSettings, apiClient: apiClient)
        let storeVM = ChatStoreViewModel(settings: appSettings, apiClient: apiClient)

        apiClient.onUnauthorized = { [weak authVM, weak storeVM] in
            storeVM?.resetSession()
            authVM?.handleUnauthorizedSession()
        }

        _settings = State(initialValue: appSettings)
        _authViewModel = State(initialValue: authVM)
        _chatStore = State(initialValue: storeVM)
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                settings: settings,
                authViewModel: authViewModel,
                chatStore: chatStore
            )
            .preferredColorScheme(settings.appearanceMode.colorScheme)
            .tint(.chatBLNPrimary)
        }
    }
}
