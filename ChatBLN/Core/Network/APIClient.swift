import Foundation

enum APIClientError: LocalizedError, Sendable {
    case invalidURL(String)
    case unauthorized
    case serverError(statusCode: Int, message: String)
    case networkError(String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let raw):
            return "Địa chỉ máy chủ không hợp lệ: \(raw)"
        case .unauthorized:
            return "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."
        case .serverError(_, let message):
            return message
        case .networkError(let reason):
            return "Không thể kết nối máy chủ: \(reason)"
        case .decodingError(let detail):
            return "Dữ liệu phản hồi từ máy chủ không hợp lệ (\(detail))."
        }
    }
}

@MainActor
final class APIClient {
    private let settings: AppSettings
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    var onUnauthorized: (() -> Void)?

    init(settings: AppSettings) {
        self.settings = settings
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func resolveAssetURL(_ pathOrURL: String?) -> URL? {
        settings.resolveAssetURL(pathOrURL)
    }

    // MARK: - Health & Auth

    func checkHealth() async throws -> HealthResponse {
        try await request(path: "/api/health", method: "GET", requiresAuth: false)
    }

    func login(username: String, password: String) async throws -> AuthResponse {
        let body = LoginRequest(username: username, password: password)
        return try await request(
            path: "/api/auth/login",
            method: "POST",
            body: body,
            requiresAuth: false
        )
    }

    func register(_ payload: RegisterRequest) async throws -> AuthResponse {
        try await request(
            path: "/api/auth/register",
            method: "POST",
            body: payload,
            requiresAuth: false
        )
    }

    func logout() async throws -> LogoutResponse {
        try await request(
            path: "/api/auth/logout",
            method: "POST",
            body: EmptyRequestBody(),
            requiresAuth: true
        )
    }

    // MARK: - Profile & Users

    func getMyProfile() async throws -> UserProfileResponse {
        try await request(path: "/api/users/me", method: "GET")
    }

    func updateMyProfile(_ payload: UpdateProfileRequest) async throws -> UserProfileResponse {
        try await request(path: "/api/users/me", method: "PUT", body: payload)
    }

    func searchUsers(keyword: String) async throws -> [UserSearchResponse] {
        try await request(
            path: "/api/users/search",
            method: "GET",
            queryItems: [URLQueryItem(name: "keyword", value: keyword)]
        )
    }

    // MARK: - Conversations & Messages

    func getConversations() async throws -> [ConversationItemResponse] {
        try await request(path: "/api/conversations", method: "GET")
    }

    func createPrivateConversation(targetUserId: Int64) async throws -> ConversationResponse {
        try await request(
            path: "/api/conversations/private",
            method: "POST",
            body: CreatePrivateConversationRequest(targetUserId: targetUserId)
        )
    }

    func createGroupConversation(name: String, memberIds: [Int64]) async throws -> ConversationResponse {
        try await request(
            path: "/api/conversations/group",
            method: "POST",
            body: CreateGroupConversationRequest(name: name, memberIds: memberIds)
        )
    }

    func deleteConversation(conversationId: Int64) async throws -> DeleteConversationResponse {
        try await request(
            path: "/api/conversations/\(conversationId)",
            method: "DELETE"
        )
    }

    func getMessages(
        conversationId: Int64,
        before: Int64? = nil,
        limit: Int = 30
    ) async throws -> MessageHistoryResponse {
        var items = [URLQueryItem(name: "limit", value: String(limit))]
        if let before {
            items.append(URLQueryItem(name: "before", value: String(before)))
        }
        return try await request(
            path: "/api/conversations/\(conversationId)/messages",
            method: "GET",
            queryItems: items
        )
    }

    func sendMessage(conversationId: Int64, payload: SendMessageRequest) async throws -> MessageDto {
        try await request(
            path: "/api/conversations/\(conversationId)/messages",
            method: "POST",
            body: payload
        )
    }

    // MARK: - Multipart File Upload

    func uploadFile(data: Data, fileName: String, mimeType: String) async throws -> UploadResponse {
        let url = try buildURL(path: "/api/uploads", queryItems: [])
        let boundary = "Boundary-\(UUID().uuidString)"

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = KeychainService.readToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let safeFileName = fileName
            .replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")

        var body = Data()
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"file\"; filename=\"\(safeFileName)\"\r\n")
        body.appendUTF8("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.appendUTF8("\r\n--\(boundary)--\r\n")
        urlRequest.httpBody = body

        return try await perform(urlRequest, notifyUnauthorized: true)
    }

    // MARK: - Friends & Requests

    func getFriends() async throws -> [FriendResponse] {
        try await request(path: "/api/friends", method: "GET")
    }

    func getReceivedFriendRequests() async throws -> [FriendshipResponse] {
        try await request(path: "/api/friends/requests/received", method: "GET")
    }

    func getSentFriendRequests() async throws -> [FriendshipResponse] {
        try await request(path: "/api/friends/requests/sent", method: "GET")
    }

    func sendFriendRequest(targetUserId: Int64) async throws -> FriendshipResponse {
        try await request(
            path: "/api/friends/request",
            method: "POST",
            body: SendFriendRequestPayload(targetUserId: targetUserId)
        )
    }

    func acceptFriendRequest(friendshipId: Int64) async throws -> FriendshipResponse {
        try await request(
            path: "/api/friends/\(friendshipId)/accept",
            method: "PUT",
            body: EmptyRequestBody()
        )
    }

    func rejectFriendRequest(friendshipId: Int64) async throws -> FriendshipResponse {
        try await request(
            path: "/api/friends/\(friendshipId)/reject",
            method: "PUT",
            body: EmptyRequestBody()
        )
    }

    // MARK: - Core Request Execution

    private func buildURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        let base = settings.normalizedBaseURL
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        guard var components = URLComponents(string: base + normalizedPath) else {
            throw APIClientError.invalidURL(base + normalizedPath)
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIClientError.invalidURL(base + normalizedPath)
        }
        return url
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        requiresAuth: Bool = true
    ) async throws -> Response {
        let url = try buildURL(path: path, queryItems: queryItems)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if requiresAuth, let token = KeychainService.readToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await perform(urlRequest, notifyUnauthorized: requiresAuth)
    }

