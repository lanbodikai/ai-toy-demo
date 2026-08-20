import XCTest
@testable import AIToy

final class LocalAnswerEvaluatorTests: XCTestCase {
    private let evaluator = LocalAnswerEvaluator()

    func testClearMandarinAnswersStayLocalAndPass() throws {
        let cases = [
            ("fox-bakes", "小狐狸菲菲最会做蛋糕"),
            ("panpan-strawberries", "盼盼带回了红红的草莓"),
            ("milk-and-stir", "燕丽加牛奶啾啾搅拌面糊"),
            ("sing-for-maomiao", "朋友们一起唱生日歌")
        ]

        for (checkpointID, transcript) in cases {
            let result = try resolvedResult(transcript, at: checkpointID)
            XCTAssertEqual(result.verdict, .correct, checkpointID)
            XCTAssertEqual(result.responseKey, .success, checkpointID)
        }
    }

    func testTraditionalAndKnownHomophonesNormalizeLocally() throws {
        XCTAssertEqual(try resolvedResult("小狐狸菲菲會做蛋糕", at: "fox-bakes").verdict, .correct)
        XCTAssertEqual(try resolvedResult("盼盼带回草梅", at: "panpan-strawberries").verdict, .correct)
        XCTAssertEqual(try resolvedResult("燕丽到牛奶啾啾脚拌", at: "milk-and-stir").verdict, .correct)
    }

    func testEnglishOnlyMeaningRequiresChineseRepeat() throws {
        let result = try resolvedResult("Pan Pan brought strawberries", at: "panpan-strawberries")
        XCTAssertEqual(result.verdict, .meaningUnderstood)
        XCTAssertEqual(result.language, .english)
        XCTAssertEqual(result.responseKey, .recastAndRepeat)
    }

    func testMixedAnswerWithAllConceptsRequiresChineseRepeat() throws {
        let result = try resolvedResult("燕丽 add milk 然后啾啾 stir", at: "milk-and-stir")
        XCTAssertEqual(result.verdict, .meaningUnderstood)
        XCTAssertEqual(result.language, .mixed)
    }

    func testPartialOrRelatedAnswerFallsBackToRemoteEvaluator() throws {
        let checkpoint = try checkpoint("milk-and-stir")
        switch evaluator.evaluate(transcript: "燕丽倒了牛奶", checkpoint: checkpoint) {
        case .needsRemote(let result):
            XCTAssertEqual(result.verdict, .partial)
            XCTAssertEqual(result.matchedConcepts, ["milk"])
        case .resolved:
            XCTFail("A semantically incomplete answer should receive bounded remote review")
        }
    }

    func testNegatedConceptIsNeverAutoAccepted() throws {
        let checkpoint = try checkpoint("fox-bakes")
        switch evaluator.evaluate(transcript: "最会做蛋糕的不是小狐狸", checkpoint: checkpoint) {
        case .needsRemote(let result):
            XCTAssertEqual(result.verdict, .uncertain)
            XCTAssertEqual(result.responseKey, .retry)
        case .resolved(let result):
            XCTFail("Negated concept was resolved locally as \(result.verdict)")
        }
    }

    func testKnownWrongAndSilenceDoNotUseRemoteEvaluator() throws {
        XCTAssertEqual(try resolvedResult("盼盼带回了面粉", at: "panpan-strawberries").verdict, .incorrect)
        XCTAssertEqual(try resolvedResult("...", at: "fox-bakes").verdict, .unusable)
    }

    private func resolvedResult(_ transcript: String, at checkpointID: String) throws -> EvaluationResult {
        switch evaluator.evaluate(transcript: transcript, checkpoint: try checkpoint(checkpointID)) {
        case .resolved(let result): return result
        case .needsRemote:
            XCTFail("Expected a local decision for \(checkpointID): \(transcript)")
            throw TestError.unexpectedFallback
        }
    }

    private func checkpoint(_ id: String) throws -> StoryCheckpoint {
        guard let checkpoint = StoryCatalog.sample.stories
            .flatMap(\.beats)
            .map(\.checkpoint)
            .first(where: { $0.id == id }) else {
            throw TestError.missingCheckpoint
        }
        return checkpoint
    }

    private enum TestError: Error {
        case missingCheckpoint
        case unexpectedFallback
    }
}
