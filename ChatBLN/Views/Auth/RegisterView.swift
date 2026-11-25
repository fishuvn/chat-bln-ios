import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var authViewModel: AuthViewModel

    @State private var username: String = ""
    @State private var fullName: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var gender: String = "Nam"
    @State private var includeDob: Bool = false
    @State private var dobDate: Date = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @State private var bio: String = ""
    @State private var localValidationError: String?

    private let genderOptions = ["Nam", "Nữ", "Khác"]

    var body: some View {
        Form {
            if let banner = localValidationError ?? authViewModel.errorMessage {
                Section {
                    Label(banner, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("Thông tin bắt buộc") {
                TextField("Tên đăng nhập (3–50 ký tự)", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Họ và tên hiển thị", text: $fullName)
                    .textContentType(.name)

                SecureField("Mật khẩu (tối thiểu 6 ký tự)", text: $password)
                    .textContentType(.newPassword)

                SecureField("Nhập lại mật khẩu", text: $confirmPassword)
                    .textContentType(.newPassword)
            }

            Section("Thông tin hồ sơ (tuỳ chọn)") {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Số điện thoại", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)

                Picker("Giới tính", selection: $gender) {
                    ForEach(genderOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }

                Toggle("Cập nhật ngày sinh", isOn: $includeDob.animation())
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
            }

            Section {
                Button {
                    submitRegistration()
                } label: {
                    HStack {
                        Spacer()
                        if authViewModel.isSubmitting {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text(authViewModel.isSubmitting ? "Đang tạo tài khoản..." : "Đăng ký & Đăng nhập")
                            .font(.headline)
                        Spacer()
                    }
                    .frame(minHeight: 36)
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
            return
        }
        guard !cleanFullName.isEmpty else {
            localValidationError = "Vui lòng nhập họ và tên hiển thị."
            return
        }
        guard password.count >= 6 else {
            localValidationError = "Mật khẩu phải có ít nhất 6 ký tự."
            return
        }
        guard password == confirmPassword else {
            localValidationError = "Mật khẩu nhập lại không khớp."
            return
        }

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
