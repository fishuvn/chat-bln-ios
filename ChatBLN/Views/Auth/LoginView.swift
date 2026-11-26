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
            ScrollView {
                VStack(spacing: 22) {
                    brandHeader
                        .padding(.top, 18)

                    if let banner = localValidationError ?? authViewModel.errorMessage {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(Color(.systemRed))
                                .padding(.top, 1)
                            Text(banner)
                                .font(.footnote)
                                .foregroundStyle(Color(.systemRed))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12)
                        .background(
                            Color(.systemRed).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color(.systemRed).opacity(0.32), lineWidth: 1)
                        )
                    }

                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tên đăng nhập hoặc Email")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 10) {
                                Image(systemName: "person")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)

                                TextField(
                                    "",
                                    text: $username,
                                    prompt: Text("Nhập tên đăng nhập hoặc email").foregroundStyle(.secondary)
                                )
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
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 50)
                            .background(
                                Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(
                                        focusedField == .username ? Color.chatBLNPrimary : Color(.separator).opacity(0.45),
                                        lineWidth: focusedField == .username ? 1.5 : 1
                                    )
                            )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Mật khẩu")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Quên mật khẩu?") {
                                    localValidationError = nil
                                    authViewModel.errorMessage = nil
                                    showForgotPassword = true
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.chatBLNPrimary)
                            }

                            HStack(spacing: 10) {
                                Image(systemName: "lock")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)

                                Group {
                                    if isPasswordVisible {
                                        TextField(
                                            "",
                                            text: $password,
                                            prompt: Text("Nhập mật khẩu").foregroundStyle(.secondary)
                                        )
                                    } else {
                                        SecureField(
                                            "",
                                            text: $password,
                                            prompt: Text("Nhập mật khẩu").foregroundStyle(.secondary)
                                        )
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
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 36, height: 36)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(isPasswordVisible ? "Ẩn mật khẩu" : "Hiện mật khẩu")
                            }
                            .padding(.leading, 14)
                            .padding(.trailing, 8)
                            .frame(minHeight: 50)
                            .background(
                                Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(
                                        focusedField == .password ? Color.chatBLNPrimary : Color(.separator).opacity(0.45),
                                        lineWidth: focusedField == .password ? 1.5 : 1
                                    )
                            )
                        }
                    }

                    VStack(spacing: 12) {
                        Button {
                            submitLogin()
                        } label: {
                            HStack(spacing: 8) {
                                if authViewModel.isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text(authViewModel.isSubmitting ? "Đang đăng nhập..." : "Đăng nhập")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(
                                Color.chatBLNPrimary,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(authViewModel.isSubmitting)
                        .opacity(authViewModel.isSubmitting ? 0.72 : 1.0)

                        Button {
                            localValidationError = nil
                            authViewModel.errorMessage = nil
                            showRegister = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.badge.plus")
                                    .font(.subheadline.weight(.semibold))
                                Text("Tạo tài khoản mới")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        showServerConfig = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(settings.normalizedBaseURL)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Color(.secondarySystemGroupedBackground),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    .accessibilityLabel("Cấu hình máy chủ Backend: \(settings.normalizedBaseURL)")
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showServerConfig = true
                    } label: {
                        Image(systemName: "server.rack")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.chatBLNPrimary)
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
        VStack(spacing: 14) {
            ChatBLNBrandMark(size: 68)

            VStack(spacing: 5) {
                Text("Chat BLN")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Nhắn tin thời gian thực tinh gọn và bảo mật.")
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
