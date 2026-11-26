/// Compile-time application identity & target platform configuration.
pub const APP_NAME: &str = "Chat BLN";
pub const APP_VERSION: &str = env!("CARGO_PKG_VERSION");
pub const DEFAULT_SERVER_URL: &str = "https://chat-bln.fishu.io.vn";

/// Target mobile platform ("android" for chat-bln-android, "ios" for chat-bln-ios).
pub const TARGET_PLATFORM: &str = "ios";
pub const GITHUB_REPO: &str = "fishuvn/chat-bln-ios";
pub const PLATFORM_DISPLAY_NAME: &str = "iOS 18+ (Rust Engine)";

pub fn current_arch_label() -> &'static str {
    if cfg!(target_arch = "aarch64") {
        "arm64"
    } else if cfg!(target_arch = "x86_64") {
        "x86_64-sim"
    } else {
        "arm64"
    }
}

pub fn normalize_server_url(raw: &str) -> String {
    let trimmed = raw.trim().trim_end_matches('/');
    if trimmed.is_empty() {
        return DEFAULT_SERVER_URL.to_string();
    }
    if trimmed.starts_with("http://") || trimmed.starts_with("https://") {
        trimmed.to_string()
    } else {
        format!("https://{trimmed}")
    }
}

pub fn build_ws_url(server_url: &str) -> String {
    let base = normalize_server_url(server_url);
    if let Some(rest) = base.strip_prefix("https://") {
        format!("wss://{rest}/ws-native")
    } else if let Some(rest) = base.strip_prefix("http://") {
        format!("ws://{rest}/ws-native")
    } else {
        format!("wss://{base}/ws-native")
    }
}

pub fn resolve_asset_url(server_url: &str, path: Option<&str>) -> Option<String> {
    let raw = path?.trim();
    if raw.is_empty() || raw.contains("api.dicebear.com") {
        return None;
    }
    if raw.starts_with("http://") || raw.starts_with("https://") || raw.starts_with("data:") {
        return Some(raw.to_string());
    }
    let base = normalize_server_url(server_url);
    if raw.starts_with('/') {
        Some(format!("{base}{raw}"))
    } else {
        Some(format!("{base}/{raw}"))
    }
}

pub fn extract_invite_code(input: &str) -> String {
    let trimmed = input.trim();
    if trimmed.is_empty() {
        return String::new();
    }
    if let Some(idx) = trimmed.rfind("/join/") {
        let code = &trimmed[idx + 6..];
        return code
            .split(['?', '#', '/'])
            .next()
            .unwrap_or("")
            .trim()
            .to_string();
    }
    trimmed
        .split(['?', '#', '/'])
        .last()
        .unwrap_or(trimmed)
        .trim()
        .to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalizes_urls_and_ws_endpoints() {
        assert_eq!(normalize_server_url(""), DEFAULT_SERVER_URL);
        assert_eq!(
            normalize_server_url("chat-bln.fishu.io.vn/"),
            "https://chat-bln.fishu.io.vn"
        );
        assert_eq!(
            build_ws_url("https://chat-bln.fishu.io.vn/"),
            "wss://chat-bln.fishu.io.vn/ws-native"
        );
        assert_eq!(
            build_ws_url("http://127.0.0.1:8088"),
            "ws://127.0.0.1:8088/ws-native"
        );
    }

    #[test]
    fn sanitizes_dicebear_and_parses_invite_links() {
        assert_eq!(
            resolve_asset_url(DEFAULT_SERVER_URL, Some("https://api.dicebear.com/7.x/svg")),
            None
        );
        assert_eq!(
            resolve_asset_url(DEFAULT_SERVER_URL, Some("/uploads/img.jpg")),
            Some("https://chat-bln.fishu.io.vn/uploads/img.jpg".to_string())
        );
        assert_eq!(
            extract_invite_code("https://chat-bln.fishu.io.vn/join/grp_xyz123?ref=1"),
            "grp_xyz123"
        );
        assert_eq!(extract_invite_code("grp_direct"), "grp_direct");
    }
}
