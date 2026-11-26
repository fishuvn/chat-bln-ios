use crate::components::icons::Icon;
use crate::config::{
    current_arch_label, normalize_server_url, resolve_asset_url, APP_VERSION, GITHUB_REPO,
    PLATFORM_DISPLAY_NAME,
};
use crate::models::{initials_of, presence_label, UpdateProfileRequest};
use crate::state::{AppState, UpdateUiState};
use crate::storage::save_session;
use crate::updater::format_bytes;
use dioxus::prelude::*;

#[component]
pub fn UpdateBanner(mut state: AppState) -> Element {
    let dismissed = state.session.read().dismissed_update_tag.clone();
    let update = state.update_state.read().clone();

    if let UpdateUiState::Available(info) = update {
        if dismissed.as_deref() == Some(info.latest_tag.as_str()) {
            return rsx! {};
        }
        let tag_for_dismiss = info.latest_tag.clone();
        return rsx! {
            div { class: "update-banner", role: "status",
                span { style: "overflow:hidden; text-overflow:ellipsis; white-space:nowrap;",
                    "Có bản cập nhật mới {info.latest_tag}"
                }
                div { class: "update-banner-actions",
                    button {
                        class: "ui-btn ui-btn-primary sm",
                        onclick: move |_| state.show_update_modal.set(true),
                        "Xem & Tải"
                    }
                    button {
                        class: "icon-btn",
                        style: "width:34px; height:34px;",
                        title: "Ẩn thông báo này",
                        onclick: move |_| {
                            let mut s = state.session.write();
                            s.dismissed_update_tag = Some(tag_for_dismiss.clone());
                            save_session(&s);
                        },
                        Icon { name: "close", size: 16 }
                    }
                }
            }
        };
    }

    rsx! {}
}

#[component]
pub fn UpdateModal(mut state: AppState) -> Element {
    if !*state.show_update_modal.read() {
        return rsx! {};
    }

    let ustate = state.update_state.read().clone();

    rsx! {
        div { class: "modal-scrim", onclick: move |_| state.show_update_modal.set(false),
            div { class: "modal-sheet", onclick: move |e| e.stop_propagation(),
                div { class: "section-title",
                    span { "Kiểm tra cập nhật ứng dụng" }
                    button { class: "icon-btn", onclick: move |_| state.show_update_modal.set(false),
                        Icon { name: "close", size: 18 }
                    }
                }

                match ustate {
                    UpdateUiState::Checking => rsx! {
                        div { class: "empty-box", "Đang kiểm tra bản phát hành mới nhất từ GitHub..." }
                    },
                    UpdateUiState::Error(err) => rsx! {
                        div { class: "alert alert-error", "{err}" }
                        button {
                            class: "ui-btn ui-btn-primary block",
                            onclick: move |_| state.trigger_update_check(false),
                            "Thử kiểm tra lại"
                        }
                    },
                    UpdateUiState::UpToDate(info) => rsx! {
                        div { class: "alert alert-success",
                            "Bạn đang dùng phiên bản mới nhất (v{info.current_version})."
                        }
                        div { class: "kv-row",
                            span { class: "kv-key", "Phiên bản hiện tại" }
                            span { class: "kv-val", "v{info.current_version}" }
                        }
                        div { class: "kv-row",
                            span { class: "kv-key", "Bản mới nhất trên GitHub" }
                            span { class: "kv-val", "{info.latest_tag}" }
                        }
                        div { class: "kv-row",
                            span { class: "kv-key", "Kiến trúc thiết bị" }
                            span { class: "kv-val", "{current_arch_label()}" }
                        }
                        a {
                            class: "ui-btn ui-btn-outline block",
                            style: "margin-top:14px; text-decoration:none;",
                            href: "{info.release_page_url}",
                            target: "_blank",
                            "Mở trang GitHub Releases"
                        }
                    },
                    UpdateUiState::Available(info) => rsx! {
                        div { class: "alert alert-info",
                            strong { "{info.release_title}" }
                            " — Phát hành {info.published_at}"
                        }
                        div { class: "kv-row",
                            span { class: "kv-key", "Đang cài đặt" }
                            span { class: "kv-val", "v{info.current_version}" }
                        }
                        div { class: "kv-row",
                            span { class: "kv-key", "Phiên bản mới" }
                            span { class: "kv-val", style: "color:var(--accent-text);", "{info.latest_tag}" }
                        }
                        div { class: "changelog-box", "{info.changelog}" }

                        if let Some(asset) = &info.recommended_asset {
                            a {
                                class: "ui-btn ui-btn-primary block",
                                style: "text-decoration:none; margin-bottom:10px;",
                                href: "{asset.browser_download_url}",
                                target: "_blank",
                                Icon { name: "download", size: 18 }
                                span { "Tải {asset.name} ({format_bytes(asset.size)})" }
                            }
                        }

                        div { class: "row-actions",
                            a {
                                class: "ui-btn ui-btn-outline sm",
                                style: "flex:1; text-decoration:none;",
                                href: "{info.release_page_url}",
                                target: "_blank",
                                "Xem chi tiết Release"
                            }
                            if let Some(sha_url) = &info.checksums_url {
                                a {
                                    class: "ui-btn ui-btn-secondary sm",
                                    style: "text-decoration:none;",
                                    href: "{sha_url}",
                                    target: "_blank",
                                    "SHA-256"
                                }
                            }
                        }
                    },
                    UpdateUiState::Idle => rsx! {
                        button {
                            class: "ui-btn ui-btn-primary block",
                            onclick: move |_| state.trigger_update_check(false),
                            "Kiểm tra cập nhật ngay"
                        }
                    },
                }
            }
        }
    }
}

