use crate::config::{normalize_server_url, APP_VERSION};
use crate::models::*;
use reqwest::{multipart, Client, Method, StatusCode};
use serde::de::DeserializeOwned;
use serde::Serialize;
use std::time::Duration;

#[derive(Debug, Clone, PartialEq)]
pub struct ApiError {
    pub status: Option<u16>,
    pub message: String,
    pub unauthorized: bool,
}

impl std::fmt::Display for ApiError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.message)
    }
}

#[derive(Clone)]
pub struct ApiClient {
    http: Client,
    base_url: String,
    token: Option<String>,
}

impl ApiClient {
    pub fn new(server_url: &str, token: Option<String>) -> Self {
        let http = Client::builder()
            .timeout(Duration::from_secs(30))
            .user_agent(format!("ChatBLN-Rust/{APP_VERSION}"))
            .build()
            .unwrap_or_else(|_| Client::new());
        Self {
            http,
            base_url: normalize_server_url(server_url),
            token,
        }
    }

    fn endpoint(&self, path: &str) -> String {
        let clean = path.trim_start_matches('/');
        format!("{}/api/{clean}", self.base_url)
    }

    async fn send_json<Req: Serialize, Resp: DeserializeOwned>(
        &self,
        method: Method,
        path: &str,
        body: Option<&Req>,
        auth: bool,
    ) -> Result<Resp, ApiError> {
        let mut req = self.http.request(method, self.endpoint(path));
        if auth {
            if let Some(tok) = &self.token {
                if !tok.is_empty() {
                    req = req.bearer_auth(tok);
                }
            }
        }
        if let Some(payload) = body {
            req = req.json(payload);
        }

        let resp = req.send().await.map_err(|e| ApiError {
            status: None,
            message: format!("Không thể kết nối máy chủ: {e}"),
            unauthorized: false,
        })?;

        let status = resp.status();
        let text = resp.text().await.unwrap_or_default();

        if !status.is_success() {
            let parsed_msg = serde_json::from_str::<ApiErrorResponse>(&text)
                .ok()
                .and_then(|e| e.message.or(e.error))
                .filter(|s| !s.trim().is_empty())
                .unwrap_or_else(|| {
                    if !text.trim().is_empty() && text.len() < 240 {
                        text.trim().to_string()
                    } else {
                        format!("Yêu cầu thất bại (HTTP {})", status.as_u16())
                    }
                });
            return Err(ApiError {
                status: Some(status.as_u16()),
                message: parsed_msg,
                unauthorized: status == StatusCode::UNAUTHORIZED,
            });
        }

        if text.trim().is_empty() {
            serde_json::from_str("null").map_err(|e| ApiError {
                status: Some(status.as_u16()),
                message: format!("Phản hồi rỗng không hợp lệ: {e}"),
                unauthorized: false,
            })
        } else {
            serde_json::from_str::<Resp>(&text).map_err(|e| ApiError {
                status: Some(status.as_u16()),
                message: format!("Lỗi phân tích dữ liệu JSON: {e}"),
                unauthorized: false,
            })
        }
    }

    // ---- Auth ----

    pub async fn login(&self, username: String, password: String) -> Result<AuthResponse, ApiError> {
        let body = LoginRequest { username, password };
        self.send_json(Method::POST, "auth/login", Some(&body), false)
            .await
    }

    pub async fn register(&self, body: RegisterRequest) -> Result<AuthResponse, ApiError> {
        self.send_json(Method::POST, "auth/register", Some(&body), false)
            .await
    }

    pub async fn logout(&self) -> Result<serde_json::Value, ApiError> {
        self.send_json::<(), _>(Method::POST, "auth/logout", None, true)
            .await
    }

    pub async fn request_password_reset_otp(
        &self,
        email: String,
    ) -> Result<ForgotPasswordOtpResponse, ApiError> {
        let body = ForgotPasswordOtpRequest { email };
        self.send_json(
            Method::POST,
            "auth/forgot-password/request",
            Some(&body),
            false,
        )
        .await
    }

