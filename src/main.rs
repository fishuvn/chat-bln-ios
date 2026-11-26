fn main() {
    let _ = rustls::crypto::ring::default_provider().install_default();
    dioxus::launch(chat_bln_mobile::App);
}
