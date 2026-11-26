import Foundation
import Observation
import SwiftUI
import UIKit

enum UserPresenceMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case online = "ONLINE"
    case idle = "IDLE"
    case sleep = "SLEEP"
    case dnd = "DND"
    case offline = "OFFLINE"

    var id: String { rawValue }

    static func fromServer(_ raw: String?) -> UserPresenceMode {
        guard let clean = raw?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
              !clean.isEmpty else {
            return .online
        }
        switch clean {
        case "IDLE", "AWAY":
            return .idle
        case "SLEEP":
            return .sleep
        case "DND", "BUSY":
            return .dnd
        case "OFFLINE", "INVISIBLE":
            return .offline
        default:
            return .online
        }
    }

    var title: String {
        switch self {
        case .online:
            return "Trực tuyến"
        case .idle:
            return "Tạm vắng"
        case .sleep:
            return "Chế độ ngủ"
        case .dnd:
            return "Không làm phiền"
        case .offline:
            return "Ẩn trạng thái"
        }
    }

    var shortTitle: String {
        title
    }

    var subtitle: String {
        switch self {
        case .online:
            return "Đang hoạt động và nhận tin nhắn tức thì"
        case .idle:
            return "Tạm rời máy, vẫn nhận tin nhắn mới"
        case .sleep:
            return "Đang nghỉ ngơi, tạm hoãn tương tác"
        case .dnd:
            return "Đang tập trung, không muốn bị làm phiền"
        case .offline:
            return "Ẩn trạng thái hoạt động với mọi người"
        }
    }

    var iconName: String {
        switch self {
        case .online:
            return "checkmark.circle.fill"
        case .idle:
            return "clock.fill"
        case .sleep:
            return "moon.zzz.fill"
        case .dnd:
            return "minus.circle.fill"
        case .offline:
            return "circle.dashed"
        }
    }

    var dotColor: Color {
        switch self {
        case .online:
            return Color(.systemGreen)
        case .idle:
            return Color(.systemOrange)
        case .sleep:
            return Color(.systemIndigo)
        case .dnd:
            return Color(.systemRed)
        case .offline:
            return Color(.secondaryLabel)
        }
    }
}

enum AppAppearanceMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "Theo hệ thống"
        case .light:
            return "Sáng"
        case .dark:
            return "Tối"
        }
    }

    var iconName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

struct CachedSessionUser: Codable, Hashable, Sendable {
    var id: Int64
    var username: String
    var fullName: String
    var email: String?
    var phone: String?
    var gender: String?
    var dob: String?
    var bio: String?
    var avatarUrl: String?
}

@MainActor
@Observable
final class AppSettings {
    static let defaultBaseURL = "https://chat-bln.fishu.io.vn"
    static let simulatorBaseURL = "http://127.0.0.1:8088"

    private enum Keys {
        static let baseURL = "chatbln.server.base_url"
        static let appearance = "chatbln.ui.appearance"
        static let presenceMode = "chatbln.user.presence_mode"
        static let cachedUser = "chatbln.auth.cached_user"
    }

    var baseURLString: String {
        didSet {
            UserDefaults.standard.set(baseURLString, forKey: Keys.baseURL)
        }
    }

