import Foundation
import FirebaseAuth

// MARK: - API Errors

enum APIError: LocalizedError {
    case unauthenticated
    case usernameRequired        // 412: Username must be set before this action
    case usernameAlreadySet      // 409: Username already exists
    case usernameTaken           // 409: Username is taken by another user
    case notFound                // 404
    case serverError(statusCode: Int, message: String)
    case decodingError(Error)
    case networkError(Error)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "ログインが必要です"
        case .usernameRequired:
            return "ユーザーネームの設定が必要です"
        case .usernameAlreadySet:
            return "ユーザーネームは既に設定されています"
        case .usernameTaken:
            return "このユーザーネームは既に使用されています"
        case .notFound:
            return "データが見つかりません"
        case .serverError(let code, let message):
            return "サーバーエラー (\(code)): \(message)"
        case .decodingError:
            return "データの解析に失敗しました"
        case .networkError:
            return "ネットワーク接続を確認してください"
        case .unknown:
            return "エラーが発生しました"
        }
    }
}

// MARK: - API Client

@MainActor
final class APIClient {
    static let shared = APIClient()

    private let baseURL = URL(string: "https://classnote-api-900324644592.asia-northeast1.run.app")!
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let session: URLSession

    private init() {
        encoder = JSONEncoder()

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    // MARK: - Auth Helper

    private func getIDToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw APIError.unauthenticated
        }
        return try await user.getIDToken()
    }

    // MARK: - Request Helper

    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Data? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        // Build URL with query items
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw APIError.unknown(URLError(.badURL))
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Auth Header
        let token = try await getIDToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

#if DEBUG
        let urlString = request.url?.absoluteString ?? path
        print("[APIClient] → \(method) \(urlString)")
        if let auth = request.value(forHTTPHeaderField: "Authorization") {
            let prefix = auth.prefix(24)
            print("[APIClient] → Authorization: \(prefix)...")
        } else {
            print("[APIClient] → Authorization: <nil>")
        }
        if let body {
            if let payload = String(data: body, encoding: .utf8) {
                print("[APIClient] → body=\(payload)")
            } else {
                print("[APIClient] → body=<\(body.count) bytes>")
            }
        }
#endif

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.unknown(URLError(.badServerResponse))
            }

#if DEBUG
            if let trace = httpResponse.value(forHTTPHeaderField: "x-cloud-trace-context") {
                print("[APIClient] trace=\(trace)")
            }
            let responseBody = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
            print("[APIClient] ← status=\(httpResponse.statusCode)")
            print("[APIClient] ← body=\(responseBody)")
