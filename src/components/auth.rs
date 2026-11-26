use crate::components::icons::{BrandGlyph, Icon};
use crate::config::{normalize_server_url, APP_NAME, APP_VERSION, PLATFORM_DISPLAY_NAME};
use crate::models::{RegisterRequest, UserProfileResponse};
use crate::state::{AppState, AuthScreen};
use crate::storage::save_session;
use dioxus::prelude::*;

#[component]
pub fn AuthRoot(mut state: AppState) -> Element {
    let mut show_server_modal = use_signal(|| false);
    let mut server_input = use_signal(move || state.session.read().server_url.clone());
    let current_screen = *state.auth_screen.read();

    rsx! {
        div { class: "auth-shell",
            div { class: "auth-card",
                div { class: "brand-row",
                    div { class: "brand-badge", BrandGlyph {} }
                    div { style: "flex:1; min-width:0;",
                        h1 { class: "brand-title", "{APP_NAME}" }
                        p { class: "brand-sub", "v{APP_VERSION} • {PLATFORM_DISPLAY_NAME}" }
                    }
                    button {
                        class: "icon-btn",
                        title: "Cấu hình máy chủ",
                        onclick: move |_| {
                            server_input.set(state.session.read().server_url.clone());
                            show_server_modal.set(true);
                        },
                        Icon { name: "server", size: 20 }
                    }
                }

                match current_screen {
                    AuthScreen::Login => rsx! { LoginForm { state } },
                    AuthScreen::Register => rsx! { RegisterForm { state } },
                    AuthScreen::ForgotPassword => rsx! { ForgotPasswordForm { state } },
                }
            }

            if *show_server_modal.read() {
                div { class: "modal-scrim", onclick: move |_| show_server_modal.set(false),
                    div { class: "modal-sheet", onclick: move |e| e.stop_propagation(),
                        div { class: "section-title",
                            span { "Địa chỉ máy chủ Chat BLN" }
                            button { class: "icon-btn", onclick: move |_| show_server_modal.set(false),
                                Icon { name: "close", size: 18 }
                            }
                        }
                        div { class: "field",
                            label { class: "field-label", "URL Máy chủ (HTTPS)" }
                            input {
                                class: "ui-input",
                                value: "{server_input}",
                                placeholder: "https://chat-bln.fishu.io.vn",
                                oninput: move |e| server_input.set(e.value()),
                            }
                        }
                        div { class: "row-actions",
                            button {
                                class: "ui-btn ui-btn-primary",
                                style: "flex:1;",
                                onclick: move |_| {
                                    let norm = normalize_server_url(&server_input.read());
                                    {
                                        let mut s = state.session.write();
                                        s.server_url = norm.clone();
                                        save_session(&s);
                                    }
                                    show_server_modal.set(false);
                                    state.notify(format!("Đã lưu máy chủ: {norm}"));
                                },
                                "Lưu máy chủ"
                            }
                            button {
                                class: "ui-btn ui-btn-secondary",
                                onclick: move |_| show_server_modal.set(false),
                                "Đóng"
                            }
                        }
                    }
                }
            }
        }
    }
}

