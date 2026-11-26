# Chat BLN — Ứng dụng iOS Thuần (Swift 6 + SwiftUI)

[![Build iOS 18+ IPA](https://github.com/fishuvn/chat-bln-ios/actions/workflows/build-ipa.yml/badge.svg)](https://github.com/fishuvn/chat-bln-ios/actions/workflows/build-ipa.yml)

Ứng dụng di động **Chat BLN** trên nền tảng **iOS 18+** được xây dựng hoàn toàn bằng **Swift 6** và **SwiftUI** theo chuẩn **Apple Human Interface Guidelines (HIG)**, kết nối trực tiếp tới Backend **Spring Boot** (REST API + Raw STOMP 1.2 WebSocket) mà **không phụ thuộc bất kỳ thư viện bên thứ ba nào** (Zero CocoaPods / Zero SPM) để mở và biên dịch ngay lập tức trên Xcode.

---

## CI/CD Tự động Build File IPA iOS 18+ (GitHub Actions macOS)

Workflow `.github/workflows/build-ipa.yml` chạy trên máy ảo `macos-15` (Xcode 16+) mỗi khi `push` / `pull_request` lên `main`, và tự động tạo **GitHub Release** khi đẩy tag `v*` (ví dụ `git tag v1.0.0 && git push origin v1.0.0`) hoặc bật `create_release` trong **Actions -> Run workflow**:

- Xuất 1 gói cài đặt duy nhất: **`ChatBLN-iOS18.ipa`** (`IPHONEOS_DEPLOYMENT_TARGET = 18.0`, kiến trúc `arm64`).
- Mặc định đóng gói `.ipa` không cần chứng chỉ trả phí (hỗ trợ cài qua AltStore / SideStore / Sideloadly); nếu cấu hình thêm GitHub Secrets (`IOS_CERT_BASE64`, `IOS_CERT_PASSWORD`, `IOS_PROVISION_BASE64`, `EXPORT_OPTIONS_PLIST_BASE64`) thì tự động ký Apple Developer chính thức.

---

## 1. Yêu cầu hệ thống

- **macOS** chạy **Xcode 16.0+** (hỗ trợ Swift 6 & iOS 18 SDK).
- **Backend Chat BLN** đang chạy ở cổng `8088` (`./mvnw spring-boot:run` trong thư mục `backend/`) cùng cơ sở dữ liệu MySQL.
- *(Tuỳ chọn)* **XcodeGen** (`brew install xcodegen`) nếu muốn tái tạo lại `ChatBLN.xcodeproj` từ `project.yml`. Dự án đã đính kèm sẵn `ChatBLN.xcodeproj` chuẩn Xcode 16 nên có thể mở trực tiếp ngay mà không cần cài thêm công cụ.

---

## 2. Cách mở dự án & chọn Team ký ứng dụng (Code Signing)

1. Mở trực tiếp tệp dự án trong Xcode:
   ```bash
   open ios-app/ChatBLN.xcodeproj
   ```
2. Trên thanh điều hướng trái của Xcode, bấm vào biểu tượng dự án **ChatBLN** -> chọn Target **ChatBLN** -> mở tab **Signing & Capabilities**.
3. Đánh dấu **Automatically manage signing**:
   - Nếu chạy trên **iOS Simulator**: không bắt buộc tài khoản trả phí, có thể để Team là *None* hoặc *Personal Team*.
   - Nếu cài lên **iPhone thật**: chọn **Personal Team** (Apple ID cá nhân miễn phí) và đổi `Bundle Identifier` (ví dụ `vn.nhom3.chatbln.tenban`) nếu bị trùng trên Apple Developer. Trên iPhone thật, vào **Cài đặt -> Cài đặt chung -> Quản lý VPN & Thiết bị** để bấm **Tin cậy (Trust)** chứng chỉ nhà phát triển.
4. Chọn thiết bị đích (ví dụ **iPhone 16 Pro** Simulator hoặc iPhone thật) rồi nhấn **`Cmd + R`** để Build & Run.

---

## 3. Cấu hình địa chỉ máy chủ (Simulator vs. iPhone thật qua mạng LAN)

Ứng dụng tích hợp sẵn màn hình **Cấu hình Máy chủ** ngay tại màn hình **Đăng nhập** (biểu tượng bánh răng / máy chủ ở góc phải trên) và trong tab **Hồ sơ -> Máy chủ Backend**:

### Trường hợp A: Chạy trên iOS Simulator (cùng máy Mac với Backend)
- Giữ nguyên địa chỉ mặc định:
  ```text
  http://127.0.0.1:8088
  ```
- WebSocket STOMP sẽ tự động chuyển đổi tương ứng sang:
  ```text
  ws://127.0.0.1:8088/ws-native
  ```

### Trường hợp B: Chạy trên iPhone thật (cùng mạng Wi-Fi / LAN với máy chạy Backend)
- Trên iPhone thật, `127.0.0.1` trỏ về chính điện thoại chứ không phải máy tính chạy Spring Boot.
- Kiểm tra địa chỉ IPv4 LAN của máy tính chạy Backend:
  - **macOS**: `ipconfig getifaddr en0`
  - **Linux**: `hostname -I`
  - **Windows**: `ipconfig`
- Mở mục **Cấu hình Máy chủ** trong ứng dụng Chat BLN trên iPhone và nhập:
  ```text
  http://192.168.1.10:8088
  ```
  *(thay `192.168.1.10` bằng IP LAN thực tế của máy tính chạy Spring Boot, đảm bảo tường lửa mở cổng `8088`).*
- Bấm **Kiểm tra kết nối (`/api/health`)** ngay trong sheet cấu hình để xác nhận máy chủ phản hồi trạng thái `UP` trước khi đăng nhập.

---

## 4. Kiến trúc thư mục (`ChatBLN/`)

```text
ios-app/
├── ChatBLN.xcodeproj/              # Dự án Xcode 16+ (mở và chạy ngay, không cần cài gói ngoài)
├── project.yml                     # Đặc tả XcodeGen tương đương
└── ChatBLN/
    ├── Info.plist                  # Cấu hình ATS (Local Networking) & quyền Thư viện Ảnh
    ├── Assets.xcassets/            # AccentColor (#0B57D0 / #3C95FF) & AppIcon
    ├── App/
    │   ├── ChatBLNApp.swift        # Điểm vào ứng dụng @main, quản lý giao diện Sáng/Tối/Hệ thống
    │   └── RootView.swift          # Điều phối màn hình Đăng nhập <-> MainTabView
    ├── Core/
    │   ├── Models/
    │   │   └── APIModels.swift     # Toàn bộ DTO Codable, Hashable, Sendable khớp Backend
    │   ├── Storage/
    │   │   ├── KeychainService.swift # Lưu trữ bảo mật JWT Token trong iOS Keychain
    │   │   └── AppSettings.swift   # @AppStorage / Observable lưu Base URL, giao diện, phiên user
    │   ├── Network/
    │   │   └── APIClient.swift     # URLSession async/await, Bearer JWT, Multipart Upload
    │   ├── Realtime/
    │   │   └── StompWebSocketClient.swift # STOMP 1.2 thuần trên URLSessionWebSocketTask (/ws-native)
    │   └── Utilities/
    │       └── MarkdownMessageFormatter.swift # Phân tích liên kết [Văn bản](url) & URL trần sang AttributedString
    ├── ViewModels/
    │   ├── AuthViewModel.swift     # Đăng nhập, Đăng ký, Đăng xuất, khôi phục phiên JWT
    │   └── ChatStoreViewModel.swift # Quản lý hội thoại, tin nhắn phân trang, STOMP realtime, bạn bè
    └── Views/
        ├── Auth/                   # LoginView, RegisterView, ServerConfigSheet
        ├── Main/                   # MainTabView (4 tab chuẩn HIG + huy hiệu lời mời kết bạn)
        ├── Conversations/          # ConversationsListView, NewConversationSheet (Chat đơn & Nhóm)
        ├── Chat/                   # ChatRoomView, MessageBubbleView, EmojiPickerSheet, ConversationInfoSheet
        ├── Contacts/               # ContactsView, AddFriendSheet, FriendRequestsView
        ├── Profile/                # ProfileView (Ảnh đại diện PhotosPicker, Sửa hồ sơ, Giao diện, Máy chủ)
        └── Components/             # AvatarView (Ảnh đại diện trực tuyến + chấm trạng thái hoạt động)
```

---

## 5. Tính năng nổi bật theo chuẩn Apple HIG

- **Điều hướng tự nhiên trên iOS**: `TabView` 4 tab (*Đoạn chat*, *Danh bạ*, *Lời mời* kèm `.badge()`, *Hồ sơ*), `NavigationStack`, `.searchable`, `.refreshable`, và các `.sheet` có `.presentationDetents([.medium, .large])`.
- **Realtime STOMP 1.2 thuần Swift**: Tự động đóng gói khung `CONNECT`, `SUBSCRIBE`, `DISCONNECT` kết thúc bằng ký tự `\0`, duy trì nhịp tim (`heart-beat:10000,10000`) và tự động kết nối lại khi mạng chập chờn.
- **Đa phương tiện & Liên kết thông minh**:
  - Menu đính kèm tách riêng rõ ràng 3 tác vụ: **Chọn gửi ảnh** (`PhotosPicker` chỉ lọc ảnh), **Chọn gửi video** (`PhotosPicker` chỉ lọc video), và **Đính kèm tệp** (`.fileImporter`).
  - Hiển thị bong bóng ảnh kèm trình xem toàn màn hình, phát video trực tiếp bằng `AVKit.VideoPlayer`, thẻ tệp đính kèm mở nhanh, và liên kết Markdown `[Tên hiển thị](https://...)` bấm mở trực tiếp.
  - Bộ chọn biểu tượng cảm xúc phân nhóm theo danh mục với ô tìm kiếm nhanh.
- **Tôn trọng quyền riêng tư danh bạ**: Màn hình **Thêm bạn bè** ẩn hoàn toàn danh sách người dùng hệ thống cho tới khi người dùng chủ động nhập từ khoá tìm kiếm.
