import Foundation
import SwiftUI

struct ExtractedMessageLink: Hashable, Sendable {
    let label: String
    let url: URL
    let host: String
}

enum GroupInviteLinkParser {
    static let canonicalWebOrigin = "https://chat-bln.fishu.io.vn"
    private static let joinPathPattern = #"\/join\/([A-Za-z0-9_-]+)"#
    private static let rawCodePattern = #"^[A-Za-z0-9_-]{4,64}$"#

    static func shareURLString(for inviteCode: String) -> String {
        let clean = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(canonicalWebOrigin)/join/\(clean)"
    }

    static func extractInviteCode(from rawInput: String?) -> String? {
        guard let trimmed = rawInput?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        if let joinRegex = try? NSRegularExpression(pattern: joinPathPattern, options: [.caseInsensitive]) {
            let ns = trimmed as NSString
            let range = NSRange(location: 0, length: ns.length)
            if let match = joinRegex.firstMatch(in: trimmed, options: [], range: range),
               match.numberOfRanges >= 2 {
                let code = ns.substring(with: match.range(at: 1))
                if !code.isEmpty {
                    return code
                }
            }
        }

        let cleanedCode = trimmed
            .trimmingCharacters(in: CharacterSet(charactersIn: "/#? "))
        if let codeRegex = try? NSRegularExpression(pattern: rawCodePattern, options: []) {
            let ns = cleanedCode as NSString
            let range = NSRange(location: 0, length: ns.length)
            if codeRegex.firstMatch(in: cleanedCode, options: [], range: range) != nil {
                return cleanedCode
            }
        }
        return nil
    }

    static func extractInviteCodeFromMessageText(_ rawText: String?) -> String? {
        guard let rawText, !rawText.isEmpty,
              let joinRegex = try? NSRegularExpression(pattern: joinPathPattern, options: [.caseInsensitive]) else {
            return nil
        }
        let ns = rawText as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = joinRegex.firstMatch(in: rawText, options: [], range: range),
              match.numberOfRanges >= 2 else {
            return nil
        }
        let code = ns.substring(with: match.range(at: 1))
        return code.hasPrefix("grp_") || !code.isEmpty ? code : nil
    }
}

enum MarkdownMessageFormatter {
    private static let tokenPattern = #"(\[[^\]]+\]\(https?:\/\/[^\s)]+\)|https?:\/\/[^\s<>"']+)"#
    private static let markdownLinkPattern = #"^\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)$"#

    static func makeAttributedString(
        from rawText: String,
        isOutgoing: Bool
    ) -> AttributedString {
        guard !rawText.isEmpty else {
            return AttributedString("")
        }

        guard let tokenRegex = try? NSRegularExpression(pattern: tokenPattern, options: [.caseInsensitive]),
              let mdRegex = try? NSRegularExpression(pattern: markdownLinkPattern, options: [.caseInsensitive]) else {
            return AttributedString(rawText)
        }

        let nsText = rawText as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = tokenRegex.matches(in: rawText, options: [], range: fullRange)

        if matches.isEmpty {
            return AttributedString(rawText)
        }

        var result = AttributedString()
        var currentLocation = 0

        for match in matches {
            let matchRange = match.range
            if matchRange.location > currentLocation {
                let plainSlice = nsText.substring(
                    with: NSRange(location: currentLocation, length: matchRange.location - currentLocation)
                )
                result.append(AttributedString(plainSlice))
            }

            let token = nsText.substring(with: matchRange)
            let tokenRange = NSRange(location: 0, length: (token as NSString).length)

            if let mdMatch = mdRegex.firstMatch(in: token, options: [], range: tokenRange),
               mdMatch.numberOfRanges >= 3 {
                let label = (token as NSString).substring(with: mdMatch.range(at: 1))
                let urlString = (token as NSString).substring(with: mdMatch.range(at: 2))
                result.append(styledLinkSegment(label: label, urlString: urlString, isOutgoing: isOutgoing))
            } else {
                result.append(styledLinkSegment(label: token, urlString: token, isOutgoing: isOutgoing))
            }

            currentLocation = matchRange.location + matchRange.length
        }

        if currentLocation < nsText.length {
            let trailing = nsText.substring(
                with: NSRange(location: currentLocation, length: nsText.length - currentLocation)
            )
            result.append(AttributedString(trailing))
        }

        return result
    }

