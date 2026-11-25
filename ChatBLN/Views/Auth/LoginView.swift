import SwiftUI

struct LoginView: View {
    @Bindable var settings: AppSettings
    @Bindable var authViewModel: AuthViewModel

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var showRegister: Bool = false
    @State private var showServerConfig: Bool = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case username
        case password
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    brandHeader
                        .padding(.top, 24)

                    loginCard

                    registerPrompt

                    serverFooterBadge
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showServerConfig = true
                    } label: {
                        Label("Máy chủ", systemImage: "server.rack")
                    }
                    .accessibilityLabel("Cấu hình máy chủ Backend")
                }
            }
            .navigationDestination(isPresented: $showRegister) {
                RegisterView(authViewModel: authViewModel)
            }
            .sheet(isPresented: $showServerConfig) {
                ServerConfigSheet(
                    settings: settings,
                    apiClient: authViewModel.apiClient
                )
            }
        }
    }

    private var brandHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.chatBLNPrimary, Color.chatBLNBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .shadow(color: Color.chatBLNPrimary.opacity(0.28), radius: 12, y: 6)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("Chat BLN")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)

            Text("Nhắn tin thời gian thực nhanh, bảo mật và mượt mà trên iOS.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let errorMessage = authViewModel.errorMessage {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Tên đăng nhập")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)

                TextField("Nhập username của bạn", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focusedField, equals: .username)
                    .onSubmit {
                        focusedField = .password
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Mật khẩu")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Group {
                        if isPasswordVisible {
                            TextField("Nhập mật khẩu", text: $password)
                        } else {
                            SecureField("Nhập mật khẩu", text: $password)
                        }
                    }
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .focused($focusedField, equals: .password)
                    .onSubmit {
                        submitLogin()
                    }

                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel(isPasswordVisible ? "Ẩn mật khẩu" : "Hiện mật khẩu")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button {
                submitLogin()
            } label: {
                HStack(spacing: 10) {
                    if authViewModel.isSubmitting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(authViewModel.isSubmitting ? "Đang đăng nhập..." : "Đăng nhập")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(.chatBLNPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .disabled(authViewModel.isSubmitting || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
        }
        .padding(20)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var registerPrompt: some View {
        HStack(spacing: 6) {
            Text("Chưa có tài khoản?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Tạo tài khoản mới") {
                authViewModel.errorMessage = nil
                showRegister = true
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.chatBLNPrimary)
        }
    }

    private var serverFooterBadge: some View {
        Button {
            showServerConfig = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "network")
                    .font(.caption)
                Text(settings.normalizedBaseURL)
                    .font(.caption.monospaced())
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
        }
    }

    private func submitLogin() {
        focusedField = nil
        Task {
            _ = await authViewModel.login(username: username, password: password)
        }
    }
}
