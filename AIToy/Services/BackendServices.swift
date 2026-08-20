import Foundation

enum BackendError: LocalizedError {
    case invalidResponse
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The tutoring service returned an invalid response."
        case let .http(status, message): "Tutoring service error \(status): \(message)"
        }
    }
}

struct TranscriptionSessionToken: Codable, Sendable {
    let clientSecret: String
    let expiresAt: Int
    let transport: String?
}

struct BackendClient: @unchecked Sendable {
    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func createTranscriptionSession(
        anonymousID: String,
        context: TranscriptionContext
    ) async throws -> TranscriptionSessionToken {
        struct Request: Encodable {
            let sessionID: String
            let prompt: String
            let keywords: [String]
            let languages: [String]
        }
        return try await post(
            path: "/transcription-sessions",
            body: Request(
                sessionID: anonymousID,
                prompt: String(context.prompt.prefix(900)),
                keywords: context.keywords,
                languages: context.languages
            ),
            response: TranscriptionSessionToken.self
        )
    }

    func evaluate(_ request: EvaluationRequest) async throws -> RemoteEvaluationResponse {
        try await post(path: "/answers/evaluate", body: request, response: RemoteEvaluationResponse.self)
    }

    func safetyCheck(transcript: String, sessionID: String) async throws -> SafetyResult {
        struct Request: Encodable { let transcript: String; let sessionID: String }
        return try await post(
            path: "/answers/safety-check",
            body: Request(transcript: transcript, sessionID: sessionID),
            response: SafetyResult.self
        )
    }

    private func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body,
        response: Response.Type
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 12
        request.httpBody = try JSONEncoder().encode(body)

        let (data, urlResponse) = try await session.data(for: request)
        guard let http = urlResponse as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw BackendError.http(http.statusCode, message ?? "Request failed")
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw BackendError.invalidResponse
        }
    }
}

struct BackendAnswerEvaluationService: AnswerEvaluationService {
    let client: BackendClient

    func evaluate(_ request: EvaluationRequest) async throws -> RemoteEvaluationResponse {
        try await client.evaluate(request)
    }
}

struct BackendSafetyService: SafetyService {
    let client: BackendClient

    func check(transcript: String, sessionID: String) async throws -> SafetyResult {
        try await client.safetyCheck(transcript: transcript, sessionID: sessionID)
    }
}
