import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ProfileView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable var settings: AppSettings
    @Bindable var authViewModel: AuthViewModel
    @Bindable var chatStore: ChatStoreViewModel

    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var gender: String = "Nam"
    @State private var hasDob: Bool = false
    @State private var dobDate: Date = Date()
    @State private var bio: String = ""

    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var isUploadingAvatar: Bool = false
    @State private var isSavingProfile: Bool = false
    @State private var statusMessage: String?
    @State private var isStatusError: Bool = false
    @State private var showServerConfigSheet: Bool = false
    @State private var showSignOutConfirmation: Bool = false
    @State private var updateChecker = AppUpdateChecker.shared

    private let genderOptions = ["Nam", "Nữ", "Khác"]

    var body: some View {
        NavigationStack {
            Form {
                avatarHeaderSection

                if let statusMessage {
                    Section {
                        Label(
                            statusMessage,
                            systemImage: isStatusError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(isStatusError ? Color(.systemRed) : Color(.systemGreen))
                    }
                }

                Section("Thông tin cá nhân") {
                    LabeledContent("Username") {
                        Text("@\(authViewModel.currentProfile?.username ?? settings.cachedUser?.username ?? "")")
                            .foregroundStyle(.secondary)
                    }

                    TextField("Họ và tên hiển thị", text: $fullName)
                        .textContentType(.name)

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Số điện thoại", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)

                    Picker("Giới tính", selection: $gender) {
                        ForEach(genderOptions, id: \.self) { item in
                            Text(item).tag(item)
                        }
                    }

                    Toggle(
                        "Hiển thị ngày sinh",
                        isOn: reduceMotion ? $hasDob : $hasDob.animation(.snappy(duration: 0.2))
                    )
                    if hasDob {
                        DatePicker(
                            "Ngày sinh",
                            selection: $dobDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .environment(\.locale, Locale(identifier: "vi_VN"))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tiểu sử")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Giới thiệu ngắn về bạn...", text: $bio, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    Button {
                        Task {
                            await saveProfileChanges()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Spacer()
                            if isSavingProfile {
                                ProgressView()
                            }
                            Text(isSavingProfile ? "Đang lưu..." : "Lưu thay đổi hồ sơ")
                                .font(.body.weight(.semibold))
                            Spacer()
                        }
                        .frame(minHeight: 44)
                    }
                    .disabled(isSavingProfile)
                }

                Section("Trạng thái & Giao diện") {
                    Picker(
                        "Trạng thái hoạt động",
                        selection: Binding(
                            get: { settings.presenceMode },
                            set: { newMode in
                                Task {
                                    await chatStore.setUserPresenceMode(newMode)
                                }
                            }
                        )
                    ) {
                        ForEach(UserPresenceMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.iconName)
                                .tag(mode)
                        }
                    }

                    Picker("Chế độ giao diện", selection: $settings.appearanceMode) {
                        ForEach(AppAppearanceMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.iconName)
                                .tag(mode)
                        }
                    }

                    Button {
                        showServerConfigSheet = true
                    } label: {
                        HStack {
                            Label("Máy chủ Backend", systemImage: "server.rack")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(settings.normalizedBaseURL)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(minHeight: 36)
                    }
                }

                Section("Ứng dụng & Cập nhật") {
                    LabeledContent("Phiên bản hiện tại") {
                        Text("v\(updateChecker.currentAppVersion)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    if let latest = updateChecker.latestInfo {
                        LabeledContent("Bản mới nhất trên GitHub") {
                            Text(latest.latestTag)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(latest.hasUpdate ? Color.chatBLNPrimary : Color(.systemGreen))
                        }
                    }

                    if let err = updateChecker.errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Color(.systemRed))
                    }

                    Button {
                        Task {
                            await updateChecker.checkForUpdates(openSheetIfDone: true)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Label("Kiểm tra cập nhật", systemImage: "arrow.triangle.2.circlepath")
                                .foregroundStyle(.primary)
                            Spacer()
                            if updateChecker.isChecking {
                                ProgressView()
                            } else {
                                Text("Kiểm tra")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.chatBLNPrimary)
                            }
                        }
                        .frame(minHeight: 36)
                    }
                    .disabled(updateChecker.isChecking)
                }

                Section {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Đăng xuất tài khoản", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.body.weight(.semibold))
                            Spacer()
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
            .navigationTitle("Hồ sơ")
            .refreshable {
                await authViewModel.refreshProfile()
                loadFieldsFromProfile()
            }
            .onAppear {
                loadFieldsFromProfile()
            }
            .onChange(of: authViewModel.currentProfile?.id) { _, _ in
                loadFieldsFromProfile()
            }
            .onChange(of: selectedAvatarItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    await uploadSelectedAvatar(newItem)
                    selectedAvatarItem = nil
                }
            }
            .sheet(isPresented: $showServerConfigSheet) {
                ServerConfigSheet(
                    settings: settings,
                    apiClient: authViewModel.apiClient,
                    onSaved: {
                        chatStore.reconnectRealtimeIfAuthenticated()
                        Task {
                            await authViewModel.refreshProfile()
                            await chatStore.loadConversations()
                            await chatStore.loadFriends()
                            await chatStore.loadFriendRequests()
                        }
                    }
                )
            }
            .confirmationDialog(
                "Bạn có chắc chắn muốn đăng xuất khỏi Chat BLN?",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Đăng xuất", role: .destructive) {
                    Task {
                        await authViewModel.signOut(chatStore: chatStore)
                    }
                }
                Button("Huỷ", role: .cancel) {}
            }
        }
    }

    private var avatarHeaderSection: some View {
        Section {
            VStack(spacing: 12) {
                PhotosPicker(
                    selection: $selectedAvatarItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    ZStack(alignment: .bottomTrailing) {
                        AvatarView(
                            name: fullName.isEmpty ? (authViewModel.currentProfile?.displayName ?? "U") : fullName,
                            avatarURL: settings.resolveAssetURL(authViewModel.currentProfile?.avatarUrl),
                            size: 88,
                            isOnline: settings.presenceMode != .offline,
                            presenceStatus: settings.presenceMode.rawValue
                        )

                        ZStack {
                            Circle()
                                .fill(Color.chatBLNPrimary)
                                .frame(width: 30, height: 30)
                            if isUploadingAvatar {
                                ProgressView()
                                    .controlSize(.mini)
                                    .tint(.white)
                            } else {
                                Image(systemName: "camera.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay(
                            Circle()
                                .stroke(Color(.systemGroupedBackground), lineWidth: 2)
                        )
                    }
                    .frame(minWidth: 96, minHeight: 96)
                }
                .buttonStyle(.plain)
                .disabled(isUploadingAvatar)
                .accessibilityLabel("Đổi ảnh đại diện")

                VStack(spacing: 6) {
                    Text(authViewModel.currentProfile?.displayName ?? settings.cachedUser?.fullName ?? "Người dùng")
                        .font(.title3.weight(.bold))

                    Menu {
                        ForEach(UserPresenceMode.allCases) { mode in
                            Button {
                                Task {
                                    await chatStore.setUserPresenceMode(mode)
                                }
                            } label: {
                                Label(
                                    mode.title,
                                    systemImage: settings.presenceMode == mode ? "checkmark" : mode.iconName
                                )
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: settings.presenceMode.iconName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(settings.presenceMode.dotColor)

                            Text(settings.presenceMode.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
                        )
                    }
                    .accessibilityLabel("Trạng thái hoạt động")
                    .accessibilityValue(settings.presenceMode.title)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .listRowBackground(Color.clear)
        }
    }

    private func loadFieldsFromProfile() {
        guard let profile = authViewModel.currentProfile else { return }
        fullName = profile.fullName ?? profile.username
        email = profile.email ?? ""
        phone = profile.phone ?? ""
        if let g = profile.gender, genderOptions.contains(g) {
            gender = g
        } else {
            gender = "Nam"
        }
        bio = profile.bio ?? ""

        if let dobRaw = profile.dob,
           let parsed = ChatDateFormatter.parseBackendDate(dobRaw) {
            hasDob = true
            dobDate = parsed
        } else {
            hasDob = false
        }
    }

    private func saveProfileChanges() async {
        let cleanFullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanFullName.isEmpty else {
            isStatusError = true
            statusMessage = "Họ và tên hiển thị không được để trống."
            return
        }

        isSavingProfile = true
        statusMessage = nil

        let dobString: String?
        if hasDob {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            dobString = formatter.string(from: dobDate)
        } else {
            dobString = nil
        }

        let payload = UpdateProfileRequest(
            fullName: cleanFullName,
            email: email.trimmedNilIfEmpty,
            phone: phone.trimmedNilIfEmpty,
            gender: gender,
            dob: dobString,
            bio: bio.trimmedNilIfEmpty,
            avatarUrl: authViewModel.currentProfile?.avatarUrl
        )

        do {
            try await authViewModel.updateProfile(payload)
            isStatusError = false
            statusMessage = "Đã lưu thông tin hồ sơ thành công."
        } catch {
            isStatusError = true
            statusMessage = error.localizedDescription
        }
        isSavingProfile = false
    }

    private func uploadSelectedAvatar(_ item: PhotosPickerItem) async {
        isUploadingAvatar = true
        statusMessage = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self), !data.isEmpty else {
                isStatusError = true
                statusMessage = "Không thể đọc tệp ảnh đại diện."
                isUploadingAvatar = false
                return
            }

            let utType = item.supportedContentTypes.first
            var uploadData = data
            var mime = utType?.preferredMIMEType ?? "image/jpeg"
            var ext = (utType?.preferredFilenameExtension ?? "jpg").lowercased()

            if ext == "heic" || ext == "heif" || ext == "tiff" || mime.contains("heic") || mime.contains("heif") {
                if let uiImage = UIImage(data: data),
                   let jpegData = uiImage.jpegData(compressionQuality: 0.85) {
                    uploadData = jpegData
                    mime = "image/jpeg"
                    ext = "jpg"
                }
            }

            let fileName = "avatar_\(Int(Date().timeIntervalSince1970)).\(ext)"

            try await authViewModel.uploadAndSaveAvatar(
                data: uploadData,
                fileName: fileName,
                mimeType: mime
            )
            isStatusError = false
            statusMessage = "Đã cập nhật ảnh đại diện mới."
        } catch {
            isStatusError = true
            statusMessage = error.localizedDescription
        }
        isUploadingAvatar = false
    }
}
