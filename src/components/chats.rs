use crate::components::icons::Icon;
use crate::config::{extract_invite_code, resolve_asset_url};
use crate::models::{
    format_group_role_label, format_short_time, initials_of, presence_label,
    ConversationItemResponse, GroupInvitePreviewResponse, GroupJoinRequestDto, GroupMemberDto,
    SendMessageRequest,
};
use crate::state::AppState;
use dioxus::prelude::*;
use std::collections::HashSet;

#[component]
pub fn ChatsRoot(mut state: AppState) -> Element {
    if let Some(chat_id) = *state.active_chat_id.read() {
        return rsx! { ChatRoomView { state, conversation_id: chat_id } };
    }
    rsx! { ConversationsListView { state } }
}

#[component]
fn ConversationsListView(mut state: AppState) -> Element {
    let mut search = use_signal(String::new);
    let mut filter = use_signal(|| "all");
    let mut show_create_group = use_signal(|| false);
    let mut show_join_group = use_signal(|| false);

    let mut group_name = use_signal(String::new);
    let mut group_visibility = use_signal(|| "PUBLIC".to_string());
    let mut selected_members = use_signal(HashSet::<i64>::new);

    let mut invite_input = use_signal(String::new);
    let mut invite_preview = use_signal(|| None::<GroupInvitePreviewResponse>);
    let mut join_loading = use_signal(|| false);

    let server_url = state.session.read().server_url.clone();
    let ws_ok = *state.ws_connected.read();
    let loading = *state.is_loading_chats.read();
    let q = search.read().trim().to_lowercase();
    let flt = *filter.read();

    let filtered: Vec<ConversationItemResponse> = state
        .conversations
        .read()
        .iter()
        .filter(|c| {
            if flt == "groups" && !c.is_group() {
                return false;
            }
            if flt == "online" && (c.is_group() || c.effective_presence() == "OFFLINE") {
                return false;
            }
            if !q.is_empty() {
                let n = c.display_name().to_lowercase();
                let lm = c.last_message.as_deref().unwrap_or("").to_lowercase();
                return n.contains(&q) || lm.contains(&q);
            }
            true
        })
        .cloned()
        .collect();

    rsx! {
        div { class: "shell-content",
            div { class: "top-bar",
                div { style: "min-width:0;",
                    h1 { class: "top-bar-title", "Chat BLN" }
                    div { class: "top-bar-sub",
                        span {
                            class: if ws_ok { "presence-online" } else { "presence-offline" },
                            style: "display:inline-block; width:8px; height:8px; border-radius:99px;",
                        }
                        span { if ws_ok { "Realtime đã kết nối" } else { "Đang kết nối lại..." } }
                    }
                }
                div { class: "row-actions",
                    button {
                        class: "icon-btn",
                        title: "Tham gia nhóm bằng link",
                        onclick: move |_| {
                            invite_input.set(String::new());
                            invite_preview.set(None);
                            show_join_group.set(true);
                        },
                        Icon { name: "link", size: 20 }
                    }
                    button {
                        class: "icon-btn",
                        title: "Tạo nhóm trò chuyện",
                        onclick: move |_| {
                            group_name.set(String::new());
                            group_visibility.set("PUBLIC".into());
                            selected_members.write().clear();
                            show_create_group.set(true);
                        },
                        Icon { name: "plus", size: 20 }
                    }
                    button {
                        class: "icon-btn",
                        title: "Làm mới",
                        onclick: move |_| state.trigger_refresh_all(),
                        Icon { name: "refresh", size: 19 }
                    }
                }
            }

            div { class: "chip-row",
                input {
                    class: "ui-input",
                    style: "min-height:36px; max-width:210px; padding:6px 10px;",
                    value: "{search}",
                    placeholder: "Tìm hội thoại...",
                    oninput: move |e| search.set(e.value()),
                }
                button {
                    class: if flt == "all" { "chip active" } else { "chip" },
                    onclick: move |_| filter.set("all"),
                    "Tất cả"
                }
                button {
                    class: if flt == "groups" { "chip active" } else { "chip" },
                    onclick: move |_| filter.set("groups"),
                    "Nhóm"
                }
                button {
                    class: if flt == "online" { "chip active" } else { "chip" },
                    onclick: move |_| filter.set("online"),
                    "Trực tuyến"
                }
            }

            div { class: "scroll-pane",
                if loading && filtered.is_empty() {
                    div { class: "empty-box", "Đang tải danh sách cuộc trò chuyện..." }
                } else if filtered.is_empty() {
                    div { class: "empty-box", "Chưa có cuộc trò chuyện nào. Tạo nhóm mới hoặc nhắn cho bạn bè trong Danh bạ." }
                } else {
                    for conv in filtered {
                        {
                            let cid = conv.id;
                            let pres = conv.effective_presence();
                            let av = resolve_asset_url(&server_url, conv.avatar_url.as_deref());
                            let time_str = format_short_time(conv.last_message_time.as_deref());
                            let preview = conv
                                .last_message
                                .as_deref()
                                .filter(|s| !s.trim().is_empty())
                                .unwrap_or("Chưa có tin nhắn");
                            rsx! {
                                button {
                                    key: "conv-{cid}",
                                    class: "list-card",
                                    onclick: move |_| {
                                        state.active_chat_id.set(Some(cid));
                                        let api = state.api();
                                        spawn(async move {
                                            if let Ok(hist) = api.get_messages(cid, None, 40).await {
                                                state.messages.write().insert(cid, hist.messages);
                                            }
                                        });
                                    },
                                    div { class: "avatar-wrap",
                                        div { class: "avatar-circle",
                                            if let Some(src) = av {
                                                img { src: "{src}", alt: "{conv.display_name()}" }
                                            } else {
                                                "{initials_of(conv.display_name())}"
                                            }
                                        }
                                        if !conv.is_group() {
                                            span { class: "presence-badge presence-{pres.to_lowercase()}" }
                                        }
                                    }
                                    div { class: "card-main",
                                        div { class: "card-head",
                                            span { class: "card-title", "{conv.display_name()}" }
                                            span { class: "card-time", "{time_str}" }
                                        }
                                        div { class: "card-sub",
                                            if conv.is_group() {
                                                span { class: "pill", style: "margin-right:6px;",
                                                    if conv.is_private_group() { "Riêng tư" } else { "Công khai" }
                                                }
                                            }
                                            "{preview}"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Create Group Modal
            if *show_create_group.read() {
                div { class: "modal-scrim", onclick: move |_| show_create_group.set(false),
                    div { class: "modal-sheet", onclick: move |e| e.stop_propagation(),
                        div { class: "section-title",
                            span { "Tạo nhóm trò chuyện mới" }
                            button { class: "icon-btn", onclick: move |_| show_create_group.set(false),
                                Icon { name: "close", size: 18 }
                            }
                        }
                        div { class: "field",
                            label { class: "field-label", "Tên nhóm *" }
                            input {
                                class: "ui-input",
                                value: "{group_name}",
                                placeholder: "Nhập tên nhóm...",
                                oninput: move |e| group_name.set(e.value()),
                            }
                        }
                        div { class: "field",
                            label { class: "field-label", "Chế độ nhóm" }
                            div { class: "row-actions",
                                button {
                                    class: if *group_visibility.read() == "PUBLIC" { "chip active" } else { "chip" },
                                    onclick: move |_| group_visibility.set("PUBLIC".into()),
                                    "Công khai (Vào trực tiếp)"
                                }
                                button {
                                    class: if *group_visibility.read() == "PRIVATE" { "chip active" } else { "chip" },
                                    onclick: move |_| group_visibility.set("PRIVATE".into()),
                                    "Riêng tư (Cần duyệt)"
                                }
                            }
                        }
                        div { class: "field",
                            label { class: "field-label", "Chọn thành viên ({selected_members.read().len()})" }
                            div { style: "max-height:180px; overflow-y:auto;",
                                for fr in state.friends.read().clone() {
                                    {
                                        let fid = fr.id;
                                        let checked = selected_members.read().contains(&fid);
                                        rsx! {
                                            button {
                                                key: "gm-{fid}",
                                                class: "list-card",
                                                style: "padding:8px 10px;",
                                                onclick: move |_| {
                                                    let mut set = selected_members.write();
                                                    if set.contains(&fid) {
                                                        set.remove(&fid);
                                                    } else {
                                                        set.insert(fid);
                                                    }
                                                },
                                                span { style: "flex:1;", "{fr.display_name()} (@{fr.username})" }
                                                span { class: if checked { "pill pill-accent" } else { "pill" },
                                                    if checked { "Đã chọn" } else { "Chọn" }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        button {
                            class: "ui-btn ui-btn-primary block",
                            onclick: move |_| {
                                let name = group_name.read().trim().to_string();
                                if name.is_empty() {
                                    state.notify("Vui lòng nhập tên nhóm.");
                                    return;
                                }
                                let vis = group_visibility.read().clone();
                                let members: Vec<i64> = selected_members.read().iter().copied().collect();
                                let api = state.api();
                                spawn(async move {
                                    match api.create_group_conversation(name, members, vis).await {
                                        Ok(created) => {
                                            show_create_group.set(false);
                                            state.active_chat_id.set(Some(created.id));
                                            state.notify("Đã tạo nhóm trò chuyện mới.");
                                            state.trigger_refresh_all();
                                        }
                                        Err(e) => state.handle_error(e),
                                    }
                                });
                            },
                            "Tạo nhóm"
                        }
                    }
                }
            }

            // Join Group By Invite Link Modal
            if *show_join_group.read() {
                div { class: "modal-scrim", onclick: move |_| show_join_group.set(false),
                    div { class: "modal-sheet", onclick: move |e| e.stop_propagation(),
                        div { class: "section-title",
                            span { "Tham gia nhóm qua liên kết mời" }
                            button { class: "icon-btn", onclick: move |_| show_join_group.set(false),
                                Icon { name: "close", size: 18 }
                            }
                        }
                        div { class: "field",
                            label { class: "field-label", "Dán link hoặc mã mời nhóm" }
                            div { style: "display:flex; gap:8px;",
                                input {
                                    class: "ui-input",
                                    value: "{invite_input}",
                                    placeholder: "https://chat-bln.fishu.io.vn/join/...",
                                    oninput: move |e| invite_input.set(e.value()),
                                }
                                button {
                                    class: "ui-btn ui-btn-secondary sm",
                                    disabled: *join_loading.read(),
                                    onclick: move |_| {
                                        let code = extract_invite_code(&invite_input.read());
                                        if code.is_empty() {
                                            state.notify("Nhập mã hoặc liên kết mời hợp lệ.");
                                            return;
                                        }
                                        join_loading.set(true);
                                        let api = state.api();
                                        spawn(async move {
                                            match api.get_group_invite_preview(&code).await {
                                                Ok(prev) => invite_preview.set(Some(prev)),
                                                Err(e) => state.handle_error(e),
                                            }
                                            join_loading.set(false);
                                        });
                                    },
                                    "Xem"
                                }
                            }
                        }
                        if let Some(prev) = invite_preview.read().clone() {
                            div { class: "section-card",
                                div { class: "card-title", "{prev.name.as_deref().unwrap_or(\"Nhóm trò chuyện\")}" }
                                div { class: "card-sub",
                                    if prev.group_visibility.eq_ignore_ascii_case("PRIVATE") {
                                        "Nhóm riêng tư (cần duyệt) • {prev.member_count} thành viên"
                                    } else {
                                        "Nhóm công khai • {prev.member_count} thành viên"
                                    }
                                }
                                button {
                                    class: "ui-btn ui-btn-primary block",
                                    style: "margin-top:12px;",
                                    onclick: move |_| {
                                        let code = prev.invite_code.clone();
                                        let api = state.api();
                                        spawn(async move {
                                            match api.join_group_by_invite_code(&code).await {
                                                Ok(res) => {
                                                    show_join_group.set(false);
                                                    state.notify(res.message.unwrap_or_else(|| "Đã xử lý yêu cầu tham gia nhóm.".into()));
                                                    state.trigger_refresh_all();
                                                }
                                                Err(e) => state.handle_error(e),
                                            }
                                        });
                                    },
                                    if prev.group_visibility.eq_ignore_ascii_case("PRIVATE") {
                                        "Gửi yêu cầu tham gia nhóm"
                                    } else {
                                        "Tham gia nhóm ngay"
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
fn ChatRoomView(mut state: AppState, conversation_id: i64) -> Element {
    let mut composer = use_signal(String::new);
    let mut sending = use_signal(|| false);
    let mut uploading = use_signal(|| false);
    let mut show_info = use_signal(|| false);
    let mut show_emojis = use_signal(|| false);
    let mut select_mode = use_signal(|| false);
    let mut selected_ids = use_signal(HashSet::<i64>::new);
    let mut group_members = use_signal(Vec::<GroupMemberDto>::new);
    let mut join_requests = use_signal(Vec::<GroupJoinRequestDto>::new);

    use_effect(move || {
        let api = state.api();
        spawn(async move {
            if let Ok(hist) = api.get_messages(conversation_id, None, 40).await {
                state.messages.write().insert(conversation_id, hist.messages);
            }
        });
    });

    let conv = state
        .conversations
        .read()
        .iter()
        .find(|c| c.id == conversation_id)
        .cloned();
    let me_id = state.current_user().map(|u| u.id).unwrap_or(0);
    let server_url = state.session.read().server_url.clone();
    let msgs = state
        .messages
        .read()
        .get(&conversation_id)
        .cloned()
        .unwrap_or_default();

    let conv_name = conv
        .as_ref()
        .map(|c| c.display_name().to_string())
        .unwrap_or_else(|| "Cuộc trò chuyện".into());
    let is_group = conv.as_ref().map(|c| c.is_group()).unwrap_or(false);
    let is_unfriended = conv
        .as_ref()
        .map(|c| c.is_unfriended_private())
        .unwrap_or(false);
    let pres = conv
        .as_ref()
        .map(|c| c.effective_presence())
        .unwrap_or("OFFLINE");

    let mut send_text = move || {
        let text = composer.read().trim().to_string();
        if text.is_empty() || *sending.read() {
            return;
        }
        sending.set(true);
        composer.set(String::new());
        let api = state.api();
        spawn(async move {
            let req = SendMessageRequest {
                content: text,
                attachment_url: None,
                attachment_type: None,
                attachment_name: None,
                attachment_size: None,
            };
            match api.send_message(conversation_id, req).await {
                Ok(msg) => {
                    let mut map = state.messages.write();
                    let list = map.entry(conversation_id).or_default();
                    if !list.iter().any(|m| m.id == msg.id) {
                        list.push(msg);
                    }
                }
                Err(e) => state.handle_error(e),
            }
            sending.set(false);
        });
    };

    let can_manage_conv = conv.as_ref().map(|c| c.can_manage_group()).unwrap_or(false);
    let open_info = move |_| {
        show_info.set(true);
        if is_group {
            let api = state.api();
            spawn(async move {
                if let Ok(m) = api.get_conversation_members(conversation_id).await {
                    group_members.set(m);
                }
                if can_manage_conv {
                    if let Ok(jr) = api.get_group_join_requests(conversation_id).await {
                        join_requests.set(jr);
                    }
                }
            });
        }
    };

    let quick_emojis = ["👍", "❤️", "😂", "🔥", "🎉", "🙏", "👌", "😊"];

    rsx! {
        div { class: "shell-content",
            div { class: "top-bar",
                button {
                    class: "icon-btn",
                    title: "Quay lại",
                    onclick: move |_| state.active_chat_id.set(None),
                    Icon { name: "back", size: 22 }
                }
                div { style: "flex:1; min-width:0;",
                    h1 { class: "top-bar-title", "{conv_name}" }
                    div { class: "top-bar-sub",
                        if is_group {
                            span {
                                if conv.as_ref().map(|c| c.is_private_group()).unwrap_or(false) {
                                    "Nhóm riêng tư"
                                } else {
                                    "Nhóm công khai"
                                }
                            }
                        } else {
                            span {
                                class: "presence-{pres.to_lowercase()}",
                                style: "display:inline-block; width:8px; height:8px; border-radius:99px;",
                            }
                            span { "{presence_label(pres)}" }
                        }
                    }
                }
                button {
                    class: "icon-btn",
                    title: "Chọn xóa tin nhắn",
                    onclick: move |_| {
                        let cur = *select_mode.read();
                        select_mode.set(!cur);
                        selected_ids.write().clear();
                    },
                    Icon { name: "trash", size: 19 }
                }
                button {
                    class: "icon-btn",
                    title: "Thông tin cuộc trò chuyện",
                    onclick: open_info,
                    Icon { name: "info", size: 20 }
                }
            }

            // Multi-select Deletion Action Bar
            if *select_mode.read() {
                div { class: "chip-row", style: "justify-content:space-between;",
                    span { style: "font-size:0.84rem; font-weight:600;",
                        "Đã chọn: {selected_ids.read().len()}"
                    }
                    div { class: "row-actions",
                        button {
                            class: "ui-btn ui-btn-secondary sm",
                            disabled: selected_ids.read().is_empty(),
                            onclick: move |_| {
                                let ids: Vec<i64> = selected_ids.read().iter().copied().collect();
                                let api = state.api();
                                spawn(async move {
                                    match api.delete_messages(conversation_id, ids.clone(), "FOR_ME").await {
                                        Ok(_) => {
                                            if let Some(list) = state.messages.write().get_mut(&conversation_id) {
                                                list.retain(|m| !ids.contains(&m.id));
                                            }
                                            select_mode.set(false);
                                            selected_ids.write().clear();
                                            state.notify("Đã xóa tin nhắn ở phía bạn.");
                                        }
                                        Err(e) => state.handle_error(e),
                                    }
                                });
                            },
                            "Xóa phía tôi"
                        }
                        button {
                            class: "ui-btn ui-btn-danger sm",
                            disabled: selected_ids.read().is_empty(),
                            onclick: move |_| {
                                let ids: Vec<i64> = selected_ids.read().iter().copied().collect();
                                let api = state.api();
                                spawn(async move {
                                    match api.delete_messages(conversation_id, ids.clone(), "FOR_EVERYONE").await {
                                        Ok(_) => {
                                            if let Some(list) = state.messages.write().get_mut(&conversation_id) {
                                                list.retain(|m| !ids.contains(&m.id));
                                            }
                                            select_mode.set(false);
                                            selected_ids.write().clear();
                                            state.notify("Đã thu hồi tin nhắn với mọi người.");
                                        }
                                        Err(e) => state.handle_error(e),
                                    }
                                });
                            },
                            "Thu hồi mọi người"
                        }
                    }
                }
            }

            // Message Stream
            div { class: "messages-pane",
                if msgs.is_empty() {
                    div { class: "empty-box", "Bắt đầu cuộc trò chuyện bằng tin nhắn đầu tiên." }
                } else {
                    for (idx, msg) in msgs.iter().enumerate() {
                        {
                            let mid = msg.id;
                            let is_mine = msg.sender.id == me_id;
                            let grouped = idx > 0 && msgs[idx - 1].sender.id == msg.sender.id;
                            let is_sel = selected_ids.read().contains(&mid);
                            let row_cls = format!(
                                "msg-row {} {} {}",
                                if is_mine { "mine" } else { "other" },
                                if grouped { "grouped" } else { "" },
                                if is_sel { "selected" } else { "" }
                            );
                            let att_url = resolve_asset_url(&server_url, msg.attachment_url.as_deref());
                            let att_type = msg.attachment_type.as_deref().unwrap_or("").to_uppercase();
                            let t_str = format_short_time(msg.created_at.as_deref());
                            rsx! {
                                div {
                                    key: "msg-{mid}",
                                    class: "{row_cls}",
                                    onclick: move |_| {
                                        if *select_mode.read() {
                                            let mut set = selected_ids.write();
                                            if set.contains(&mid) {
                                                set.remove(&mid);
                                            } else {
                                                set.insert(mid);
                                            }
                                        }
                                    },
                                    if !is_mine && !grouped && is_group {
                                        span { class: "msg-sender", "{msg.sender.display_name()}" }
                                    }
                                    div { class: "msg-bubble",
                                        if !msg.content.trim().is_empty() {
                                            div { "{msg.content}" }
                                        }
                                        if let Some(url) = att_url {
                                            if att_type == "IMAGE" {
                                                img { class: "msg-img", src: "{url}", alt: "Hình ảnh đính kèm" }
                                            } else if att_type == "VIDEO" {
                                                video {
                                                    class: "msg-img",
                                                    controls: true,
                                                    src: "{url}",
                                                }
                                            } else {
                                                a {
                                                    href: "{url}",
                                                    target: "_blank",
                                                    style: "color:inherit; text-decoration:underline; display:inline-block; margin-top:4px;",
                                                    "{msg.attachment_name.as_deref().unwrap_or(\"Tệp đính kèm\")}"
                                                }
                                            }
                                        }
                                    }
                                    span { class: "msg-meta", "{t_str}" }
                                }
                            }
                        }
                    }
                }
            }

            if *show_emojis.read() {
                div { class: "chip-row",
                    for em in quick_emojis {
                        button {
                            key: "em-{em}",
                            class: "chip",
                            onclick: move |_| {
                                composer.write().push_str(em);
                            },
                            "{em}"
                        }
                    }
                }
            }

            // Composer or Unfriended Lock
            if is_unfriended {
                div { class: "alert alert-error", style: "margin:8px 12px;",
                    "Hai tài khoản chưa phải bạn bè. Hãy kết bạn lại trong mục Danh bạ để tiếp tục nhắn tin."
                }
            } else {
                div { class: "composer-bar",
                    label {
                        class: "icon-btn",
                        title: "Đính kèm ảnh hoặc tệp",
                        input {
                            r#type: "file",
                            style: "display:none;",
                            onchange: move |evt| {
                                let files = evt.files();
                                if let Some(file) = files.into_iter().next() {
                                    uploading.set(true);
                                    let api = state.api();
                                    spawn(async move {
                                        let file_name = file.name();
                                        let mime = file.content_type();
                                        match file.read_bytes().await {
                                            Ok(bytes) => {
                                                match api.upload_file(file_name, bytes.to_vec(), mime.as_deref()).await {
                                                    Ok(up) => {
                                                        let req = SendMessageRequest {
                                                            content: String::new(),
                                                            attachment_url: Some(up.url),
                                                            attachment_type: Some(up.kind),
                                                            attachment_name: Some(up.file_name),
                                                            attachment_size: Some(up.file_size),
                                                        };
                                                        match api.send_message(conversation_id, req).await {
                                                            Ok(msg) => {
                                                                let mut map = state.messages.write();
                                                                let list = map.entry(conversation_id).or_default();
                                                                if !list.iter().any(|m| m.id == msg.id) {
                                                                    list.push(msg);
                                                                }
                                                            }
                                                            Err(e) => state.handle_error(e),
                                                        }
                                                    }
                                                    Err(e) => state.handle_error(e),
                                                }
                                            }
                                            Err(_) => state.notify("Không đọc được tệp đã chọn."),
                                        }
                                        uploading.set(false);
                                    });
                                }
                            },
                        }
                        Icon { name: "attach", size: 20 }
                    }
                    button {
                        class: "icon-btn",
                        title: "Biểu tượng cảm xúc",
                        onclick: move |_| {
                            let cur = *show_emojis.read();
                            show_emojis.set(!cur);
                        },
                        "😊"
                    }
                    input {
                        class: "composer-input",
                        value: "{composer}",
                        placeholder: if *uploading.read() { "Đang tải tệp lên..." } else { "Nhập tin nhắn..." },
                        oninput: move |e| composer.set(e.value()),
                        onkeydown: move |e| {
                            if e.key() == Key::Enter {
                                send_text();
                            }
                        },
                    }
                    button {
                        class: "ui-btn ui-btn-primary sm",
                        disabled: *sending.read() || *uploading.read(),
                        onclick: move |_| send_text(),
                        Icon { name: "send", size: 17 }
                    }
                }
            }

            // Group / Peer Info & Role Management Modal
            if *show_info.read() {
                if let Some(c) = conv.clone() {
                    div { class: "modal-scrim", onclick: move |_| show_info.set(false),
                        div { class: "modal-sheet", onclick: move |e| e.stop_propagation(),
                            div { class: "section-title",
                                span { "{c.display_name()}" }
                                button { class: "icon-btn", onclick: move |_| show_info.set(false),
                                    Icon { name: "close", size: 18 }
                                }
                            }

                            if c.is_group() {
                                div { class: "kv-row",
                                    span { class: "kv-key", "Vai trò của bạn" }
                                    span { class: "kv-val", "{format_group_role_label(c.current_user_role.as_deref())}" }
                                }
                                div { class: "kv-row",
                                    span { class: "kv-key", "Chế độ nhóm" }
                                    span { class: "kv-val",
                                        if c.is_private_group() { "Nhóm riêng tư" } else { "Nhóm công khai" }
                                    }
                                }

                                if let Some(code) = c.invite_code.as_deref() {
                                    div { class: "section-card", style: "margin-top:10px;",
                                        div { class: "field-label", "Liên kết mời tham gia nhóm" }
                                        div {
                                            style: "font-family:var(--font-mono); font-size:0.8rem; word-break:break-all; margin:6px 0;",
                                            "{server_url}/join/{code}"
                                        }
                                        if c.can_manage_group() {
                                            div { class: "row-actions",
                                                button {
                                                    class: "ui-btn ui-btn-secondary sm",
                                                    onclick: move |_| {
                                                        let api = state.api();
                                                        spawn(async move {
                                                            match api.regenerate_invite_code(conversation_id).await {
                                                                Ok(_) => {
                                                                    state.notify("Đã tạo liên kết mời mới.");
                                                                    state.trigger_refresh_all();
                                                                }
                                                                Err(e) => state.handle_error(e),
                                                            }
                                                        });
                                                    },
                                                    "Làm mới link"
                                                }
                                                if c.is_admin() {
                                                    {
                                                        let next_vis = if c.is_private_group() { "PUBLIC" } else { "PRIVATE" };
                                                        let vis_btn_label = if c.is_private_group() { "Chuyển Công khai" } else { "Chuyển Riêng tư" };
                                                        rsx! {
                                                            button {
                                                                class: "ui-btn ui-btn-outline sm",
                                                                onclick: move |_| {
                                                                    let api = state.api();
                                                                    spawn(async move {
                                                                        match api.update_group_visibility(conversation_id, next_vis.into()).await {
                                                                            Ok(_) => {
                                                                                state.notify("Đã đổi chế độ nhóm.");
                                                                                state.trigger_refresh_all();
                                                                            }
                                                                            Err(e) => state.handle_error(e),
                                                                        }
                                                                    });
                                                                },
                                                                "{vis_btn_label}"
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Pending Join Requests (Admin / Deputy)
                                if c.can_manage_group() && !join_requests.read().is_empty() {
                                    div { class: "section-title", style: "margin-top:12px;",
                                        span { "Yêu cầu chờ duyệt ({join_requests.read().len()})" }
                                    }
                                    for req in join_requests.read().clone() {
                                        {
                                            let rid = req.id;
                                            rsx! {
                                                div { key: "jr-{rid}", class: "list-card", style: "cursor:default;",
                                                    div { class: "card-main",
                                                        div { class: "card-title", "{req.display_name()}" }
                                                        div { class: "card-sub", "@{req.username}" }
                                                    }
                                                    div { class: "row-actions",
                                                        button {
                                                            class: "ui-btn ui-btn-primary sm",
                                                            onclick: move |_| {
                                                                let api = state.api();
                                                                spawn(async move {
                                                                    match api.approve_group_join_request(conversation_id, rid).await {
                                                                        Ok(_) => {
                                                                            join_requests.write().retain(|x| x.id != rid);
                                                                            state.notify("Đã duyệt thành viên vào nhóm.");
                                                                            state.trigger_refresh_all();
                                                                        }
                                                                        Err(e) => state.handle_error(e),
                                                                    }
                                                                });
                                                            },
                                                            "Duyệt"
                                                        }
                                                        button {
                                                            class: "ui-btn ui-btn-danger-soft sm",
                                                            onclick: move |_| {
                                                                let api = state.api();
                                                                spawn(async move {
                                                                    match api.reject_group_join_request(conversation_id, rid).await {
                                                                        Ok(_) => {
                                                                            join_requests.write().retain(|x| x.id != rid);
                                                                            state.notify("Đã từ chối yêu cầu.");
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

                                // Group Members + Admin/Deputy Actions
                                div { class: "section-title", style: "margin-top:12px;",
                                    span { "Thành viên ({group_members.read().len()})" }
                                }
                                for m in group_members.read().clone() {
                                    {
                                        let mid = m.id;
                                        let is_self = mid == me_id;
                                        let m_is_deputy = m.is_deputy();
                                        let can_admin = c.is_admin() && !is_self && !m.is_admin();
                                        rsx! {
                                            div { key: "mem-{mid}", class: "list-card", style: "cursor:default; flex-direction:column; align-items:stretch;",
                                                div { style: "display:flex; justify-content:space-between; align-items:center; gap:8px;",
                                                    div {
                                                        div { class: "card-title", "{m.display_name()}" }
                                                        div { class: "card-sub", "@{m.username}" }
                                                    }
                                                    span { class: "pill pill-accent", "{format_group_role_label(m.role.as_deref())}" }
                                                }
                                                if can_admin {
                                                    div { class: "row-actions", style: "margin-top:6px;",
                                                        button {
                                                            class: "ui-btn ui-btn-secondary sm",
                                                            onclick: move |_| {
                                                                let next_role = if m_is_deputy { "MEMBER" } else { "DEPUTY" };
                                                                let api = state.api();
                                                                spawn(async move {
                                                                    match api.update_group_member_role(conversation_id, mid, next_role).await {
                                                                        Ok(updated) => {
                                                                            group_members.set(updated);
                                                                            state.notify("Đã cập nhật vai trò thành viên.");
                                                                        }
                                                                        Err(e) => state.handle_error(e),
                                                                    }
                                                                });
                                                            },
                                                            if m_is_deputy { "Gỡ Phó nhóm" } else { "Bổ nhiệm Phó nhóm" }
                                                        }
                                                        button {
                                                            class: "ui-btn ui-btn-outline sm",
                                                            onclick: move |_| {
                                                                let api = state.api();
                                                                spawn(async move {
                                                                    match api.transfer_group_leadership(conversation_id, mid).await {
                                                                        Ok(updated) => {
                                                                            group_members.set(updated);
                                                                            state.notify("Đã chuyển quyền Trưởng nhóm.");
                                                                            state.trigger_refresh_all();
                                                                        }
                                                                        Err(e) => state.handle_error(e),
                                                                    }
                                                                });
                                                            },
                                                            "Chuyển Trưởng nhóm"
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                if c.is_admin() {
                                    button {
                                        class: "ui-btn ui-btn-danger-soft block",
                                        style: "margin-top:12px;",
                                        onclick: move |_| {
                                            let api = state.api();
                                            spawn(async move {
                                                match api.delete_conversation(conversation_id).await {
                                                    Ok(_) => {
                                                        show_info.set(false);
                                                        state.active_chat_id.set(None);
                                                        state.notify("Đã giải tán nhóm.");
                                                        state.trigger_refresh_all();
                                                    }
                                                    Err(e) => state.handle_error(e),
                                                }
                                            });
                                        },
                                        "Giải tán nhóm trò chuyện"
                                    }
                                }
                            } else {
                                if let Some(un) = &c.target_username {
                                    div { class: "kv-row",
                                        span { class: "kv-key", "Username" }
                                        span { class: "kv-val", "@{un}" }
                                    }
                                }
                                if let Some(em) = &c.email {
                                    div { class: "kv-row",
                                        span { class: "kv-key", "Email" }
                                        span { class: "kv-val", "{em}" }
                                    }
                                }
                                if let Some(tid) = c.target_user_id {
                                    if !c.is_unfriended_private() {
                                        button {
                                            class: "ui-btn ui-btn-danger-soft block",
                                            style: "margin-top:14px;",
                                            onclick: move |_| {
                                                let api = state.api();
                                                spawn(async move {
                                                    match api.unfriend(tid).await {
                                                        Ok(_) => {
                                                            show_info.set(false);
                                                            state.notify("Đã hủy tư cách bạn bè.");
                                                            state.trigger_refresh_all();
                                                        }
                                                        Err(e) => state.handle_error(e),
                                                    }
                                                });
                                            },
                                            "Hủy kết bạn"
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
