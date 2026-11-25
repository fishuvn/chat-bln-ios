# Changelog — Chat BLN iOS

Quy ước phiên bản: `1.0.x` / `1.x.x` cho các bản cập nhật và sửa lỗi nhỏ (mỗi bậc tối đa `10`, ví dụ `1.0.10` → `1.1.0`); `x.0.0` dành cho thay đổi lớn về kiến trúc, ngôn ngữ lập trình, nâng phiên bản HĐH tối thiểu hoặc đại tu UI/UX.

## v1.0.0 — Chat BLN iOS (Bản nền tảng ban đầu)

- **Phiên bản**: `v1.0.0` (Build `10000`)
- **Phân loại**: Bản phát hành nền tảng đầu tiên (`Major 1.0.0` — SwiftUI iOS 18.0+)

### ✨ Tính năng nền tảng
- Ứng dụng iOS Native (Swift / SwiftUI cho iOS 18.0+) kết nối REST API & Raw STOMP WebSocket (`/ws-native`).
- Trò chuyện riêng 1-1 và nhóm thời gian thực, xem danh sách thành viên nhóm, gửi ảnh (tự chuẩn hóa HEIC sang JPEG), video và tài liệu.
- Xóa một hoặc nhiều tin nhắn cùng lúc (`Xóa ở phía tôi` / `Thu hồi với mọi người`), quản lý bạn bè & thu hồi lời mời đã gửi.
- Đồng bộ realtime 5 trạng thái hoạt động (`Online`, `Idle`, `Sleep`, `DND`, `Offline`) giữa iOS, Android và Web.
