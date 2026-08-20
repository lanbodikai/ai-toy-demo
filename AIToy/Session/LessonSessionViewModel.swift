import Combine
import Foundation

enum TutorCommand: Equatable {
    case repeatQuestion
    case replaySection
    case englishHint
}

struct TutorCommandParser {
    static func parse(_ transcript: String) -> TutorCommand? {
        let text = transcript
            .lowercased()
            .replacingOccurrences(of: "[\\s，。！？、,.!?]", with: "", options: .regularExpression)

        let asksForEnglish = text.contains("英文") || text.contains("英语") || text.contains("english")
        if asksForEnglish && (text.contains("提示") || text.contains("hint") || text.contains("帮帮")) {
            return .englishHint
        }

        let asksToRepeat = ["重复", "再说一遍", "再讲一遍", "重新讲", "重讲", "再来一次"].contains {
            text.contains($0)
        }
        if asksToRepeat && text.contains("问题") {
            return .repeatQuestion
        }
        if asksToRepeat && (text.contains("故事") || text.contains("这一段") || text.contains("这段")) {
            return .replaySection
        }
        return nil
    }
}

@MainActor
final class LessonSessionViewModel: ObservableObject {
    enum Phase: Equatable {
        case preparing
        case welcome
        case readyToStart
        case narrating
        case asking
        case waitingForAnswer
        case listening
        case evaluating
        case givingFeedback
        case audioProblem
        case serviceUnavailable
        case completed
    }

    enum WarmupStep: Equatable {
        case greeting
        case mood
        case ready
        case finished
    }

    enum Mood: String, CaseIterable, Identifiable {
        case happy
        case calm
        case sleepy

        var id: String { rawValue }

        var label: String {
            switch self {
            case .happy: "😄 很开心"
            case .calm: "🙂 还不错"
            case .sleepy: "😴 有点困"
            }
        }
    }

    let story: StoryLesson
    let anonymousSessionID: String
    let isReturningLearner: Bool

    @Published private(set) var phase: Phase = .preparing
    @Published private(set) var sceneIndex: Int = 0
    @Published private(set) var attemptCount: Int = 0
    @Published private(set) var hintLevel: Int = 0
    @Published private(set) var meaningUnderstood = false
    @Published private(set) var completedCheckpointIDs: Set<String>
    @Published private(set) var transcriptPreview = ""
    @Published private(set) var feedback = "故事准备中……"
    @Published private(set) var metrics: SessionMetrics
    @Published private(set) var serviceError: String?
    @Published private(set) var warmupStep: WarmupStep = .greeting
    @Published private(set) var voiceConnected = false
    @Published private(set) var practiceVocabulary: [VocabularyItem] = []
    @Published private(set) var englishSubtitleText = ""

    private var transcription: any TranscriptionService
    private let remoteEvaluator: any AnswerEvaluationService
    private let safetyService: any SafetyService
    private let localEvaluator: LocalAnswerEvaluator
    private let audioPlayer: any StoryAudioPlaying
    private let progressStore: ProgressStore
    private let metricsStore: MetricsStore
    private var hasStarted = false
    private var unusableTranscriptions = 0
    private var awaitingFinalTranscript = false
    private var practiceVocabularyIDs: Set<String> = []
    private var englishSubtitleSegments: [String] = []

    var currentBeat: StoryBeat { story.beats[sceneIndex] }
    var currentCheckpoint: StoryCheckpoint { currentBeat.checkpoint }
    var progressFraction: Double {
        Double(completedCheckpointIDs.count) / Double(max(story.beats.count, 1))
    }
    var isListening: Bool { phase == .listening }
    var canTalk: Bool { phase == .waitingForAnswer || phase == .asking }
    var readyPrompt: String {
        isReturningLearner
            ? "欢迎回来！准备好再听《\(story.title)》了吗？"
            : "准备好听第一段了吗？"
    }
    var readyButtonTitle: String {
        isReturningLearner ? "准备好了，再听一次" : "我准备好了，开始故事"
    }

