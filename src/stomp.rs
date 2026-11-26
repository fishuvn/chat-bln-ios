use crate::config::build_ws_url;
use crate::models::{DeleteMessagesResponse, FriendshipEventDto, MessageDto, PresenceEvent};
use futures_util::{SinkExt, StreamExt};
use std::collections::{BTreeMap, HashMap, HashSet};
use std::time::Duration;
use tokio::sync::mpsc;
use tokio_tungstenite::tungstenite::client::IntoClientRequest;
use tokio_tungstenite::tungstenite::http::HeaderValue;
use tokio_tungstenite::tungstenite::Message as WsMessage;

pub const TOPIC_PRESENCE: &str = "/topic/presence";

#[derive(Debug, Clone)]
pub enum RealtimeEvent {
    ConnectionChanged(bool),
    Message(MessageDto),
    Presence(PresenceEvent),
    Deletion(DeleteMessagesResponse),
    Friendship(FriendshipEventDto),
}

#[derive(Debug, Clone)]
pub enum StompCommand {
    SyncConversations(Vec<i64>),
    Disconnect,
}

#[derive(Debug, Clone, PartialEq)]
pub struct StompFrame {
    pub command: String,
    pub headers: BTreeMap<String, String>,
    pub body: String,
}

pub fn escape_header(value: &str) -> String {
    let mut out = String::with_capacity(value.len());
    for ch in value.chars() {
        match ch {
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            ':' => out.push_str("\\c"),
            _ => out.push(ch),
        }
    }
    out
}

pub fn unescape_header(value: &str) -> String {
    let mut out = String::with_capacity(value.len());
    let chars: Vec<char> = value.chars().collect();
    let mut i = 0;
    while i < chars.len() {
        if chars[i] == '\\' && i + 1 < chars.len() {
            match chars[i + 1] {
                'n' => out.push('\n'),
                'r' => out.push('\r'),
                'c' => out.push(':'),
                '\\' => out.push('\\'),
                other => {
                    out.push('\\');
                    out.push(other);
                }
            }
            i += 2;
        } else {
            out.push(chars[i]);
            i += 1;
        }
    }
    out
}

pub fn encode_frame(command: &str, headers: &[(&str, &str)], body: &str) -> String {
    let escape = command != "CONNECT" && command != "CONNECTED";
    let mut out = String::new();
    out.push_str(command);
    out.push('\n');
    for (k, v) in headers {
        if escape {
            out.push_str(&escape_header(k));
            out.push(':');
            out.push_str(&escape_header(v));
        } else {
            out.push_str(k);
            out.push(':');
            out.push_str(v);
        }
        out.push('\n');
    }
    out.push('\n');
    out.push_str(body);
    out.push('\0');
    out
}

pub fn parse_frame(raw: &str) -> Option<StompFrame> {
    let normalized = raw.replace("\r\n", "\n");
    let trimmed = normalized.trim_start_matches('\n');
    if trimmed.is_empty() {
        return None;
    }

    let Some(first_nl) = trimmed.find('\n') else {
        return Some(StompFrame {
            command: trimmed.trim().to_string(),
            headers: BTreeMap::new(),
            body: String::new(),
        });
    };

    let command = trimmed[..first_nl].trim().to_string();
    let rest = &trimmed[first_nl + 1..];
    let (header_block, body) = match rest.find("\n\n") {
        Some(idx) => (&rest[..idx], &rest[idx + 2..]),
        None => (rest, ""),
    };

    let unescape = command != "CONNECT" && command != "CONNECTED";
    let mut headers = BTreeMap::new();
    for line in header_block.split('\n') {
        if line.is_empty() {
            continue;
        }
        if let Some(colon) = line.find(':') {
            let rk = &line[..colon];
            let rv = &line[colon + 1..];
            let k = if unescape {
                unescape_header(rk)
            } else {
                rk.to_string()
            };
            let v = if unescape {
                unescape_header(rv)
            } else {
                rv.to_string()
            };
            headers.entry(k).or_insert(v);
        }
    }

    Some(StompFrame {
        command,
        headers,
        body: body.to_string(),
    })
}

pub fn extract_complete_frames(buffer: &mut String, chunk: &str) -> Vec<StompFrame> {
    buffer.push_str(chunk);
    let mut frames = Vec::new();
    while let Some(nul_idx) = buffer.find('\0') {
        let raw = buffer[..nul_idx].to_string();
        buffer.drain(..=nul_idx);
        if let Some(frame) = parse_frame(&raw) {
            frames.push(frame);
        }
    }
    if buffer.chars().all(|c| c == '\n' || c == '\r') {
        buffer.clear();
    }
    frames
}

