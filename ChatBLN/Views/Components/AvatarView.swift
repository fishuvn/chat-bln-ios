import SwiftUI
import UIKit

@MainActor
final class AvatarImageCache {
    static let shared = AvatarImageCache()

    private let cache = NSCache<NSURL, UIImage>()
    private var inFlightTasks: [URL: Task<UIImage?, Never>] = [:]
    private let session: URLSession

    private init() {
        cache.countLimit = 300
        cache.totalCostLimit = 48 * 1024 * 1024

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func loadImage(from url: URL) async -> UIImage? {
        if let existing = cache.object(forKey: url as NSURL) {
            return existing
        }

        if let running = inFlightTasks[url] {
            return await running.value
        }

        let session = self.session
        let task = Task<UIImage?, Never> {
            do {
                let (data, response) = try await session.data(from: url)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    return nil
                }
                return UIImage(data: data)
            } catch {
                return nil
            }
        }

        inFlightTasks[url] = task
        let fetched = await task.value
        inFlightTasks.removeValue(forKey: url)

        if let fetched {
            let cost = Int(fetched.size.width * fetched.size.height * fetched.scale * fetched.scale * 4)
            cache.setObject(fetched, forKey: url as NSURL, cost: max(1, cost))
        }
        return fetched
    }
}

struct AvatarView: View {
    let name: String
    let avatarURL: URL?
    var size: CGFloat = 44
    var isGroup: Bool = false
    var isOnline: Bool? = nil
    var presenceStatus: String? = nil

    @State private var loadedImage: UIImage?

    private var resolvedMode: UserPresenceMode {
        guard isOnline == true else {
            return .offline
        }
        return UserPresenceMode.fromServer(presenceStatus)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            avatarSurface
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
                )

            if isOnline != nil, !isGroup {
                presenceBadge
                    .accessibilityHidden(true)
            }
        }
        .task(id: avatarURL) {
            guard let url = avatarURL else {
                loadedImage = nil
                return
            }
            if let instant = AvatarImageCache.shared.cachedImage(for: url) {
                loadedImage = instant
                return
            }
            loadedImage = await AvatarImageCache.shared.loadImage(from: url)
        }
    }

    @ViewBuilder
    private var avatarSurface: some View {
        if let url = avatarURL, let instant = loadedImage ?? AvatarImageCache.shared.cachedImage(for: url) {
            Image(uiImage: instant)
                .resizable()
                .scaledToFill()
        } else {
            monogramSurface
        }
    }

    private var monogramSurface: some View {
        ZStack {
            Color(.tertiarySystemFill)
            if isGroup {
                Image(systemName: "person.2.fill")
                    .font(monogramFont)
                    .foregroundStyle(Color.chatBLNPrimary)
            } else {
                Text(initials)
                    .font(monogramFont)
                    .foregroundStyle(Color(.label))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
    }

    private var presenceBadge: some View {
        let mode = resolvedMode
        let badgeDiameter = max(12, size * 0.28)
        return ZStack {
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: badgeDiameter + 3, height: badgeDiameter + 3)

            Image(systemName: presenceBadgeSymbol(for: mode))
                .resizable()
                .scaledToFit()
                .frame(width: badgeDiameter, height: badgeDiameter)
                .foregroundStyle(mode.dotColor)
        }
    }

    private func presenceBadgeSymbol(for mode: UserPresenceMode) -> String {
        switch mode {
        case .online:
            return "circle.fill"
        case .idle:
            return "clock.fill"
        case .sleep:
            return "moon.circle.fill"
        case .dnd:
            return "minus.circle.fill"
        case .offline:
            return "circle"
        }
    }

    private var monogramFont: Font {
        if size >= 72 {
            return .title2.weight(.semibold)
        } else if size >= 44 {
            return .subheadline.weight(.semibold)
        } else {
            return .caption2.weight(.semibold)
        }
    }

    private var initials: String {
        let words = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
        if words.count >= 2,
           let first = words.first?.first,
           let last = words.last?.first {
            return "\(first)\(last)".uppercased()
        }
        if let first = name.trimmingCharacters(in: .whitespacesAndNewlines).first {
            return String(first).uppercased()
        }
        return "B"
    }
}
