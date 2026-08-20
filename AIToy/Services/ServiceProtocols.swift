import Foundation

@MainActor
protocol TranscriptionService: AnyObject {
    var onPartialTranscript: ((String) -> Void)? { get set }
    var onFinalTranscript: ((FinalTranscript) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }

    func startSession(initialContext: TranscriptionContext, anonymousID: String) async throws
    func updateContext(_ context: TranscriptionContext) async throws
    func beginTurn() async throws
    func endTurn() async throws
    func close()
}

protocol AnswerEvaluationService: Sendable {
    func evaluate(_ request: EvaluationRequest) async throws -> RemoteEvaluationResponse
}

protocol SafetyService: Sendable {
    func check(transcript: String, sessionID: String) async throws -> SafetyResult
}

struct SafetyResult: Codable, Sendable {
    let safe: Bool
    let categories: [String]
}

struct RemoteEvaluationResponse: Codable, Sendable {
    let result: EvaluationResult
    let inputTokens: Int
    let outputTokens: Int
}

@MainActor
protocol StoryAudioPlaying: AnyObject {
    var onPlaybackProgress: ((Double) -> Void)? { get set }

    func play(text: String, cueID: String) async
    func stop()
}

extension StoryAudioPlaying {
    var onPlaybackProgress: ((Double) -> Void)? {
        get { nil }
        set {}
    }
}

@MainActor
final class ConsentStore: ObservableObject {
    private let defaults: UserDefaults
    private let key = "guardianConsentAccepted.v1"

    @Published private(set) var hasGuardianConsent: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasGuardianConsent = defaults.bool(forKey: key)
    }

    func accept() {
        defaults.set(true, forKey: key)
        hasGuardianConsent = true
    }

    func revoke() {
        defaults.removeObject(forKey: key)
        hasGuardianConsent = false
    }
}

@MainActor
final class ProgressStore {
    private let defaults: UserDefaults
    private let keyPrefix = "storyProgress.v1."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func progress(for storyID: String) -> StoryProgress {
        guard let data = defaults.data(forKey: keyPrefix + storyID),
              let value = try? JSONDecoder().decode(StoryProgress.self, from: data) else {
            return StoryProgress(storyID: storyID, completedCheckpointIDs: [], lastUpdated: .distantPast)
        }
        return value
    }

    func markCompleted(storyID: String, checkpointID: String) {
        var value = progress(for: storyID)
        value.completedCheckpointIDs.insert(checkpointID)
        value.lastUpdated = Date()
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: keyPrefix + storyID)
        }
    }

    func reset(storyID: String) {
        defaults.removeObject(forKey: keyPrefix + storyID)
    }
}

@MainActor
final class MetricsStore {
    private let defaults: UserDefaults
    private let keyPrefix = "sessionMetrics.v1."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ metrics: SessionMetrics) {
        guard let data = try? JSONEncoder().encode(metrics) else { return }
        defaults.set(data, forKey: keyPrefix + metrics.storyID)
    }

    func latest(for storyID: String) -> SessionMetrics? {
        guard let data = defaults.data(forKey: keyPrefix + storyID) else { return nil }
        return try? JSONDecoder().decode(SessionMetrics.self, from: data)
    }
}
