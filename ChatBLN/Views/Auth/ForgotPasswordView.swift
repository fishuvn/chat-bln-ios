import SwiftUI
import UIKit

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let apiClient: APIClient
    var onRecoveredUsername: ((String) -> Void)? = nil

    private enum Step: Int, CaseIterable {
        case email = 1
        case verifyOtp = 2
        case resetPassword = 3

        var title: String {
            switch self {
            case .email:
                return "Bước 1/3 · Nhập email đăng ký"
            case .verifyOtp:
                return "Bước 2/3 · Xác thực mã OTP"
            case .resetPassword:
                return "Bước 3/3 · Đặt mật khẩu mới"
            }
        }
    }

    @State private var currentStep: Step = .email
    @State private var email: String = ""
    @State private var otpCode: String = ""
    @State private var serverIssuedOtpHint: String?
    @State private var matchedUsername: String?

    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showNewPassword: Bool = false

    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var isResetCompleted: Bool = false

    @FocusState private var focusedField: FocusTarget?

    private enum FocusTarget: Hashable {
        case email
        case otp
        case newPassword
        case confirmPassword
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentStep.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.chatBLNPrimary)

                    ProgressView(value: Double(currentStep.rawValue), total: 3.0)
                        .tint(.chatBLNPrimary)
                        .accessibilityLabel("Tiến trình khôi phục mật khẩu")
                        .accessibilityValue("Bước \(currentStep.rawValue) trên 3")
                }
                .padding(.vertical, 4)
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Color(.systemRed))
                }
            }

            if let infoMessage {
                Section {
                    Label(infoMessage, systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Color(.systemGreen))
                }
            }

            switch currentStep {
            case .email:
                emailStepSection
            case .verifyOtp:
                otpStepSection
            case .resetPassword:
                resetPasswordStepSection
            }
        }
        .navigationTitle("Quên mật khẩu")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Đặt lại mật khẩu thành công", isPresented: $isResetCompleted) {
            Button("Quay lại Đăng nhập") {
                if let matchedUsername, !matchedUsername.isEmpty {
                    onRecoveredUsername?(matchedUsername)
                }
                dismiss()
            }
        } message: {
            Text("Mật khẩu mới đã được cập nhật. Bạn có thể đăng nhập ngay bây giờ.")
        }
    }

    // MARK: - Step 1: Request OTP by Email

    @ViewBuilder
    private var emailStepSection: some View {
        Section {
            TextField("Địa chỉ email đã đăng ký", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.send)
                .focused($focusedField, equals: .email)
                .onSubmit {
                    Task { await submitEmailRequest() }
                }
        } header: {
            Text("Tài khoản cần khôi phục")
        } footer: {
            Text("Hệ thống sẽ tạo mã xác thực OTP gồm 6 chữ số có hiệu lực trong 5 phút.")
        }

        Section {
            Button {
                Task { await submitEmailRequest() }
            } label: {
                HStack {
                    Spacer()
                    if isSubmitting {
                        ProgressView()
                            .padding(.trailing, 8)
                    }
                    Text(isSubmitting ? "Đang gửi yêu cầu..." : "Nhận mã OTP 6 số")
                        .font(.body.weight(.semibold))
                    Spacer()
                }
                .frame(minHeight: 44)
            }
            .disabled(isSubmitting)
        }
    }

    // MARK: - Step 2: Verify 6-Digit OTP

    @ViewBuilder
    private var otpStepSection: some View {
        Section {
            LabeledContent("Email", value: email.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.subheadline)

            if let serverIssuedOtpHint, !serverIssuedOtpHint.isEmpty {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mã xác thực hệ thống cấp (5 phút)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(serverIssuedOtpHint)
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Button("Điền mã") {
                        otpCode = serverIssuedOtpHint
                    }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                }
                .padding(.vertical, 2)
            }

            TextField("Nhập mã OTP 6 chữ số", text: $otpCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.body.monospacedDigit())
                .focused($focusedField, equals: .otp)
                .onChange(of: otpCode) { _, newValue in
                    let digitsOnly = String(newValue.filter(\.isNumber).prefix(6))
                    if digitsOnly != newValue {
                        otpCode = digitsOnly
                    }
                }
        } header: {
            Text("Mã xác thực OTP")
        } footer: {
            Text("Nhập chính xác 6 chữ số để xác minh quyền đặt lại mật khẩu.")
        }

        Section {
            Button {
                Task { await submitOtpVerification() }
            } label: {
                HStack {
                    Spacer()
                    if isSubmitting {
                        ProgressView()
                            .padding(.trailing, 8)
                    }
                    Text(isSubmitting ? "Đang kiểm tra..." : "Xác thực mã OTP")
                        .font(.body.weight(.semibold))
                    Spacer()
                }
                .frame(minHeight: 44)
            }
            .disabled(isSubmitting)

            Button {
                Task { await submitEmailRequest(isResend: true) }
            } label: {
                Label("Gửi lại mã OTP mới", systemImage: "arrow.clockwise")
                    .frame(minHeight: 44)
            }
            .disabled(isSubmitting)
        }
    }

    // MARK: - Step 3: Reset New Password

    @ViewBuilder
    private var resetPasswordStepSection: some View {
        Section {
            HStack(spacing: 8) {
                Group {
                    if showNewPassword {
                        TextField("Mật khẩu mới (tối thiểu 6 ký tự)", text: $newPassword)
                    } else {
                        SecureField("Mật khẩu mới (tối thiểu 6 ký tự)", text: $newPassword)
                    }
                }
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .newPassword)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .confirmPassword
                }

                Button {
                    showNewPassword.toggle()
                } label: {
                    Image(systemName: showNewPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showNewPassword ? "Ẩn mật khẩu mới" : "Hiện mật khẩu mới")
            }

            Group {
                if showNewPassword {
                    TextField("Nhập lại mật khẩu mới", text: $confirmPassword)
                } else {
                    SecureField("Nhập lại mật khẩu mới", text: $confirmPassword)
                }
            }
            .textContentType(.newPassword)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .confirmPassword)
            .submitLabel(.done)
            .onSubmit {
                Task { await submitPasswordReset() }
            }
        } header: {
            Text("Thiết lập mật khẩu mới")
        } footer: {
            Text("Mật khẩu mới cần có độ dài từ 6 đến 72 ký tự.")
        }

        Section {
            Button {
                Task { await submitPasswordReset() }
            } label: {
                HStack {
                    Spacer()
                    if isSubmitting {
                        ProgressView()
                            .padding(.trailing, 8)
                    }
                    Text(isSubmitting ? "Đang cập nhật..." : "Lưu mật khẩu mới")
                        .font(.body.weight(.semibold))
                    Spacer()
                }
                .frame(minHeight: 44)
            }
            .disabled(isSubmitting)
        }
    }

    // MARK: - Actions

    private func transition(to nextStep: Step) {
        if reduceMotion {
            currentStep = nextStep
        } else {
            withAnimation(.snappy(duration: 0.2)) {
                currentStep = nextStep
            }
        }
    }

    private func submitEmailRequest(isResend: Bool = false) async {
        focusedField = nil
        errorMessage = nil
        infoMessage = nil

        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty, cleanEmail.contains("@") else {
            errorMessage = "Vui lòng nhập địa chỉ email hợp lệ đã gắn với tài khoản."
            focusedField = .email
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let response = try await apiClient.requestPasswordResetOtp(email: cleanEmail)
            email = response.email ?? cleanEmail
            matchedUsername = response.username
            serverIssuedOtpHint = response.otp
            otpCode = ""
            infoMessage = isResend
                ? "Đã cấp lại mã OTP 6 chữ số mới cho \(email)."
                : "Đã tạo mã xác thực OTP cho tài khoản \(response.username ?? email)."
            transition(to: .verifyOtp)
            focusedField = .otp
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitOtpVerification() async {
        focusedField = nil
        errorMessage = nil
        infoMessage = nil

        let cleanOtp = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanOtp.count == 6 else {
            errorMessage = "Vui lòng nhập đủ 6 chữ số của mã OTP."
            focusedField = .otp
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await apiClient.verifyPasswordResetOtp(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                otp: cleanOtp
            )
            infoMessage = "Xác thực OTP thành công. Hãy nhập mật khẩu mới."
            transition(to: .resetPassword)
            focusedField = .newPassword
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitPasswordReset() async {
        focusedField = nil
        errorMessage = nil
        infoMessage = nil

        guard newPassword.count >= 6 && newPassword.count <= 72 else {
            errorMessage = "Mật khẩu mới phải từ 6 đến 72 ký tự."
            focusedField = .newPassword
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "Mật khẩu xác nhận không khớp."
            focusedField = .confirmPassword
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await apiClient.resetPasswordWithOtp(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                otp: otpCode.trimmingCharacters(in: .whitespacesAndNewlines),
                newPassword: newPassword
            )
            isResetCompleted = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
