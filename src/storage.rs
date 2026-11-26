use crate::config::{normalize_server_url, DEFAULT_SERVER_URL};
use crate::models::UserProfileResponse;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PersistedSession {
    pub server_url: String,
    pub token: Option<String>,
    pub user: Option<UserProfileResponse>,
    pub dark_mode: bool,
    pub dismissed_update_tag: Option<String>,
}

impl Default for PersistedSession {
    fn default() -> Self {
        Self {
            server_url: DEFAULT_SERVER_URL.to_string(),
            token: None,
            user: None,
            dark_mode: false,
            dismissed_update_tag: None,
        }
    }
}

fn session_file_path() -> PathBuf {
    let base = dirs::data_local_dir()
        .or_else(dirs::config_dir)
        .unwrap_or_else(std::env::temp_dir);
    base.join("chat-bln-rust").join("session.json")
}

pub fn load_session() -> PersistedSession {
    let path = session_file_path();
    let Ok(raw) = fs::read_to_string(&path) else {
        return PersistedSession::default();
    };
    let mut parsed = serde_json::from_str::<PersistedSession>(&raw).unwrap_or_default();
    parsed.server_url = normalize_server_url(&parsed.server_url);
    parsed
}

pub fn save_session(session: &PersistedSession) {
    let path = session_file_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Ok(json) = serde_json::to_string_pretty(session) {
        let _ = fs::write(path, json);
    }
}

pub fn clear_auth(session: &mut PersistedSession) {
    session.token = None;
    session.user = None;
    save_session(session);
}