pub fn spawn_stomp_session(
    server_url: String,
    token: String,
    username: String,
    initial_conversation_ids: Vec<i64>,
    event_tx: mpsc::UnboundedSender<RealtimeEvent>,
) -> mpsc::UnboundedSender<StompCommand> {
    let (cmd_tx, mut cmd_rx) = mpsc::unbounded_channel::<StompCommand>();

    tokio::spawn(async move {
        let mut desired_conv_ids: HashSet<i64> =
            initial_conversation_ids.into_iter().filter(|id| *id > 0).collect();

        loop {
            let ws_url = build_ws_url(&server_url);
            let mut request = match ws_url.into_client_request() {
                Ok(r) => r,
                Err(_) => {
                    let _ = event_tx.send(RealtimeEvent::ConnectionChanged(false));
                    tokio::time::sleep(Duration::from_secs(3)).await;
                    continue;
                }
            };

            if let Ok(val) = HeaderValue::from_str(&format!("Bearer {token}")) {
                request.headers_mut().insert("Authorization", val);
            }

            let socket = match tokio_tungstenite::connect_async(request).await {
                Ok((stream, _)) => stream,
                Err(_) => {
                    let _ = event_tx.send(RealtimeEvent::ConnectionChanged(false));
                    tokio::select! {
                        Some(cmd) = cmd_rx.recv() => {
                            match cmd {
                                StompCommand::Disconnect => break,
                                StompCommand::SyncConversations(ids) => {
                                    desired_conv_ids = ids.into_iter().filter(|id| *id > 0).collect();
                                }
                            }
                        }
                        _ = tokio::time::sleep(Duration::from_secs(3)) => {}
                    }
                    continue;
                }
            };

            let (mut writer, mut reader) = socket.split();
            let auth_header = format!("Bearer {token}");
            let connect_frame = encode_frame(
                "CONNECT",
                &[
                    ("accept-version", "1.1,1.2"),
                    ("heart-beat", "10000,10000"),
                    ("Authorization", &auth_header),
                ],
                "",
            );
            if writer.send(WsMessage::Text(connect_frame.into())).await.is_err() {
                let _ = event_tx.send(RealtimeEvent::ConnectionChanged(false));
                tokio::time::sleep(Duration::from_secs(3)).await;
                continue;
            }

            let mut recv_buf = String::new();
            let mut sub_counter: u64 = 1;
            let mut active_subs: HashMap<String, String> = HashMap::new();
            let mut stomp_connected = false;
            let mut heartbeat = tokio::time::interval(Duration::from_secs(10));
            let mut should_exit = false;

            loop {
                tokio::select! {
                    _ = heartbeat.tick() => {
                        if stomp_connected && writer.send(WsMessage::Text("\n".into())).await.is_err() {
                            break;
                        }
                    }
                    cmd = cmd_rx.recv() => {
                        match cmd {
                            Some(StompCommand::Disconnect) | None => {
                                if stomp_connected {
                                    let disc = encode_frame("DISCONNECT", &[], "");
                                    let _ = writer.send(WsMessage::Text(disc.into())).await;
                                }
                                should_exit = true;
                                break;
                            }
                            Some(StompCommand::SyncConversations(ids)) => {
                                desired_conv_ids = ids.into_iter().filter(|id| *id > 0).collect();
                                if stomp_connected {
                                    let target_topics: HashSet<String> = desired_conv_ids
                                        .iter()
                                        .map(|id| format!("/topic/conversations/{id}"))
                                        .collect();
                                    let stale: Vec<String> = active_subs
                                        .keys()
                                        .filter(|t| t.starts_with("/topic/conversations/") && !target_topics.contains(*t))
                                        .cloned()
                                        .collect();
                                    for topic in stale {
                                        if let Some(sub_id) = active_subs.remove(&topic) {
                                            let f = encode_frame("UNSUBSCRIBE", &[("id", &sub_id)], "");
                                            let _ = writer.send(WsMessage::Text(f.into())).await;
                                        }
                                    }
                                    for topic in target_topics {
                                        if !active_subs.contains_key(&topic) {
                                            let sub_id = format!("sub-{sub_counter}");
                                            sub_counter += 1;
                                            let f = encode_frame(
                                                "SUBSCRIBE",
                                                &[("id", &sub_id), ("destination", &topic), ("ack", "auto")],
                                                "",
                                            );
                                            if writer.send(WsMessage::Text(f.into())).await.is_ok() {
                                                active_subs.insert(topic, sub_id);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    incoming = reader.next() => {
                        match incoming {
                            Some(Ok(WsMessage::Text(txt))) => {
                                for frame in extract_complete_frames(&mut recv_buf, txt.as_str()) {
                                    match frame.command.as_str() {
                                        "CONNECTED" => {
                                            stomp_connected = true;
                                            let _ = event_tx.send(RealtimeEvent::ConnectionChanged(true));
                                            let mut base_topics = vec![
                                                TOPIC_PRESENCE.to_string(),
                                                format!("/topic/users/{username}"),
                                                format!("/topic/users/{username}/deletions"),
                                                format!("/topic/friendships/{username}"),
                                            ];
                                            for id in &desired_conv_ids {
                                                base_topics.push(format!("/topic/conversations/{id}"));
                                            }
                                            for topic in base_topics {
                                                if !active_subs.contains_key(&topic) {
                                                    let sub_id = format!("sub-{sub_counter}");
                                                    sub_counter += 1;
                                                    let f = encode_frame(
                                                        "SUBSCRIBE",
                                                        &[("id", &sub_id), ("destination", &topic), ("ack", "auto")],
                                                        "",
                                                    );
                                                    if writer.send(WsMessage::Text(f.into())).await.is_ok() {
                                                        active_subs.insert(topic, sub_id);
                                                    }
                                                }
                                            }
                                        }
                                        "MESSAGE" => {
                                            let dest = frame.headers.get("destination").map(String::as_str).unwrap_or("");
                                            let payload = frame.body.trim();
                                            if payload.is_empty() {
                                                continue;
                                            }
                                            if dest == TOPIC_PRESENCE {
                                                if let Ok(ev) = serde_json::from_str::<PresenceEvent>(payload) {
                                                    let _ = event_tx.send(RealtimeEvent::Presence(ev));
                                                }
                                            } else if dest.ends_with("/deletions") {
                                                if let Ok(ev) = serde_json::from_str::<DeleteMessagesResponse>(payload) {
                                                    let _ = event_tx.send(RealtimeEvent::Deletion(ev));
                                                }
                                            } else if dest.starts_with("/topic/friendships/") {
                                                if let Ok(ev) = serde_json::from_str::<FriendshipEventDto>(payload) {
                                                    let _ = event_tx.send(RealtimeEvent::Friendship(ev));
                                                }
                                            } else if dest.starts_with("/topic/users/") || dest.starts_with("/topic/conversations/") {
                                                if let Ok(msg) = serde_json::from_str::<MessageDto>(payload) {
                                                    let _ = event_tx.send(RealtimeEvent::Message(msg));
                                                }
                                            }
                                        }
                                        "ERROR" => {
                                            break;
                                        }
                                        _ => {}
                                    }
                                }
                            }
                            Some(Ok(WsMessage::Ping(p))) => {
                                let _ = writer.send(WsMessage::Pong(p)).await;
                            }
                            Some(Ok(WsMessage::Close(_))) | Some(Err(_)) | None => {
                                break;
                            }
                            _ => {}
                        }
                    }
                }
            }

            let _ = event_tx.send(RealtimeEvent::ConnectionChanged(false));
            if should_exit {
                break;
            }
            tokio::time::sleep(Duration::from_secs(3)).await;
        }
    });

    cmd_tx
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn encodes_and_parses_stomp_12_frames() {
        let encoded = encode_frame(
            "SUBSCRIBE",
            &[("id", "sub-1"), ("destination", "/topic/presence")],
            "",
        );
        assert!(encoded.ends_with('\0'));

        let mut buf = String::new();
        let frames = extract_complete_frames(&mut buf, &encoded);
        assert_eq!(frames.len(), 1);
        assert_eq!(frames[0].command, "SUBSCRIBE");
        assert_eq!(
            frames[0].headers.get("destination").map(String::as_str),
            Some("/topic/presence")
        );
    }

    #[test]
    fn handles_chunked_frames_and_heartbeats() {
        let mut buf = String::new();
        assert!(extract_complete_frames(&mut buf, "\n\n").is_empty());
        assert!(buf.is_empty());

        let part1 = "MESSAGE\ndestination:/topic/presence\n\n{\"userId\":";
        let part2 = "7,\"username\":\"demo\",\"online\":true}\0";
        assert!(extract_complete_frames(&mut buf, part1).is_empty());
        let parsed = extract_complete_frames(&mut buf, part2);
        assert_eq!(parsed.len(), 1);
        assert_eq!(parsed[0].command, "MESSAGE");
        let ev: PresenceEvent = serde_json::from_str(&parsed[0].body).unwrap();
        assert_eq!(ev.user_id, 7);
        assert!(ev.is_online);
    }
}