    static func extractFirstLink(from rawText: String?) -> ExtractedMessageLink? {
        guard let rawText, !rawText.isEmpty,
              let tokenRegex = try? NSRegularExpression(pattern: tokenPattern, options: [.caseInsensitive]),
              let mdRegex = try? NSRegularExpression(pattern: markdownLinkPattern, options: [.caseInsensitive]) else {
            return nil
        }

        let nsText = rawText as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        guard let firstMatch = tokenRegex.firstMatch(in: rawText, options: [], range: fullRange) else {
            return nil
        }

        let token = nsText.substring(with: firstMatch.range)
        let tokenRange = NSRange(location: 0, length: (token as NSString).length)

        if let mdMatch = mdRegex.firstMatch(in: token, options: [], range: tokenRange),
           mdMatch.numberOfRanges >= 3 {
            let label = (token as NSString).substring(with: mdMatch.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            let urlString = (token as NSString).substring(with: mdMatch.range(at: 2))
            guard let url = URL(string: urlString) else { return nil }
            let host = cleanHost(from: url)
            return ExtractedMessageLink(label: label.isEmpty ? host : label, url: url, host: host)
        }

        guard let url = URL(string: token) else { return nil }
        let host = cleanHost(from: url)
        return ExtractedMessageLink(label: host, url: url, host: host)
    }

    private static func styledLinkSegment(
        label: String,
        urlString: String,
        isOutgoing: Bool
    ) -> AttributedString {
        var segment = AttributedString(label)
        if let url = URL(string: urlString) {
            segment.link = url
            segment.underlineStyle = .single
            segment.foregroundColor = isOutgoing ? .white : .chatBLNPrimary
        }
        return segment
    }

    static func cleanHost(from url: URL) -> String {
        guard let host = url.host else { return url.absoluteString }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

// MARK: - Backend Date & Presence Formatting

enum ChatDateFormatter {
    static func parseBackendDate(_ raw: String?) -> Date? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        let isoWithFractional = ISO8601DateFormatter()
        isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoWithFractional.date(from: trimmed) {
            return date
        }

        let isoStandard = ISO8601DateFormatter()
        isoStandard.formatOptions = [.withInternetDateTime]
        if let date = isoStandard.date(from: trimmed) {
            return date
        }

        let localFormats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current

        for format in localFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }

    static func formatMessageTime(_ raw: String?) -> String {
        guard let date = parseBackendDate(raw) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "HH:mm dd/MM"
        }
        return formatter.string(from: date)
    }

    static func formatConversationTime(_ raw: String?) -> String {
        guard let date = parseBackendDate(raw) else {
            return ""
        }
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return "Hôm qua"
        }
        formatter.dateFormat = "dd/MM"
        return formatter.string(from: date)
    }

    static func formatPresenceStatus(isOnline: Bool?, presenceStatus: String? = nil, lastSeen: String?) -> String {
        if isOnline == true {
            let mode = UserPresenceMode.fromServer(presenceStatus)
            switch mode {
            case .online:
                return "Trực tuyến"
            case .idle:
                return "Tạm vắng (Idle)"
            case .sleep:
                return "Chế độ ngủ (Sleep)"
            case .dnd:
                return "Không làm phiền (DND)"
            case .offline:
                break
            }
        }
        guard let date = parseBackendDate(lastSeen) else {
            return "Ngoại tuyến"
        }
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        let minutes = seconds / 60
        if minutes < 1 {
            return "Hoạt động vừa xong"
        }
        if minutes < 60 {
            return "Hoạt động \(minutes) phút trước"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "Hoạt động \(hours) giờ trước"
        }
        let days = hours / 24
        return "Hoạt động \(days) ngày trước"
    }

    static func presenceTintColor(isOnline: Bool?, presenceStatus: String? = nil) -> Color {
        guard isOnline == true else { return .secondary }
        let mode = UserPresenceMode.fromServer(presenceStatus)
        return mode == .offline ? .secondary : mode.dotColor
    }
}
