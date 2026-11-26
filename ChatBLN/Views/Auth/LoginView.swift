import SwiftUI

struct LoginView: View {
    @Bindable var settings: AppSettings
    @Bindable var authViewModel: AuthViewModel

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var localValidationError: String?
    @State private var showRegister: Bool = false
    @State private var showForgotPassword: Bool = false
    @State private var showServerConfig: Bool = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case username
        case password
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    brandHeader
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                if let banner = localValidationError ?? authViewModel.errorMessage {
                    Section {
                        Label(banner, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Color(.systemRed))
                    }
                }

                Section("Thông tin đăng nhập") {
                    TextField("Tên đăng nhập hoặc email", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focusedField, equals: .username)
                        .onChange(of: username) { _, _ in
                            localValidationError = nil
                        }
                        .onSubmit {
                            focusedField = .password
                        }
                        .frame(minHeight: 36)

                    HStack(spacing: 8) {
                        Group {
                            if isPasswordVisible {
                                TextField("Mật khẩu", text: $password)
                            } else {
                                SecureField("Mật khẩu", text: $password)
                            }
                        }
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .focused($focusedField, equals: .password)
                        .onChange(of: password) { _, _ in
                            localValidationError = nil
                        }
                        .onSubmit {
                            submitLogin()
                        }

                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isPasswordVisible ? "Ẩn mật khẩu" : "Hiện mật khẩu")
                    }
                }

                Section {
                    Button {
                        submitLogin()
                    } label: {
                        HStack(spacing: 8) {
                            Spacer()
                            if authViewModel.isSubmitting {
                                ProgressView()
                            }
                            Text(authViewModel.isSubmitting ? "Đang đăng nhập..." : "Đăng nhập")
                                .font(.headline)
                            Spacer()
                        }
                        .frame(minHeight: 44)
                    }
                    .disabled(authViewModel.isSubmitting)

                    Button {
                        localValidationError = nil
                        authViewModel.errorMessage = nil
                        showForgotPassword = true
                    } label: {
                        HStack {
                            Text("Quên mật khẩu?")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.chatBLNPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(minHeight: 44)
                    }
                }

                Section {
                    Button {
                        localValidationError = nil
                        authViewModel.errorMessage = nil
                        showRegister = true
                    } label: {
                        HStack {
                            Label("Tạo tài khoản mới", systemImage: "person.badge.plus")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(minHeight: 44)
                    }
                } footer: {
                    HStack(spacing: 6) {
                        Image(systemName: "network")
                            .accessibilityHidden(true)
                        Text("Máy chủ hiện tại: \(settings.normalizedBaseURL)")
                            .font(.caption.monospaced())
                    }
                    .padding(.top, 6)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showServerConfig = true
                    } label: {
                        Label("Máy chủ", systemImage: "server.rack")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Cấu hình máy chủ Backend")
                }
            }
            .navigationDestination(isPresented: $showRegister) {
                RegisterView(authViewModel: authViewModel)
            }
            .navigationDestination(isPresented: $showForgotPassword) {
                ForgotPasswordView(apiClient: authViewModel.apiClient) { recoveredUser in
                    username = recoveredUser
                    password = ""
                }
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
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.chatBLNPrimary)
                    .frame(width: 60, height: 60)

                Image(systemName: "bubble.left.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("Chat BLN")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Nhắn tin thời gian thực tinh gọn, bảo mật trên iOS.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func submitLogin() {
        localValidationError = nil
        authViewModel.errorMessage = nil

        let cleanUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUser.isEmpty else {
            localValidationError = "Vui lòng nhập tên đăng nhập hoặc email."
            focusedField = .username
            return
        }
        guard !password.isEmpty else {
            localValidationError = "Vui lòng nhập mật khẩu."
            focusedField = .password
            return
        }

        focusedField = nil
        Task {
            _ = await authViewModel.login(username: cleanUser, password: password)
        }
    }
}