    pub async fn verify_password_reset_otp(
        &self,
        email: String,
        otp: String,
    ) -> Result<VerifyForgotPasswordOtpResponse, ApiError> {
        let body = VerifyForgotPasswordOtpRequest { email, otp };
        self.send_json(
            Method::POST,
            "auth/forgot-password/verify",
            Some(&body),
            false,
        )
        .await
    }

    pub async fn reset_password_with_otp(
        &self,
        email: String,
        otp: String,
        new_password: String,
    ) -> Result<ResetPasswordWithOtpResponse, ApiError> {
        let body = ResetPasswordWithOtpRequest {
            email,
            otp,
            new_password,
        };
        self.send_json(
            Method::POST,
            "auth/forgot-password/reset",
            Some(&body),
            false,
        )
        .await
    }

    // ---- Users & Presence ----

    pub async fn get_my_profile(&self) -> Result<UserProfileResponse, ApiError> {
        self.send_json::<(), _>(Method::GET, "users/me", None, true)
            .await
    }

    pub async fn update_my_profile(
        &self,
        body: UpdateProfileRequest,
    ) -> Result<UserProfileResponse, ApiError> {
        self.send_json(Method::PUT, "users/me", Some(&body), true)
            .await
    }

    pub async fn update_my_presence(
        &self,
        presence_status: String,
    ) -> Result<UserProfileResponse, ApiError> {
        let body = UpdatePresenceRequest { presence_status };
        self.send_json(Method::PUT, "users/me/presence", Some(&body), true)
            .await
    }

    pub async fn search_users(&self, keyword: &str) -> Result<Vec<UserSearchResponse>, ApiError> {
        let encoded = urlencoding::encode(keyword.trim());
        self.send_json::<(), _>(
            Method::GET,
            &format!("users/search?keyword={encoded}"),
            None,
            true,
        )
        .await
    }

    // ---- Conversations & Groups ----

    pub async fn get_conversations(&self) -> Result<Vec<ConversationItemResponse>, ApiError> {
        self.send_json::<(), _>(Method::GET, "conversations", None, true)
            .await
    }

    pub async fn create_private_conversation(
        &self,
        target_user_id: i64,
    ) -> Result<ConversationResponse, ApiError> {
        let body = CreatePrivateConversationRequest { target_user_id };
        self.send_json(Method::POST, "conversations/private", Some(&body), true)
            .await
    }

    pub async fn create_group_conversation(
        &self,
        name: String,
        member_ids: Vec<i64>,
        group_visibility: String,
    ) -> Result<ConversationResponse, ApiError> {
        let body = CreateGroupConversationRequest {
            name,
            member_ids,
            group_visibility,
        };
        self.send_json(Method::POST, "conversations/group", Some(&body), true)
            .await
    }

    pub async fn delete_conversation(&self, id: i64) -> Result<serde_json::Value, ApiError> {
        self.send_json::<(), _>(Method::DELETE, &format!("conversations/{id}"), None, true)
            .await
    }

    pub async fn get_conversation_members(&self, id: i64) -> Result<Vec<GroupMemberDto>, ApiError> {
        self.send_json::<(), _>(
            Method::GET,
            &format!("conversations/{id}/members"),
            None,
            true,
        )
        .await
    }

    pub async fn update_group_visibility(
        &self,
        id: i64,
        group_visibility: String,
    ) -> Result<ConversationResponse, ApiError> {
        let body = UpdateGroupVisibilityRequest { group_visibility };
        self.send_json(
            Method::PUT,
            &format!("conversations/{id}/visibility"),
            Some(&body),
            true,
        )
        .await
    }