    init(
        story: StoryLesson,
        transcription: any TranscriptionService,
        remoteEvaluator: any AnswerEvaluationService,
        safetyService: any SafetyService,
        localEvaluator: LocalAnswerEvaluator,
        audioPlayer: any StoryAudioPlaying,
        progressStore: ProgressStore,
        metricsStore: MetricsStore
    ) {
        self.story = story
        self.transcription = transcription
        self.remoteEvaluator = remoteEvaluator
        self.safetyService = safetyService
        self.localEvaluator = localEvaluator
        self.audioPlayer = audioPlayer
        self.progressStore = progressStore
        self.metricsStore = metricsStore
        anonymousSessionID = Self.makeAnonymousSessionID()
        let progress = progressStore.progress(for: story.id)
        isReturningLearner = progress.isComplete
        completedCheckpointIDs = progress.isComplete ? [] : progress.completedCheckpointIDs
        metrics = SessionMetrics(storyID: story.id)
        if let firstIncomplete = story.beats.firstIndex(where: { !progress.completedCheckpointIDs.contains($0.checkpoint.id) }) {
            sceneIndex = firstIncomplete
        }
        bindTranscriptionCallbacks()
        bindAudioCallbacks()
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        phase = .preparing
        feedback = "正在连接语音老师……"
        do {
            try await transcription.startSession(
                initialContext: storyTranscriptionContext(),
                anonymousID: anonymousSessionID
            )
            serviceError = nil
            voiceConnected = true
        } catch {
            voiceConnected = false
            serviceError = error.localizedDescription
        }
        await beginWarmup()
    }

    func stop() {
        awaitingFinalTranscript = false
        englishSubtitleText = ""
        audioPlayer.stop()
        transcription.close()
        metricsStore.save(metrics)
    }

    func respondToMood(_ mood: Mood) async {
        guard warmupStep == .mood else { return }
        phase = .welcome
        let response: String
        switch mood {
        case .happy:
            response = "太棒啦！你的好心情一定会让今天的故事更有趣。"
        case .calm:
            response = "听起来很舒服。我们一起慢慢走进故事里吧。"
        case .sleepy:
            response = "那我们轻轻地听故事。如果想休息，也可以随时停下来。"
        }
        feedback = response
        await audioPlayer.play(text: response, cueID: "welcome_mood_\(mood.rawValue)")
        warmupStep = .ready
        phase = .readyToStart
        feedback = "今天我们要帮妙妙准备生日惊喜。你准备好听第一段了吗？"
        await audioPlayer.play(text: feedback, cueID: "welcome_ready")
    }

    func confirmStoryStart() async {
        guard warmupStep == .ready else { return }
        warmupStep = .finished
        await playCurrentScene()
    }

    func playCurrentScene() async {
        audioPlayer.stop()
        phase = .narrating
        feedback = "仔细听，故事里藏着答案。"
        prepareEnglishSubtitles()
        await audioPlayer.play(text: currentBeat.narration, cueID: currentBeat.narrationCueID)
        guard phase == .narrating else { return }
        await askQuestion()
    }

    func askQuestion() async {
        phase = .asking
        transcriptPreview = ""
        feedback = "听完问题后，按住话筒回答。"
        if voiceConnected {
            do {
                try await transcription.updateContext(context(for: currentBeat))
            } catch {
                voiceConnected = false
                serviceError = error.localizedDescription
            }
        }
        await audioPlayer.play(text: currentCheckpoint.question, cueID: currentCheckpoint.questionCueID)
        guard phase == .asking else { return }
        if voiceConnected {
            phase = .waitingForAnswer
        } else {
            phase = .serviceUnavailable
            feedback = "问题听完了，但语音还没有连接。重新连接后就可以回答。"
        }
    }

    func beginListening() async {
        guard canTalk else { return }
        audioPlayer.stop()
        transcriptPreview = "正在听……"
        feedback = meaningUnderstood ? "请用中文跟着说。" : "说完后松开按钮。"
        phase = .listening
        do {
            try await transcription.beginTurn()
        } catch {
            if case TranscriptionError.sessionNotReady = error {
                voiceConnected = false
            }
            phase = .audioProblem
            serviceError = error.localizedDescription
            feedback = voiceConnected
                ? "话筒没有准备好，请检查模拟器的音频输入。"
                : "语音连接已断开，请重新连接后再试。"
        }
    }

    func endListening() async {
        guard phase == .listening else { return }
        phase = .evaluating
        feedback = "我在想你说的答案……"
        awaitingFinalTranscript = true
        do {
            try await transcription.endTurn()
        } catch {
            awaitingFinalTranscript = false
            phase = .audioProblem
            serviceError = error.localizedDescription
            feedback = "这次没有听清楚，我们检查一下话筒再试。"
        }
    }

