use serde::{Deserialize, Serialize};

pub fn format_group_role_label(role: Option<&str>) -> &'static str {
    match role.unwrap_or("").trim().to_uppercase().as_str() {
        "ADMIN" => "Trưởng nhóm",
        "DEPUTY" => "Phó nhóm",
        _ => "Thành viên",
    }
}

pub fn normalize_presence(status: Option<&str>, is_online: bool) -> &'static str {
    match status.unwrap_or("").trim().to_uppercase().as_str() {
        "ONLINE" => "ONLINE",
        "IDLE" => "IDLE",
        "SLEEP" => "SLEEP",
        "DND" => "DND",
        "OFFLINE" => "OFFLINE",
        _ => {
            if is_online {
                "ONLINE"
            } else {
                "OFFLINE"
            }
        }
    }
}

pub fn presence_label(status: &str) -> &'static str {
    match status.to_uppercase().as_str() {
        "ONLINE" => "Trực tuyến",
        "IDLE" => "Tạm vắng",
        "SLEEP" => "Chế độ ngủ",
        "DND" => "Không làm phiền",
        _ => "Ngoại tuyến",
    }
}

pub fn initials_of(name: &str) -> String {
    let parts: Vec<&str> = name.split_whitespace().collect();
    match parts.as_slice() {
        [] => "U".to_string(),
        [single] => single
            .chars()
            .take(2)
            .collect::<String>()
            .to_uppercase(),
        [first, .., last] => {
            let mut out = String::new();
            if let Some(c) = first.chars().next() {
                out.push(c);
            }
            if let Some(c) = last.chars().next() {
                out.push(c);
            }
            out.to_uppercase()
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct LoginRequest {
    pub username: String,
    pub password: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct RegisterRequest {
    pub username: String,
    pub password: String,
    pub full_name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub email: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub phone: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gender: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub dob: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub bio: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct AuthResponse {
    pub id: i64,
    pub username: String,
    pub full_name: Option<String>,
    pub token: String,
    pub token_type: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ForgotPasswordOtpRequest {
    pub email: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ForgotPasswordOtpResponse {
    pub email: Option<String>,
    pub username: Option<String>,
    pub full_name: Option<String>,
    pub otp: Option<String>,
    pub message: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct VerifyForgotPasswordOtpRequest {
    pub email: String,
    pub otp: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct VerifyForgotPasswordOtpResponse {
    #[serde(default)]
    pub verified: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ResetPasswordWithOtpRequest {
    pub email: String,
    pub otp: String,
    pub new_password: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ResetPasswordWithOtpResponse {
    #[serde(default)]
    pub reset: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Default)]
#[serde(rename_all = "camelCase")]
pub struct UserProfileResponse {
    pub id: i64,
    pub username: String,
    pub full_name: Option<String>,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub gender: Option<String>,
    pub dob: Option<String>,
    pub bio: Option<String>,
    pub avatar_url: Option<String>,
    #[serde(alias = "online", default)]
    pub is_online: Option<bool>,
    pub presence_status: Option<String>,
    pub last_seen: Option<String>,
}

impl UserProfileResponse {
    pub fn display_name(&self) -> &str {
        self.full_name
            .as_deref()
            .filter(|s| !s.trim().is_empty())
            .unwrap_or(&self.username)
    }

    pub fn effective_presence(&self) -> &'static str {
        normalize_presence(
            self.presence_status.as_deref(),
            self.is_online.unwrap_or(false),
        )
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct UpdateProfileRequest {
    pub full_name: Option<String>,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub gender: Option<String>,
    pub dob: Option<String>,
    pub bio: Option<String>,
    pub avatar_url: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct UpdatePresenceRequest {
    pub presence_status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct UserSearchResponse {
    pub id: i64,
    pub username: String,
    pub full_name: Option<String>,
    pub avatar_url: Option<String>,
    #[serde(alias = "online", default)]
    pub is_online: Option<bool>,
    pub presence_status: Option<String>,
    #[serde(alias = "friend", default)]
    pub is_friend: Option<bool>,
    pub friendship_status: Option<String>,
}

impl UserSearchResponse {
    pub fn display_name(&self) -> &str {
        self.full_name
            .as_deref()
            .filter(|s| !s.trim().is_empty())
            .unwrap_or(&self.username)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct GroupMemberDto {
    pub id: i64,
    pub username: String,
    pub full_name: Option<String>,
    pub avatar_url: Option<String>,
    pub role: Option<String>,
    #[serde(alias = "online", default)]
    pub is_online: bool,
    pub presence_status: Option<String>,
    pub last_seen: Option<String>,
    pub joined_at: Option<String>,
}

impl GroupMemberDto {
    pub fn display_name(&self) -> &str {
        self.full_name
            .as_deref()
            .filter(|s| !s.trim().is_empty())
            .unwrap_or(&self.username)
    }

    pub fn is_admin(&self) -> bool {
        self.role
            .as_deref()
            .map(|r| r.eq_ignore_ascii_case("ADMIN"))
            .unwrap_or(false)
    }

    pub fn is_deputy(&self) -> bool {
        self.role
            .as_deref()
            .map(|r| r.eq_ignore_ascii_case("DEPUTY"))
            .unwrap_or(false)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ConversationItemResponse {
    pub id: i64,
    pub name: Option<String>,
    #[serde(default = "default_private_type")]
    pub r#type: String,
    pub group_visibility: Option<String>,
    pub invite_code: Option<String>,
    pub pending_join_request_count: Option<i32>,
    pub avatar_url: Option<String>,
    #[serde(alias = "online", default)]
    pub is_online: Option<bool>,
    pub presence_status: Option<String>,
    pub target_user_id: Option<i64>,
    pub target_username: Option<String>,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub gender: Option<String>,
    pub dob: Option<String>,
    pub bio: Option<String>,
    pub last_seen: Option<String>,
    pub last_message: Option<String>,
    pub last_message_sender_name: Option<String>,
    pub last_message_sender_username: Option<String>,
    pub last_message_time: Option<String>,
    pub current_user_role: Option<String>,
    pub member_count: Option<i32>,
    pub members: Option<Vec<GroupMemberDto>>,
    #[serde(alias = "friend", default)]
    pub is_friend: Option<bool>,
    pub friendship_status: Option<String>,
}

fn default_private_type() -> String {
    "PRIVATE".to_string()
}

impl ConversationItemResponse {
    pub fn display_name(&self) -> &str {
        self.name
            .as_deref()
            .filter(|s| !s.trim().is_empty())
            .or(self.target_username.as_deref())
            .unwrap_or("Cuộc trò chuyện")
    }

    pub fn is_group(&self) -> bool {
        self.r#type.eq_ignore_ascii_case("GROUP")
    }

    pub fn is_admin(&self) -> bool {
        self.current_user_role
            .as_deref()
            .map(|r| r.eq_ignore_ascii_case("ADMIN"))
            .unwrap_or(false)
    }

    pub fn is_deputy(&self) -> bool {
        self.current_user_role
            .as_deref()
            .map(|r| r.eq_ignore_ascii_case("DEPUTY"))
            .unwrap_or(false)
    }

    pub fn can_manage_group(&self) -> bool {
        self.is_admin() || self.is_deputy()
    }

    pub fn is_private_group(&self) -> bool {
        self.group_visibility
            .as_deref()
            .map(|v| v.eq_ignore_ascii_case("PRIVATE"))
            .unwrap_or(false)
    }

    pub fn is_unfriended_private(&self) -> bool {
        !self.is_group() && self.is_friend == Some(false)
    }

    pub fn effective_presence(&self) -> &'static str {
        normalize_presence(
            self.presence_status.as_deref(),
            self.is_online.unwrap_or(false),
        )
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ConversationResponse {
    pub id: i64,
    pub name: Option<String>,
    #[serde(default = "default_private_type")]
    pub r#type: String,
    pub group_visibility: Option<String>,
    pub invite_code: Option<String>,
    pub created_by_id: Option<i64>,
    pub created_at: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct CreatePrivateConversationRequest {
    pub target_user_id: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct CreateGroupConversationRequest {
    pub name: String,
    pub member_ids: Vec<i64>,
    pub group_visibility: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct UpdateGroupVisibilityRequest {
    pub group_visibility: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct RegenerateInviteCodeResponse {
    pub conversation_id: i64,
    pub invite_code: String,
    pub group_visibility: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct UpdateMemberRoleRequest {
    pub role: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct TransferGroupLeaderRequest {
    pub new_leader_user_id: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct GroupInvitePreviewResponse {
    pub conversation_id: i64,
    pub name: Option<String>,
    #[serde(default)]
    pub group_visibility: String,
    pub invite_code: String,
    #[serde(default)]
    pub member_count: i32,
    #[serde(alias = "isAlreadyMember", default)]
    pub already_member: bool,
    #[serde(default)]
    pub join_status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct JoinGroupResponse {
    pub conversation_id: i64,
    pub name: Option<String>,
    pub group_visibility: Option<String>,
    pub status: String,
    pub message: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct GroupJoinRequestDto {
    pub id: i64,
    pub conversation_id: i64,
    pub user_id: i64,
    pub username: String,
    pub full_name: Option<String>,
    pub avatar_url: Option<String>,
    #[serde(default)]
    pub status: String,
    pub created_at: Option<String>,
}

impl GroupJoinRequestDto {
    pub fn display_name(&self) -> &str {
        self.full_name
            .as_deref()
            .filter(|s| !s.trim().is_empty())
            .unwrap_or(&self.username)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct SenderDto {
    pub id: i64,
    pub username: String,
    pub full_name: Option<String>,
    pub avatar_url: Option<String>,
}

impl SenderDto {
    pub fn display_name(&self) -> &str {
        self.full_name
            .as_deref()
            .filter(|s| !s.trim().is_empty())
            .unwrap_or(&self.username)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct MessageDto {
    pub id: i64,
    pub conversation_id: i64,
    pub sender: SenderDto,
    #[serde(default)]
    pub content: String,
    pub attachment_url: Option<String>,
    pub attachment_type: Option<String>,
    pub attachment_name: Option<String>,
    pub attachment_size: Option<String>,
    pub created_at: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct MessageHistoryResponse {
    pub conversation_id: i64,
    #[serde(default = "default_private_type")]
    pub conversation_type: String,
    #[serde(default)]
    pub messages: Vec<MessageDto>,
    #[serde(default)]
    pub size: i32,
    #[serde(default)]
    pub has_more: bool,
    pub oldest_message_id: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct SendMessageRequest {
    pub content: String,
    pub attachment_url: Option<String>,
    pub attachment_type: Option<String>,
    pub attachment_name: Option<String>,
    pub attachment_size: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct DeleteMessagesRequest {
    pub message_ids: Vec<i64>,
    pub mode: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct DeleteMessagesResponse {
    pub conversation_id: i64,
    pub mode: Option<String>,
    #[serde(default)]
    pub deleted_ids: Vec<i64>,
    pub last_message: Option<String>,
    pub last_message_sender_name: Option<String>,
    pub last_message_sender_username: Option<String>,
    pub last_message_time: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct UploadResponse {
    pub url: String,
    pub file_name: String,
    pub file_size: String,
    pub content_type: String,
    pub kind: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct PresenceEvent {
    pub user_id: i64,
    pub username: String,
    #[serde(alias = "online", default)]
    pub is_online: bool,
    pub presence_status: Option<String>,
    pub last_seen: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct FriendshipEventDto {
    pub r#type: Option<String>,
    pub actor_user_id: Option<i64>,
    pub target_user_id: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct FriendRequestDto {
    pub target_user_id: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct FriendResponse {
    pub id: i64,
    pub username: String,
    pub full_name: Option<String>,
    pub avatar_url: Option<String>,
    #[serde(alias = "online", default)]
    pub is_online: bool,
    pub presence_status: Option<String>,
    pub last_seen: Option<String>,
}

impl FriendResponse {
    pub fn display_name(&self) -> &str {
        self.full_name
            .as_deref()
            .filter(|s| !s.trim().is_empty())
            .unwrap_or(&self.username)
    }

    pub fn effective_presence(&self) -> &'static str {
        normalize_presence(self.presence_status.as_deref(), self.is_online)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct FriendshipResponse {
    pub id: i64,
    pub requester_id: i64,
    pub requester_username: Option<String>,
    pub requester_full_name: Option<String>,
    pub requester_avatar_url: Option<String>,
    pub addressee_id: i64,
    pub addressee_username: Option<String>,
    pub addressee_full_name: Option<String>,
    pub addressee_avatar_url: Option<String>,
    #[serde(default)]
    pub status: String,
    pub created_at: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ApiErrorResponse {
    pub status: Option<i32>,
    pub error: Option<String>,
    pub message: Option<String>,
}

pub fn format_short_time(iso: Option<&str>) -> String {
    let raw = match iso {
        Some(v) if !v.trim().is_empty() => v.trim(),
        _ => return String::new(),
    };
    if let Some(t_idx) = raw.find('T') {
        let time_part = &raw[t_idx + 1..];
        if time_part.len() >= 5 {
            return time_part[..5].to_string();
        }
    }
    raw.chars().take(5).collect()
}
