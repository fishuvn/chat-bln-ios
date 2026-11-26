use crate::api::{ApiClient, ApiError};
use crate::models::{
    ConversationItemResponse, FriendResponse, FriendshipResponse, MessageDto, UserProfileResponse,
};
use crate::stomp::StompCommand;
use crate::storage::{clear_auth, load_session, save_session, PersistedSession};
use crate::updater::{check_for_updates, UpdateCheckResult};
use dioxus::prelude::*;
use std::collections::HashMap;
use tokio::sync::mpsc::UnboundedSender;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AuthScreen {
    Login,
    Register,
    ForgotPassword,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MainTab {
    Chats,
    Contacts,
    Requests,
    Profile,
}

#[derive(Debug, Clone, PartialEq)]
pub enum UpdateUiState {
    Idle,
    Checking,
    UpToDate(UpdateCheckResult),
    Available(UpdateCheckResult),
    Error(String),
}

#[derive(Clone, Copy, PartialEq)]
pub struct AppState {
    pub session: Signal<PersistedSession>,
    pub auth_screen: Signal<AuthScreen>,
    pub active_tab: Signal<MainTab>,
    pub active_chat_id: Signal<Option<i64>>,
    pub conversations: Signal<Vec<ConversationItemResponse>>,
    pub messages: Signal<HashMap<i64, Vec<MessageDto>>>,
    pub friends: Signal<Vec<FriendResponse>>,
    pub received_requests: Signal<Vec<FriendshipResponse>>,
    pub sent_requests: Signal<Vec<FriendshipResponse>>,
    pub is_loading_chats: Signal<bool>,
    pub ws_connected: Signal<bool>,
    pub stomp_tx: Signal<Option<UnboundedSender<StompCommand>>>,
    pub toast: Signal<Option<String>>,
    pub update_state: Signal<UpdateUiState>,
    pub show_update_modal: Signal<bool>,
}

impl AppState {
    pub fn init() -> Self {
        let persisted = load_session();
        Self {
            session: use_signal(move || persisted),
            auth_screen: use_signal(|| AuthScreen::Login),
            active_tab: use_signal(|| MainTab::Chats),
            active_chat_id: use_signal(|| None),
            conversations: use_signal(Vec::new),
            messages: use_signal(HashMap::new),
            friends: use_signal(Vec::new),
            received_requests: use_signal(Vec::new),
            sent_requests: use_signal(Vec::new),
            is_loading_chats: use_signal(|| false),
            ws_connected: use_signal(|| false),
            stomp_tx: use_signal(|| None),
            toast: use_signal(|| None),
            update_state: use_signal(|| UpdateUiState::Idle),
            show_update_modal: use_signal(|| false),
        }
    }

    pub fn api(&self) -> ApiClient {
        let s = self.session.read();
        ApiClient::new(&s.server_url, s.token.clone())
    }

    pub fn is_authenticated(&self) -> bool {
        let s = self.session.read();
        s.token.as_deref().map(|t| !t.is_empty()).unwrap_or(false) && s.user.is_some()
    }

    pub fn current_user(&self) -> Option<UserProfileResponse> {
        self.session.read().user.clone()
    }

    pub fn notify(&mut self, msg: impl Into<String>) {
        let text = msg.into();
        self.toast.set(Some(text.clone()));
        let mut toast_sig = self.toast;
        spawn(async move {
            tokio::time::sleep(std::time::Duration::from_secs(3)).await;
            if toast_sig.read().as_deref() == Some(text.as_str()) {
                toast_sig.set(None);
            }
        });
    }

    pub fn force_logout(&mut self, reason: Option<&str>) {
        if let Some(tx) = self.stomp_tx.write().take() {
            let _ = tx.send(StompCommand::Disconnect);
        }
        {
            let mut s = self.session.write();
            clear_auth(&mut s);
        }
        self.ws_connected.set(false);
        self.active_chat_id.set(None);
        self.conversations.set(Vec::new());
        self.messages.set(HashMap::new());
        self.friends.set(Vec::new());
        self.received_requests.set(Vec::new());
        self.sent_requests.set(Vec::new());
        self.auth_screen.set(AuthScreen::Login);
        if let Some(msg) = reason {
            self.notify(msg);
        }
    }

    pub fn handle_error(&mut self, err: ApiError) {
        if err.unauthorized {
            self.force_logout(Some("Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."));
        } else {
            self.notify(err.message);
        }
    }

    pub fn trigger_refresh_all(mut self) {
        let api = self.api();
        spawn(async move {
            self.is_loading_chats.set(true);
            if let Ok(profile) = api.get_my_profile().await {
                let mut s = self.session.write();
                s.user = Some(profile);
                save_session(&s);
            }
            match api.get_conversations().await {
                Ok(list) => {
                    let ids: Vec<i64> = list.iter().map(|c| c.id).collect();
                    self.conversations.set(list);
                    if let Some(tx) = self.stomp_tx.read().as_ref() {
                        let _ = tx.send(StompCommand::SyncConversations(ids));
                    }
                }
                Err(e) => self.handle_error(e),
            }
            if let Ok(fr) = api.get_friends().await {
                self.friends.set(fr);
            }
            if let Ok(rec) = api.get_received_friend_requests().await {
                self.received_requests.set(rec);
            }
            if let Ok(sent) = api.get_sent_friend_requests().await {
                self.sent_requests.set(sent);
            }
            self.is_loading_chats.set(false);
        });
    }

    pub fn trigger_update_check(mut self, silent: bool) {
        spawn(async move {
            self.update_state.set(UpdateUiState::Checking);
            match check_for_updates().await {
                Ok(res) => {
                    if res.has_update {
                        self.update_state.set(UpdateUiState::Available(res));
                        if !silent {
                            self.show_update_modal.set(true);
                        }
                    } else {
                        self.update_state.set(UpdateUiState::UpToDate(res));
                        if !silent {
                            self.notify("Bạn đang dùng phiên bản mới nhất.");
                        }
                    }
                }
                Err(err) => {
                    self.update_state.set(UpdateUiState::Error(err.clone()));
                    if !silent {
                        self.notify(err);
                    }
                }
            }
        });
    }
}