#endif

            // Handle specific error codes
            switch httpResponse.statusCode {
            case 200...299:
                break // Success
            case 401:
                throw APIError.unauthenticated
            case 404:
                throw APIError.notFound
            case 409:
                throw APIError.usernameTaken
            case 412:
                throw APIError.usernameRequired
            default:
                let msg = String(data: data, encoding: .utf8) ?? "Unknown Error"
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: msg)
            }

            // Handle Empty Response
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                print("[APIClient] Decoding Error: \(error)")
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("[APIClient] Raw response: \(rawResponse)")
                }
                throw APIError.decodingError(error)
            }
        } catch let error as APIError {
            throw error
        } catch {
            print("[APIClient] Network Error: \(error)")
            if let urlError = error as? URLError {
                print("[APIClient] URLError: \(urlError.code.rawValue) \(urlError.code)")
            }
            throw APIError.networkError(error)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Users

    /// Get current user profile
    func getMe() async throws -> User {
        try await request("users/me")
    }

    /// Create or refresh share code
    func createOrRefreshShareCode() async throws -> ShareCodeResponse {
        try await request("users/me/share-code", method: "POST")
    }

    /// Set username (one-time, immutable)
    /// - Throws: usernameAlreadySet (409) if already set, usernameTaken (409) if taken
    func setUsername(_ username: String) async throws -> User {
        let body = try encoder.encode(ClaimUsernameRequest(username: username))
        let _: EmptyResponse = try await request("users/claim-username", method: "POST", body: body)
        return try await getMe()
    }

    /// Lookup user by username (optional)
    func lookupUser(username: String) async throws -> PublicUser {
        let results: [PublicUser] = try await request("users/search", queryItems: [
            URLQueryItem(name: "q", value: username)
        ])
        if let match = results.first(where: { $0.username?.lowercased() == username.lowercased() }) {
            return match
        }
        throw APIError.notFound
    }

    // MARK: - Imports

    func importYouTube(
        url: String,
        mode: SessionType,
        title: String?,
        language: String?
    ) async throws -> ImportYouTubeResponse {
        let body = try encoder.encode(ImportYouTubeRequest(url: url, mode: mode, title: title, language: language))
        return try await request("imports/youtube", method: "POST", body: body)
    }

    // MARK: - Sessions

    /// Create a new session
    func createSession(type: SessionType, title: String) async throws -> Session {
        let req = CreateSessionRequest(title: title, mode: type)
        let body = try encoder.encode(req)
        return try await request("sessions", method: "POST", body: body)
    }

    /// List sessions with optional filters
    func listSessions(
        type: SessionType? = nil,
        query: String? = nil,
        from: Date? = nil,
        to: Date? = nil
    ) async throws -> [Session] {
        if let query = query, !query.isEmpty {
            var queryItems: [URLQueryItem] = [URLQueryItem(name: "q", value: query)]
            if let type = type {
                queryItems.append(URLQueryItem(name: "mode", value: type.rawValue))
            }
            if let from = from {
                queryItems.append(URLQueryItem(name: "from_date", value: formatDate(from)))
            }
            if let to = to {
                queryItems.append(URLQueryItem(name: "to_date", value: formatDate(to)))
            }
            return try await request("search/sessions", queryItems: queryItems)
        }

        var queryItems: [URLQueryItem] = []
        if let type = type {
            queryItems.append(URLQueryItem(name: "kind", value: type.rawValue))
        }
        if let from = from {
            queryItems.append(URLQueryItem(name: "from_date", value: formatDate(from)))
        }
        if let to = to {
            queryItems.append(URLQueryItem(name: "to_date", value: formatDate(to)))
        }
        return try await request("sessions", queryItems: queryItems.isEmpty ? nil : queryItems)
    }

    /// Get single session details
    func getSession(id: String) async throws -> Session {
        try await request("sessions/\(id)")
    }

    /// Update session (title, memo)
    func updateSession(
        id: String,
        title: String? = nil,
        tags: [String]? = nil,
        status: String? = nil,
        visibility: String? = nil
    ) async throws -> Session {
        struct PatchReq: Encodable {
            let title: String?
            let tags: [String]?
            let status: String?
            let visibility: String?
        }
        let body = try encoder.encode(PatchReq(title: title, tags: tags, status: status, visibility: visibility))
        return try await request("sessions/\(id)", method: "PATCH", body: body)
    }

    /// Delete session
    func deleteSession(id: String) async throws {
        let _: EmptyResponse = try await request("sessions/\(id)", method: "DELETE")
    }

    // MARK: - Media / Upload

    func prepareAudioUpload(sessionId: String, request payload: AudioPrepareRequest) async throws -> AudioPrepareResponse {
        let body = try encoder.encode(payload)
        return try await request("sessions/\(sessionId)/audio:prepareUpload", method: "POST", body: body)
    }

    func commitAudioUpload(sessionId: String, request payload: AudioCommitRequest) async throws -> AudioCommitResponse {
        let body = try encoder.encode(payload)
        return try await request("sessions/\(sessionId)/audio:commit", method: "POST", body: body)
    }

    func getImageUploadURL(sessionId: String, contentType: String) async throws -> ImageUploadUrlResponse {
        let body = try encoder.encode(ImageUploadUrlRequest(contentType: contentType))
        return try await request("sessions/\(sessionId)/image_notes/upload_url", method: "POST", body: body)
    }

    func listImageNotes(sessionId: String) async throws -> [ImageNoteDTO] {
        try await request("sessions/\(sessionId)/image_notes")
    }

    func getAudioURL(sessionId: String) async throws -> SignedCompressedAudioResponse {
        try await request("sessions/\(sessionId)/audio_url")
    }

    /// Upload binary data to the signed URL (no auth)
    func upload(
        data: Data,
        to uploadURL: URL,
        contentType: String,
        method: String = "PUT",
        headers: [String: String]? = nil
    ) async throws {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = method
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        #if DEBUG
        let urlString = request.url?.absoluteString ?? "<unknown>"
        print("[APIClient] → \(method) \(urlString)")
        print("[APIClient] → Content-Length=\(data.count)")
        #endif

        let (responseData, response) = try await session.upload(for: request, from: data)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown(URLError(.badServerResponse))
        }
        #if DEBUG
        let responseBody = String(data: responseData, encoding: .utf8) ?? "<\(responseData.count) bytes>"
        print("[APIClient] ← status=\(httpResponse.statusCode)")
        if !responseBody.isEmpty {
            print("[APIClient] ← body=\(responseBody)")
        }
        #endif
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: responseData, encoding: .utf8) ?? "Upload failed"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    // MARK: - Tags / Notes

    func updateTags(sessionId: String, tags: [String]) async throws {
        struct TagReq: Encodable { let tags: [String] }
        let body = try encoder.encode(TagReq(tags: tags))
        let _: EmptyResponse = try await request("sessions/\(sessionId)/tags", method: "PATCH", body: body)
    }

    func updateNotes(sessionId: String, notes: String) async throws {
        struct NotesReq: Encodable { let notes: String }
        let body = try encoder.encode(NotesReq(notes: notes))
        let _: EmptyResponse = try await request("sessions/\(sessionId)/notes", method: "PATCH", body: body)
    }

    // MARK: - Transcript (Device)

    func updateTranscript(sessionId: String, transcriptText: String, source: String = "device") async throws {
        struct TranscriptReq: Encodable {
            let transcriptText: String
            let source: String?
        }
        let body = try encoder.encode(TranscriptReq(transcriptText: transcriptText, source: source))
        let _: EmptyResponse = try await request("sessions/\(sessionId)/transcript", method: "POST", body: body)
    }

    // MARK: - AI Features

    private func createJob(sessionId: String, type: JobType) async throws -> JobResponse {
        let body = try encoder.encode(JobRequest(type: type))
        return try await request("sessions/\(sessionId)/jobs", method: "POST", body: body)
    }

    /// Trigger transcription
    func transcribe(sessionId: String) async throws {
        _ = try await createJob(sessionId: sessionId, type: .transcribe)
    }

    /// Trigger summary generation
    func summarize(sessionId: String) async throws {
        _ = try await createJob(sessionId: sessionId, type: .summary)
    }

    /// Trigger quiz generation
    func generateQuiz(sessionId: String) async throws {
        _ = try await createJob(sessionId: sessionId, type: .quiz)
    }

    /// Trigger speaker diarization
    func diarize(sessionId: String) async throws {
        _ = try await createJob(sessionId: sessionId, type: .diarize)
    }

    // MARK: - Sharing

    /// Create share link (requires username to be set)
    /// - Throws: usernameRequired (412) if username not set
    func createShareLink(sessionId: String) async throws -> ShareLinkResponse {
        try await request("sessions/\(sessionId)/share/link", method: "POST")
    }

    /// Share session to user by their share code
    func shareSessionByCode(sessionId: String, targetShareCode: String, role: ShareRole? = nil) async throws -> ShareResponse {
        let body = try encoder.encode(ShareUserCodeRequest(shareCode: targetShareCode, role: role))
        return try await request("sessions/\(sessionId)/share/user", method: "POST", body: body)
    }

    /// Invite session member by userId (resolved from username search)
    func inviteSessionMember(sessionId: String, userId: String, role: ShareRole? = nil) async throws -> SessionMember {
        let body = try encoder.encode(SessionMemberInviteRequest(userId: userId, role: role))
        return try await request("sessions/\(sessionId)/share:invite", method: "POST", body: body)
    }

    /// Accept a share invitation
    func acceptShare(shareToken: String) async throws -> ShareResponse {
        try await request("share/\(shareToken)/join", method: "POST")
    }

    // MARK: - Reactions

    /// Set reaction for session (replaces existing)
    func sendReaction(sessionId: String, type: ReactionType) async throws {
        let body = try encoder.encode(SetReactionRequest(emoji: type.rawValue))
        let _: ReactionStateResponse = try await request("sessions/\(sessionId)/reaction", method: "PUT", body: body)
    }

    /// Remove reaction
    func removeReaction(sessionId: String) async throws {
        let body = try encoder.encode(SetReactionRequest(emoji: nil))
        let _: ReactionStateResponse = try await request("sessions/\(sessionId)/reaction", method: "PUT", body: body)
    }

    /// Get reactions for session
    func getReactions(sessionId: String) async throws -> ReactionsResponse {
        let response: ReactionStateResponse = try await request("sessions/\(sessionId)/reaction")
        let summary = ReactionsSummary.fromCounts(response.counts ?? [:])
        let myReaction = response.myEmoji.flatMap(ReactionType.init(rawValue:))
        return ReactionsResponse(myReaction: myReaction, summary: summary)
    }
}