    func recoverFromAudioProblem() async {
        let needsReconnect = !voiceConnected || phase == .serviceUnavailable
        unusableTranscriptions = 0
        serviceError = nil
        phase = .preparing
        feedback = needsReconnect ? "正在重新连接语音老师……" : "正在重新准备话筒……"
        do {
            if needsReconnect {
                try await transcription.startSession(
                    initialContext: storyTranscriptionContext(),
                    anonymousID: anonymousSessionID
                )
            } else {
                try await transcription.updateContext(context(for: currentBeat))
            }
            voiceConnected = true
            phase = .waitingForAnswer
            feedback = "准备好了，请按住话筒再说一次。"
        } catch {
            voiceConnected = false
            phase = .serviceUnavailable
            feedback = "语音服务仍未连接。请确认后端正在运行。"
            serviceError = error.localizedDescription
        }
    }

    func resetStory() async {
        progressStore.reset(storyID: story.id)
        completedCheckpointIDs = []
        sceneIndex = 0
        attemptCount = 0
        hintLevel = 0
        meaningUnderstood = false
        practiceVocabulary = []
        practiceVocabularyIDs = []
        metrics = SessionMetrics(storyID: story.id)
        try? await transcription.updateContext(context(for: currentBeat))
        await playCurrentScene()
    }

    private func bindTranscriptionCallbacks() {
        transcription.onPartialTranscript = { [weak self] text in
            guard let self, self.phase == .listening || self.phase == .evaluating else { return }
            self.transcriptPreview = text
        }
        transcription.onFinalTranscript = { [weak self] final in
            guard let self else { return }
            Task { await self.handleFinalTranscript(final) }
        }
        transcription.onError = { [weak self] error in
            guard let self, self.phase != .completed else { return }
            self.serviceError = error.localizedDescription
            self.voiceConnected = false
            self.phase = .serviceUnavailable
            self.feedback = "语音连接中断了。这不是答错了，请检查网络后再试。"
        }
    }

    private func bindAudioCallbacks() {
        audioPlayer.onPlaybackProgress = { [weak self] progress in
            guard let self, self.phase == .narrating else { return }
            self.updateEnglishSubtitle(for: progress)
        }
    }

    private func prepareEnglishSubtitles() {
        englishSubtitleSegments = NarrationSubtitleSegmenter.segments(from: currentBeat.englishNarration)
        englishSubtitleText = englishSubtitleSegments.first ?? ""
    }

    private func updateEnglishSubtitle(for progress: Double) {
        guard !englishSubtitleSegments.isEmpty else {
            englishSubtitleText = ""
            return
        }

        let weights = englishSubtitleSegments.map { max($0.count, 1) }
        let total = weights.reduce(0, +)
        let target = min(max(progress, 0), 1) * Double(total)
        var cumulative = 0
        for (index, weight) in weights.enumerated() {
            cumulative += weight
            if target < Double(cumulative) || index == weights.indices.last {
                englishSubtitleText = englishSubtitleSegments[index]
                return
            }
        }
    }

    private func handleFinalTranscript(_ final: FinalTranscript) async {
        guard awaitingFinalTranscript, phase == .evaluating || phase == .listening else { return }
        let handlingStartedAt = Date()
        awaitingFinalTranscript = false
        transcriptPreview = final.text.trimmingCharacters(in: .whitespacesAndNewlines)
        metrics.submittedAudioSeconds += final.audioDuration

        if let command = TutorCommandParser.parse(final.text) {
            markFeedbackReady(final, handlingStartedAt: handlingStartedAt)
            await handleTutorCommand(command)
            saveMetrics()
            return
        }

        flagHomophoneMatches(in: final.text)

        let localDecision = localEvaluator.evaluate(transcript: final.text, checkpoint: currentCheckpoint)
        let preliminary: EvaluationResult
        switch localDecision {
        case let .resolved(result), let .needsRemote(result): preliminary = result
        }

        if preliminary.verdict == .unusable {
            markFeedbackReady(final, handlingStartedAt: handlingStartedAt)
            await handleUnusableTranscript()
            saveMetrics()
            return
        }

        metrics.usableAnswers += 1
        metrics.safetyCalls += 1
        do {
            let safety = try await safetyService.check(transcript: final.text, sessionID: anonymousSessionID)
            guard safety.safe else {
                markFeedbackReady(final, handlingStartedAt: handlingStartedAt)
                await apply(EvaluationResult(
                    verdict: .unsafe,
                    language: preliminary.language,
                    matchedConcepts: [],
                    confidence: 1,
                    responseKey: .parentHelp
                ))
                saveMetrics()
                return
            }
        } catch {
            markFeedbackReady(final, handlingStartedAt: handlingStartedAt)
            serviceError = error.localizedDescription
            phase = .waitingForAnswer
            feedback = "安全检查暂时没有连接，请让家长确认网络后再试。"
            saveMetrics()
            return
        }

        switch localDecision {
        case let .resolved(result):
            metrics.localDecisions += 1
            markFeedbackReady(final, handlingStartedAt: handlingStartedAt)
            await apply(result)
        case .needsRemote:
            metrics.evaluatorCalls += 1
            do {
                let response = try await remoteEvaluator.evaluate(EvaluationRequest(
                    sessionID: anonymousSessionID,
                    storyID: story.id,
                    checkpointID: currentCheckpoint.id,
                    transcript: final.text,
                    attempt: attemptCount,
                    hintLevel: hintLevel,
                    detectedLanguage: preliminary.language
                ))
                metrics.inputTokens += response.inputTokens
                metrics.outputTokens += response.outputTokens
                markFeedbackReady(final, handlingStartedAt: handlingStartedAt)
                await apply(response.result)
            } catch {
                serviceError = error.localizedDescription
                markFeedbackReady(final, handlingStartedAt: handlingStartedAt)
                await giveNextHint(prefix: "我还不太确定你的意思。")
            }
        }
        saveMetrics()
    }