    private func request<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Body,
        requiresAuth: Bool = true
    ) async throws -> Response {
        let url = try buildURL(path: path, queryItems: queryItems)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if requiresAuth, let token = KeychainService.readToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.httpBody = try encoder.encode(body)
        return try await perform(urlRequest, notifyUnauthorized: requiresAuth)
    }

    private func perform<Response: Decodable>(
        _ urlRequest: URLRequest,
        notifyUnauthorized: Bool
    ) async throws -> Response {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let urlError as URLError {
            throw APIClientError.networkError(Self.describeURLError(urlError, baseURL: settings.normalizedBaseURL))
        } catch {
            throw APIClientError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.networkError("Phản hồi HTTP không hợp lệ.")
        }

        if http.statusCode == 401 {
            if notifyUnauthorized {
                onUnauthorized?()
                throw APIClientError.unauthorized
            }
            let message = extractServerMessage(from: data) ?? "Sai tên đăng nhập hoặc mật khẩu."
            throw APIClientError.serverError(statusCode: 401, message: message)
        }

        guard (200...299).contains(http.statusCode) else {
            let fallback = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            let message = extractServerMessage(from: data) ?? "Lỗi máy chủ (\(http.statusCode)): \(fallback)"
            throw APIClientError.serverError(statusCode: http.statusCode, message: message)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIClientError.decodingError(error.localizedDescription)
        }
    }

    private func extractServerMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let apiError = try? decoder.decode(APIErrorResponse.self, from: data),
           let msg = apiError.message?.trimmingCharacters(in: .whitespacesAndNewlines),
           !msg.isEmpty {
            return msg
        }
        if let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           raw.count < 240 {
            return raw
        }
        return nil
    }

    private static func describeURLError(_ error: URLError, baseURL: String) -> String {
        switch error.code {
        case .cannotConnectToHost, .cannotFindHost:
            return "Không kết nối được tới \(baseURL). Hãy kiểm tra Spring Boot đang chạy cổng 8088 hoặc cấu hình IP LAN."
        case .timedOut:
            return "Quá thời gian chờ phản hồi từ \(baseURL)."
        case .notConnectedToInternet:
            return "Thiết bị hiện không có kết nối mạng."
        default:
            return error.localizedDescription
        }
    }
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        if let encoded = string.data(using: .utf8) {
            append(encoded)
        }
    }
}
