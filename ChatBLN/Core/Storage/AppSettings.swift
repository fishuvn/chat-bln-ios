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
}