#[component]
pub fn ProfileView(mut state: AppState) -> Element {
    let user = state.current_user().unwrap_or_default();
    let server_url = state.session.read().server_url.clone();
    let dark_mode = state.session.read().dark_mode;
    let update_state = state.update_state.read().clone();

    let mut editing = use_signal(|| false);
    let mut full_name = use_signal(|| user.full_name.clone().unwrap_or_default());
    let mut email = use_signal(|| user.email.clone().unwrap_or_default());
    let mut phone = use_signal(|| user.phone.clone().unwrap_or_default());
    let mut bio = use_signal(|| user.bio.clone().unwrap_or_default());
    let mut server_input = use_signal(move || server_url.clone());
    let mut saving = use_signal(|| false);

    let presence_modes = [
        ("ONLINE", "Trực tuyến", "presence-online"),
        ("IDLE", "Tạm vắng", "presence-idle"),
        ("SLEEP", "Chế độ ngủ", "presence-sleep"),
        ("DND", "Không làm phiền", "presence-dnd"),
        ("OFFLINE", "Ẩn trạng thái", "presence-offline"),
    ];

    let active_presence = user.effective_presence();
    let avatar_src = resolve_asset_url(&state.session.read().server_url, user.avatar_url.as_deref());

    rsx! {
        div { class: "shell-content",
            div { class: "top-bar",
                h1 { class: "top-bar-title", "Hồ sơ & Cài đặt" }
                button {
                    class: "icon-btn",
                    title: "Đổi giao diện Sáng/Tối",
                    onclick: move |_| {
                        let mut s = state.session.write();
                        s.dark_mode = !s.dark_mode;
                        save_session(&s);
                    },
                    if dark_mode {
                        Icon { name: "sun", size: 20 }
                    } else {
                        Icon { name: "moon", size: 20 }
                    }
                }
            }

            div { class: "scroll-pane",
                // User Header Card
                div { class: "section-card",
                    div { style: "display:flex; align-items:center; gap:14px; margin-bottom:12px;",
                        div { class: "avatar-wrap",
                            div { class: "avatar-circle",
                                if let Some(src) = avatar_src {
                                    img { src: "{src}", alt: "{user.display_name()}" }
                                } else {
                                    "{initials_of(user.display_name())}"
                                }
                            }
                            span { class: "presence-badge presence-{active_presence.to_lowercase()}" }
                        }
                        div { style: "flex:1; min-width:0;",
                            div { class: "card-title", "{user.display_name()}" }
                            div { class: "card-sub", "@{user.username} • {presence_label(active_presence)}" }
                        }
                        button {
                            class: "ui-btn ui-btn-secondary sm",
                            onclick: move |_| {
                                let cur = *editing.read();
                                if !cur {
                                    if let Some(u) = state.current_user() {
                                        full_name.set(u.full_name.unwrap_or_default());
                                        email.set(u.email.unwrap_or_default());
                                        phone.set(u.phone.unwrap_or_default());
                                        bio.set(u.bio.unwrap_or_default());
                                    }
                                }
                                editing.set(!cur);
                            },
                            if *editing.read() { "Hủy" } else { "Sửa" }
                        }
                    }

                    if *editing.read() {
                        div { class: "field",
                            label { class: "field-label", "Họ và tên" }
                            input { class: "ui-input", value: "{full_name}", oninput: move |e| full_name.set(e.value()) }
                        }
                        div { class: "field",
                            label { class: "field-label", "Email" }
                            input { class: "ui-input", value: "{email}", oninput: move |e| email.set(e.value()) }
                        }
                        div { class: "field",
                            label { class: "field-label", "Số điện thoại" }
                            input { class: "ui-input", value: "{phone}", oninput: move |e| phone.set(e.value()) }
                        }
                        div { class: "field",
                            label { class: "field-label", "Tiểu sử" }
                            input { class: "ui-input", value: "{bio}", oninput: move |e| bio.set(e.value()) }
                        }
                        button {
                            class: "ui-btn ui-btn-primary block",
                            disabled: *saving.read(),
                            onclick: move |_| {
                                saving.set(true);
                                let api = state.api();
                                let existing = state.current_user().unwrap_or_default();
                                let req = UpdateProfileRequest {
                                    full_name: Some(full_name.read().trim().to_string()),
                                    email: Some(email.read().trim().to_string()),
                                    phone: Some(phone.read().trim().to_string()),
                                    gender: existing.gender,
                                    dob: existing.dob,
                                    bio: Some(bio.read().trim().to_string()),
                                    avatar_url: existing.avatar_url,
                                };
                                spawn(async move {
                                    match api.update_my_profile(req).await {
                                        Ok(updated) => {
                                            {
                                                let mut s = state.session.write();
                                                s.user = Some(updated);
                                                save_session(&s);
                                            }
                                            editing.set(false);
                                            state.notify("Đã cập nhật hồ sơ.");
                                        }
                                        Err(e) => state.handle_error(e),
                                    }
                                    saving.set(false);
                                });
                            },
                            if *saving.read() { "Đang lưu..." } else { "Lưu thay đổi" }
                        }
                    }
                }

                // 5-Mode Realtime Presence Card
                div { class: "section-card",
                    div { class: "section-title",
                        span { "Trạng thái hoạt động (Realtime)" }
                        span { class: "pill", "{presence_label(active_presence)}" }
                    }
                    div { class: "row-actions",
                        for (code, label, dot_cls) in presence_modes {
                            button {
                                key: "{code}",
                                class: if active_presence == code { "chip active" } else { "chip" },
                                onclick: move |_| {
                                    let api = state.api();
                                    let next = code.to_string();
                                    spawn(async move {
                                        match api.update_my_presence(next).await {
                                            Ok(updated) => {
                                                {
                                                    let mut s = state.session.write();
                                                    s.user = Some(updated);
                                                    save_session(&s);
                                                }
                                                state.notify(format!("Đã chuyển sang: {label}"));
                                            }
                                            Err(e) => state.handle_error(e),
                                        }
                                    });
                                },
                                span {
                                    class: "{dot_cls}",
                                    style: "display:inline-block; width:8px; height:8px; border-radius:99px; margin-right:6px;",
                                }
                                "{label}"
                            }
                        }
                    }
                }

                // Dedicated App Update Checker Card
                div { class: "section-card",
                    div { class: "section-title",
                        span { "Cập nhật ứng dụng" }
                        match &update_state {
                            UpdateUiState::Available(info) => rsx! {
                                span { class: "pill pill-accent", "Có bản mới {info.latest_tag}" }
                            },
                            UpdateUiState::UpToDate(_) => rsx! {
                                span { class: "pill", "Mới nhất" }
                            },
                            UpdateUiState::Checking => rsx! {
                                span { class: "pill", "Đang kiểm tra..." }
                            },
                            _ => rsx! {
                                span { class: "pill", "v{APP_VERSION}" }
                            },
                        }
                    }
                    div { class: "kv-row",
                        span { class: "kv-key", "Phiên bản hiện tại" }
                        span { class: "kv-val", "v{APP_VERSION}" }
                    }
                    div { class: "kv-row",
                        span { class: "kv-key", "Nền tảng / Kiến trúc" }
                        span { class: "kv-val", "{PLATFORM_DISPLAY_NAME} • {current_arch_label()}" }
                    }
                    div { class: "kv-row",
                        span { class: "kv-key", "Kho phát hành" }
                        span { class: "kv-val", "{GITHUB_REPO}" }
                    }

                    div { class: "row-actions", style: "margin-top:12px;",
                        button {
                            class: "ui-btn ui-btn-primary sm",
                            style: "flex:1;",
                            disabled: matches!(update_state, UpdateUiState::Checking),
                            onclick: move |_| state.trigger_update_check(false),
                            Icon { name: "refresh", size: 16 }
                            span {
                                if matches!(update_state, UpdateUiState::Checking) {
                                    "Đang kiểm tra..."
                                } else {
                                    "Kiểm tra cập nhật"
                                }
                            }
                        }
                        if matches!(update_state, UpdateUiState::Available(_) | UpdateUiState::UpToDate(_)) {
                            button {
                                class: "ui-btn ui-btn-outline sm",
                                onclick: move |_| state.show_update_modal.set(true),
                                "Xem chi tiết"
                            }
                        }
                    }
                }

                // Server Endpoint Card
                div { class: "section-card",
                    div { class: "section-title", span { "Máy chủ kết nối" } }
                    div { style: "display:flex; gap:8px;",
                        input {
                            class: "ui-input",
                            value: "{server_input}",
                            oninput: move |e| server_input.set(e.value()),
                        }
                        button {
                            class: "ui-btn ui-btn-secondary sm",
                            onclick: move |_| {
                                let norm = normalize_server_url(&server_input.read());
                                {
                                    let mut s = state.session.write();
                                    s.server_url = norm.clone();
                                    save_session(&s);
                                }
                                state.notify(format!("Đã cập nhật máy chủ: {norm}"));
                                state.trigger_refresh_all();
                            },
                            "Lưu"
                        }
                    }
                }

                button {
                    class: "ui-btn ui-btn-danger-soft block",
                    onclick: move |_| {
                        let api = state.api();
                        spawn(async move {
                            let _ = api.logout().await;
                            state.force_logout(Some("Đã đăng xuất."));
                        });
                    },
                    "Đăng xuất tài khoản"
                }
            }
        }
    }
}
