import SwiftUI

struct AvatarView: View {
    let name: String
    let avatarURL: URL?
    var size: CGFloat = 48
    var isGroup: Bool = false
    var isOnline: Bool? = nil
    var presenceStatus: String? = nil

    private var resolvedDotColor: Color {
        guard isOnline == true else {
            return Color(.systemGray4)
        }
        let mode = UserPresenceMode.fromServer(presenceStatus)
        return mode == .offline ? Color(.systemGray4) : mode.dotColor
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            avatarGraphic
                .frame(width: size, height: size)
                .clipShape(Circle())

            if isOnline != nil, !isGroup {
                Circle()
                    .fill(resolvedDotColor)
                    .frame(width: max(10, size * 0.26), height: max(10, size * 0.26))
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var avatarGraphic: some View {
        if let avatarURL {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty, .failure:
                    fallbackBadge
                @unknown default:
                    fallbackBadge
                }
            }
        } else {
            fallbackBadge
        }
    }

    private var fallbackBadge: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if isGroup {
                Image(systemName: "person.3.fill")
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
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

    private var gradientColors: [Color] {
        if isGroup {
            return [Color.chatBLNPrimary, Color.indigo]
        }
        let palette: [[Color]] = [
            [Color.chatBLNPrimary, Color.chatBLNBlue],
            [Color.indigo, Color.blue],
            [Color.teal, Color.cyan],
            [Color.orange, Color.pink],
            [Color.purple, Color.indigo]
        ]
        let hash = abs(name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
        return palette[hash % palette.count]
    }
}