    private func apply(_ result: EvaluationResult) async {
        switch result.verdict {
        case .correct:
            if result.language == .english {
                await requireChineseRecast()
            } else {
                await completeCheckpoint()
            }
        case .meaningUnderstood:
            await requireChineseRecast()
        case .partial, .incorrect:
            await giveNextHint()
        case .uncertain:
            await handleUncertainTranscript()
        case .unusable:
            await handleUnusableTranscript()
        case .unsafe:
            phase = .givingFeedback
            feedback = "我们先暂停一下，请把设备交给身边的家长或老师。"
            await audioPlayer.play(text: feedback, cueID: "parent_help")
            phase = .audioProblem
        }
    }

    private func requireChineseRecast() async {
        flagCurrentVocabularyForPractice()
        meaningUnderstood = true
        phase = .givingFeedback
        feedback = "你理解对了！现在跟着我用中文说：\(currentCheckpoint.recast)"
        await audioPlayer.play(text: feedback, cueID: "recast_\(currentCheckpoint.id)")
        phase = .waitingForAnswer
    }

    private func giveNextHint(prefix: String? = nil) async {
        flagCurrentVocabularyForPractice()
        attemptCount += 1
        hintLevel = min(attemptCount, currentCheckpoint.hints.count)
        let hint = currentCheckpoint.hints[max(0, hintLevel - 1)]
        phase = .givingFeedback
        feedback = [prefix, hint.text].compactMap { $0 }.joined(separator: " ")
        await audioPlayer.play(text: feedback, cueID: hint.cueID)
        phase = .waitingForAnswer
    }

    private func handleUnusableTranscript() async {
        flagCurrentVocabularyForPractice()
        unusableTranscriptions += 1
        if unusableTranscriptions >= 3 {
            phase = .audioProblem
            feedback = "连续三次没有收到清楚的声音。这不是答错了，请让家长检查话筒。"
            await audioPlayer.play(text: feedback, cueID: "audio_problem")
        } else {
            phase = .givingFeedback
            feedback = "我没有听到完整的答案。请靠近话筒，再说一次。"
            await audioPlayer.play(text: feedback, cueID: "please_repeat_unheard")
            phase = .waitingForAnswer
        }
    }

    private func handleUncertainTranscript() async {
        flagCurrentVocabularyForPractice()
        phase = .givingFeedback
        feedback = "我不确定刚才有没有听清。这个不算答错，请把答案完整地再说一次。"
        await audioPlayer.play(text: feedback, cueID: "please_repeat_uncertain")
        phase = .waitingForAnswer
    }

    private func completeCheckpoint() async {
        unusableTranscriptions = 0
        meaningUnderstood = false
        completedCheckpointIDs.insert(currentCheckpoint.id)
        progressStore.markCompleted(storyID: story.id, checkpointID: currentCheckpoint.id)
        phase = .givingFeedback
        feedback = currentCheckpoint.successMessage
        await audioPlayer.play(text: currentCheckpoint.successMessage, cueID: "success_\(currentCheckpoint.id)")

        if sceneIndex == story.beats.count - 1 {
            phase = .completed
            feedback = practiceVocabulary.isEmpty
                ? "故事讲完啦！今天听得很认真。"
                : "故事讲完啦！来练一练刚才有点难的词语。"
            await audioPlayer.play(text: feedback, cueID: "story_complete")
            metricsStore.save(metrics)
            return
        }

        sceneIndex += 1
        attemptCount = 0
        hintLevel = 0
        transcriptPreview = ""
        do {
            try await transcription.updateContext(context(for: currentBeat))
        } catch {
            serviceError = error.localizedDescription
        }
        await playCurrentScene()
    }