// MARK: - Response Types

struct EmptyResponse: Decodable {}

struct ImportYouTubeRequest: Encodable {
    let url: String
    let mode: SessionType
    let title: String?
    let language: String?
}

struct ImportYouTubeResponse: Decodable {
    let sessionId: String
    let transcriptStatus: String?
    let summaryStatus: String?
    let quizStatus: String?

    private enum SnakeCaseKeys: String, CodingKey {
        case sessionId = "session_id"
        case transcriptStatus = "transcript_status"
        case summaryStatus = "summary_status"
        case quizStatus = "quiz_status"
    }

    private enum CamelCaseKeys: String, CodingKey {
        case sessionId
        case transcriptStatus
        case summaryStatus
        case quizStatus
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: SnakeCaseKeys.self),
           let id = try? container.decode(String.self, forKey: .sessionId) {
            sessionId = id
            transcriptStatus = try? container.decode(String.self, forKey: .transcriptStatus)
            summaryStatus = try? container.decode(String.self, forKey: .summaryStatus)
            quizStatus = try? container.decode(String.self, forKey: .quizStatus)
            return
        }
        let container = try decoder.container(keyedBy: CamelCaseKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        transcriptStatus = try? container.decode(String.self, forKey: .transcriptStatus)
        summaryStatus = try? container.decode(String.self, forKey: .summaryStatus)
        quizStatus = try? container.decode(String.self, forKey: .quizStatus)
    }
}

