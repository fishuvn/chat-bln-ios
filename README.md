# Chat BLN iOS — 100% Rust Mobile Client (`v3.0.0`)

Ứng dụng **Chat BLN iOS 18+** được viết lại hoàn toàn bằng **Rust** (`Dioxus 0.7.10`, `Tokio`, `Reqwest + Rustls`, `tokio-tungstenite` STOMP 1.2) theo hệ thống thiết kế tối giản **Quiet Signal**, tích hợp sẵn **trình kiểm tra cập nhật tự động qua GitHub Releases API**.

## Tính năng chính
- **100% Rust**: Toàn bộ giao diện, trạng thái, REST API, WebSocket STOMP 1.2 (`/ws-native`), lưu trữ phiên cục bộ và trình kiểm tra cập nhật viết bằng Rust thuần (`arm64`, iOS 18.0+).
- **Kiểm tra cập nhật ứng dụng (Update Checker)**: Tự động kiểm tra bản phát hành mới trên `fishuvn/chat-bln-ios` khi khởi động và kiểm tra thủ công trong mục **Cài đặt**, so sánh chuẩn SemVer, hiển thị Changelog, dung lượng `ChatBLN-iOS18.ipa` và liên kết `SHA256SUMS.txt`.
- **Đầy đủ nghiệp vụ Chat BLN**: Đăng nhập/Đăng ký JWT, Quên mật khẩu OTP 3 bước, Trạng thái hoạt động 5 chế độ (`ONLINE`, `IDLE`, `SLEEP`, `DND`, `OFFLINE`), Kết bạn & chống spam 5 lần/ngày, Hủy kết bạn, Trò chuyện 1-1 & Nhóm 3 cấp quyền (`ADMIN` / `DEPUTY` / `MEMBER`), Chuyển trưởng nhóm, Nhóm `PUBLIC` / `PRIVATE` + Link mời `/join/:code`, Duyệt yêu cầu vào nhóm, Xóa tin nhắn `FOR_ME` / `FOR_EVERYONE`, Gửi ảnh/video/tệp `<= 50MB`, Light/Dark theme.

## Build & Kiểm thử cục bộ
```bash
# Chạy kiểm thử đơn vị Rust (API, STOMP 1.2, Update Checker)
cargo test --lib --no-default-features

# Đóng gói IPA Release cho iOS 18+ arm64 (trên macOS có Xcode 16+ & dx v0.7.10)
dx bundle --ios --release --target aarch64-apple-ios --package-types ipa --codesign false
```
