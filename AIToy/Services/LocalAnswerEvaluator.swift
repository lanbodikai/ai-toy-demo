import Foundation

struct LocalAnswerEvaluator: Sendable {
    enum Decision: Equatable, Sendable {
        case resolved(EvaluationResult)
        case needsRemote(EvaluationResult)
    }

    func evaluate(transcript: String, checkpoint: StoryCheckpoint) -> Decision {
        let normalized = normalize(transcript)
        guard isUsable(normalized) else {
            return .resolved(result(.unusable, .unknown, [], 0, .retry))
        }

        let language = detectLanguage(in: normalized)
        let conceptMatches = checkpoint.requiredConcepts.map { concept in
            match(concept: concept, in: normalized)
        }
        let matchedIDs = zip(checkpoint.requiredConcepts, conceptMatches)
            .filter { $0.1.matched }
            .map { $0.0.id }
        let allMatched = conceptMatches.allSatisfy { $0.matched }
        let allMatchedInChinese = conceptMatches.allSatisfy { $0.matchedInChinese }

        if allMatched && containsNegatedConcept(in: normalized, checkpoint: checkpoint) {
            return .needsRemote(result(.uncertain, language, matchedIDs, 0.35, .retry))
        }

        if allMatchedInChinese {
            return .resolved(result(.correct, language, matchedIDs, 0.99, .success))
        }

        if allMatched {
            return .resolved(result(.meaningUnderstood, language, matchedIDs, 0.96, .recastAndRepeat))
        }

        let hasRelatedTerm = checkpoint.relatedTerms
            .map(normalize)
            .contains(where: normalized.contains)
        let hasKnownWrongTerm = checkpoint.knownWrongTerms
            .map(normalize)
            .contains(where: normalized.contains)

        if hasKnownWrongTerm && matchedIDs.isEmpty {
            return .resolved(result(.incorrect, language, [], 0.98, .hintOne))
        }

        if !matchedIDs.isEmpty || hasRelatedTerm {
            return .needsRemote(result(.partial, language, matchedIDs, 0.55, .retry))
        }

        if normalized.count <= 3 && !normalized.contains(where: { $0.isLetter }) {
            return .resolved(result(.unusable, language, [], 0.1, .retry))
        }

        return .resolved(result(.incorrect, language, [], 0.92, .hintOne))
    }

    func normalize(_ source: String) -> String {
        var value = source.lowercased().folding(options: [.widthInsensitive, .diacriticInsensitive], locale: Locale(identifier: "zh_CN"))
        let replacements: [String: String] = [
            "種": "种", "籽": "子", "發": "发", "現": "现", "顆": "颗",
            "會": "会", "裡": "里", "裏": "里", "葉": "叶", "讓": "让",
            "螢": "萤", "蟲": "虫", "幫": "帮", "這": "这", "個": "个",
            "麼": "么", "開": "开", "來": "来", "還": "还", "點": "点",
            "帶": "带", "麗": "丽", "攪": "搅", "麵": "面", "樂": "乐",
            "們": "们", "為": "为", "慶": "庆", "紅": "红", "進": "进",
            "門": "门", "燭": "烛", "寫": "写", "滿": "满", "張": "张",
            "然後": "然后", "嗯": "", "呃": "", "那个": "", "就是": ""
        ]
        for (from, to) in replacements {
            value = value.replacingOccurrences(of: from, with: to)
        }
        value = value.unicodeScalars
            .filter { CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0) }
            .map(String.init)
            .joined()
        return value
    }

    func detectLanguage(in normalized: String) -> LearnerLanguage {
        let hasHan = normalized.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
        let hasLatin = normalized.unicodeScalars.contains { scalar in
            (0x41...0x5A).contains(Int(scalar.value)) || (0x61...0x7A).contains(Int(scalar.value))
        }
        switch (hasHan, hasLatin) {
        case (true, true): return .mixed
        case (true, false): return .chinese
        case (false, true): return .english
        case (false, false): return .unknown
        }
    }

    private func isUsable(_ value: String) -> Bool {
        value.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count >= 1
    }

    private func match(concept: AnswerConcept, in transcript: String) -> (matched: Bool, matchedInChinese: Bool) {
        let chineseTerms = (concept.chineseTerms + concept.homophones).map(normalize)
        if chineseTerms.contains(where: transcript.contains) {
            return (true, true)
        }

        let englishTerms = concept.englishTerms.map(normalize)
        if englishTerms.contains(where: transcript.contains) {
            return (true, false)
        }
        return (false, false)
    }

    private func containsNegatedConcept(in transcript: String, checkpoint: StoryCheckpoint) -> Bool {
        let chineseTerms = checkpoint.requiredConcepts.flatMap { $0.chineseTerms + $0.homophones }.map(normalize)
        let englishTerms = checkpoint.requiredConcepts.flatMap(\.englishTerms).map(normalize)
        let chineseNegations = ["不是", "并非", "没有", "没用", "没拿", "没找到"]
        let englishNegations = ["not", "wasnt", "didnt", "didnot", "never", "without"]

        return chineseTerms.contains { term in
            chineseNegations.contains { transcript.contains($0 + term) }
        } || englishTerms.contains { term in
            englishNegations.contains { transcript.contains($0 + term) }
        }
    }

    private func result(
        _ verdict: EvaluationVerdict,
        _ language: LearnerLanguage,
        _ concepts: [String],
        _ confidence: Double,
        _ responseKey: ResponseKey
    ) -> EvaluationResult {
        EvaluationResult(
            verdict: verdict,
            language: language,
            matchedConcepts: concepts,
            confidence: confidence,
            responseKey: responseKey
        )
    }
}