struct ShareCodeResponse: Decodable {
    let shareCode: String

    private enum SnakeCaseKeys: String, CodingKey {
        case shareCode = "share_code"
    }

    private enum CamelCaseKeys: String, CodingKey {
        case shareCode
    }

    init(from decoder: Decoder) throws {
        // Try snake_case first (API convention)
        if let container = try? decoder.container(keyedBy: SnakeCaseKeys.self),
           let code = try? container.decode(String.self, forKey: .shareCode) {
            self.shareCode = code
            return
        }
        // Fallback to camelCase
        let container = try decoder.container(keyedBy: CamelCaseKeys.self)
        self.shareCode = try container.decode(String.self, forKey: .shareCode)
    }
}

enum ShareRole: String, Encodable, CaseIterable, Hashable {
    case viewer
    case editor
}

struct ShareUserCodeRequest: Encodable {
    let shareCode: String
    let role: ShareRole?
}

struct SessionMemberInviteRequest: Encodable {
    let userId: String
    let role: ShareRole?
}

struct ShareLinkResponse: Decodable {
    let url: String
}

struct ShareResponse: Decodable {
    let sessionId: String
    let sharedUserIds: [String]
}

struct SignedCompressedAudioResponse: Decodable {
    let audioUrl: URL
    let expiresAt: Date
    let compressionMetadata: AudioMeta
}

struct ReactionsResponse {
    let myReaction: ReactionType?
    let summary: ReactionsSummary
}

struct ReactionStateResponse: Decodable {
    let myEmoji: String?
    let counts: [String: Int]?
}

struct SetReactionRequest: Encodable {
    let emoji: String?
}

enum AudioStatus: String, Decodable {
    case pending
    case uploading
    case uploaded
    case processing
    case ready
    case failed
    case expired
    case unknown
}

struct AudioMeta: Codable {
    let variant: String?
    let codec: String
    let container: String
    let sampleRate: Int
    let channels: Int
    let sizeBytes: Int
    let payloadSha256: String
    let bitrate: Int?
    let durationSec: Double?
    let originalSha256: String?
}

struct AudioPrepareRequest: Encodable {
    let contentType: String
    let durationSec: Double?
    let sampleRate: Int?
    let bitrate: Int?
    let codec: String?
    let appVersion: String?
}

struct AudioPrepareResponse: Decodable {
    let uploadUrl: URL
    let method: String
    let headers: [String: String]
    let storagePath: String?
    let deleteAfterAt: Date?
}

struct AudioCommitRequest: Encodable {
    let storagePath: String?
    let sizeBytes: Int?
    let contentType: String?
    let durationSec: Double?
    let metadata: AudioMeta?
    let expectedSizeBytes: Int
    let expectedPayloadSha256: String
}

struct AudioCommitResponse: Decodable {
    let status: AudioStatus
    let deleteAfterAt: Date?
}

struct ImageUploadUrlRequest: Encodable {
    let contentType: String
}

struct ImageUploadUrlResponse: Decodable {
    let imageId: String
    let uploadUrl: URL
    let storagePath: String?
    let method: String?
    let headers: [String: String]?
}

struct ImageNoteDTO: Decodable {
    let id: String
    let url: URL
    let createdAt: Date?
}

enum JobType: String, Encodable {
    case summary
    case quiz
    case explain
    case playlist
    case calendarSync = "calendar_sync"
    case transcribe
    case generateHighlights = "generate_highlights"
    case diarize
    case translate
    case qa
}

struct JobRequest: Encodable {
    let type: JobType
    let params: [String: String]
    let idempotencyKey: String?

    init(type: JobType, params: [String: String] = [:], idempotencyKey: String? = nil) {
        self.type = type
        self.params = params
        self.idempotencyKey = idempotencyKey
    }
}

struct JobResponse: Decodable {
    let jobId: String
    let type: String
    let status: String
    let createdAt: Date
    let errorReason: String?
}

struct PublicUser: Decodable {
    let uid: String
    let displayName: String?
    let username: String?
    let email: String?
    let photoUrl: URL?
}