#[component]
fn LoginForm(mut state: AppState) -> Element {
    let mut username = use_signal(String::new);
    let mut password = use_signal(String::new);
    let mut show_pass = use_signal(|| false);
    let mut error = use_signal(|| None::<String>);
    let mut loading = use_signal(|| false);

    let submit = move |_| {
        let u = username.read().trim().to_string();
        let p = password.read().clone();
        if u.is_empty() || p.is_empty() {
            error.set(Some("Vui lòng nhập tên đăng nhập và mật khẩu.".into()));
            return;
        }
        error.set(None);
        loading.set(true);
        let api = state.api();
        spawn(async move {
            match api.login(u, p).await {
                Ok(auth) => {
                    let authed_api = {
                        let s = state.session.read();
                        crate::api::ApiClient::new(&s.server_url, Some(auth.token.clone()))
                    };
                    let profile = authed_api.get_my_profile().await.unwrap_or_else(|_| {
                        UserProfileResponse {
                            id: auth.id,
                            username: auth.username.clone(),
                            full_name: auth.full_name.clone(),
                            is_online: Some(true),
                            presence_status: Some("ONLINE".into()),
                            ..Default::default()
                        }
                    });
                    {
                        let mut s = state.session.write();
                        s.token = Some(auth.token);
                        s.user = Some(profile);
                        save_session(&s);
                    }
                    state.trigger_refresh_all();
                }
                Err(err) => {
                    error.set(Some(err.message));
                }
            }
            loading.set(false);
        });
    };

    rsx! {
        div {
            if let Some(err) = error.read().as_ref() {
                div { class: "alert alert-error", "{err}" }
            }
            div { class: "field",
                label { class: "field-label", "Tên đăng nhập hoặc Email" }
                input {
                    class: "ui-input",
                    value: "{username}",
                    placeholder: "Nhập username...",
                    oninput: move |e| username.set(e.value()),
                }
            }
            div { class: "field",
                label { class: "field-label", "Mật khẩu" }
                div { style: "display:flex; gap:8px;",
                    input {
                        class: "ui-input",
                        r#type: if *show_pass.read() { "text" } else { "password" },
                        value: "{password}",
                        placeholder: "Nhập mật khẩu...",
                        oninput: move |e| password.set(e.value()),
                    }
                    button {
                        class: "ui-btn ui-btn-secondary sm",
                        onclick: move |_| {
                            let cur = *show_pass.read();
                            show_pass.set(!cur);
                        },
                        if *show_pass.read() { "Ẩn" } else { "Hiện" }
                    }
                }
            }

            button {
                class: "ui-btn ui-btn-primary block",
                disabled: *loading.read(),
                onclick: submit,
                if *loading.read() { "Đang đăng nhập..." } else { "Đăng nhập" }
            }

            div { class: "row-actions", style: "justify-content:space-between; margin-top:14px;",
                button {
                    class: "ui-btn ui-btn-secondary sm",
                    onclick: move |_| state.auth_screen.set(AuthScreen::ForgotPassword),
                    "Quên mật khẩu?"
                }
                button {
                    class: "ui-btn ui-btn-outline sm",
                    onclick: move |_| state.auth_screen.set(AuthScreen::Register),
                    "Tạo tài khoản mới"
                }
            }
        }
    }
}

