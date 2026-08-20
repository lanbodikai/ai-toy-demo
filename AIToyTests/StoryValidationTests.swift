import XCTest
@testable import AIToy

final class StoryValidationTests: XCTestCase {
    func testEnglishNarrationIsSplitIntoReadableSubtitleChunks() {
        for beat in StoryCatalog.sample.stories.flatMap(\.beats) {
            let chunks = NarrationSubtitleSegmenter.segments(from: beat.englishNarration)
            XCTAssertGreaterThan(chunks.count, 1, beat.id)
            XCTAssertTrue(chunks.allSatisfy { $0.count <= 82 }, beat.id)
            XCTAssertEqual(
                chunks.joined(separator: " ").split(whereSeparator: \.isWhitespace).joined(separator: " "),
                beat.englishNarration.split(whereSeparator: \.isWhitespace).joined(separator: " "),
                beat.id
            )
        }
    }

    @MainActor
    func testWarmupChatRequiresConfirmationBeforeStoryNarration() async throws {
        let suiteName = "AIToyTests.Warmup.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let audio = RecordingStoryAudioPlayer()
        let viewModel = LessonSessionViewModel(
            story: try XCTUnwrap(StoryCatalog.sample.stories.first),
            transcription: ConnectedTranscriptionService(),
            remoteEvaluator: UnusedAnswerService(),
            safetyService: UnusedSafetyService(),
            localEvaluator: LocalAnswerEvaluator(),
            audioPlayer: audio,
            progressStore: ProgressStore(defaults: defaults),
            metricsStore: MetricsStore(defaults: defaults)
        )

        await viewModel.start()
        XCTAssertEqual(viewModel.warmupStep, .mood)
        XCTAssertEqual(audio.cueIDs, ["welcome_greeting", "welcome_mood_question"])
        XCTAssertFalse(audio.cueIDs.contains("scene_choose_helper"))

        await viewModel.respondToMood(.happy)
        XCTAssertEqual(viewModel.warmupStep, .ready)
        XCTAssertFalse(audio.cueIDs.contains("scene_choose_helper"))

        await viewModel.confirmStoryStart()
        XCTAssertEqual(viewModel.warmupStep, .finished)
        XCTAssertTrue(audio.cueIDs.contains("scene_choose_helper"))
    }

    @MainActor
    func testConsentAcceptsPersistsAndRevokesWithoutAdultGate() throws {
        let suiteName = "AIToyTests.Consent.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ConsentStore(defaults: defaults)
        XCTAssertFalse(store.hasGuardianConsent)
        store.accept()
        XCTAssertTrue(store.hasGuardianConsent)
        XCTAssertTrue(ConsentStore(defaults: defaults).hasGuardianConsent)
        store.revoke()
        XCTAssertFalse(store.hasGuardianConsent)
    }

    func testMVPStoryHasFourCompleteSceneCheckpointBeats() throws {
        let story = try XCTUnwrap(StoryCatalog.sample.stories.first)
        XCTAssertEqual(story.beats.count, 4)
        XCTAssertTrue((5...8).contains(story.estimatedMinutes))
        XCTAssertEqual(story.difficulty, .general)

        let beatIDs = Set(story.beats.map(\.id))
        let checkpointIDs = Set(story.beats.map(\.checkpoint.id))
        XCTAssertEqual(beatIDs.count, 4)
        XCTAssertEqual(checkpointIDs.count, 4)

        for beat in story.beats {
            XCTAssertFalse(beat.narration.isEmpty)
            XCTAssertFalse(beat.englishNarration.isEmpty)
            XCTAssertFalse(beat.narrationCueID.isEmpty)
            XCTAssertFalse(beat.checkpoint.question.isEmpty)
            XCTAssertFalse(beat.checkpoint.englishQuestion.isEmpty)
            XCTAssertFalse(beat.checkpoint.recast.isEmpty)
            XCTAssertFalse(beat.checkpoint.minimalEnglishHint.isEmpty)
            XCTAssertFalse(beat.checkpoint.reviewVocabulary.isEmpty)
            XCTAssertFalse(beat.checkpoint.requiredConcepts.isEmpty)
            XCTAssertEqual(beat.checkpoint.hints.map(\.level), [1, 2, 3, 4])
            XCTAssertTrue(beat.checkpoint.hints.allSatisfy { !$0.cueID.isEmpty && !$0.text.isEmpty })
        }
    }

    func testPresetTutorRequestsStayDeterministic() {
        XCTAssertEqual(TutorCommandParser.parse("可以重复一遍问题吗？"), .repeatQuestion)
        XCTAssertEqual(TutorCommandParser.parse("可以重新讲一下故事吗"), .replaySection)
        XCTAssertEqual(TutorCommandParser.parse("你可以用英文提示我一下吗？"), .englishHint)
        XCTAssertNil(TutorCommandParser.parse("朋友们一起唱生日歌"))
    }

