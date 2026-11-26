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

    @Environment(\.colorScheme) private var colorScheme
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
        let isDark = colorScheme == .dark
        let bgColor: Color = isDark
            ? Color(red: 23.0 / 255.0, green: 37.0 / 255.0, blue: 84.0 / 255.0)
            : (isGroup
                ? Color(red: 219.0 / 255.0, green: 234.0 / 255.0, blue: 254.0 / 255.0)
                : Color(red: 230.0 / 255.0, green: 239.0 / 255.0, blue: 252.0 / 255.0))
        let primaryColor: Color = isDark
            ? Color(red: 248.0 / 255.0, green: 250.0 / 255.0, blue: 252.0 / 255.0)
            : Color(red: 15.0 / 255.0, green: 82.0 / 255.0, blue: 186.0 / 255.0)
        let accentColor: Color = isDark
            ? Color(red: 96.0 / 255.0, green: 165.0 / 255.0, blue: 250.0 / 255.0)
            : Color(red: 59.0 / 255.0, green: 130.0 / 255.0, blue: 246.0 / 255.0)

        return Canvas { ctx, canvasSize in
            let s = min(canvasSize.width, canvasSize.height) / 128.0
            let ox = (canvasSize.width - 128.0 * s) * 0.5
            let oy = (canvasSize.height - 128.0 * s) * 0.5
            func px(_ x: CGFloat) -> CGFloat { ox + x * s }
            func py(_ y: CGFloat) -> CGFloat { oy + y * s }
            func rrect(
                _ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat,
                _ rtl: CGFloat, _ rtr: CGFloat, _ rbr: CGFloat, _ rbl: CGFloat
            ) -> Path {
                let l = px(x0), t = py(y0), r = px(x1), b = py(y1)
                let tl = rtl * s, tr = rtr * s, br = rbr * s, bl = rbl * s
                var p = Path()
                p.move(to: CGPoint(x: l + tl, y: t))
                p.addLine(to: CGPoint(x: r - tr, y: t))
                p.addArc(center: CGPoint(x: r - tr, y: t + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
                p.addLine(to: CGPoint(x: r, y: b - br))
                p.addArc(center: CGPoint(x: r - br, y: b - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
                p.addLine(to: CGPoint(x: l + bl, y: b))
                p.addArc(center: CGPoint(x: l + bl, y: b - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
                p.addLine(to: CGPoint(x: l, y: t + tl))
                p.addArc(center: CGPoint(x: l + tl, y: t + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
                p.closeSubpath()
                return p
            }

            ctx.fill(Path(CGRect(origin: .zero, size: canvasSize)), with: .color(bgColor))

            if isGroup {
                // Back-right secondary member with concentric 5px negative-space moat
                let backHead = Path(ellipseIn: CGRect(x: px(84 - 12), y: py(49 - 12), width: 24 * s, height: 24 * s))
                ctx.fill(backHead, with: .color(accentColor))

                var backTorso = Path()
                backTorso.move(to: CGPoint(x: px(71.52), y: py(70)))
                backTorso.addLine(to: CGPoint(x: px(90), y: py(70)))
                backTorso.addArc(center: CGPoint(x: px(90), y: py(87)), radius: 17 * s, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
                backTorso.addArc(center: CGPoint(x: px(98), y: py(87)), radius: 9 * s, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
                backTorso.addLine(to: CGPoint(x: px(75.71), y: py(96)))
                backTorso.addArc(center: CGPoint(x: px(55), y: py(86)), radius: 23 * s, startAngle: .degrees(25.77), endAngle: .degrees(-44.08), clockwise: true)
                backTorso.closeSubpath()
                ctx.fill(backTorso, with: .color(accentColor))

                // Front-left primary member
                let frontHead = Path(ellipseIn: CGRect(x: px(47 - 15), y: py(45 - 15), width: 30 * s, height: 30 * s))
                ctx.fill(frontHead, with: .color(primaryColor))
                ctx.fill(rrect(21, 68, 73, 96, 18, 18, 10, 10), with: .color(primaryColor))
            } else {
                // Default B-Dialogue geometric user silhouette
                let head = Path(ellipseIn: CGRect(x: px(64 - 17), y: py(45 - 17), width: 34 * s, height: 34 * s))
                ctx.fill(rrect(29, 72, 99, 102, 20, 20, 10, 10), with: .color(accentColor))
                ctx.fill(head, with: .color(primaryColor))
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
