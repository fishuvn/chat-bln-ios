import Foundation

enum StompRealtimeEvent: Sendable {
    case connected
    case disconnected
    case message(MessageDto)
    case presence(PresenceEvent)
}

struct StompFrame: Sendable {
    let command: String
    let headers: [String: String]
    let body: String

    func serialize() -> String {
        var lines: [String] = [command]
        for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
            lines.append("\(key):\(value)")
        }
        let headerSection = lines.joined(separator: "\n")
        return "\(headerSection)\n\n\(body)\u{0000}"
    }

    static func parseFrames(from rawChunk: String) -> (frames: [StompFrame], remainder: String) {
        let normalized = rawChunk.replacingOccurrences(of: "\r\n", with: "\n")
        let parts = normalized.components(separatedBy: "\u{0000}")
        guard parts.count > 1 else {
            let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return ([], "")
            }
            return ([], normalized)
        }

        var parsed: [StompFrame] = []
        for index in 0..<(parts.count - 1) {
            let rawFrame = parts[index].trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
            if rawFrame.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }

            let sections = rawFrame.components(separatedBy: "\n\n")
            let headerLines = (sections.first ?? "").components(separatedBy: "\n")
            guard let command = headerLines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !command.isEmpty else {
                continue
            }

            var headers: [String: String] = [:]
            for line in headerLines.dropFirst() {
                guard let colonIndex = line.firstIndex(of: ":") else { continue }
                let key = String(line[..<colonIndex])
                let val = String(line[line.index(after: colonIndex)...])
                if headers[key] == nil {
                    headers[key] = val
                }
            }

            let body = sections.dropFirst().joined(separator: "\n\n")
            parsed.append(StompFrame(command: command, headers: headers, body: body))
        }

        let trailing = parts.last ?? ""
        let cleanRemainder = trailing.trimmingCharacters(in: CharacterSet(charactersIn: "\n")).isEmpty ? "" : trailing
        return (parsed, cleanRemainder)
    }
}

@MainActor
final class StompWebSocketClient {
    private let settings: AppSettings
    private let session: URLSession
    private let decoder = JSONDecoder()

    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    private var desiredTopics: Set<String> = []
    private var activeSubscriptionIds: [String: String] = [:]
    private var subscriptionCounter: Int = 0
    private var frameRemainder: String = ""
    private var shouldReconnect: Bool = false
    private var currentToken: String?

    private(set) var isConnected: Bool = false {
        didSet {
            if oldValue != isConnected {
                onConnectionStateChanged?(isConnected)
                eventContinuation?.yield(isConnected ? .connected : .disconnected)
            }
        }
    }

    var onMessageReceived: ((MessageDto) -> Void)?
    var onPresenceReceived: ((PresenceEvent) -> Void)?
    var onConnectionStateChanged: ((Bool) -> Void)?

    private var eventContinuation: AsyncStream<StompRealtimeEvent>.Continuation?

    init(settings: AppSettings) {
        self.settings = settings
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    func makeEventStream() -> AsyncStream<StompRealtimeEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }

    func connect(token: String) {
        currentToken = token
        shouldReconnect = true
        reconnectTask?.cancel()
        reconnectTask = nil

        if isConnected, webSocketTask != nil {
            syncSubscriptionsIfConnected()
            return
        }

        openSocket(token: token)
    }

    func subscribe(topic: String) {
        desiredTopics.insert(topic)
        guard isConnected else { return }
        sendSubscribeFrameIfNeeded(for: topic)
    }

    func unsubscribe(topic: String) {
        desiredTopics.remove(topic)
        guard let subId = activeSubscriptionIds.removeValue(forKey: topic), isConnected else {
            return
        }
        let frame = StompFrame(
            command: "UNSUBSCRIBE",
            headers: ["id": subId],
            body: ""
        )
        sendRawString(frame.serialize())
    }

    func disconnect() {
        shouldReconnect = false
        currentToken = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        receiveTask?.cancel()
        receiveTask = nil

        if isConnected, let task = webSocketTask {
            let disconnectFrame = StompFrame(
                command: "DISCONNECT",
                headers: ["receipt": "disconnect-client"],
                body: ""
            )
            let payload = disconnectFrame.serialize()
            task.send(.string(payload)) { _ in
                task.cancel(with: .normalClosure, reason: nil)
            }
        } else {
            webSocketTask?.cancel(with: .goingAway, reason: nil)
        }

        webSocketTask = nil
        activeSubscriptionIds.removeAll()
        desiredTopics.removeAll()
        frameRemainder = ""
        isConnected = false
    }

