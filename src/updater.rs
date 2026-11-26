use crate::config::{current_arch_label, APP_VERSION, GITHUB_REPO, TARGET_PLATFORM};
use semver::Version;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GitHubReleaseAsset {
    pub name: String,
    pub browser_download_url: String,
    #[serde(default)]
    pub size: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GitHubReleasePayload {
    pub tag_name: String,
    pub name: Option<String>,
    pub body: Option<String>,
    pub html_url: String,
    pub published_at: Option<String>,
    #[serde(default)]
    pub prerelease: bool,
    #[serde(default)]
    pub draft: bool,
    #[serde(default)]
    pub assets: Vec<GitHubReleaseAsset>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct UpdateCheckResult {
    pub current_version: String,
    pub latest_version: String,
    pub latest_tag: String,
    pub release_title: String,
    pub changelog: String,
    pub published_at: String,
    pub release_page_url: String,
    pub recommended_asset: Option<GitHubReleaseAsset>,
    pub checksums_url: Option<String>,
    pub all_assets: Vec<GitHubReleaseAsset>,
    pub has_update: bool,
}

pub fn parse_semver_relaxed(raw: &str) -> Option<Version> {
    let cleaned = raw.trim().trim_start_matches(['v', 'V']);
    Version::parse(cleaned).ok()
}

pub fn is_newer_version(current_raw: &str, latest_raw: &str) -> bool {
    match (
        parse_semver_relaxed(current_raw),
        parse_semver_relaxed(latest_raw),
    ) {
        (Some(cur), Some(lat)) => lat > cur,
        _ => {
            let c = current_raw.trim().trim_start_matches(['v', 'V']);
            let l = latest_raw.trim().trim_start_matches(['v', 'V']);
            !l.is_empty() && l != c
        }
    }
}

pub fn select_best_asset(
    assets: &[GitHubReleaseAsset],
    platform: &str,
    arch: &str,
) -> Option<GitHubReleaseAsset> {
    if platform.eq_ignore_ascii_case("ios") {
        return assets
            .iter()
            .find(|a| a.name.to_lowercase().ends_with(".ipa"))
            .cloned();
    }

    let preferred_substr = match arch {
        "arm64-v8a" => "arm64-v8a.apk",
        "armeabi-v7a" => "arm32-v7a.apk",
        _ => "universal.apk",
    };

    assets
        .iter()
        .find(|a| a.name.to_lowercase().contains(preferred_substr))
        .or_else(|| {
            assets
                .iter()
                .find(|a| a.name.to_lowercase().contains("universal.apk"))
        })
        .or_else(|| {
            assets
                .iter()
                .find(|a| a.name.to_lowercase().ends_with(".apk"))
        })
        .cloned()
}

pub fn format_bytes(bytes: u64) -> String {
    if bytes >= 1_048_576 {
        format!("{:.1} MB", bytes as f64 / 1_048_576.0)
    } else if bytes >= 1024 {
        format!("{:.1} KB", bytes as f64 / 1024.0)
    } else {
        format!("{bytes} B")
    }
}

pub fn evaluate_release(
    payload: GitHubReleasePayload,
    current_version: &str,
    platform: &str,
    arch: &str,
) -> UpdateCheckResult {
    let latest_clean = payload
        .tag_name
        .trim()
        .trim_start_matches(['v', 'V'])
        .to_string();
    let has_update = is_newer_version(current_version, &latest_clean);
    let recommended_asset = select_best_asset(&payload.assets, platform, arch);
    let checksums_url = payload
        .assets
        .iter()
        .find(|a| a.name.eq_ignore_ascii_case("SHA256SUMS.txt"))
        .map(|a| a.browser_download_url.clone());

    let release_title = payload
        .name
        .filter(|s| !s.trim().is_empty())
        .unwrap_or_else(|| format!("Chat BLN {}", payload.tag_name));

    let changelog = payload
        .body
        .filter(|s| !s.trim().is_empty())
        .unwrap_or_else(|| "Bản phát hành mới kèm tối ưu hiệu năng và sửa lỗi.".to_string());

    let published_at = payload
        .published_at
        .as_deref()
        .map(|s| s.split('T').next().unwrap_or(s).to_string())
        .unwrap_or_default();

    UpdateCheckResult {
        current_version: current_version.to_string(),
        latest_version: latest_clean,
        latest_tag: payload.tag_name,
        release_title,
        changelog,
        published_at,
        release_page_url: payload.html_url,
        recommended_asset,
        checksums_url,
        all_assets: payload.assets,
        has_update,
    }
}

pub async fn check_for_updates() -> Result<UpdateCheckResult, String> {
    check_for_updates_from_repo(GITHUB_REPO, APP_VERSION, TARGET_PLATFORM, current_arch_label())
        .await
}

pub async fn check_for_updates_from_repo(
    repo: &str,
    current_version: &str,
    platform: &str,
    arch: &str,
) -> Result<UpdateCheckResult, String> {
    let url = format!("https://api.github.com/repos/{repo}/releases/latest");
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(12))
        .user_agent(format!("ChatBLN-Rust/{current_version}"))
        .build()
        .map_err(|e| format!("Không thể khởi tạo HTTP client: {e}"))?;

    let resp = client
        .get(&url)
        .header("Accept", "application/vnd.github+json")
        .send()
        .await
        .map_err(|e| format!("Không thể kết nối GitHub Releases: {e}"))?;

    let status = resp.status();
    if status.as_u16() == 404 {
        return Err("Chưa có bản phát hành nào trên kho GitHub.".to_string());
    }
    if status.as_u16() == 403 {
        return Err("GitHub API tạm giới hạn lượt kiểm tra. Thử lại sau vài phút.".to_string());
    }
    if !status.is_success() {
        return Err(format!("Lỗi kiểm tra cập nhật (HTTP {}).", status.as_u16()));
    }

    let payload = resp
        .json::<GitHubReleasePayload>()
        .await
        .map_err(|e| format!("Không đọc được dữ liệu phát hành: {e}"))?;

    Ok(evaluate_release(payload, current_version, platform, arch))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compares_semver_versions_accurately() {
        assert!(is_newer_version("3.0.0", "v3.0.1"));
        assert!(is_newer_version("3.0.9", "v3.0.10"));
        assert!(is_newer_version("3.0.10", "v3.1.0"));
        assert!(is_newer_version("2.0.0", "v3.0.0"));
        assert!(!is_newer_version("3.0.0", "v3.0.0"));
        assert!(!is_newer_version("3.1.0", "v3.0.10"));
    }

    #[test]
    fn picks_architecture_specific_mobile_assets() {
        let android_assets = vec![
            GitHubReleaseAsset {
                name: "ChatBLN-arm32-v7a.apk".into(),
                browser_download_url: "https://example.com/arm32.apk".into(),
                size: 12_000_000,
            },
            GitHubReleaseAsset {
                name: "ChatBLN-arm64-v8a.apk".into(),
                browser_download_url: "https://example.com/arm64.apk".into(),
                size: 13_500_000,
            },
            GitHubReleaseAsset {
                name: "ChatBLN-arm-universal.apk".into(),
                browser_download_url: "https://example.com/universal.apk".into(),
                size: 21_000_000,
            },
        ];

        assert_eq!(
            select_best_asset(&android_assets, "android", "arm64-v8a")
                .unwrap()
                .name,
            "ChatBLN-arm64-v8a.apk"
        );
        assert_eq!(
            select_best_asset(&android_assets, "android", "armeabi-v7a")
                .unwrap()
                .name,
            "ChatBLN-arm32-v7a.apk"
        );
        assert_eq!(
            select_best_asset(&android_assets, "android", "universal")
                .unwrap()
                .name,
            "ChatBLN-arm-universal.apk"
        );

        let ios_assets = vec![GitHubReleaseAsset {
            name: "ChatBLN-iOS18.ipa".into(),
            browser_download_url: "https://example.com/ChatBLN-iOS18.ipa".into(),
            size: 9_200_000,
        }];
        assert_eq!(
            select_best_asset(&ios_assets, "ios", "arm64")
                .unwrap()
                .name,
            "ChatBLN-iOS18.ipa"
        );
    }

    #[test]
    fn evaluates_release_payload_end_to_end() {
        let payload = GitHubReleasePayload {
            tag_name: "v3.1.0".into(),
            name: Some("Chat BLN Android v3.1.0".into()),
            body: Some("### Tính năng mới\n- Kiểm tra cập nhật".into()),
            html_url: "https://github.com/fishuvn/chat-bln-android/releases/tag/v3.1.0".into(),
            published_at: Some("2026-11-26T12:00:00Z".into()),
            prerelease: false,
            draft: false,
            assets: vec![
                GitHubReleaseAsset {
                    name: "ChatBLN-arm64-v8a.apk".into(),
                    browser_download_url: "https://example.com/arm64.apk".into(),
                    size: 10_485_760,
                },
                GitHubReleaseAsset {
                    name: "SHA256SUMS.txt".into(),
                    browser_download_url: "https://example.com/SHA256SUMS.txt".into(),
                    size: 512,
                },
            ],
        };

        let result = evaluate_release(payload, "3.0.0", "android", "arm64-v8a");
        assert!(result.has_update);
        assert_eq!(result.latest_version, "3.1.0");
        assert_eq!(result.published_at, "2026-11-26");
        assert!(result.checksums_url.is_some());
        assert_eq!(format_bytes(10_485_760), "10.0 MB");
    }
}
