pub mod api;
pub mod components;
pub mod config;
pub mod models;
pub mod state;
pub mod stomp;
pub mod storage;
pub mod styles;
pub mod updater;

use crate::components::auth::AuthRoot;
use crate::components::chats::ChatsRoot;
use crate::components::contacts::{ContactsView, RequestsView};
use crate::components::icons::Icon;
use crate::components::profile::{ProfileView, UpdateBanner, UpdateModal};
use crate::state::{AppState, MainTab, UpdateUiState};
use crate::stomp::{spawn_stomp_session, RealtimeEvent, StompCommand};
use crate::styles::QUIET_SIGNAL_CSS;
use dioxus::prelude::*;
use tokio::sync::mpsc;

#[component]
pub fn App() -> Element {
    let mut state = AppState::init();
    let mut startup_checked = use_signal(|| false);
    let mut ws_booted_user = use_signal(|| None::<String>);

    // Silent background update check once at launch
    use_effect(move || {
        if !*startup_checked.read() {
            startup_checked.set(true);
            state.trigger_update_check(true);
        }
    });

    // Manage STOMP realtime session automatically whenever auth state changes
    let auth_key = {
        let s = state.session.read();
        match (&s.token, &s.user) {
            (Some(tok), Some(u)) if !tok.is_empty() => {
                Some((s.server_url.clone(), tok.clone(), u.username.clone()))
            }
            _ => None,
        }
    };

    use_effect(move || {
        let current_key = auth_key.as_ref().map(|(s, t, u)| format!("{s}|{u}|{}", t.len()));
        if *ws_booted_user.read() == current_key {
            return;
        }
        ws_booted_user.set(current_key);

        if let Some(old_tx) = state.stomp_tx.write().take() {
            let _ = old_tx.send(StompCommand::Disconnect);
        }

        if let Some((server_url, token, username)) = auth_key.clone() {
            let (ev_tx, mut ev_rx) = mpsc::unbounded_channel::<RealtimeEvent>();
            let initial_ids: Vec<i64> = state.conversations.read().iter().map(|c| c.id).collect();
            let cmd_tx = spawn_stomp_session(server_url, token, username, initial_ids, ev_tx);
            state.stomp_tx.set(Some(cmd_tx));
            state.trigger_refresh_all();

            spawn(async move {
                while let Some(ev) = ev_rx.recv().await {
                    match ev {
                        RealtimeEvent::ConnectionChanged(ok) => {
                            state.ws_connected.set(ok);
                        }
                        RealtimeEvent::Message(msg) => {
                            let cid = msg.conversation_id;
                            {
                                let mut map = state.messages.write();
                                let list = map.entry(cid).or_default();
                                if !list.iter().any(|m| m.id == msg.id) {
                                    list.push(msg.clone());
                                }
                            }
                            let mut convs = state.conversations.write();
                            if let Some(c) = convs.iter_mut().find(|c| c.id == cid) {
                                c.last_message = Some(if msg.content.trim().is_empty() {
                                    "[Tệp đính kèm]".into()
                                } else {
                                    msg.content.clone()
                                });
                                c.last_message_time = msg.created_at.clone();
                            }
                        }
                        RealtimeEvent::Presence(p) => {
                            {
                                let mut convs = state.conversations.write();
                                for c in convs.iter_mut() {
                                    if c.target_user_id == Some(p.user_id) {
                                        c.is_online = Some(p.is_online);
                                        c.presence_status = p.presence_status.clone();
                                    }
                                }
                            }
                            {
                                let mut frs = state.friends.write();
                                for f in frs.iter_mut() {
                                    if f.id == p.user_id {
                                        f.is_online = p.is_online;
                                        f.presence_status = p.presence_status.clone();
                                    }
                                }
                            }
                            let is_me = state.current_user().map(|u| u.id == p.user_id).unwrap_or(false);
                            if is_me {
                                if let Some(u) = state.session.write().user.as_mut() {
                                    u.is_online = Some(p.is_online);
                                    u.presence_status = p.presence_status.clone();
                                }
                            }
                        }
                        RealtimeEvent::Deletion(del) => {
                            if let Some(list) = state.messages.write().get_mut(&del.conversation_id) {
                                list.retain(|m| !del.deleted_ids.contains(&m.id));
                            }
                            if let Some(c) = state
                                .conversations
                                .write()
                                .iter_mut()
                                .find(|c| c.id == del.conversation_id)
                            {
                                c.last_message = del.last_message.clone();
                                c.last_message_time = del.last_message_time.clone();
                            }
                        }
                        RealtimeEvent::Friendship(_) => {
                            state.trigger_refresh_all();
                        }
                    }
                }
            });
        }
    });

    let dark = state.session.read().dark_mode;
    let has_banner = match &*state.update_state.read() {
        UpdateUiState::Available(info) => {
            state.session.read().dismissed_update_tag.as_deref() != Some(info.latest_tag.as_str())
        }
        _ => false,
    };
    let root_cls = format!(
        "app-root {} {}",
        if dark { "dark" } else { "" },
        if has_banner { "has-banner" } else { "" }
    );
    let req_count = state.received_requests.read().len();
    let active_tab = *state.active_tab.read();
    let in_room = state.active_chat_id.read().is_some();

    rsx! {
        style { "{QUIET_SIGNAL_CSS}" }
        div { class: "{root_cls}",
            UpdateBanner { state }

            if !state.is_authenticated() {
                AuthRoot { state }
            } else {
                div { class: "main-shell",
                    match active_tab {
                        MainTab::Chats => rsx! { ChatsRoot { state } },
                        MainTab::Contacts => rsx! { ContactsView { state } },
                        MainTab::Requests => rsx! { RequestsView { state } },
                        MainTab::Profile => rsx! { ProfileView { state } },
                    }

                    if !in_room {
                        nav { class: "bottom-nav", "aria-label": "Điều hướng chính",
                            button {
                                class: if active_tab == MainTab::Chats { "nav-item active" } else { "nav-item" },
                                onclick: move |_| state.active_tab.set(MainTab::Chats),
                                Icon { name: "chat", size: 20 }
                                span { "Trò chuyện" }
                            }
                            button {
                                class: if active_tab == MainTab::Contacts { "nav-item active" } else { "nav-item" },
                                onclick: move |_| state.active_tab.set(MainTab::Contacts),
                                Icon { name: "contacts", size: 20 }
                                span { "Danh bạ" }
                            }
                            button {
                                class: if active_tab == MainTab::Requests { "nav-item active" } else { "nav-item" },
                                onclick: move |_| state.active_tab.set(MainTab::Requests),
                                Icon { name: "requests", size: 20 }
                                span { "Lời mời" }
                                if req_count > 0 {
                                    span { class: "nav-badge", "{req_count}" }
                                }
                            }
                            button {
                                class: if active_tab == MainTab::Profile { "nav-item active" } else { "nav-item" },
                                onclick: move |_| state.active_tab.set(MainTab::Profile),
                                Icon { name: "profile", size: 20 }
                                span { "Cài đặt" }
                            }
                        }
                    }
                }
            }

            UpdateModal { state }

            if let Some(msg) = state.toast.read().as_ref() {
                div { class: "toast", role: "status", "{msg}" }
            }
        }
    }
}
