import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let catalog: StoryCatalog
    let consentStore: ConsentStore
    let progressStore: ProgressStore
    let metricsStore: MetricsStore
    let backendURL: URL

    init(
        catalog: StoryCatalog = .sample,
        consentStore: ConsentStore? = nil,
        progressStore: ProgressStore? = nil,
        metricsStore: MetricsStore? = nil,
        backendURL: URL? = nil
    ) {
        self.catalog = catalog
        self.consentStore = consentStore ?? ConsentStore()
        self.progressStore = progressStore ?? ProgressStore()
        self.metricsStore = metricsStore ?? MetricsStore()
        let configuredURL = ProcessInfo.processInfo.environment["AIToyBackendURL"]
        self.backendURL = backendURL
            ?? configuredURL.flatMap(URL.init(string:))
            ?? URL(string: "https://api.mousefit.pro/ai-toy")!
    }

    static let live = AppEnvironment()

    func makeSession(for story: StoryLesson) -> LessonSessionViewModel {
        let backend = BackendClient(baseURL: backendURL)
        return LessonSessionViewModel(
            story: story,
            transcription: OpenAIRealtimeTranscriptionService(backend: backend),
            remoteEvaluator: BackendAnswerEvaluationService(client: backend),
            safetyService: BackendSafetyService(client: backend),
            localEvaluator: LocalAnswerEvaluator(),
            audioPlayer: CueAudioPlayer(),
            progressStore: progressStore,
            metricsStore: metricsStore
        )
    }
}