#[component]
fn RegisterForm(mut state: AppState) -> Element {
    let mut full_name = use_signal(String::new);
    let mut username = use_signal(String::new);
    let mut email = use_signal(String::new);
    let mut phone = use_signal(String::new);
    let mut password = use_signal(String::new);
    let mut confirm = use_signal(String::new);
    let mut error = use_signal(|| None::<String>);
    let mut loading = use_signal(|| false);

    let submit = move |_| {
        let fn_v = full_name.read().trim().to_string();
        let un_v = username.read().trim().to_string();
        let em_v = email.read().trim().to_string();
        let ph_v = phone.read().trim().to_string();
        let pw_v = password.read().clone();
        let cf_v = confirm.read().clone();

        if fn_v.is_empty() || un_v.len() < 3 || em_v.is_empty() || pw_v.len() < 6 {
            error.set(Some("Điền đầy đủ họ tên, username (>=3 ký tự), email và mật khẩu (>=6 ký tự).".into()));
            return;
        }
        if pw_v != cf_v {
            error.set(Some("Mật khẩu xác nhận không khớp.".into()));
            return;
        }
        error.set(None);
        loading.set(true);
        let api = state.api();
        spawn(async move {
            let req = RegisterRequest {
                username: un_v,
                password: pw_v,
                full_name: fn_v,
                email: Some(em_v),
                phone: if ph_v.is_empty() { None } else { Some(ph_v) },
                gender: Some("Khác".into()),
                dob: None,
                bio: None,
            };
            match api.register(req).await {
                Ok(auth) => {
                    let profile = UserProfileResponse {
                        id: auth.id,
                        username: auth.username,
                        full_name: auth.full_name,
                        is_online: Some(true),
                        presence_status: Some("ONLINE".into()),
                        ..Default::default()
                    };
                    {
                        let mut s = state.session.write();
                        s.token = Some(auth.token);
                        s.user = Some(profile);
                        save_session(&s);
                    }
                    state.notify("Tạo tài khoản thành công!");
                    state.trigger_refresh_all();
                }
                Err(err) => error.set(Some(err.message)),
            }
            loading.set(false);
        });
    };

    rsx! {
        div {
            if let Some(err) = error.read().as_ref() {
                div { class: "alert alert-error", "{err}" }
            }
            div { class: "field",
                label { class: "field-label", "Họ và tên *" }
                input { class: "ui-input", value: "{full_name}", oninput: move |e| full_name.set(e.value()) }
            }
            div { class: "field",
                label { class: "field-label", "Username *" }
                input { class: "ui-input", value: "{username}", oninput: move |e| username.set(e.value()) }
            }
            div { class: "field",
                label { class: "field-label", "Email *" }
                input { class: "ui-input", r#type: "email", value: "{email}", oninput: move |e| email.set(e.value()) }
            }
            div { class: "field",
                label { class: "field-label", "Số điện thoại" }
                input { class: "ui-input", r#type: "tel", value: "{phone}", oninput: move |e| phone.set(e.value()) }
            }
            div { class: "field",
                label { class: "field-label", "Mật khẩu *" }
                input { class: "ui-input", r#type: "password", value: "{password}", oninput: move |e| password.set(e.value()) }
            }
            div { class: "field",
                label { class: "field-label", "Nhập lại mật khẩu *" }
                input { class: "ui-input", r#type: "password", value: "{confirm}", oninput: move |e| confirm.set(e.value()) }
            }
            button {
                class: "ui-btn ui-btn-primary block",
                disabled: *loading.read(),
                onclick: submit,
                if *loading.read() { "Đang đăng ký..." } else { "Đăng ký tài khoản" }
            }
            button {
                class: "ui-btn ui-btn-secondary block",
                style: "margin-top:10px;",
                onclick: move |_| state.auth_screen.set(AuthScreen::Login),
                "Quay lại đăng nhập"
            }
        }
    }
}

#[component]
fn ForgotPasswordForm(mut state: AppState) -> Element {
    let mut step = use_signal(|| 1u8);
    let mut email = use_signal(String::new);
    let mut otp = use_signal(String::new);
    let mut hint_otp = use_signal(|| None::<String>);
    let mut new_password = use_signal(String::new);
    let mut confirm_password = use_signal(String::new);
    let mut info = use_signal(|| None::<String>);
    let mut error = use_signal(|| None::<String>);
    let mut loading = use_signal(|| false);

    rsx! {
        div {
            div { class: "section-title",
                span { "Khôi phục mật khẩu (Bước {step}/3)" }
            }
            if let Some(err) = error.read().as_ref() {
                div { class: "alert alert-error", "{err}" }
            }
            if let Some(msg) = info.read().as_ref() {
                div { class: "alert alert-info", "{msg}" }
            }

            if *step.read() == 1 {
                div { class: "field",
                    label { class: "field-label", "Email đã đăng ký" }
                    input {
                        class: "ui-input",
                        r#type: "email",
                        value: "{email}",
                        placeholder: "ten@domain.com",
                        oninput: move |e| email.set(e.value()),
                    }
                }
                button {
                    class: "ui-btn ui-btn-primary block",
                    disabled: *loading.read(),
                    onclick: move |_| {
                        let em = email.read().trim().to_string();
                        if em.is_empty() || !em.contains('@') {
                            error.set(Some("Nhập địa chỉ email hợp lệ.".into()));
                            return;
                        }
                        error.set(None);
                        loading.set(true);
                        let api = state.api();
                        spawn(async move {
                            match api.request_password_reset_otp(em).await {
                                Ok(res) => {
                                    hint_otp.set(res.otp.clone());
                                    info.set(Some(res.message.unwrap_or_else(|| "Đã gửi mã OTP 6 chữ số.".into())));
                                    step.set(2);
                                }
                                Err(e) => error.set(Some(e.message)),
                            }
                            loading.set(false);
                        });
                    },
                    if *loading.read() { "Đang gửi mã OTP..." } else { "Gửi mã xác thực OTP" }
                }
            } else if *step.read() == 2 {
                if let Some(code) = hint_otp.read().clone() {
                    div { class: "alert alert-success",
                        span { "Mã OTP hệ thống: {code} " }
                        button {
                            class: "ui-btn ui-btn-secondary sm",
                            style: "margin-left:8px;",
                            onclick: move |_| otp.set(code.clone()),
                            "Điền nhanh"
                        }
                    }
                }
                div { class: "field",
                    label { class: "field-label", "Mã OTP (6 chữ số)" }
                    input {
                        class: "ui-input",
                        value: "{otp}",
                        placeholder: "000000",
                        oninput: move |e| otp.set(e.value()),
                    }
                }
                button {
                    class: "ui-btn ui-btn-primary block",
                    disabled: *loading.read(),
                    onclick: move |_| {
                        let em = email.read().trim().to_string();
                        let code = otp.read().trim().to_string();
                        if code.len() != 6 {
                            error.set(Some("Mã OTP phải gồm đúng 6 chữ số.".into()));
                            return;
                        }
                        error.set(None);
                        loading.set(true);
                        let api = state.api();
                        spawn(async move {
                            match api.verify_password_reset_otp(em, code).await {
                                Ok(res) if res.verified => {
                                    info.set(Some("Xác thực OTP thành công. Đặt mật khẩu mới.".into()));
                                    step.set(3);
                                }
                                Ok(_) => error.set(Some("Mã OTP không đúng hoặc đã hết hạn.".into())),
                                Err(e) => error.set(Some(e.message)),
                            }
                            loading.set(false);
                        });
                    },
                    if *loading.read() { "Đang xác thực..." } else { "Xác nhận mã OTP" }
                }
            } else {
                div { class: "field",
                    label { class: "field-label", "Mật khẩu mới (>= 6 ký tự)" }
                    input {
                        class: "ui-input",
                        r#type: "password",
                        value: "{new_password}",
                        oninput: move |e| new_password.set(e.value()),
                    }
                }
                div { class: "field",
                    label { class: "field-label", "Nhập lại mật khẩu mới" }
                    input {
                        class: "ui-input",
                        r#type: "password",
                        value: "{confirm_password}",
                        oninput: move |e| confirm_password.set(e.value()),
                    }
                }
                button {
                    class: "ui-btn ui-btn-primary block",
                    disabled: *loading.read(),
                    onclick: move |_| {
                        let p1 = new_password.read().clone();
                        let p2 = confirm_password.read().clone();
                        if p1.len() < 6 || p1 != p2 {
                            error.set(Some("Mật khẩu mới phải >= 6 ký tự và khớp nhau.".into()));
                            return;
                        }
                        error.set(None);
                        loading.set(true);
                        let api = state.api();
                        let em = email.read().trim().to_string();
                        let code = otp.read().trim().to_string();
                        spawn(async move {
                            match api.reset_password_with_otp(em, code, p1).await {
                                Ok(res) if res.reset => {
                                    state.notify("Đặt lại mật khẩu thành công. Đăng nhập ngay.");
                                    state.auth_screen.set(AuthScreen::Login);
                                }
                                Ok(_) => error.set(Some("Không thể đặt lại mật khẩu.".into())),
                                Err(e) => error.set(Some(e.message)),
                            }
                            loading.set(false);
                        });
                    },
                    if *loading.read() { "Đang lưu..." } else { "Đặt lại mật khẩu" }
                }
            }

            button {
                class: "ui-btn ui-btn-secondary block",
                style: "margin-top:10px;",
                onclick: move |_| state.auth_screen.set(AuthScreen::Login),
                "Quay lại đăng nhập"
            }
        }
    }
}