    var appearanceMode: AppAppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: Keys.appearance)
        }
    }

    var presenceMode: UserPresenceMode {
        didSet {
            UserDefaults.standard.set(presenceMode.rawValue, forKey: Keys.presenceMode)
        }
    }

    var cachedUser: CachedSessionUser? {
        didSet {
            if let cachedUser,
               let encoded = try? JSONEncoder().encode(cachedUser) {
                UserDefaults.standard.set(encoded, forKey: Keys.cachedUser)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.cachedUser)
            }
        }
    }

    init() {
        let savedBaseURL = UserDefaults.standard.string(forKey: Keys.baseURL)
        self.baseURLString = Self.normalizeBaseURL(savedBaseURL ?? Self.defaultBaseURL)

        if let rawAppearance = UserDefaults.standard.string(forKey: Keys.appearance),
           let mode = AppAppearanceMode(rawValue: rawAppearance) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = .system
        }

        if let rawPresence = UserDefaults.standard.string(forKey: Keys.presenceMode) {
            self.presenceMode = UserPresenceMode.fromServer(rawPresence)
        } else {
            self.presenceMode = .online
        }

        if let userData = UserDefaults.standard.data(forKey: Keys.cachedUser),
           let decoded = try? JSONDecoder().decode(CachedSessionUser.self, from: userData) {
            self.cachedUser = decoded
        } else {
            self.cachedUser = nil
        }
    }

    var normalizedBaseURL: String {
        Self.normalizeBaseURL(baseURLString)
    }

    var webSocketURL: URL? {
        guard var components = URLComponents(string: normalizedBaseURL) else {
            return nil
        }
        let currentScheme = (components.scheme ?? "http").lowercased()
        components.scheme = (currentScheme == "https" || currentScheme == "wss") ? "wss" : "ws"
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = basePath.isEmpty ? "/ws-native" : "/\(basePath)/ws-native"
        components.query = nil
        components.fragment = nil
        return components.url
    }

    func updateBaseURL(_ rawValue: String) {
        baseURLString = Self.normalizeBaseURL(rawValue)
    }

    func resetBaseURLToDefault() {
        baseURLString = Self.defaultBaseURL
    }

    func resolveAssetURL(_ pathOrURL: String?) -> URL? {
        guard let raw = pathOrURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }

        if raw == "/avatars/default-avatar.svg" || raw.hasSuffix(".svg") {
            if raw.contains("api.dicebear.com"), raw.contains("/svg") {
                let pngVariant = raw.replacingOccurrences(of: "/svg", with: "/png")
                return URL(string: pngVariant)
            }
            return nil
        }

        if raw.lowercased().hasPrefix("http://") || raw.lowercased().hasPrefix("https://") || raw.lowercased().hasPrefix("data:") {
            return URL(string: raw)
        }

        let cleanPath = raw.hasPrefix("/") ? raw : "/\(raw)"
        return URL(string: normalizedBaseURL + cleanPath)
    }

    static func normalizeBaseURL(_ input: String) -> String {
        var trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return defaultBaseURL
        }
        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            let scheme = shouldDefaultToCleartextHTTP(trimmed) ? "http" : "https"
            trimmed = "\(scheme)://\(trimmed)"
        }
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        if trimmed.lowercased().hasSuffix("/api") {
            trimmed = String(trimmed.dropLast(4))
        }
        if trimmed.lowercased() == "http://chat-bln.fishu.io.vn" {
            trimmed = "https://chat-bln.fishu.io.vn"
        }
        return trimmed
    }

    private static func shouldDefaultToCleartextHTTP(_ rawHostPort: String) -> Bool {
        let hostAndPort = rawHostPort.split(separator: "/").first.map(String.init) ?? rawHostPort
        let lower = hostAndPort.lowercased()
        if lower.contains(":8088") || lower.contains(":8080") || lower.contains(":4200") {
            return true
        }
        let hostOnly = lower.split(separator: ":").first.map(String.init) ?? lower
        if hostOnly == "localhost" || hostOnly.hasSuffix(".local") {
            return true
        }
        let octets = hostOnly.split(separator: ".").compactMap { Int($0) }
        if octets.count == 4 {
            return true
        }
        return false
    }
}

extension Color {
    /// Quiet Signal Precision Sapphire: `#0F52BA` in Light Mode, `#3B82F6` in Dark Mode (>= 4.5:1 AA contrast).
    static let chatBLNPrimary = Color(
        UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 59.0 / 255.0, green: 130.0 / 255.0, blue: 246.0 / 255.0, alpha: 1.0)
            } else {
                return UIColor(red: 15.0 / 255.0, green: 82.0 / 255.0, blue: 186.0 / 255.0, alpha: 1.0)
            }
        }
    )

    static let chatBLNBeacon = Color(red: 56.0 / 255.0, green: 189.0 / 255.0, blue: 248.0 / 255.0)
}

