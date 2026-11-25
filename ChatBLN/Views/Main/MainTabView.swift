import SwiftUI

struct MainTabView: View {
    @Bindable var settings: AppSettings
    @Bindable var authViewModel: AuthViewModel
    @Bindable var chatStore: ChatStoreViewModel

    var body: some View {
        TabView(selection: $chatStore.selectedTab) {
            ConversationsListView(
                settings: settings,
                authViewModel: authViewModel,
                chatStore: chatStore
            )
            .tabItem {
                Label("Đoạn chat", systemImage: "bubble.left.and.bubble.right")
            }
            .badge(chatStore.totalUnreadMessages)
            .tag(MainAppTab.conversations)

            ContactsView(
                settings: settings,
                chatStore: chatStore
            )
            .tabItem {
                Label("Danh bạ", systemImage: "person.2")
            }
            .tag(MainAppTab.contacts)

            FriendRequestsView(
                settings: settings,
                chatStore: chatStore
            )
            .tabItem {
                Label("Lời mời", systemImage: "person.badge.plus")
            }
            .badge(chatStore.receivedRequests.count)
            .tag(MainAppTab.requests)

            ProfileView(
                settings: settings,
                authViewModel: authViewModel,
                chatStore: chatStore
            )
            .tabItem {
                Label("Hồ sơ", systemImage: "person.crop.circle")
            }
            .tag(MainAppTab.profile)
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(.chatBLNPrimary)
    }
}