    private func context(for beat: StoryBeat) -> TranscriptionContext {
        let checkpoint = beat.checkpoint
        let prompt = "一名华裔儿童正在回答普通话故事理解问题。故事片段：\(beat.narration) 问题：\(checkpoint.question) 可能用中文、英文或中英混合回答。只转写孩子实际说出的内容，不要补全答案。"
        return TranscriptionContext(
            storyID: story.id,
            checkpointID: checkpoint.id,
            prompt: prompt,
            keywords: checkpoint.transcriptionKeywords,
            languages: ["zh-cn", "en"]
        )
    }

    private func storyTranscriptionContext() -> TranscriptionContext {
        let questions = story.beats.map { $0.checkpoint.question }.joined(separator: "；")
        let helpRequests = ["可以重复一遍问题吗", "可以重新讲一下故事吗", "可以用英文提示我一下吗"]
        let keywords = Array(Set(story.beats.flatMap { $0.checkpoint.transcriptionKeywords } + helpRequests)).sorted()
        let prompt = "一名华裔儿童正在用中文、英文或中英混合回答普通话故事理解问题，也可能请求重复问题、重讲这一段或要英文提示。问题包括：\(questions)。只转写孩子实际说出的内容，不要补全答案。"
        return TranscriptionContext(
            storyID: story.id,
            checkpointID: "story-wide",
            prompt: prompt,
            keywords: keywords,
            languages: ["zh-cn", "en"]
        )
    }

    private func beginWarmup() async {
        if isReturningLearner {
            warmupStep = .ready
            phase = .readyToStart
            feedback = readyPrompt
            await audioPlayer.play(text: feedback, cueID: "welcome_returning")
            return
        }
        warmupStep = .greeting
        phase = .welcome
        feedback = "嗨！我是小龙啾啾。见到你真开心！在我们出发前，我想先认识一下你。"
        await audioPlayer.play(text: feedback, cueID: "welcome_greeting")
        warmupStep = .mood
        feedback = "你今天心情怎么样？选一个告诉我吧。"
        await audioPlayer.play(text: feedback, cueID: "welcome_mood_question")
    }

    private func handleTutorCommand(_ command: TutorCommand) async {
        audioPlayer.stop()
        switch command {
        case .repeatQuestion:
            phase = .givingFeedback
            feedback = "当然可以，再听一次问题。"
            await audioPlayer.play(text: currentCheckpoint.question, cueID: currentCheckpoint.questionCueID)
        case .replaySection:
            phase = .narrating
            feedback = "当然可以，我们把这一段再听一次。"
            prepareEnglishSubtitles()
            await audioPlayer.play(text: currentBeat.narration, cueID: currentBeat.narrationCueID)
            phase = .asking
            feedback = "现在再听一次问题。"
            await audioPlayer.play(text: currentCheckpoint.question, cueID: currentCheckpoint.questionCueID)
        case .englishHint:
            phase = .givingFeedback
            feedback = "English hint: \(currentCheckpoint.minimalEnglishHint)"
            await audioPlayer.play(text: currentCheckpoint.minimalEnglishHint, cueID: "english_hint_\(currentCheckpoint.id)")
        }
        phase = .waitingForAnswer
        feedback = "准备好后，按住话筒回答。"
    }

    private func flagCurrentVocabularyForPractice() {
        for item in currentCheckpoint.reviewVocabulary where practiceVocabularyIDs.insert(item.id).inserted {
            practiceVocabulary.append(item)
        }
    }

    private func flagHomophoneMatches(in transcript: String) {
        let normalized = transcript.lowercased()
        let heardHomophone = currentCheckpoint.requiredConcepts
            .flatMap(\.homophones)
            .contains { normalized.contains($0.lowercased()) }
        if heardHomophone {
            flagCurrentVocabularyForPractice()
        }
    }

    private func saveMetrics() {
        metricsStore.save(metrics)
    }

    private func markFeedbackReady(_ final: FinalTranscript, handlingStartedAt: Date) {
        let processingLatency = Date().timeIntervalSince(handlingStartedAt)
        metrics.feedbackLatencies.append(final.latency + processingLatency)
        transcriptPreview = ""
    }

    private static func makeAnonymousSessionID() -> String {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let raw = "\(UUID().uuidString)-\(day)"
        return Data(raw.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
    }
}
