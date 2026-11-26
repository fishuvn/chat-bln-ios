use crate::components::icons::Icon;
use crate::config::resolve_asset_url;
use crate::models::{initials_of, presence_label, UserSearchResponse};
use crate::state::{AppState, MainTab};
use dioxus::prelude::*;

#[component]
pub fn ContactsView(mut state: AppState) -> Element {
    let mut keyword = use_signal(String::new);
    let mut search_results = use_signal(Vec::<UserSearchResponse>::new);
    let mut searching = use_signal(|| false);
    let mut searched = use_signal(|| false);

    let server_url = state.session.read().server_url.clone();
    let friends = state.friends.read().clone();

    let run_search = move |_| {
        let q = keyword.read().trim().to_string();
        if q.is_empty() {
            search_results.set(Vec::new());
            searched.set(false);
            return;
        }
        searching.set(true);
        let api = state.api();
        spawn(async move {
            match api.search_users(&q).await {
                Ok(list) => {
                    search_results.set(list);
                    searched.set(true);
                }
                Err(e) => state.handle_error(e),
            }
            searching.set(false);
        });
    };

    rsx! {
        div { class: "shell-content",
            div { class: "top-bar",
                h1 { class: "top-bar-title", "Danh bạ ({friends.len()})" }
                button {
                    class: "icon-btn",
                    title: "Làm mới danh bạ",
                    onclick: move |_| state.trigger_refresh_all(),
                    Icon { name: "refresh", size: 20 }
                }
            }

            div { class: "scroll-pane",
                // Search & Add Friend Card
                div { class: "section-card",
                    div { class: "section-title", span { "Tìm & Kết bạn mới" } }
                    div { style: "display:flex; gap:8px;",
                        input {
                            class: "ui-input",
                            value: "{keyword}",
                            placeholder: "Nhập tên hoặc username...",
                            oninput: move |e| keyword.set(e.value()),
                        }
                        button {
                            class: "ui-btn ui-btn-primary sm",
                            disabled: *searching.read(),
                            onclick: run_search,
                            if *searching.read() { "..." } else { "Tìm" }
                        }
                    }

                    if *searched.read() {
                        div { style: "margin-top:12px;",
                            if search_results.read().is_empty() {
                                div { class: "card-sub", "Không tìm thấy người dùng phù hợp." }
                            } else {
                                for u in search_results.read().clone() {
                                    {
                                        let uid = u.id;
                                        let av = resolve_asset_url(&server_url, u.avatar_url.as_deref());
                                        let is_friend = u.is_friend.unwrap_or(false)
                                            || u.friendship_status.as_deref() == Some("ACCEPTED");
                                        let is_pending = u.friendship_status.as_deref() == Some("PENDING");
                                        rsx! {
                                            div { key: "sr-{uid}", class: "list-card", style: "cursor:default;",
                                                div { class: "avatar-wrap",
                                                    div { class: "avatar-circle",
                                                        if let Some(src) = av {
                                                            img { src: "{src}", alt: "{u.display_name()}" }
                                                        } else {
                                                            "{initials_of(u.display_name())}"
                                                        }
                                                    }
                                                }
                                                div { class: "card-main",
                                                    div { class: "card-title", "{u.display_name()}" }
                                                    div { class: "card-sub", "@{u.username}" }
                                                }
                                                if is_friend {
                                                    span { class: "pill pill-accent", "Bạn bè" }
                                                } else if is_pending {
                                                    span { class: "pill", "Đang chờ" }
                                                } else {
                                                    button {
                                                        class: "ui-btn ui-btn-primary sm",
                                                        onclick: move |_| {
                                                            let api = state.api();
                                                            spawn(async move {
                                                                match api.send_friend_request(uid).await {
                                                                    Ok(_) => {
                                                                        state.notify("Đã gửi lời mời kết bạn.");
                                                                        state.trigger_refresh_all();
                                                                    }
                                                                    Err(e) => state.handle_error(e),
                                                                }
                                                            });
                                                        },
                                                        "Kết bạn"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Friends List
                div { class: "section-title", style: "margin-top:8px;",
                    span { "Bạn bè hiện tại" }
                }
                if friends.is_empty() {
                    div { class: "empty-box", "Chưa có bạn bè. Tìm kiếm username ở trên để kết bạn." }
                } else {
                    for f in friends {
                        {
                            let fid = f.id;
                            let pres = f.effective_presence();
                            let av = resolve_asset_url(&server_url, f.avatar_url.as_deref());
                            rsx! {
                                div { key: "fr-{fid}", class: "list-card", style: "cursor:default;",
                                    div { class: "avatar-wrap",
                                        div { class: "avatar-circle",
                                            if let Some(src) = av {
                                                img { src: "{src}", alt: "{f.display_name()}" }
                                            } else {
                                                "{initials_of(f.display_name())}"
                                            }
                                        }
                                        span { class: "presence-badge presence-{pres.to_lowercase()}" }
                                    }
                                    div { class: "card-main",
                                        div { class: "card-title", "{f.display_name()}" }
                                        div { class: "card-sub", "@{f.username} • {presence_label(pres)}" }
                                    }
                                    div { class: "row-actions",
                                        button {
                                            class: "ui-btn ui-btn-primary sm",
                                            onclick: move |_| {
                                                let api = state.api();
                                                spawn(async move {
                                                    match api.create_private_conversation(fid).await {
                                                        Ok(conv) => {
                                                            state.active_chat_id.set(Some(conv.id));
                                                            state.active_tab.set(MainTab::Chats);
                                                            state.trigger_refresh_all();
                                                        }
                                                        Err(e) => state.handle_error(e),
                                                    }
                                                });
                                            },
                                            "Nhắn"
                                        }
                                        button {
                                            class: "ui-btn ui-btn-danger-soft sm",
                                            onclick: move |_| {
                                                let api = state.api();
                                                spawn(async move {
                                                    match api.unfriend(fid).await {
                                                        Ok(_) => {
                                                            state.notify("Đã hủy kết bạn.");
                                                            state.trigger_refresh_all();
                                                        }
                                                        Err(e) => state.handle_error(e),
                                                    }
                                                });
                                            },
                                            "Hủy"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

#[component]
pub fn RequestsView(mut state: AppState) -> Element {
    let server_url = state.session.read().server_url.clone();
    let received = state.received_requests.read().clone();
    let sent = state.sent_requests.read().clone();

    rsx! {
        div { class: "shell-content",
            div { class: "top-bar",
                h1 { class: "top-bar-title", "Lời mời kết bạn" }
                button {
                    class: "icon-btn",
                    title: "Làm mới lời mời",
                    onclick: move |_| state.trigger_refresh_all(),
                    Icon { name: "refresh", size: 20 }
                }
            }

            div { class: "scroll-pane",
                div { class: "section-title", span { "Đã nhận ({received.len()})" } }
                if received.is_empty() {
                    div { class: "section-card",
                        div { class: "card-sub", "Không có lời mời kết bạn nào đang chờ." }
                    }
                } else {
                    for req in received {
                        {
                            let req_id = req.id;
                            let name = req.requester_full_name
                                .as_deref()
                                .filter(|s| !s.trim().is_empty())
                                .or(req.requester_username.as_deref())
                                .unwrap_or("Người dùng")
                                .to_string();
                            let uname = req.requester_username.clone().unwrap_or_default();
                            let av = resolve_asset_url(&server_url, req.requester_avatar_url.as_deref());
                            rsx! {
                                div { key: "rec-{req_id}", class: "list-card", style: "cursor:default;",
                                    div { class: "avatar-wrap",
                                        div { class: "avatar-circle",
                                            if let Some(src) = av {
                                                img { src: "{src}", alt: "{name}" }
                                            } else {
                                                "{initials_of(&name)}"
                                            }
                                        }
                                    }
                                    div { class: "card-main",
                                        div { class: "card-title", "{name}" }
                                        div { class: "card-sub", "@{uname}" }
                                    }
                                    div { class: "row-actions",
                                        button {
                                            class: "ui-btn ui-btn-primary sm",
                                            onclick: move |_| {
                                                let api = state.api();
                                                spawn(async move {
                                                    match api.accept_friend_request(req_id).await {
                                                        Ok(_) => {
                                                            state.notify("Đã chấp nhận lời mời kết bạn.");
                                                            state.trigger_refresh_all();
                                                        }
                                                        Err(e) => state.handle_error(e),
                                                    }
                                                });
                                            },
                                            "Đồng ý"
                                        }
                                        button {
                                            class: "ui-btn ui-btn-danger-soft sm",
                                            onclick: move |_| {
                                                let api = state.api();
                                                spawn(async move {
                                                    match api.reject_friend_request(req_id).await {
                                                        Ok(_) => {
                                                            state.notify("Đã từ chối lời mời.");
                                                            state.trigger_refresh_all();
                                                        }
                                                        Err(e) => state.handle_error(e),
                                                    }
                                                });
                                            },
                                            "Từ chối"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                div { class: "section-title", style: "margin-top:16px;",
                    span { "Đã gửi ({sent.len()})" }
                }
                if sent.is_empty() {
                    div { class: "section-card",
                        div { class: "card-sub", "Bạn chưa gửi lời mời kết bạn nào." }
                    }
                } else {
                    for req in sent {
                        {
                            let req_id = req.id;
                            let name = req.addressee_full_name
                                .as_deref()
                                .filter(|s| !s.trim().is_empty())
                                .or(req.addressee_username.as_deref())
                                .unwrap_or("Người dùng")
                                .to_string();
                            let uname = req.addressee_username.clone().unwrap_or_default();
                            rsx! {
                                div { key: "sent-{req_id}", class: "list-card", style: "cursor:default;",
                                    div { class: "avatar-wrap",
                                        div { class: "avatar-circle", "{initials_of(&name)}" }
                                    }
                                    div { class: "card-main",
                                        div { class: "card-title", "{name}" }
                                        div { class: "card-sub", "@{uname} • Đang chờ phản hồi" }
                                    }
                                    button {
                                        class: "ui-btn ui-btn-secondary sm",
                                        onclick: move |_| {
                                            let api = state.api();
                                            spawn(async move {
                                                match api.cancel_sent_friend_request(req_id).await {
                                                    Ok(_) => {
                                                        state.notify("Đã thu hồi lời mời kết bạn.");
                                                        state.trigger_refresh_all();
                                                    }
                                                    Err(e) => state.handle_error(e),
                                                }
                                            });
                                        },
                                        "Thu hồi"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
