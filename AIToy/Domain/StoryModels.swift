import Foundation

enum StoryDifficulty: String, Codable, CaseIterable, Sendable {
    case general
    case beginner
    case intermediate
    case advanced

    var displayName: String {
        switch self {
        case .general: "综合"
        case .beginner: "初级"
        case .intermediate: "中级"
        case .advanced: "高级"
        }
    }
}

struct StoryLesson: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let difficulty: StoryDifficulty
    let estimatedMinutes: Int
    let coverEmoji: String
    let themeColors: [String]
    let beats: [StoryBeat]
}

struct StoryBeat: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let illustrationEmoji: String
    let narration: String
    let englishNarration: String
    let narrationCueID: String
    let checkpoint: StoryCheckpoint
}

enum NarrationSubtitleSegmenter {
    static func segments(from text: String, maxCharacters: Int = 82) -> [String] {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .bySentences) { substring, _, _, _ in
            guard let sentence = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !sentence.isEmpty else {
                return
            }
            sentences.append(sentence)
        }

        return sentences.flatMap { wrap($0, maxCharacters: maxCharacters) }
    }

    private static func wrap(_ sentence: String, maxCharacters: Int) -> [String] {
        let words = sentence.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return [] }

        var chunks: [String] = []
        var current = ""
        for word in words {
            let candidate = current.isEmpty ? word : "\(current) \(word)"
            if candidate.count <= maxCharacters || current.isEmpty {
                current = candidate
            } else {
                chunks.append(current)
                current = word
            }
        }
        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
    }
}

struct StoryCheckpoint: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let question: String
    let englishQuestion: String
    let questionCueID: String
    let requiredConcepts: [AnswerConcept]
    let relatedTerms: [String]
    let knownWrongTerms: [String]
    let recast: String
    let successMessage: String
    let minimalEnglishHint: String
    let reviewVocabulary: [VocabularyItem]
    let hints: [HintStep]

    var transcriptionKeywords: [String] {
        let terms = requiredConcepts.flatMap { $0.chineseTerms + $0.homophones }
        return Array(Set(terms + relatedTerms)).sorted()
    }
}

struct VocabularyItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let chinese: String
    let pinyin: String
    let english: String
}

struct AnswerConcept: Codable, Hashable, Sendable {
    let id: String
    let chineseTerms: [String]
    let englishTerms: [String]
    let homophones: [String]
}

struct HintStep: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let level: Int
    let text: String
    let cueID: String
}

enum LearnerLanguage: String, Codable, Sendable {
    case chinese
    case english
    case mixed
    case unknown
}

enum EvaluationVerdict: String, Codable, Sendable {
    case correct
    case meaningUnderstood
    case partial
    case incorrect
    case uncertain
    case unusable
    case unsafe
}

enum ResponseKey: String, Codable, Sendable {
    case success
    case recastAndRepeat
    case hintOne
    case hintTwo
    case bilingualHint
    case multipleChoice
    case retry
    case audioProblem
    case offTopic
    case parentHelp
}

struct EvaluationRequest: Codable, Sendable {
    let sessionID: String
    let storyID: String
    let checkpointID: String
    let transcript: String
    let attempt: Int
    let hintLevel: Int
    let detectedLanguage: LearnerLanguage
}

struct EvaluationResult: Codable, Equatable, Sendable {
    let verdict: EvaluationVerdict
    let language: LearnerLanguage
    let matchedConcepts: [String]
    let confidence: Double
    let responseKey: ResponseKey
}

struct TranscriptionContext: Sendable {
    let storyID: String
    let checkpointID: String
    let prompt: String
    let keywords: [String]
    let languages: [String]
}

struct FinalTranscript: Sendable {
    let text: String
    let audioDuration: TimeInterval
    let latency: TimeInterval
}

struct SessionMetrics: Codable, Equatable, Sendable {
    var storyID: String
    var submittedAudioSeconds: Double = 0
    var evaluatorCalls: Int = 0
    var safetyCalls: Int = 0
    var usableAnswers: Int = 0
    var localDecisions: Int = 0
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var feedbackLatencies: [Double] = []

    var fallbackRate: Double {
        guard usableAnswers > 0 else { return 0 }
        return Double(evaluatorCalls) / Double(usableAnswers)
    }

    var estimatedCostUSD: Double {
        let transcription = submittedAudioSeconds / 60 * 0.017
        let input = Double(inputTokens) / 1_000_000 * 0.05
        let output = Double(outputTokens) / 1_000_000 * 0.40
        return transcription + input + output
    }
}

struct StoryProgress: Codable, Equatable, Sendable {
    let storyID: String
    var completedCheckpointIDs: Set<String>
    var lastUpdated: Date

    var isComplete: Bool { completedCheckpointIDs.count >= 4 }
}
