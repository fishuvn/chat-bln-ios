import Foundation
import Observation

@MainActor
@Observable
final class AuthViewModel {
    let settings: AppSettings
    let apiClient: APIClient

    var currentProfile: UserProfileResponse?
    var sessionToken: String?
    var isRestoringSession: Bool = true
    var isSubmitting: Bool = false
    var errorMessage: String?

    var isAuthenticated: Bool {
        guard let sessionToken else { return false }
        return !sessionToken.isEmpty
    }

    init(settings: AppSettings, apiClient: APIClient) {
        self.settings = settings
        self.apiClient = apiClient
    }

    func restoreSessionIfAvailable() async {
        defer { isRestoringSession = false }

        guard let savedToken = KeychainService.readToken(), !savedToken.isEmpty else {
            sessionToken = nil
            currentProfile = nil
            return
        }

        if let cached = settings.cachedUser {
            currentProfile = UserProfileResponse(
                id: cached.id,
                username: cached.username,
                fullName: cached.fullName,
                email: cached.email,
                phone: cached.phone,
                gender: cached.gender,
                dob: cached.dob,
                bio: cached.bio,
                avatarUrl: cached.avatarUrl,
                isOnline: true,
                lastSeen: nil
            )
        }

        do {
            let profile = try await apiClient.getMyProfile()
            applyProfile(profile)
            sessionToken = savedToken
        } catch APIClientError.unauthorized {
            handleUnauthorizedSession()
        } catch {
            // Giữ phiên tạm đã lưu trong Keychain nếu máy chủ đang khởi động lại
            sessionToken = savedToken
        }
    }

    func login(username: String, password: String) async -> Bool {
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUsername.isEmpty, !password.isEmpty else {
            errorMessage = "Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu."
            return false
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let auth = try await apiClient.login(username: cleanUsername, password: password)
            KeychainService.saveToken(auth.token)

            let fallback = UserProfileResponse(
                id: auth.id,
                username: auth.username,
                fullName: auth.fullName,
                email: nil,
                phone: nil,
                gender: nil,
                dob: nil,
                bio: nil,
                avatarUrl: nil,
                isOnline: true,
                lastSeen: nil
            )
            // Gán hồ sơ người dùng TRƯỚC khi bật sessionToken để MainTabView có ngay username tải hội thoại
            applyProfile(fallback)
            if let profile = try? await apiClient.getMyProfile() {
                applyProfile(profile)
            }
            sessionToken = auth.token
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func register(_ request: RegisterRequest) async -> Bool {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            let auth = try await apiClient.register(request)
            KeychainService.saveToken(auth.token)

            let fallback = UserProfileResponse(
                id: auth.id,
                username: auth.username,
                fullName: auth.fullName ?? request.fullName,
                email: request.email,
                phone: request.phone,
                gender: request.gender,
                dob: request.dob,
                bio: request.bio,
                avatarUrl: nil,
                isOnline: true,
                lastSeen: nil
            )
            applyProfile(fallback)
            if let profile = try? await apiClient.getMyProfile() {
                applyProfile(profile)
            }
            sessionToken = auth.token
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func refreshProfile() async {
        guard isAuthenticated else { return }
        if let profile = try? await apiClient.getMyProfile() {
            applyProfile(profile)
        }
    }

    func updateProfile(_ payload: UpdateProfileRequest) async throws {
        let updated = try await apiClient.updateMyProfile(payload)
        applyProfile(updated)
    }

    func uploadAndSaveAvatar(data: Data, fileName: String, mimeType: String) async throws {
        let uploaded = try await apiClient.uploadFile(data: data, fileName: fileName, mimeType: mimeType)
        let current = currentProfile
        let updatePayload = UpdateProfileRequest(
            fullName: current?.fullName,
            email: current?.email,
            phone: current?.phone,
            gender: current?.gender,
            dob: current?.dob,
            bio: current?.bio,
            avatarUrl: uploaded.url
        )
        let updated = try await apiClient.updateMyProfile(updatePayload)
        applyProfile(updated)
    }

    func signOut(chatStore: ChatStoreViewModel) async {
        _ = try? await apiClient.logout()
        chatStore.resetSession()
        KeychainService.deleteToken()
        settings.cachedUser = nil
        currentProfile = nil
        sessionToken = nil
        errorMessage = nil
    }

    func handleUnauthorizedSession() {
        KeychainService.deleteToken()
        settings.cachedUser = nil
        currentProfile = nil
        sessionToken = nil
    }

    private func applyProfile(_ profile: UserProfileResponse) {
        currentProfile = profile
        settings.cachedUser = CachedSessionUser(
            id: profile.id,
            username: profile.username,
            fullName: profile.displayName,
            email: profile.email,
            phone: profile.phone,
            gender: profile.gender,
            dob: profile.dob,
            bio: profile.bio,
            avatarUrl: profile.avatarUrl
        )
    }
}