    pub async fn regenerate_invite_code(
        &self,
        id: i64,
    ) -> Result<RegenerateInviteCodeResponse, ApiError> {
        let empty = serde_json::json!({});
        self.send_json(
            Method::POST,
            &format!("conversations/{id}/invite-code/regenerate"),
            Some(&empty),
            true,
        )
        .await
    }

    pub async fn update_group_member_role(
        &self,
        conversation_id: i64,
        target_user_id: i64,
        role: &str,
    ) -> Result<Vec<GroupMemberDto>, ApiError> {
        let body = UpdateMemberRoleRequest {
            role: role.to_string(),
        };
        self.send_json(
            Method::PUT,
            &format!("conversations/{conversation_id}/members/{target_user_id}/role"),
            Some(&body),
            true,
        )
        .await
    }

    pub async fn transfer_group_leadership(
        &self,
        conversation_id: i64,
        new_leader_user_id: i64,
    ) -> Result<Vec<GroupMemberDto>, ApiError> {
        let body = TransferGroupLeaderRequest { new_leader_user_id };
        self.send_json(
            Method::PUT,
            &format!("conversations/{conversation_id}/leader"),
            Some(&body),
            true,
        )
        .await
    }

    pub async fn get_group_invite_preview(
        &self,
        invite_code: &str,
    ) -> Result<GroupInvitePreviewResponse, ApiError> {
        let enc = urlencoding::encode(invite_code.trim());
        self.send_json::<(), _>(
            Method::GET,
            &format!("conversations/invite/{enc}"),
            None,
            true,
        )
        .await
    }

    pub async fn join_group_by_invite_code(
        &self,
        invite_code: &str,
    ) -> Result<JoinGroupResponse, ApiError> {
        let enc = urlencoding::encode(invite_code.trim());
        let empty = serde_json::json!({});
        self.send_json(
            Method::POST,
            &format!("conversations/join/{enc}"),
            Some(&empty),
            true,
        )
        .await
    }

    pub async fn get_group_join_requests(
        &self,
        conversation_id: i64,
    ) -> Result<Vec<GroupJoinRequestDto>, ApiError> {
        self.send_json::<(), _>(
            Method::GET,
            &format!("conversations/{conversation_id}/join-requests"),
            None,
            true,
        )
        .await
    }

    pub async fn approve_group_join_request(
        &self,
        conversation_id: i64,
        request_id: i64,
    ) -> Result<GroupJoinRequestDto, ApiError> {
        let empty = serde_json::json!({});
        self.send_json(
            Method::PUT,
            &format!("conversations/{conversation_id}/join-requests/{request_id}/approve"),
            Some(&empty),
            true,
        )
        .await
    }

    pub async fn reject_group_join_request(
        &self,
        conversation_id: i64,
        request_id: i64,
    ) -> Result<GroupJoinRequestDto, ApiError> {
        let empty = serde_json::json!({});
        self.send_json(
            Method::PUT,
            &format!("conversations/{conversation_id}/join-requests/{request_id}/reject"),
            Some(&empty),
            true,
        )
        .await
    }

    // ---- Messages & Uploads ----

    pub async fn get_messages(
        &self,
        conversation_id: i64,
        before: Option<i64>,
        limit: usize,
    ) -> Result<MessageHistoryResponse, ApiError> {
        let path = match before {
            Some(b) => format!("conversations/{conversation_id}/messages?before={b}&limit={limit}"),
            None => format!("conversations/{conversation_id}/messages?limit={limit}"),
        };
        self.send_json::<(), _>(Method::GET, &path, None, true)
            .await
    }

    pub async fn send_message(
        &self,
        conversation_id: i64,
        body: SendMessageRequest,
    ) -> Result<MessageDto, ApiError> {
        self.send_json(
            Method::POST,
            &format!("conversations/{conversation_id}/messages"),
            Some(&body),
            true,
        )
        .await
    }

