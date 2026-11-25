import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
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
                        .foregroundStyle(isStatusError ? Color.red : Color.green)
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

                    Toggle("Hiển thị ngày sinh", isOn: $hasDob.animation())
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
                        HStack {
                            Spacer()
                            if isSavingProfile {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isSavingProfile ? "Đang lưu..." : "Lưu thay đổi hồ sơ")
                                .font(.body.weight(.semibold))
                            Spacer()
                        }
                    }
                    .disabled(isSavingProfile || fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("Giao diện & Kết nối") {
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
                    }
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
            .onChange(of: authViewModel.currentProfile?.avatarUrl) { _, _ in
                // Đồng bộ lại ảnh đại diện mới nhất
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
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(
                        name: fullName.isEmpty ? (authViewModel.currentProfile?.displayName ?? "U") : fullName,
                        avatarURL: settings.resolveAssetURL(authViewModel.currentProfile?.avatarUrl),
                        size: 92,
                        isOnline: true
                    )

                    PhotosPicker(
                        selection: $selectedAvatarItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        ZStack {
                            Circle()
                                .fill(Color.chatBLNPrimary)
                                .frame(width: 32, height: 32)
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
                                .stroke(Color(.systemBackground), lineWidth: 2)
                        )
                    }
                    .disabled(isUploadingAvatar)
                    .accessibilityLabel("Đổi ảnh đại diện")
                }

                VStack(spacing: 3) {
                    Text(authViewModel.currentProfile?.displayName ?? settings.cachedUser?.fullName ?? "Người dùng")
                        .font(.title3.weight(.bold))

                    Text(chatStore.isRealtimeConnected ? "Đang kết nối Realtime STOMP" : "Đang chờ kết nối máy chủ")
                        .font(.caption)
                        .foregroundStyle(chatStore.isRealtimeConnected ? Color.green : .secondary)
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
            fullName: fullName.trimmedNilIfEmpty,
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
            let mime = utType?.preferredMIMEType ?? "image/jpeg"
            let ext = utType?.preferredFilenameExtension ?? "jpg"
            let fileName = "avatar_\(Int(Date().timeIntervalSince1970)).\(ext)"

            try await authViewModel.uploadAndSaveAvatar(
                data: data,
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