/// Unified Chat BLN "Signal Aperture" Brand Mark (matches Web `logo.svg` & Android `QuietSignalBrandMark`).
struct ChatBLNBrandMark: View {
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 23.0 / 255.0, green: 88.0 / 255.0, blue: 238.0 / 255.0),
                            Color(red: 10.0 / 255.0, green: 54.0 / 255.0, blue: 157.0 / 255.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Canvas { ctx, canvasSize in
                let w = canvasSize.width
                let h = canvasSize.height
                let center = CGPoint(x: w * 0.5, y: h * 0.515)
                let radius = w * 0.275
                let strokeW = w * 0.072

                // Open chat aperture arc with bottom-left speech tail
                var arcPath = Path()
                arcPath.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(-12),
                    endAngle: .degrees(118),
                    clockwise: false
                )
                let tip = CGPoint(x: w * 0.23, y: h * 0.77)
                arcPath.addLine(to: tip)
                let tailUpper = CGPoint(
                    x: center.x + radius * cos(148 * .pi / 180),
                    y: center.y + radius * sin(148 * .pi / 180)
                )
                arcPath.addLine(to: tailUpper)
                arcPath.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(148),
                    endAngle: .degrees(296),
                    clockwise: false
                )

                ctx.stroke(
                    arcPath,
                    with: .color(.white),
                    style: StrokeStyle(lineWidth: strokeW, lineCap: .round, lineJoin: .round)
                )

                // Ascending precision signal bars
                let barW = w * 0.074
                let bar1 = Path(
                    roundedRect: CGRect(x: w * 0.375, y: h * 0.46, width: barW, height: h * 0.145),
                    cornerRadius: barW * 0.5
                )
                let bar2 = Path(
                    roundedRect: CGRect(x: w * 0.495, y: h * 0.385, width: barW, height: h * 0.22),
                    cornerRadius: barW * 0.5
                )
                ctx.fill(bar1, with: .color(.white))
                ctx.fill(bar2, with: .color(.white))

                // Sky-cyan live realtime beacon dot
                let dotR = w * 0.065
                let dotRect = CGRect(
                    x: w * 0.695 - dotR,
                    y: h * 0.315 - dotR,
                    width: dotR * 2,
                    height: dotR * 2
                )
                ctx.fill(Path(ellipseIn: dotRect), with: .color(.chatBLNBeacon))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - GitHub Releases Update Checker (Native Swift 6)

struct GitHubReleaseAssetDTO: Decodable, Sendable, Hashable {
    let name: String
    let browserDownloadUrl: String
    let size: Int64

    private enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

struct GitHubReleaseDTO: Decodable, Sendable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String
    let publishedAt: String?
    let assets: [GitHubReleaseAssetDTO]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}

struct AppUpdateInfo: Sendable, Hashable, Identifiable {
    var id: String { latestTag }
    let currentVersion: String
    let latestVersion: String
    let latestTag: String
    let releaseTitle: String
    let changelog: String
    let publishedDate: String
    let releasePageURL: URL?
    let ipaAsset: GitHubReleaseAssetDTO?
    let checksumsURL: URL?
    let hasUpdate: Bool
}

@MainActor
@Observable
final class AppUpdateChecker {
    static let shared = AppUpdateChecker()
    static let githubRepo = "fishuvn/chat-bln-ios"

    var isChecking: Bool = false
    var latestInfo: AppUpdateInfo?
    var errorMessage: String?
    var bannerDismissed: Bool = false
    var showUpdateSheet: Bool = false

    var currentAppVersion: String {
        if let raw = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return "4.0.0"
    }

    var shouldShowBanner: Bool {
        guard !bannerDismissed, let info = latestInfo else { return false }
        return info.hasUpdate
    }

    func checkForUpdates(openSheetIfDone: Bool = false) async {
        guard !isChecking else { return }
        isChecking = true
        errorMessage = nil

        let currentVer = currentAppVersion
        guard let url = URL(string: "https://api.github.com/repos/\(Self.githubRepo)/releases/latest") else {
            errorMessage = "URL kiểm tra cập nhật không hợp lệ."
            isChecking = false
            return
        }

        var request = URLRequest(url: url, timeoutInterval: 12)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ChatBLN-iOS/\(currentVer)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                errorMessage = "Phản hồi máy chủ GitHub không hợp lệ."
                isChecking = false
                return
            }

            if http.statusCode == 404 {
                errorMessage = "Chưa có bản phát hành nào trên GitHub."
                isChecking = false
                return
            }
            if http.statusCode == 403 {
                errorMessage = "GitHub API tạm giới hạn lượt kiểm tra. Thử lại sau vài phút."
                isChecking = false
                return
            }
            guard (200...299).contains(http.statusCode) else {
                errorMessage = "Không thể kiểm tra cập nhật (HTTP \(http.statusCode))."
                isChecking = false
                return
            }

