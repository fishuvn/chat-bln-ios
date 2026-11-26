# Changelog — Chat BLN iOS

Quy ước phiên bản: `1.0.x` / `1.x.x` cho các bản cập nhật và sửa lỗi nhỏ (mỗi bậc tối đa `10`, ví dụ `1.0.10` → `1.1.0`); `x.0.0` dành cho thay đổi lớn về kiến trúc, ngôn ngữ lập trình, nâng phiên bản HĐH tối thiểu hoặc đại tu UI/UX.

## v4.0.2 — Chat BLN iOS (2026-11-26 23:54 UTC+7)

- **Phiên bản**: `v4.0.2` (Build `40002`)
- **Phân loại**: Bản cập nhật & sửa lỗi nhỏ (`1.x.x`, giới hạn tối đa `.10`)

### ✨ Tính năng mới
- feat(brand): upgrade to symmetric Dual Dialogue brand mark and regenerated 1024px Light/Dark/Tinted App Icons (`a120936`)

## v4.0.1 — Chat BLN iOS (2026-11-26 23:40 UTC+7)

- **Phiên bản**: `v4.0.1` (Build `40001`)
- **Phân loại**: Bản cập nhật & sửa lỗi nhỏ (`1.x.x`, giới hạn tối đa `.10`)

### 🐛 Sửa lỗi
- fix(ui): fix iOS 26 auth/profile/alert UI defects and apply Signal Aperture brand & app icons (`59403c5`)

## v4.0.0 — Chat BLN iOS (2026-11-26 23:19 UTC+7)

- **Phiên bản**: `v4.0.0` (Build `40000`)
- **Phân loại**: Cập nhật lớn (`x.0.0` — Kiến trúc / Ngôn ngữ / HĐH / Đại tu UI-UX)

### 🚀 Thay đổi lớn (Cấu trúc / HĐH / UI-UX)
- arch!: revert iOS app to native Swift 6 + SwiftUI 18+ with GitHub Releases update checker (`9beab72`)

### 🐛 Sửa lỗi
- fix(ios): simplify currentAppVersion optional unwrap in AppUpdateChecker (`5261645`)

## v3.0.0 — Chat BLN iOS (Rust) (2026-11-26 22:56 UTC+7)

- **Phiên bản**: `v3.0.0` (Build `30000`)
- **Phân loại**: Cập nhật lớn (`x.0.0` — Kiến trúc / Ngôn ngữ / HĐH / Đại tu UI-UX)

### 🚀 Thay đổi lớn (Cấu trúc / HĐH / UI-UX)
- arch!: rebuild complete iOS app in 100% Rust (Dioxus 0.7) and add GitHub Releases update checker (`afbf2bd`)

### 🐛 Sửa lỗi
- fix(ci): expose rust sysroot libLLVM.dylib for rust-objcopy on macOS (`f27850f`)

## v2.0.0 — Chat BLN iOS (2026-11-26 02:10 UTC+7)

- **Phiên bản**: `v2.0.0` (Build `20000`)
- **Phân loại**: Cập nhật lớn (`x.0.0` — Kiến trúc / Ngôn ngữ / HĐH / Đại tu UI-UX)

### 🚀 Thay đổi lớn (Cấu trúc / HĐH / UI-UX)
- ui!: complete minimalist Apple HIG redesign, accessibility, forgot-password OTP, and image cache optimization (`8ce5905`)

## v1.0.2 — Chat BLN iOS (2026-11-26 01:26 UTC+7)

- **Phiên bản**: `v1.0.2` (Build `10002`)
- **Phân loại**: Bản cập nhật & sửa lỗi nhỏ (`1.x.x`, giới hạn tối đa `.10`)

### ✨ Tính năng mới
- feat(group): add deputy role, leader transfer, public/private invite links, and join approvals (`967ef1d`)

## v1.0.1 — Chat BLN iOS (2026-11-26 00:43 UTC+7)

- **Phiên bản**: `v1.0.1` (Build `10001`)
- **Phân loại**: Bản cập nhật & sửa lỗi nhỏ (`1.x.x`, giới hạn tối đa `.10`)

### ✨ Tính năng mới
- feat(ios): sync ONLINE/IDLE/SLEEP/DND/OFFLINE presence modes with backend and render live status badges (`e66800e`)
- feat(ios): add group members list and unfriend/re-friend support (`3668ad6`)
- feat(ios): add single and multi-select message deletion with realtime sync (`3e60a9e`)
- feat(ios): add persistent conversation deletion via DELETE /api/conversations/:id (`3b49fbb`)
- feat(ios): init SwiftUI iOS 18+ app with Xcode IPA CI/CD (`8f26291`)

### 🐛 Sửa lỗi
- fix(ios): show sent friend request recipient details, support withdrawing requests, and convert HEIC media to JPEG (`c26ad02`)
- fix(ios): refresh search state when friend request is rejected (`7637988`)
- fix(ios): fix login bootstrap race and add full interactive status selector (`b0bf15e`)
- fix(ios): fix ATS policy and default to https://chat-bln.fishu.io.vn (`d29c7fb`)

### 🔧 Cải tiến & Bảo trì
- ci(release): auto-bump version (max .10 per slot), generate changelog, and publish iOS IPA Release on build (`ce9ae5f`)

## v1.0.0 — Chat BLN iOS (Bản nền tảng ban đầu)

- **Phiên bản**: `v1.0.0` (Build `10000`)
- **Phân loại**: Bản phát hành nền tảng đầu tiên (`Major 1.0.0` — SwiftUI iOS 18.0+)

### ✨ Tính năng nền tảng
- Ứng dụng iOS Native (Swift / SwiftUI cho iOS 18.0+) kết nối REST API & Raw STOMP WebSocket (`/ws-native`).
- Trò chuyện riêng 1-1 và nhóm thời gian thực, xem danh sách thành viên nhóm, gửi ảnh (tự chuẩn hóa HEIC sang JPEG), video và tài liệu.
- Xóa một hoặc nhiều tin nhắn cùng lúc (`Xóa ở phía tôi` / `Thu hồi với mọi người`), quản lý bạn bè & thu hồi lời mời đã gửi.
- Đồng bộ realtime 5 trạng thái hoạt động (`Online`, `Idle`, `Sleep`, `DND`, `Offline`) giữa iOS, Android và Web.
