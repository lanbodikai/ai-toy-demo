import AVFoundation
import Foundation

enum TranscriptionError: LocalizedError {
    case microphoneDenied
    case audioInputUnavailable
    case sessionNotReady
    case connectionTimedOut
    case connectionFailed(String)
    case invalidEvent
    case mockMode
    case server(String)

    var errorDescription: String? {
        switch self {
        case .microphoneDenied: "Microphone access is required for story answers."
        case .audioInputUnavailable:
#if targetEnvironment(simulator)
            "这台 Mac 没有可用的音频输入。请允许模拟器使用 Mac 麦克风，或连接 USB／蓝牙麦克风后重试。"
#else
            "没有检测到可用的麦克风。请检查系统麦克风权限后重试。"
#endif
        case .sessionNotReady: "语音连接尚未准备好，请点按重新连接后再试。"
        case .connectionTimedOut: "实时语音连接超时，请检查网络后重试。"
        case let .connectionFailed(message): "实时语音连接失败：\(message)"
        case .invalidEvent: "The speech service returned an invalid event."
        case .mockMode: "后端正在使用 MOCK_OPENAI 模式；模拟凭证不能连接实时语音。请用真实 OPENAI_API_KEY 启动后端。"
        case let .server(message): message
        }
    }
}

@MainActor
final class OpenAIRealtimeTranscriptionService: TranscriptionService {
    private enum ConfigurationState {
        case idle
        case waiting
        case ready
        case failed(String)
    }

    var onPartialTranscript: ((String) -> Void)?
    var onFinalTranscript: ((FinalTranscript) -> Void)?
    var onError: ((Error) -> Void)?

    private let backend: BackendClient
    private let audioCapture = PCM24kAudioCapture()
    private var webSocketSession: URLSession?
    private var webSocketDelegate: RealtimeWebSocketDelegate?
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var sendChain: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var currentContext: TranscriptionContext?
    private var turnStartedAt: Date?
    private var commitStartedAt: Date?
    private var currentAudioDuration: TimeInterval = 0
    private var partialTranscript = ""
    private var configurationState: ConfigurationState = .idle

    init(backend: BackendClient) {
        self.backend = backend
    }

    func startSession(initialContext: TranscriptionContext, anonymousID: String) async throws {
        close()
        let token = try await backend.createTranscriptionSession(
            anonymousID: anonymousID,
            context: initialContext
        )
        guard token.transport != "mock", !token.clientSecret.hasPrefix("ek_mock") else {
            throw TranscriptionError.mockMode
        }
        var request = URLRequest(url: URL(string: "wss://api.openai.com/v1/realtime")!)
        request.setValue("Bearer \(token.clientSecret)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 12

        let delegate = RealtimeWebSocketDelegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.webSocketTask(with: request)
        webSocketDelegate = delegate
        webSocketSession = session
        socket = task
        currentContext = initialContext
        task.resume()

        do {
            try await delegate.waitUntilOpen(timeout: 10)
        } catch {
            close()
            throw error
        }

        configurationState = .waiting
        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
        do {
            try await waitForConfiguration(timeout: 8)
        } catch {
            close()
            throw error
        }
    }

    func updateContext(_ context: TranscriptionContext) async throws {
        guard socket != nil, webSocketDelegate?.isOpen == true else {
            throw TranscriptionError.sessionNotReady
        }
        // The credential already contains a bounded story-wide recognition context.
        // Re-sending the transcription model in session.update can be rejected by
        // Realtime even though the created transcription session is valid.
        currentContext = context
    }

    func beginTurn() async throws {
        guard socket != nil, webSocketDelegate?.isOpen == true else {
            throw TranscriptionError.sessionNotReady
        }
        let granted = await requestMicrophonePermission()
        guard granted else { throw TranscriptionError.microphoneDenied }

        timeoutTask?.cancel()
        partialTranscript = ""
        currentAudioDuration = 0
        turnStartedAt = Date()
        commitStartedAt = nil
        try await send(["type": "input_audio_buffer.clear"])

        try audioCapture.start { [weak self] data in
            DispatchQueue.main.async {
                self?.enqueueAudio(data)
            }
        }
    }

    func endTurn() async throws {
        currentAudioDuration = audioCapture.stop()
        await sendChain?.value
        commitStartedAt = Date()
        try await send(["type": "input_audio_buffer.commit"])

        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(7))
            guard !Task.isCancelled else { return }
            self?.finishTranscript("")
        }
    }

    func close() {
        _ = audioCapture.stop()
        timeoutTask?.cancel()
        receiveTask?.cancel()
        sendChain?.cancel()
        socket?.cancel(with: .normalClosure, reason: nil)
        webSocketSession?.invalidateAndCancel()
        socket = nil
        webSocketSession = nil
        webSocketDelegate = nil
        receiveTask = nil
        sendChain = nil
        configurationState = .idle
    }

    private func enqueueAudio(_ data: Data) {
        guard !data.isEmpty else { return }
        let previous = sendChain
        let socket = socket
        sendChain = Task {
            await previous?.value
            guard !Task.isCancelled, let socket else { return }
            let event: [String: Any] = [
                "type": "input_audio_buffer.append",
                "audio": data.base64EncodedString()
            ]
            guard let encoded = try? JSONSerialization.data(withJSONObject: event),
                  let text = String(data: encoded, encoding: .utf8) else { return }
            try? await socket.send(.string(text))
        }
    }

    private func send(_ event: [String: Any]) async throws {
        guard let socket else { throw TranscriptionError.sessionNotReady }
        let data = try JSONSerialization.data(withJSONObject: event)
        guard let text = String(data: data, encoding: .utf8) else {
            throw TranscriptionError.invalidEvent
        }
        try await socket.send(.string(text))
    }

    private func receiveLoop() async {
        while !Task.isCancelled, let socket {
            do {
                let message = try await socket.receive()
                let data: Data
                switch message {
                case let .string(text): data = Data(text.utf8)
                case let .data(value): data = value
                @unknown default: continue
                }
                handleEvent(data)
            } catch {
                if !Task.isCancelled {
                    self.socket = nil
                    failConfigurationOrNotify(error.localizedDescription)
                }
                return
            }
        }
    }

    private func handleEvent(_ data: Data) {
        guard let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = event["type"] as? String else { return }
        switch type {
        case "session.created", "transcription_session.created":
            configurationState = .ready
        case "session.updated", "transcription_session.updated":
            configurationState = .ready
        case "conversation.item.input_audio_transcription.delta":
            let delta = event["delta"] as? String ?? ""
            partialTranscript += delta
            onPartialTranscript?(partialTranscript)
        case "conversation.item.input_audio_transcription.completed":
            finishTranscript(event["transcript"] as? String ?? partialTranscript)
        case "error":
            let detail = event["error"] as? [String: Any]
            let code = detail?["code"] as? String
            let message: String
            if code == "model_not_found" {
                message = "当前 OpenAI 项目没有实时转写模型权限。请在 OpenAI 项目中启用模型或账单后重试。"
            } else {
                message = detail?["message"] as? String ?? "Speech service error"
            }
            failConfigurationOrNotify(message)
        default:
            break
        }
    }

    private func waitForConfiguration(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try Task.checkCancellation()
            switch configurationState {
            case .idle, .waiting:
                try await Task.sleep(for: .milliseconds(40))
            case .ready:
                return
            case let .failed(message):
                throw TranscriptionError.server(message)
            }
        }
        throw TranscriptionError.connectionTimedOut
    }

    private func failConfigurationOrNotify(_ message: String) {
        if case .waiting = configurationState {
            configurationState = .failed(message)
        } else {
            onError?(TranscriptionError.server(message))
        }
    }

    private func finishTranscript(_ text: String) {
        timeoutTask?.cancel()
        timeoutTask = nil
        let latency = commitStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        onFinalTranscript?(FinalTranscript(text: text, audioDuration: currentAudioDuration, latency: latency))
        partialTranscript = ""
        turnStartedAt = nil
        commitStartedAt = nil
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }
}