    pub async fn delete_messages(
        &self,
        conversation_id: i64,
        message_ids: Vec<i64>,
        mode: &str,
    ) -> Result<DeleteMessagesResponse, ApiError> {
        let body = DeleteMessagesRequest {
            message_ids,
            mode: mode.to_string(),
        };
        self.send_json(
            Method::POST,
            &format!("conversations/{conversation_id}/messages/delete"),
            Some(&body),
            true,
        )
        .await
    }

    pub async fn upload_file(
        &self,
        file_name: String,
        bytes: Vec<u8>,
        mime_type: Option<&str>,
    ) -> Result<UploadResponse, ApiError> {
        let mut part = multipart::Part::bytes(bytes.clone()).file_name(file_name.clone());
        if let Some(mime) = mime_type {
            if let Ok(typed) = multipart::Part::bytes(bytes)
                .file_name(file_name)
                .mime_str(mime)
            {
                part = typed;
            }
        }
        let form = multipart::Form::new().part("file", part);
        let mut req = self.http.post(self.endpoint("uploads")).multipart(form);
        if let Some(tok) = &self.token {
            if !tok.is_empty() {
                req = req.bearer_auth(tok);
            }
        }

        let resp = req.send().await.map_err(|e| ApiError {
            status: None,
            message: format!("Tải tệp lên thất bại: {e}"),
            unauthorized: false,
        })?;
        let status = resp.status();
        let text = resp.text().await.unwrap_or_default();
        if !status.is_success() {
            return Err(ApiError {
                status: Some(status.as_u16()),
                message: format!("Tải tệp thất bại (HTTP {})", status.as_u16()),
                unauthorized: status == StatusCode::UNAUTHORIZED,
            });
        }
        serde_json::from_str(&text).map_err(|e| ApiError {
            status: Some(status.as_u16()),
            message: format!("Lỗi đọc kết quả tải tệp: {e}"),
            unauthorized: false,
        })
    }

    // ---- Friends ----

    pub async fn get_friends(&self) -> Result<Vec<FriendResponse>, ApiError> {
        self.send_json::<(), _>(Method::GET, "friends", None, true)
            .await
    }

    pub async fn get_received_friend_requests(&self) -> Result<Vec<FriendshipResponse>, ApiError> {
        self.send_json::<(), _>(Method::GET, "friends/requests/received", None, true)
            .await
    }

    pub async fn get_sent_friend_requests(&self) -> Result<Vec<FriendshipResponse>, ApiError> {
        self.send_json::<(), _>(Method::GET, "friends/requests/sent", None, true)
            .await
    }

    pub async fn send_friend_request(
        &self,
        target_user_id: i64,
    ) -> Result<FriendshipResponse, ApiError> {
        let body = FriendRequestDto { target_user_id };
        self.send_json(Method::POST, "friends/request", Some(&body), true)
            .await
    }

    pub async fn accept_friend_request(
        &self,
        friendship_id: i64,
    ) -> Result<FriendshipResponse, ApiError> {
        let empty = serde_json::json!({});
        self.send_json(
            Method::PUT,
            &format!("friends/{friendship_id}/accept"),
            Some(&empty),
            true,
        )
        .await
    }

    pub async fn reject_friend_request(
        &self,
        friendship_id: i64,
    ) -> Result<FriendshipResponse, ApiError> {
        let empty = serde_json::json!({});
        self.send_json(
            Method::PUT,
            &format!("friends/{friendship_id}/reject"),
            Some(&empty),
            true,
        )
        .await
    }

    pub async fn cancel_sent_friend_request(
        &self,
        friendship_id: i64,
    ) -> Result<serde_json::Value, ApiError> {
        self.send_json::<(), _>(
            Method::DELETE,
            &format!("friends/requests/{friendship_id}"),
            None,
            true,
        )
        .await
    }

    pub async fn unfriend(&self, target_user_id: i64) -> Result<serde_json::Value, ApiError> {
        self.send_json::<(), _>(
            Method::DELETE,
            &format!("friends/{target_user_id}"),
            None,
            true,
        )
        .await
    }
}
