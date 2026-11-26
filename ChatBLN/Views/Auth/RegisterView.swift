import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var authViewModel: AuthViewModel

    @State private var username: String = ""
    @State private var fullName: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPasswords: Bool = false
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var gender: String = "Nam"
    @State private var includeDob: Bool = false
    @State private var dobDate: Date = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @State private var bio: String = ""
    @State private var localValidationError: String?

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case username
        case fullName
        case password
        case confirmPassword
        case email
        case phone
        case bio
    }

    private let genderOptions = ["Nam", "Nữ", "Khác"]

    var body: some View {
        Form {
            if let banner = localValidationError ?? authViewModel.errorMessage {
                Section {
                    Label(banner, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Color(.systemRed))
                }
            }

            Section {
                TextField("Tên đăng nhập (3–50 ký tự)", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .fullName }

                TextField("Họ và tên hiển thị", text: $fullName)
                    .textContentType(.name)
                    .focused($focusedField, equals: .fullName)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                HStack(spacing: 8) {
                    Group {
                        if showPasswords {
                            TextField("Mật khẩu (tối thiểu 6 ký tự)", text: $password)
                        } else {
                            SecureField("Mật khẩu (tối thiểu 6 ký tự)", text: $password)
                        }
                    }
                    .textContentType(.newPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .password)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .confirmPassword }

                    Button {
                        showPasswords.toggle()
                    } label: {
                        Image(systemName: showPasswords ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showPasswords ? "Ẩn mật khẩu" : "Hiện mật khẩu")
                }

                Group {
                    if showPasswords {
                        TextField("Nhập lại mật khẩu", text: $confirmPassword)
                    } else {
                        SecureField("Nhập lại mật khẩu", text: $confirmPassword)
                    }
                }
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .confirmPassword)
                .submitLabel(.next)
                .onSubmit { focusedField = .email }
            } header: {
                Text("Thông tin tài khoản bắt buộc")
            } footer: {
                Text("Nên cung cấp thêm Email ở mục bên dưới để có thể khôi phục mật khẩu bằng mã OTP khi cần.")
            }

            Section("Thông tin hồ sơ (tuỳ chọn)") {
                TextField("Email (dùng để nhận OTP quên mật khẩu)", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .phone }

                TextField("Số điện thoại", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .focused($focusedField, equals: .phone)

                Picker("Giới tính", selection: $gender) {
                    ForEach(genderOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }

                Toggle(
                    "Cập nhật ngày sinh",
                    isOn: reduceMotion ? $includeDob : $includeDob.animation(.snappy(duration: 0.2))
                )
                if includeDob {
                    DatePicker(
                        "Ngày sinh",
                        selection: $dobDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "vi_VN"))
                }

                TextField("Tiểu sử ngắn (tối đa 300 ký tự)", text: $bio, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focusedField, equals: .bio)
            }

            Section {
                Button {
                    submitRegistration()
                } label: {
                    HStack(spacing: 8) {
                        Spacer()
                        if authViewModel.isSubmitting {
                            ProgressView()
                        }
                        Text(authViewModel.isSubmitting ? "Đang tạo tài khoản..." : "Đăng ký & Đăng nhập")
                            .font(.headline)
                        Spacer()
                    }
                    .frame(minHeight: 44)
                }
                .disabled(authViewModel.isSubmitting)
            }
        }
        .navigationTitle("Tạo tài khoản")
        .navigationBarTitleDisplayMode(.large)
    }

    private func submitRegistration() {
        localValidationError = nil
        authViewModel.errorMessage = nil

        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanFullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanUsername.count >= 3 else {
            localValidationError = "Tên đăng nhập phải có ít nhất 3 ký tự."
            focusedField = .username
            return
        }
        guard !cleanFullName.isEmpty else {
            localValidationError = "Vui lòng nhập họ và tên hiển thị."
            focusedField = .fullName
            return
        }
        guard password.count >= 6 else {
            localValidationError = "Mật khẩu phải có ít nhất 6 ký tự."
            focusedField = .password
            return
        }
        guard password == confirmPassword else {
            localValidationError = "Mật khẩu nhập lại không khớp."
            focusedField = .confirmPassword
            return
        }

        focusedField = nil

        let dobString: String?
        if includeDob {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            dobString = formatter.string(from: dobDate)
        } else {
            dobString = nil
        }

        let request = RegisterRequest(
            username: cleanUsername,
            password: password,
            fullName: cleanFullName,
            email: email.trimmedNilIfEmpty,
            phone: phone.trimmedNilIfEmpty,
            gender: gender,
            dob: dobString,
            bio: bio.trimmedNilIfEmpty
        )

        Task {
            let ok = await authViewModel.register(request)
            if ok {
                dismiss()
            }
        }
    }
}

extension String {
    var trimmedNilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