private final class RealtimeWebSocketDelegate: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private enum ConnectionState {
        case connecting
        case open
        case failed(String)
    }

    private let stateLock = NSLock()
    private var state: ConnectionState = .connecting

    var isOpen: Bool {
        if case .open = currentState() { return true }
        return false
    }

    func waitUntilOpen(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try Task.checkCancellation()
            switch currentState() {
            case .connecting:
                try await Task.sleep(for: .milliseconds(40))
            case .open:
                return
            case let .failed(message):
                throw TranscriptionError.connectionFailed(message)
            }
        }
        throw TranscriptionError.connectionTimedOut
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        setState(.open)
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let detail = reason.flatMap { String(data: $0, encoding: .utf8) }
            ?? "连接已关闭（\(closeCode.rawValue)）"
        setState(.failed(detail))
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        setState(.failed(error.localizedDescription))
    }

    private func currentState() -> ConnectionState {
        stateLock.lock()
        defer { stateLock.unlock() }
        return state
    }

    private func setState(_ newState: ConnectionState) {
        stateLock.lock()
        state = newState
        stateLock.unlock()
    }
}

private final class PCM24kAudioCapture {
    private let engine = AVAudioEngine()
    private var outputFrames: AVAudioFramePosition = 0
    private let stateLock = NSLock()
    private var running = false

    func start(onPCM: @escaping @Sendable (Data) -> Void) throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !running else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw TranscriptionError.audioInputUnavailable
        }
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 24_000,
            channels: 1,
            interleaved: false
        ), let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw TranscriptionError.audioInputUnavailable
        }

        outputFrames = 0
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1_024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let ratio = outputFormat.sampleRate / inputFormat.sampleRate
            let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 32
            guard let converted = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }
            var supplied = false
            var conversionError: NSError?
            let status = converter.convert(to: converted, error: &conversionError) { _, inputStatus in
                if supplied {
                    inputStatus.pointee = .noDataNow
                    return nil
                }
                supplied = true
                inputStatus.pointee = .haveData
                return buffer
            }
            guard status != .error,
                  converted.frameLength > 0,
                  let channel = converted.int16ChannelData?[0] else { return }
            self.stateLock.lock()
            self.outputFrames += AVAudioFramePosition(converted.frameLength)
            self.stateLock.unlock()
            onPCM(Data(bytes: channel, count: Int(converted.frameLength) * MemoryLayout<Int16>.size))
        }

        engine.prepare()
        try engine.start()
        running = true
    }

    @discardableResult
    func stop() -> TimeInterval {
        stateLock.lock()
        let wasRunning = running
        running = false
        let frames = outputFrames
        stateLock.unlock()
        if wasRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        return Double(frames) / 24_000
    }
}
