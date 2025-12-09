import Foundation
import FirebaseAuth

struct UploadUrlResponse: Codable {
    let url: String?
    let uploadUrl: String?
    let upload_url: String?
    
    var resolvedURL: String? { url ?? uploadUrl ?? upload_url }
    
    init(url: String?, uploadUrl: String?, upload_url: String?) {
        self.url = url
        self.uploadUrl = uploadUrl
        self.upload_url = upload_url
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        uploadUrl = try container.decodeIfPresent(String.self, forKey: .uploadUrl)
        upload_url = try container.decodeIfPresent(String.self, forKey: .upload_url)
        // 両方 nil の場合も decode エラーにしないで呼び出し側で判定
    }
    
    private enum CodingKeys: String, CodingKey {
        case url
        case uploadUrl
        case upload_url
    }
}

struct CreateSessionResponse: Codable {
    let id: String
    let mode: String
}

enum SessionMode: String, Codable, CaseIterable, Identifiable {
    case lecture
    case meeting
    var id: String { rawValue }
}

actor CloudAPIClient {
    private var baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.httpShouldSetCookies = false
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = iso.date(from: string) { return date }
            if let fallback = ISO8601DateFormatter().date(from: string) { return fallback }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date")
        }
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    func updateBaseURL(_ url: URL) {
        self.baseURL = url
    }

    private func authedRequest(path: String, method: String, token: String, body: Encodable? = nil) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body = body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            logHTTPError(request: request, response: http, data: data)
            throw APIError.httpStatus(http.statusCode, data)
        }
        return (data, http)
    }

    /// 非2xxレスポンス時に簡易ログを出す（機微情報は出さない）
    private func logHTTPError(request: URLRequest, response: HTTPURLResponse, data: Data) {
        let urlString = request.url?.absoluteString ?? "unknown"
        let method = request.httpMethod ?? "UNKNOWN"
        let status = response.statusCode
        let bodySnippet: String
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            bodySnippet = text.count > 500 ? String(text.prefix(500)) + "…" : text
        } else {
            bodySnippet = "<no body>"
        }
        print("[HTTP] \(method) \(urlString) -> \(status) body:\n\(bodySnippet)")
    }

    func createSession(mode: SessionMode, title: String?, userId: String, token: String) async throws -> CreateSessionResponse {
        struct Payload: Codable { let mode: String; let title: String?; let userId: String }
        let (data, _) = try await authedRequest(path: "/sessions", method: "POST", token: token, body: Payload(mode: mode.rawValue, title: title, userId: userId))
        return try decoder.decode(CreateSessionResponse.self, from: data)
    }

    func uploadURL(sessionId: String, mode: SessionMode, contentType: String, token: String) async throws -> UploadUrlResponse {
        struct Payload: Codable { let sessionId: String; let mode: String; let contentType: String }
        let (data, _) = try await authedRequest(path: "/upload-url", method: "POST", token: token, body: Payload(sessionId: sessionId, mode: mode.rawValue, contentType: contentType))
        do {
            return try decoder.decode(UploadUrlResponse.self, from: data)
        } catch {
            // デコードに失敗した場合は簡易解析してログを出す
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let pretty = json.map { "\($0): \($1)" }.joined(separator: ", ")
                print("[HTTP] upload-url decode fallback payload: \(pretty)")
                let alt = UploadUrlResponse(url: json["url"] as? String,
                                            uploadUrl: json["uploadUrl"] as? String ?? json["upload_url"] as? String,
                                            upload_url: json["upload_url"] as? String)
                return alt
            }
            throw error
        }
    }

    func startTranscribe(sessionId: String, mode: SessionMode, token: String) async throws {
        struct Payload: Codable { let mode: String }
        _ = try await authedRequest(path: "/sessions/\(sessionId)/start_transcribe", method: "POST", token: token, body: Payload(mode: mode.rawValue))
    }

    func refreshTranscript(sessionId: String, token: String) async throws -> RefreshTranscriptResponse {
        struct Empty: Codable {}
        let (data, _) = try await authedRequest(path: "/sessions/\(sessionId)/refresh_transcript", method: "POST", token: token, body: Empty())
        return try decoder.decode(RefreshTranscriptResponse.self, from: data)
    }

    func summarize(sessionId: String, token: String) async throws -> SummarizeResponse {
        struct Empty: Codable {}
        let (data, _) = try await authedRequest(path: "/sessions/\(sessionId)/summarize", method: "POST", token: token, body: Empty())
        return try decoder.decode(SummarizeResponse.self, from: data)
    }

    func askQuestion(sessionId: String, question: String, token: String) async throws -> QAResponse {
        struct Payload: Codable { let question: String }
        let path = "/sessions/\(sessionId)/qa"
        let (data, _) = try await authedRequest(path: path, method: "POST", token: token, body: Payload(question: question))
        return try decoder.decode(QAResponse.self, from: data)
    }

    func generateQuiz(sessionId: String, count: Int, token: String) async throws -> QuizResponseDTO {
        let path = "/sessions/\(sessionId)/quiz?count=\(count)"
        let (data, _) = try await authedRequest(path: path, method: "POST", token: token)
        return try decoder.decode(QuizResponseDTO.self, from: data)
    }

    func putSignedURL(url: URL, data: Data, contentType: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        _ = try await session.upload(for: request, from: data)
    }
}

struct RefreshTranscriptResponse: Codable {
    let status: String?
    let transcriptText: String?
}

struct SummarizeResponse: Codable {
    let status: String?
    let summary: Summary?
}

struct QAResponse: Codable {
    let answer: String?
    let citations: [String]?
}

// MARK: - Quiz Models

struct QuizChoice: Codable, Identifiable, Hashable {
    let id = UUID()
    let text: String
}

struct QuizQuestion: Codable, Identifiable, Hashable {
    let id: String
    let question: String
    let choices: [QuizChoice]
    let correctIndex: Int
    let explanation: String?
}

struct QuizResponseDTO: Codable {
    let sessionId: String
    let count: Int
    let questions: [QuizQuestion]
}