    // MARK: - Private Socket Lifecycle

    private func openSocket(token: String) {
        heartbeatTask?.cancel()
        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        activeSubscriptionIds.removeAll()
        frameRemainder = ""
        isConnected = false

        guard let wsURL = settings.webSocketURL else {
            scheduleReconnectIfNeeded()
            return
        }

        var request = URLRequest(url: wsURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let task = session.webSocketTask(with: request)
        self.webSocketTask = task
        task.resume()

        startReceiveLoop(for: task)
        sendConnectFrame(token: token, over: task)
    }

    private func sendConnectFrame(token: String, over task: URLSessionWebSocketTask) {
        let hostHeader = settings.webSocketURL?.host ?? "localhost"
        let connectFrame = StompFrame(
            command: "CONNECT",
            headers: [
                "accept-version": "1.1,1.2",
                "heart-beat": "10000,10000",
                "host": hostHeader,
                "Authorization": "Bearer \(token)"
            ],
            body: ""
        )

        task.send(.string(connectFrame.serialize())) { [weak self] error in
            guard let self else { return }
            if error != nil {
                Task { @MainActor in
                    self.handleSocketDrop()
                }
            }
        }
    }

    private func startReceiveLoop(for task: URLSessionWebSocketTask) {
        receiveTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    if Task.isCancelled { break }
                    switch message {
                    case .string(let text):
                        self.processIncomingText(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.processIncomingText(text)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    if !Task.isCancelled {
                        self.handleSocketDrop()
                    }
                    break
                }
            }
        }
    }

    private func processIncomingText(_ text: String) {
        let combined = frameRemainder + text
        let result = StompFrame.parseFrames(from: combined)
        frameRemainder = result.remainder

        for frame in result.frames {
            handleFrame(frame)
        }
    }

    private func handleFrame(_ frame: StompFrame) {
        switch frame.command {
        case "CONNECTED":
            isConnected = true
            syncSubscriptionsIfConnected()
            startHeartbeatLoop()

        case "MESSAGE":
            let destination = frame.headers["destination"] ?? ""
            guard let bodyData = frame.body.data(using: .utf8), !bodyData.isEmpty else { return }

            if destination == "/topic/presence" {
                if let event = try? decoder.decode(PresenceEvent.self, from: bodyData) {
                    onPresenceReceived?(event)
                    eventContinuation?.yield(.presence(event))
                }
            } else if destination.hasPrefix("/topic/users/") || destination.hasPrefix("/topic/conversations/") {
                if let dto = try? decoder.decode(MessageDto.self, from: bodyData) {
                    onMessageReceived?(dto)
                    eventContinuation?.yield(.message(dto))
                }
            }

        case "ERROR":
            handleSocketDrop()

        default:
            break
        }
    }

    private func syncSubscriptionsIfConnected() {
        guard isConnected else { return }
        for topic in desiredTopics {
            sendSubscribeFrameIfNeeded(for: topic)
        }
    }

    private func sendSubscribeFrameIfNeeded(for topic: String) {
        guard activeSubscriptionIds[topic] == nil else { return }
        subscriptionCounter += 1
        let subId = "sub-\(subscriptionCounter)"
        activeSubscriptionIds[topic] = subId

        let frame = StompFrame(
            command: "SUBSCRIBE",
            headers: [
                "id": subId,
                "destination": topic,
                "ack": "auto"
            ],
            body: ""
        )
        sendRawString(frame.serialize())
    }

    private func startHeartbeatLoop() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard let self, !Task.isCancelled, self.isConnected, let task = self.webSocketTask else {
                    break
                }
                task.send(.string("\n")) { [weak self] error in
                    if error != nil {
                        Task { @MainActor in
                            self?.handleSocketDrop()
                        }
                    }
                }
                task.sendPing { [weak self] error in
                    if error != nil {
                        Task { @MainActor in
                            self?.handleSocketDrop()
                        }
                    }
                }
            }
        }
    }

    private func sendRawString(_ raw: String) {
        webSocketTask?.send(.string(raw)) { [weak self] error in
            if error != nil {
                Task { @MainActor in
                    self?.handleSocketDrop()
                }
            }
        }
    }

    private func handleSocketDrop() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        activeSubscriptionIds.removeAll()
        frameRemainder = ""
        isConnected = false
        scheduleReconnectIfNeeded()
    }

    private func scheduleReconnectIfNeeded() {
        guard shouldReconnect, let token = currentToken else { return }
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, !Task.isCancelled, self.shouldReconnect, !self.isConnected else { return }
            self.openSocket(token: token)
        }
    }
}
