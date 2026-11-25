import Foundation
import Observation
import SwiftUI

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
            return "sun.max.fill"
        case .dark:
            return "moon.stars.fill"
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
    static let defaultBaseURL = "http://127.0.0.1:8088"

    private enum Keys {
        static let baseURL = "chatbln.server.base_url"
        static let appearance = "chatbln.ui.appearance"
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

        if raw.lowercased().hasPrefix("http://") || raw.lowercased().hasPrefix("https://") {
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
            trimmed = "http://\(trimmed)"
        }
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        if trimmed.lowercased().hasSuffix("/api") {
            trimmed = String(trimmed.dropLast(4))
        }
        return trimmed
    }
}

extension Color {
    static let chatBLNPrimary = Color(red: 11.0 / 255.0, green: 87.0 / 255.0, blue: 208.0 / 255.0)
    static let chatBLNBlue = Color(red: 0.0 / 255.0, green: 122.0 / 255.0, blue: 255.0 / 255.0)
}