    @MainActor
    func testCompletedLearnerGetsWelcomeBackInsteadOfMoodQuestion() async throws {
        let suiteName = "AIToyTests.Returning.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let story = try XCTUnwrap(StoryCatalog.sample.stories.first)
        let progress = ProgressStore(defaults: defaults)
        for beat in story.beats {
            progress.markCompleted(storyID: story.id, checkpointID: beat.checkpoint.id)
        }
        let audio = RecordingStoryAudioPlayer()
        let viewModel = LessonSessionViewModel(
            story: story,
            transcription: ConnectedTranscriptionService(),
            remoteEvaluator: UnusedAnswerService(),
            safetyService: UnusedSafetyService(),
            localEvaluator: LocalAnswerEvaluator(),
            audioPlayer: audio,
            progressStore: progress,
            metricsStore: MetricsStore(defaults: defaults)
        )

        await viewModel.start()

        XCTAssertTrue(viewModel.isReturningLearner)
        XCTAssertEqual(viewModel.warmupStep, .ready)
        XCTAssertEqual(audio.cueIDs, ["welcome_returning"])
        XCTAssertTrue(viewModel.feedback.contains("欢迎回来"))
        XCTAssertEqual(viewModel.completedCheckpointIDs, [])
    }

    func testRubricsContainMultilingualAndASRMetadata() {
        for checkpoint in StoryCatalog.sample.stories.flatMap(\.beats).map(\.checkpoint) {
            for concept in checkpoint.requiredConcepts {
                XCTAssertFalse(concept.chineseTerms.isEmpty)
                XCTAssertFalse(concept.englishTerms.isEmpty)
                XCTAssertFalse(concept.homophones.isEmpty)
            }
            XCTAssertFalse(checkpoint.transcriptionKeywords.isEmpty)
        }
    }

    func testNoRawLearnerDataIsEncodedInMetrics() throws {
        var metrics = SessionMetrics(storyID: "choochoo-birthday-cake")
        metrics.submittedAudioSeconds = 45
        metrics.evaluatorCalls = 2
        let encoded = try JSONEncoder().encode(metrics)
        let json = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("transcript"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("audioData"))
        XCTAssertLessThan(metrics.estimatedCostUSD, 0.03)
    }

    func testEveryRuntimeCueHasBundledEdgeTTSAudio() throws {
        let story = try XCTUnwrap(StoryCatalog.sample.stories.first)
        var cueIDs: Set<String> = [
            "welcome_greeting",
            "welcome_mood_question",
            "welcome_mood_happy",
            "welcome_mood_calm",
            "welcome_mood_sleepy",
            "welcome_ready",
            "welcome_returning",
            "please_repeat_unheard",
            "please_repeat_uncertain",
            "audio_problem",
            "parent_help",
            "story_complete"
        ]

        for beat in story.beats {
            cueIDs.insert(beat.narrationCueID)
            cueIDs.insert(beat.checkpoint.questionCueID)
            cueIDs.insert("recast_\(beat.checkpoint.id)")
            cueIDs.insert("success_\(beat.checkpoint.id)")
            cueIDs.insert("english_hint_\(beat.checkpoint.id)")
            cueIDs.formUnion(beat.checkpoint.hints.map(\.cueID))
        }

        let missing = cueIDs.sorted().filter { cueID in
            Bundle.main.url(forResource: cueID, withExtension: "mp3", subdirectory: "Audio") == nil
                && Bundle.main.url(forResource: cueID, withExtension: "m4a", subdirectory: "Audio") == nil
        }
        XCTAssertTrue(missing.isEmpty, "Missing bundled Edge-TTS cues: \(missing.joined(separator: ", "))")
    }
}

@MainActor
private final class ConnectedTranscriptionService: TranscriptionService {
    var onPartialTranscript: ((String) -> Void)?
    var onFinalTranscript: ((FinalTranscript) -> Void)?
    var onError: ((Error) -> Void)?

    func startSession(initialContext: TranscriptionContext, anonymousID: String) async throws {}
    func updateContext(_ context: TranscriptionContext) async throws {}
    func beginTurn() async throws {}
    func endTurn() async throws {}
    func close() {}
}

@MainActor
private final class RecordingStoryAudioPlayer: StoryAudioPlaying {
    private(set) var cueIDs: [String] = []

    func play(text: String, cueID: String) async {
        cueIDs.append(cueID)
    }

    func stop() {}
}

private struct UnusedAnswerService: AnswerEvaluationService {
    func evaluate(_ request: EvaluationRequest) async throws -> RemoteEvaluationResponse {
        throw TestServiceError.unused
    }
}

private struct UnusedSafetyService: SafetyService {
    func check(transcript: String, sessionID: String) async throws -> SafetyResult {
        throw TestServiceError.unused
    }
}

private enum TestServiceError: Error {
    case unused
}
