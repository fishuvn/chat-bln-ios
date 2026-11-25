import SwiftUI

struct ServerConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: AppSettings
    let apiClient: APIClient
    var onSaved: (() -> Void)?

    @State private var urlInput: String = ""
    @State private var isTestingConnection: Bool = false
    @State private var healthResultMessage: String?
    @State private var healthResultSuccess: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://127.0.0.1:8088", text: $urlInput)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())

                    Button {
                        urlInput = AppSettings.defaultBaseURL
                    } label: {
                        Label("Đặt lại mặc định Simulator (127.0.0.1:8088)", systemImage: "arrow.counterclockwise")
                    }
                } header: {
                    Text("Địa chỉ Backend Spring Boot")
                } footer: {
                    Text("Trên iOS Simulator dùng http://127.0.0.1:8088. Trên iPhone thật cùng Wi-Fi, nhập IP LAN của máy tính (ví dụ http://192.168.1.10:8088).")
                }

                Section("Kiểm tra trạng thái máy chủ") {
                    Button {
                        Task {
                            await testConnection()
                        }
                    } label: {
                        HStack {
                            Label("Kiểm tra kết nối (/api/health)", systemImage: "bolt.horizontal.circle.fill")
                            Spacer()
                            if isTestingConnection {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isTestingConnection)

                    if let healthResultMessage {
                        Label(
                            healthResultMessage,
                            systemImage: healthResultSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(healthResultSuccess ? Color.green : Color.red)
                    }
                }

                if let wsPreview = previewWebSocketURL {
                    Section("Kênh STOMP 1.2 Realtime tương ứng") {
                        Text(wsPreview)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Máy chủ Backend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        settings.updateBaseURL(urlInput)
                        onSaved?()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                urlInput = settings.baseURLString
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var previewWebSocketURL: String? {
        let normalized = AppSettings.normalizeBaseURL(urlInput)
        guard var components = URLComponents(string: normalized) else { return nil }
        components.scheme = (components.scheme?.lowercased() == "https") ? "wss" : "ws"
        components.path = "/ws-native"
        return components.url?.absoluteString
    }

    private func testConnection() async {
        isTestingConnection = true
        healthResultMessage = nil
        let previousURL = settings.baseURLString
        settings.updateBaseURL(urlInput)
        urlInput = settings.baseURLString

        do {
            let health = try await apiClient.checkHealth()
            healthResultSuccess = true
            healthResultMessage = "Kết nối thành công: \(health.status) — \(health.message ?? "Máy chủ sẵn sàng")"
        } catch {
            settings.updateBaseURL(previousURL)
            healthResultSuccess = false
            healthResultMessage = error.localizedDescription
        }
        isTestingConnection = false
    }
}