            let dto = try JSONDecoder().decode(GitHubReleaseDTO.self, from: data)
            let latestClean = dto.tagName.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let hasUpdate = Self.isNewerVersion(current: currentVer, latest: latestClean)
            let ipa = dto.assets.first { $0.name.lowercased().hasSuffix(".ipa") }
            let sha = dto.assets.first { $0.name.caseInsensitiveCompare("SHA256SUMS.txt") == .orderedSame }
                .flatMap { URL(string: $0.browserDownloadUrl) }

            let info = AppUpdateInfo(
                currentVersion: currentVer,
                latestVersion: latestClean,
                latestTag: dto.tagName.isEmpty ? "v\(latestClean)" : dto.tagName,
                releaseTitle: (dto.name?.isEmpty == false ? dto.name! : "Chat BLN \(dto.tagName)"),
                changelog: (dto.body?.isEmpty == false ? dto.body! : "Bản phát hành mới kèm tối ưu hiệu năng và sửa lỗi."),
                publishedDate: dto.publishedAt?.components(separatedBy: "T").first ?? "",
                releasePageURL: URL(string: dto.htmlUrl),
                ipaAsset: ipa,
                checksumsURL: sha,
                hasUpdate: hasUpdate
            )
            latestInfo = info
            if openSheetIfDone {
                showUpdateSheet = true
            }
        } catch {
            errorMessage = "Không thể kết nối GitHub Releases: \(error.localizedDescription)"
        }
        isChecking = false
    }

    nonisolated static func isNewerVersion(current: String, latest: String) -> Bool {
        let cur = parseSemVer(current)
        let lat = parseSemVer(latest)
        if let cur, let lat {
            if lat.0 != cur.0 { return lat.0 > cur.0 }
            if lat.1 != cur.1 { return lat.1 > cur.1 }
            return lat.2 > cur.2
        }
        let cleanCur = current.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let cleanLat = latest.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        return !cleanLat.isEmpty && cleanLat != cleanCur
    }

    nonisolated private static func parseSemVer(_ raw: String) -> (Int, Int, Int)? {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .components(separatedBy: "-").first ?? ""
        let parts = clean.split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return (parts[0], parts[1], parts.count >= 3 ? parts[2] : 0)
    }

    nonisolated static func formatBytes(_ bytes: Int64) -> String {
        if bytes >= 1_048_576 {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576.0)
        } else if bytes >= 1_024 {
            return String(format: "%.1f KB", Double(bytes) / 1_024.0)
        }
        return "\(bytes) B"
    }
}

struct UpdateDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let info: AppUpdateInfo

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(
                            info.hasUpdate ? "Có bản cập nhật mới (\(info.latestTag))" : "Bạn đang dùng bản mới nhất",
                            systemImage: info.hasUpdate ? "arrow.down.circle.fill" : "checkmark.circle.fill"
                        )
                        .font(.headline)
                        .foregroundStyle(info.hasUpdate ? Color.chatBLNPrimary : Color(.systemGreen))

                        Text("Hiện tại: v\(info.currentVersion)  •  Mới nhất: \(info.latestTag)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if !info.publishedDate.isEmpty {
                            Text("Ngày phát hành: \(info.publishedDate)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nhật ký thay đổi (Changelog)")
                            .font(.subheadline.weight(.semibold))
                        Text(info.changelog)
                            .font(.footnote)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if info.hasUpdate, let ipa = info.ipaAsset, let downloadURL = URL(string: ipa.browserDownloadUrl) {
                        Button {
                            openURL(downloadURL)
                        } label: {
                            Label(
                                "Tải \(ipa.name) (\(AppUpdateChecker.formatBytes(ipa.size)))",
                                systemImage: "arrow.down.doc.fill"
                            )
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 46)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.chatBLNPrimary)
                    }

                    if let pageURL = info.releasePageURL {
                        Button {
                            openURL(pageURL)
                        } label: {
                            Label("Mở trang GitHub Releases", systemImage: "safari")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Cập nhật ứng dụng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}
