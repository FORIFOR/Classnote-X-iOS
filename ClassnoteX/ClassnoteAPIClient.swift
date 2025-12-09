import Foundation

// MARK: - Diarization Status

enum DiarizationStatus: String, Codable {
    case none = "none"
    case pending = "pending"
    case processing = "processing"
    case done = "done"
    case failed = "failed"
    
    var displayText: String {
        switch self {
        case .none: return "未処理"
        case .pending: return "待機中..."
        case .processing: return "処理中..."
        case .done: return "完了"
        case .failed: return "失敗"
        }
    }
    
    var isLoading: Bool {
        self == .pending || self == .processing
    }
}

// MARK: - Speaker (話者情報)

struct Speaker: Codable, Identifiable, Equatable {
    let id: String          // "spk_0", "spk_1"
    let label: String       // "A", "B"
    let displayName: String // "話者A"
    let colorHex: String?   // "#FFADAD" (optional, UI can decide)
    
    enum CodingKeys: String, CodingKey {
        case id, label
        case displayName = "display_name"
        case colorHex = "color_hex"
    }
    
    init(id: String, label: String, displayName: String, colorHex: String? = nil) {
        self.id = id
        self.label = label
        self.displayName = displayName
        self.colorHex = colorHex
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // ID is usually required, but let's be safe
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        // Label fallback
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? "?"
        // DisplayName fallback to label or empty
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? label
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
    }
    
    // Default colors for speakers
    static let defaultColors: [String] = [
        "#5E97F6", // Blue
        "#9C6ADE", // Purple
        "#F19837", // Orange
        "#47B881", // Green
        "#EC4C47", // Red
        "#14B5D0", // Cyan
        "#F7B955", // Yellow
        "#8E8E93"  // Gray
    ]
    
    var color: String {
        colorHex ?? Speaker.defaultColors[abs(id.hashValue) % Speaker.defaultColors.count]
    }
}

// MARK: - Diarized Segment (話者分離済みセグメント)

struct DiarizedSegment: Codable, Identifiable, Equatable {
    let id: String
    let start: TimeInterval
    let end: TimeInterval
    let speakerId: String
    let text: String
    
    enum CodingKeys: String, CodingKey {
        case id, start, end, text
        case speakerId = "speaker_id"
    }
    
    var duration: TimeInterval {
        end - start
    }
}

// MARK: - Speaker Stats (話者ごとの統計)

struct SpeakerStats: Codable {
    let speakerId: String
    let totalDuration: TimeInterval
    let segmentCount: Int
    let wordCount: Int
    
    enum CodingKeys: String, CodingKey {
        case speakerId = "speaker_id"
        case totalDuration = "total_duration"
        case segmentCount = "segment_count"
        case wordCount = "word_count"
    }
    
    var formattedDuration: String {
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Legacy Speaker Segment (互換性のため残す)

struct SpeakerSegment: Codable, Identifiable {
    var id: String { "\(speaker)-\(start)" }
    let speaker: String
    let speakerName: String?
    let start: Double
    let end: Double
    let text: String
    
    enum CodingKeys: String, CodingKey {
        case speaker, speakerName = "speaker_name", start, end, text
    }
}

// MARK: - Action Item (会議モード用)

struct ActionItem: Codable, Identifiable {
    var id: String { "\(assignee)-\(task)" }
    let assignee: String
    let task: String
    let due: String?
}

// MARK: - Meeting Summary (会議モード用)

struct MeetingSummary: Codable {
    let overview: String
    let participants: [String]
    let decisions: [String]
    let actionItems: [ActionItem]
    let nextSteps: String?
    
    enum CodingKeys: String, CodingKey {
        case overview, participants, decisions
        case actionItems = "action_items"
        case nextSteps = "next_steps"
    }
}

// MARK: - Lecture Summary (講義モード用)

struct LectureSummary: Codable {
    let overview: String
    let keyPoints: [String]
    let keywords: [String]
    let questionsToReview: [String]
    
    enum CodingKeys: String, CodingKey {
        case overview
        case keyPoints = "key_points"
        case keywords
        case questionsToReview = "questions_to_review"
    }
}

// MARK: - Chapter Marker (YouTube-style chapters)

struct ChapterMarker: Codable, Identifiable, Equatable {
    let id: String
    let timeSeconds: Double
    let title: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case timeSeconds = "time_seconds"
        case title
    }
    
    init(id: String = UUID().uuidString, timeSeconds: Double, title: String) {
        self.id = id
        self.timeSeconds = timeSeconds
        self.title = title
    }
}

// MARK: - Session Tag (ハッシュタグ)

struct SessionTag: Codable, Identifiable, Equatable {
    let id: String
    let text: String            // Max 10 chars
    let score: Double?          // AI confidence
    let isUserAdded: Bool       // Manual vs AI-generated
    
    enum CodingKeys: String, CodingKey {
        case id, text, score
        case isUserAdded = "is_user_added"
    }
    
    init(id: String = UUID().uuidString, text: String, score: Double? = nil, isUserAdded: Bool = false) {
        self.id = id
        // Trim to 10 chars max
        self.text = String(text.prefix(10))
        self.score = score
        self.isUserAdded = isUserAdded
    }
}

// MARK: - Meeting Decision (決定事項)

struct MeetingDecision: Codable, Identifiable {
    let id: String
    let content: String
    var assignee: String?
    var dueDate: Date?
    let timeStart: Double
    let timeEnd: Double
    let chapterId: String?
    
    enum CodingKeys: String, CodingKey {
        case id, content, assignee
        case dueDate = "due_date"
        case timeStart = "time_start"
        case timeEnd = "time_end"
        case chapterId = "chapter_id"
    }
    
    init(id: String = UUID().uuidString, content: String, assignee: String? = nil, dueDate: Date? = nil, timeStart: Double, timeEnd: Double, chapterId: String? = nil) {
        self.id = id
        self.content = content
        self.assignee = assignee
        self.dueDate = dueDate
        self.timeStart = timeStart
        self.timeEnd = timeEnd
        self.chapterId = chapterId
    }
}

// MARK: - Meeting Task (ToDo)

struct MeetingTask: Codable, Identifiable {
    let id: String
    var title: String
    var assignee: String?
    var dueDate: Date?
    var priority: Int           // 1-5 stars
    var isCompleted: Bool
    let relatedDecisionId: String?
    let timeSeconds: Double
    
    enum CodingKeys: String, CodingKey {
        case id, title, assignee, priority
        case dueDate = "due_date"
        case isCompleted = "is_completed"
        case relatedDecisionId = "related_decision_id"
        case timeSeconds = "time_seconds"
    }
    
    init(id: String = UUID().uuidString, title: String, assignee: String? = nil, dueDate: Date? = nil, priority: Int = 3, isCompleted: Bool = false, relatedDecisionId: String? = nil, timeSeconds: Double = 0) {
        self.id = id
        self.title = title
        self.assignee = assignee
        self.dueDate = dueDate
        self.priority = min(max(priority, 1), 5)
        self.isCompleted = isCompleted
        self.relatedDecisionId = relatedDecisionId
        self.timeSeconds = timeSeconds
    }
}

// MARK: - AI Timeline Tag (タイムライン上のAIタグ)

enum AITagType: String, Codable, CaseIterable {
    case decision = "決定"
    case todo = "ToDo"
    case topic = "論点"
    case question = "質問"
    case casual = "雑談"
    
    var icon: String {
        switch self {
        case .decision: return "checkmark.seal.fill"
        case .todo: return "checklist"
        case .topic: return "lightbulb.fill"
        case .question: return "questionmark.bubble.fill"
        case .casual: return "bubble.left.and.bubble.right.fill"
        }
    }
    
    var color: String {
        switch self {
        case .decision: return "blue"
        case .todo: return "red"
        case .topic: return "orange"
        case .question: return "green"
        case .casual: return "gray"
        }
    }
}

struct AITimelineTag: Codable, Identifiable {
    let id: String
    let type: AITagType
    let timeSeconds: Double
    let text: String
    
    enum CodingKeys: String, CodingKey {
        case id, type, text
        case timeSeconds = "time_seconds"
    }
    
    init(id: String = UUID().uuidString, type: AITagType, timeSeconds: Double, text: String) {
        self.id = id
        self.type = type
        self.timeSeconds = timeSeconds
        self.text = text
    }
}

// MARK: - Session

struct Session: Decodable, Identifiable {
    let id: String
    let title: String
    let mode: String
    let status: String
    let transcriptText: String?
    let summary: String?  // Legacy: raw markdown
    let quizMarkdown: String?
    let createdAt: Date?
    
    // Speaker segments for meeting mode (legacy)
    let segments: [SpeakerSegment]?
    
    // Structured summaries
    let meetingSummary: MeetingSummary?
    let lectureSummary: LectureSummary?
    
    // YouTube-style chapter markers
    let chapters: [ChapterMarker]
    
    // Hashtags
    let tags: [SessionTag]
    
    // Meeting mode: Decisions & Tasks
    let decisions: [MeetingDecision]
    let tasks: [MeetingTask]
    
    // AI Timeline tags
    let aiTags: [AITimelineTag]
    
    // ========== Diarization (NEW) ==========
    let diarizationStatus: DiarizationStatus
    let speakers: [Speaker]
    let diarizedSegments: [DiarizedSegment]
    let speakerStats: [SpeakerStats]
    let audioUrl: String?
    let userNote: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, mode, status, transcriptText, createdAt
        case summary, summaryMarkdown, quizMarkdown
        case segments, chapters, tags, decisions, tasks
        case meetingSummary = "meeting_summary"
        case lectureSummary = "lecture_summary"
        case aiTags = "ai_tags"
        // Diarization
        case diarizationStatus = "diarization_status"
        case speakers
        case diarizedSegments = "diarized_segments"
        case speakerStats = "speaker_stats"
        case audioUrl = "audio_url"
        case userNote = "user_note"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled"
        mode = try container.decodeIfPresent(String.self, forKey: .mode) ?? "lecture"
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        transcriptText = try container.decodeIfPresent(String.self, forKey: .transcriptText)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        quizMarkdown = try container.decodeIfPresent(String.self, forKey: .quizMarkdown)
        segments = try container.decodeIfPresent([SpeakerSegment].self, forKey: .segments)
        meetingSummary = try container.decodeIfPresent(MeetingSummary.self, forKey: .meetingSummary)
        lectureSummary = try container.decodeIfPresent(LectureSummary.self, forKey: .lectureSummary)
        chapters = try container.decodeIfPresent([ChapterMarker].self, forKey: .chapters) ?? []
        tags = try container.decodeIfPresent([SessionTag].self, forKey: .tags) ?? []
        decisions = try container.decodeIfPresent([MeetingDecision].self, forKey: .decisions) ?? []
        tasks = try container.decodeIfPresent([MeetingTask].self, forKey: .tasks) ?? []
        aiTags = try container.decodeIfPresent([AITimelineTag].self, forKey: .aiTags) ?? []
        
        // Diarization fields (with defaults for backward compatibility)
        if let statusString = try container.decodeIfPresent(String.self, forKey: .diarizationStatus) {
            diarizationStatus = DiarizationStatus(rawValue: statusString) ?? .none
        } else {
            diarizationStatus = .none
        }
        speakers = try container.decodeIfPresent([Speaker].self, forKey: .speakers) ?? []
        diarizedSegments = try container.decodeIfPresent([DiarizedSegment].self, forKey: .diarizedSegments) ?? []
        speakerStats = try container.decodeIfPresent([SpeakerStats].self, forKey: .speakerStats) ?? []
        audioUrl = try container.decodeIfPresent(String.self, forKey: .audioUrl)
        userNote = try container.decodeIfPresent(String.self, forKey: .userNote)
        
        // Try both field names for summary
        if let s = try container.decodeIfPresent(String.self, forKey: .summary) {
            summary = s
        } else if let sm = try container.decodeIfPresent(String.self, forKey: .summaryMarkdown) {
            summary = sm
        } else {
            summary = nil
        }
    }
    
    // Manual init for creating copies
    init(id: String, title: String, mode: String, status: String, transcriptText: String?, summary: String?, quizMarkdown: String?, createdAt: Date?, segments: [SpeakerSegment]? = nil, meetingSummary: MeetingSummary? = nil, lectureSummary: LectureSummary? = nil, chapters: [ChapterMarker] = [], tags: [SessionTag] = [], decisions: [MeetingDecision] = [], tasks: [MeetingTask] = [], aiTags: [AITimelineTag] = [], diarizationStatus: DiarizationStatus = .none, speakers: [Speaker] = [], diarizedSegments: [DiarizedSegment] = [], speakerStats: [SpeakerStats] = [], audioUrl: String? = nil, userNote: String? = nil) {
        self.id = id
        self.title = title
        self.mode = mode
        self.status = status
        self.transcriptText = transcriptText
        self.summary = summary
        self.quizMarkdown = quizMarkdown
        self.createdAt = createdAt
        self.segments = segments
        self.meetingSummary = meetingSummary
        self.lectureSummary = lectureSummary
        self.chapters = chapters
        self.tags = tags
        self.decisions = decisions
        self.tasks = tasks
        self.aiTags = aiTags
        self.diarizationStatus = diarizationStatus
        self.speakers = speakers
        self.diarizedSegments = diarizedSegments
        self.speakerStats = speakerStats
        self.audioUrl = audioUrl
        self.userNote = userNote
    }
    
    // Helper: Check if diarization is available
    var hasDiarization: Bool {
        diarizationStatus == .done && !diarizedSegments.isEmpty
    }
    
    // Helper: Get speaker by ID
    func speaker(byId id: String) -> Speaker? {
        speakers.first { $0.id == id }
    }
    
    // Create a copy with modified fields
    func copyingSession(
        title: String? = nil,
        status: String? = nil,
        transcriptText: String? = nil,
        summary: String? = nil,
        quizMarkdown: String? = nil,
        userNote: String? = nil
    ) -> Session {
        Session(
            id: id,
            title: title ?? self.title,
            mode: mode,
            status: status ?? self.status,
            transcriptText: transcriptText ?? self.transcriptText,
            summary: summary ?? self.summary,
            quizMarkdown: quizMarkdown ?? self.quizMarkdown,
            createdAt: createdAt,
            segments: segments,
            meetingSummary: meetingSummary,
            lectureSummary: lectureSummary,
            chapters: chapters,
            tags: tags,
            decisions: decisions,
            tasks: tasks,
            aiTags: aiTags,
            diarizationStatus: diarizationStatus,
            speakers: speakers,
            diarizedSegments: diarizedSegments,
            speakerStats: speakerStats,
            audioUrl: audioUrl,
            userNote: userNote ?? self.userNote
        )
    }
}

struct SessionListResponse: Decodable {
    let sessions: [Session]
}

final class ClassnoteAPIClient {
    let baseURL: URL
    private let decoder: JSONDecoder

    init(baseURL: URL) {
        self.baseURL = baseURL
        self.decoder = JSONDecoder()
        
        // Custom date decoder for multiple formats
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            
            // Format 1: ISO8601 with fractional seconds (microseconds from Python)
            // e.g. "2025-12-06T20:36:09.471551"
            let formatter1 = DateFormatter()
            formatter1.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
            formatter1.locale = Locale(identifier: "en_US_POSIX")
            formatter1.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = formatter1.date(from: string) { return date }
            
            // Format 2: ISO8601 with milliseconds
            // e.g. "2025-12-06T20:36:09.471"
            let formatter2 = DateFormatter()
            formatter2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
            formatter2.locale = Locale(identifier: "en_US_POSIX")
            formatter2.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = formatter2.date(from: string) { return date }
            
            // Format 3: Standard ISO8601
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: string) { return date }
            
            // Format 4: ISO8601 without fractional seconds
            let iso2 = ISO8601DateFormatter()
            if let date = iso2.date(from: string) { return date }
            
            print("[API] Failed to parse date: \(string)")
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
    }

    func healthCheck() async throws {
        let url = baseURL.appendingPathComponent("health")
        let (_, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - Mock Fallback (Temporary)
    private var mockStore: [String: Session] = [:]
    
    // GET /sessions?userId=...
    func getSessions(userId: String) async throws -> [Session] {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent("sessions"), resolvingAgainstBaseURL: true) else {
            throw URLError(.badURL)
        }
        comps.queryItems = [URLQueryItem(name: "userId", value: userId)]
        guard let url = comps.url else { throw URLError(.badURL) }
        
        print("[API] GET \(url)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let http = response as? HTTPURLResponse {
                print("[API] Response status: \(http.statusCode)")
                
                if http.statusCode == 405 || http.statusCode == 404 {
                    print("[API] GET /sessions failed with \(http.statusCode). Falling back to mock.")
                    throw URLError(.badServerResponse)
                }
            }
            
            // Debug: log response preview
            if let responseStr = String(data: data, encoding: .utf8) {
                print("[API] Response preview: \(responseStr.prefix(200))")
            }
            
            // Try decoding as array first (most backends return this)
            do {
                let sessions = try decoder.decode([Session].self, from: data)
                print("[API] ✅ Decoded \(sessions.count) sessions from array")
                return sessions
            } catch let arrayError {
                print("[API] Array decode failed: \(arrayError)")
                
                // Try as { "sessions": [...] } wrapper
                do {
                    let wrapped = try decoder.decode(SessionListResponse.self, from: data)
                    print("[API] ✅ Decoded \(wrapped.sessions.count) sessions from wrapper")
                    return wrapped.sessions
                } catch let wrapperError {
                    print("[API] Wrapper decode failed: \(wrapperError)")
                    throw arrayError
                }
            }
        } catch {
            print("[API] Returning local mock sessions due to error: \(error)")
            // Return sorted mock sessions
            return mockStore.values.sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
        }
    }

    func createSession(title: String, mode: String, userId: String) async throws -> Session {
        let url = baseURL.appendingPathComponent("sessions")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Body: Encodable { let title: String; let mode: String; let userId: String }
        req.httpBody = try JSONEncoder().encode(Body(title: title, mode: mode, userId: userId))

        let (data, _) = try await URLSession.shared.data(for: req)
        let session = try decoder.decode(Session.self, from: data)
        
        // Save to mock store
        var storedSession = session
        // Force status to recording just in case
        // storedSession.status = "recording" 
        mockStore[session.id] = storedSession
        return session
    }

    func getSession(id: String) async throws -> Session {
        // Handle local-* session IDs (created when API was unreachable)
        if id.hasPrefix("local-") {
            if let local = mockStore[id] {
                // Check if enough time has passed to "complete" transcription
                if let created = local.createdAt, Date().timeIntervalSince(created) > 5 {
                    if local.status == "recording" {
                        let updated = Session(
                            id: local.id,
                            title: local.title,
                            mode: local.mode,
                            status: "transcribed",
                            transcriptText: "【ローカル録音】\nバックエンドに接続できなかったため、ローカル音声認識のみで動作しました。\n\n実際の文字起こし結果はアプリ画面に表示されていたものをご確認ください。",
                            summary: "【オフライン録音】\nサーバー未接続状態での録音が完了しました。音声認識はデバイス上で処理されました。",
                            quizMarkdown: "### 理解度チェック（モック）\n\n1. この録音はどこで処理されましたか？\n- [x] デバイス上（オンデバイス）\n- [ ] クラウドサーバー",
                            createdAt: local.createdAt
                        )
                        mockStore[id] = updated
                        return updated
                    }
                }
                return local
            } else {
                // Create a new mock entry for this local session
                let newSession = Session(
                    id: id,
                    title: "ローカル録音",
                    mode: "lecture",
                    status: "recording",
                    transcriptText: nil,
                    summary: nil,
                    quizMarkdown: nil,
                    createdAt: Date()
                )
                mockStore[id] = newSession
                print("[API] Created mock entry for local session: \(id)")
                return newSession
            }
        }
        
        // Regular mock store lookup
        if var local = mockStore[id] {
            // If it's been > 5 seconds since creation, pretend it's transcribed
            if let created = local.createdAt, Date().timeIntervalSince(created) > 8 {
                if local.status == "recording" {
                    // Update to transcribed with dummy text
                    let updated = Session(
                        id: local.id,
                        title: local.title,
                        mode: local.mode,
                        status: "transcribed",
                        transcriptText: "これはモックの文字起こしテキストです。\nサーバーからの取得が404エラーのため、クライアント側でシミュレートしています。\n\n本来であれば、ここにWebSocketで送信された音声の認識結果が表示されます。",
                        summary: "【モック要約】\nバックエンド接続エラー時のフォールバック表示です。録音は正常に開始されました。",
                        quizMarkdown: "### モックテスト\n1. このアプリの目的は？\n- [ ] 録音\n- [ ] メモ\n- [x] 両方",
                        createdAt: local.createdAt
                    )
                    mockStore[id] = updated
                    return updated
                }
            }
            return local
        }
        
        // Try Real API
        let url = baseURL.appendingPathComponent("sessions/\(id)")
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
             // If not in mock store (e.g. fresh launch) and 404, we can't do much. 
             // But if we just created it, it should be in mockStore.
             throw URLError(.badServerResponse)
        }
        
        return try decoder.decode(Session.self, from: data)
    }

    private func makeURL(_ path: String, queries: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true) else {
            throw URLError(.badURL)
        }
        if !queries.isEmpty {
            components.queryItems = queries
        }
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    func downloadURL(path: String, id: String) throws -> URL {
        try makeURL(path, queries: [.init(name: "id", value: id)])
    }
    
    // MARK: - Local File Helpers
    
    /// Try to find a local recording file for a given session ID
    /// Matches format: "lecture_{timestamp}.wav" or straightforward file name check
    func findLocalAudioFile(sessionId: String, createdAt: Date?) -> URL? {
        print("[API] Looking for local audio for session: \(sessionId)")
        let fileManager = FileManager.default
        guard let docDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let recordingsDir = docDir.appendingPathComponent("Recordings")
        
        // 1. If we have a timestamp, try to match the filename format: lecture_yyyyMMdd_HHmmss.wav
        // This is a heuristic since we don't have the exact filename stored in Session
        if let date = createdAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let dateStr = formatter.string(from: date)
            
            // Allow for slight time differences (e.g. +/- 2 seconds) just in case
            for offset in -2...2 {
                let adjDate = date.addingTimeInterval(TimeInterval(offset))
                let adjStr = formatter.string(from: adjDate)
                let candidate = recordingsDir.appendingPathComponent("lecture_\(adjStr).wav")
                if fileManager.fileExists(atPath: candidate.path) {
                    print("[API] ✅ Found local file by timestamp: \(candidate.lastPathComponent)")
                    return candidate
                }
            }
        }
        
        // 2. Fallback: Search all wav files in Recordings directory and sort by modification date
        // If the session was created recently, it might be the newest file.
        // This is risky if there are many files, but OK for fallback.
        do {
            let files = try fileManager.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)
            let wavs = files.filter { $0.pathExtension == "wav" }
            
            // Sort by modification date descending
            let sorted = wavs.sorted {
                let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return d1 > d2
            }
            
            // Check if closest file matches our session creation time within reasonable margin (e.g. 1 minute)
            if let date = createdAt {
                 for file in sorted {
                    if let modDate = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                       abs(modDate.timeIntervalSince(date)) < 60 {
                        print("[API] ✅ Found local file by proximity: \(file.lastPathComponent)")
                        return file
                    }
                 }
            }
        } catch {
            print("[API] Failed to list local recordings: \(error)")
        }
        
        return nil
    }


    
    struct SummarizeAPIResponse: Decodable {
        let summary: Summary?
    }

    func summarize(sessionId: String, token: String?) async throws -> SummarizeAPIResponse {
        print("[API] ========== SUMMARIZE REQUEST ==========")
        print("[API] Session ID: \(sessionId)")
        
        let url = baseURL.appendingPathComponent("sessions/\(sessionId)/summarize")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Mock fallback check
        if let local = mockStore[sessionId], let summaryStr = local.summary {
            // For mock, we return a Summary struct constructed from the string
            // This is a simplification; in reality we'd parse the markdown
            let mockSummary = Summary(overview: summaryStr, points: [], keywords: [])
            return SummarizeAPIResponse(summary: mockSummary)
        }
        
        print("[API] POST \(url)")
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        if let http = response as? HTTPURLResponse {
            print("[API] Response status: \(http.statusCode)")
            if http.statusCode == 200 {
                return try decoder.decode(SummarizeAPIResponse.self, from: data)
            } else {
                let responseText = String(data: data, encoding: .utf8) ?? "N/A"
                print("[API] ⚠️ Non-200 response: \(responseText.prefix(200))")
                throw URLError(.badServerResponse)
            }
        }
        
        throw URLError(.badServerResponse)
    }

    
    private func meetingFallbackSummary() -> String {
        return """
## 📋 会議サマリー

### 📝 概要
この会議の文字起こしに基づいて、AIが要約を生成します。
バックエンドAPIが接続されると、以下の情報が自動で抽出されます。

### ✅ 決定事項
• バックエンド接続後に自動抽出されます

### 📌 ToDo / アクションアイテム
| 担当者 | タスク | 期限 |
|--------|--------|------|
| - | バックエンド接続が必要です | - |

### 🎯 次のステップ
• APIエンドポイントの実装後、自動で要約が生成されます

---
*このサマリーはGLASSNOTE-X AIによって生成されます*
"""
    }
    
    private func lectureFallbackSummary() -> String {
        return """
## 📚 講義サマリー

### 🎯 この講義のポイント
バックエンドAPIが接続されると、講義内容から重要なポイントが自動抽出されます。

### 📖 主なトピック
1. **トピック1** - 詳細はAPI接続後に表示
2. **トピック2** - 詳細はAPI接続後に表示
3. **トピック3** - 詳細はAPI接続後に表示

### 💡 キーワード
`キーワード1` `キーワード2` `キーワード3`

### ❓ 復習用の質問
- [ ] 主要な概念を説明できますか？
- [ ] 具体例を挙げられますか？
- [ ] 他の知識との関連性は？

### 📝 補足情報
バックエンドの要約エンドポイントが実装されると、AIが以下を自動生成します：
• 講義の構造的なまとめ
• 重要用語と定義
• 試験対策用のポイント

---
*このサマリーはGLASSNOTE-X AIによって生成されます*
"""
    }

    func quiz(id: String, count: Int) async throws -> String {
        print("[API] ========== QUIZ REQUEST ==========")
        print("[API] Session ID: \(id)")
        print("[API] Question count: \(count)")
        
        // Fallback
        if let local = mockStore[id], local.quizMarkdown != nil {
            print("[API] ✅ Found cached quiz in mockStore")
            return local.quizMarkdown!
        }
        print("[API] No cached quiz in mockStore, calling backend...")
        
        let url = baseURL.appendingPathComponent("sessions/\(id)/quiz")
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: true) else { throw URLError(.badURL) }
        comps.queryItems = [URLQueryItem(name: "count", value: "\(count)")]
        guard let fullURL = comps.url else { throw URLError(.badURL) }
        
        var req = URLRequest(url: fullURL)
        req.httpMethod = "POST"
        
        print("[API] POST \(fullURL)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            
            if let http = response as? HTTPURLResponse {
                print("[API] Response status: \(http.statusCode)")
                
                if http.statusCode == 200 {
                    struct Resp: Decodable { let quizMarkdown: String }
                    let decoded = try decoder.decode(Resp.self, from: data)
                    print("[API] ✅ Quiz received from backend (\(decoded.quizMarkdown.count) chars)")
                    return decoded.quizMarkdown
                } else {
                    let responseText = String(data: data, encoding: .utf8) ?? "N/A"
                    print("[API] ⚠️ Non-200 response: \(responseText.prefix(200))")
                }
            }
            
            // Decode anyway in case it worked
            struct Resp: Decodable { let quizMarkdown: String }
            return try decoder.decode(Resp.self, from: data).quizMarkdown
        } catch {
            print("[API] ❌ Quiz error: \(error)")
            return "### モック小テスト\n\nQ1. バックエンド接続は成功しましたか？\n- [ ] はい\n- [x] いいえ (GETメソッドが未実装のようです)"
        }
    }
    
    // MARK: - Session Note
    
    func updateUserNote(sessionId: String, note: String) async throws {
        print("[API] ========== UPDATE NOTE ==========")
        print("[API] Session ID: \(sessionId)")
        print("[API] Note length: \(note.count) chars")
        
        // Mock update
        if var local = mockStore[sessionId] {
            let updated = Session(
                id: local.id,
                title: local.title,
                mode: local.mode,
                status: local.status,
                transcriptText: local.transcriptText,
                summary: local.summary,
                quizMarkdown: local.quizMarkdown,
                createdAt: local.createdAt,
                segments: local.segments,
                meetingSummary: local.meetingSummary,
                lectureSummary: local.lectureSummary,
                chapters: local.chapters,
                tags: local.tags,
                decisions: local.decisions,
                tasks: local.tasks,
                aiTags: local.aiTags,
                diarizationStatus: local.diarizationStatus,
                speakers: local.speakers,
                diarizedSegments: local.diarizedSegments,
                speakerStats: local.speakerStats,
                audioUrl: local.audioUrl,
                userNote: note
            )
            mockStore[sessionId] = updated
            print("[API] ✅ Mock store updated with new note")
            return
        }
        
        // Real API call
        let url = baseURL.appendingPathComponent("sessions/\(sessionId)/note")
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct NoteUpdate: Encodable {
            let note: String
        }
        req.httpBody = try JSONEncoder().encode(NoteUpdate(note: note))
        
        print("[API] PATCH \(url)")
        
        let (_, response) = try await URLSession.shared.data(for: req)
        
        if let http = response as? HTTPURLResponse {
            print("[API] Response status: \(http.statusCode)")
            guard (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
        }
        
        print("[API] ✅ Note updated successfully on server")
    }

    // MARK: - Transcript Upload
    
    /// Upload final transcript text to server after recording stops
    func uploadTranscript(sessionId: String, text: String) async throws {
        print("[API] Uploading transcript for session: \(sessionId)")
        print("[API] Transcript length: \(text.count) characters")
        
        let url = baseURL.appendingPathComponent("sessions/\(sessionId)/transcript")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct TranscriptBody: Encodable {
            let transcriptText: String
        }
        req.httpBody = try JSONEncoder().encode(TranscriptBody(transcriptText: text))
        
        let (data, response) = try await URLSession.shared.data(for: req)
        
        if let http = response as? HTTPURLResponse {
            print("[API] Upload response status: \(http.statusCode)")
            
            if http.statusCode == 404 {
                // Endpoint not implemented yet - store locally
                print("[API] ⚠️ POST /sessions/{id}/transcript not implemented, storing locally")
                if var local = mockStore[sessionId] {
                    let updated = Session(
                        id: local.id,
                        title: local.title,
                        mode: local.mode,
                        status: "transcribed",
                        transcriptText: text,
                        summary: nil,
                        quizMarkdown: nil,
                        createdAt: local.createdAt
                    )
                    mockStore[sessionId] = updated
                }
                return
            }
            
            guard (200..<300).contains(http.statusCode) else {
                print("[API] ❌ Upload failed with status: \(http.statusCode)")
                throw URLError(.badServerResponse)
            }
        }
        
        print("[API] ✅ Transcript uploaded successfully")
    }
    
    /// Update local mock store with transcript (for offline mode)
    func storeTranscriptLocally(sessionId: String, text: String) {
        if mockStore[sessionId] != nil {
            let local = mockStore[sessionId]!
            let updated = Session(
                id: local.id,
                title: local.title,
                mode: local.mode,
                status: "transcribed",
                transcriptText: text,
                summary: nil,
                quizMarkdown: nil,
                createdAt: local.createdAt
            )
            mockStore[sessionId] = updated
            print("[API] Stored transcript locally for: \(sessionId)")
        }
    }
    
    // MARK: - Chapter Storage (Local)
    
    /// Store chapters locally for a session
    func storeChaptersLocally(sessionId: String, chapters: [ChapterMarker]) {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docDir.appendingPathComponent("chapters_\(sessionId).json")
        
        do {
            let data = try JSONEncoder().encode(chapters)
            try data.write(to: fileURL)
            print("[API] 💾 Stored \(chapters.count) chapters locally for: \(sessionId)")
        } catch {
            print("[API] ❌ Failed to store chapters: \(error)")
        }
    }
    
    /// Load chapters from local storage
    func loadLocalChapters(sessionId: String) -> [ChapterMarker] {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docDir.appendingPathComponent("chapters_\(sessionId).json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("[API] No local chapters found for: \(sessionId)")
            return []
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let chapters = try JSONDecoder().decode([ChapterMarker].self, from: data)
            print("[API] 📖 Loaded \(chapters.count) local chapters for: \(sessionId)")
            return chapters
        } catch {
            print("[API] ❌ Failed to load chapters: \(error)")
            return []
        }
    }
    
    /// Store transcript segments locally
    func storeSegmentsLocally(sessionId: String, segments: [TranscriptSegment]) {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docDir.appendingPathComponent("segments_\(sessionId).json")
        
        do {
            let data = try JSONEncoder().encode(segments)
            try data.write(to: fileURL)
            print("[API] 💾 Stored \(segments.count) segments locally for: \(sessionId)")
        } catch {
            print("[API] ❌ Failed to store segments: \(error)")
        }
    }
    
    /// Load segments from local storage
    func loadLocalSegments(sessionId: String) -> [TranscriptSegment] {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docDir.appendingPathComponent("segments_\(sessionId).json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([TranscriptSegment].self, from: data)
        } catch {
            print("[API] ❌ Failed to load segments: \(error)")
            return []
        }
    }
    
    // MARK: - Delete Session
    
    func deleteSession(id: String) async throws {
        let url = baseURL.appendingPathComponent("sessions/\(id)")
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        
        print("[API] DELETE \(url)")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if http.statusCode == 200 || http.statusCode == 204 {
                print("[API] ✅ Session deleted: \(id)")
                mockStore.removeValue(forKey: id)
            } else if http.statusCode == 404 {
                // Already deleted, treat as success
                print("[API] Session not found (already deleted?): \(id)")
                mockStore.removeValue(forKey: id)
            } else {
                print("[API] ❌ Delete failed with status: \(http.statusCode)")
                throw URLError(.badServerResponse)
            }
        } catch {
            print("[API] Delete error: \(error)")
            // Still remove from local mock store
            mockStore.removeValue(forKey: id)
        }
    }
    
    func batchDeleteSessions(ids: [String]) async throws {
        print("[API] Batch deleting \(ids.count) sessions...")
        
        // Try batch endpoint first
        let url = baseURL.appendingPathComponent("sessions/batch_delete")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["ids": ids])
        
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 || http.statusCode == 204 {
                print("[API] ✅ Batch delete successful")
                ids.forEach { mockStore.removeValue(forKey: $0) }
                return
            }
        } catch {
            print("[API] Batch endpoint not available, falling back to individual deletes")
        }
        
        // Fallback: delete one by one
        for id in ids {
            try? await deleteSession(id: id)
        }
    }
    
    // MARK: - Chapter Generation
    
    func generateChapters(sessionId: String) async throws -> [ChapterMarker] {
        let url = baseURL.appendingPathComponent("sessions/\(sessionId)/chapters/generate")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("[API] POST \(url) - Generate chapters")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if http.statusCode == 200 {
                struct ChaptersResponse: Decodable {
                    let chapters: [ChapterMarker]
                }
                let result = try decoder.decode(ChaptersResponse.self, from: data)
                print("[API] ✅ Generated \(result.chapters.count) chapters")
                return result.chapters
            } else {
                print("[API] ❌ Chapter generation failed: \(http.statusCode)")
                throw URLError(.badServerResponse)
            }
        } catch {
            print("[API] Chapter generation error: \(error)")
            // Return empty array on failure (feature gracefully degrades)
            return []
        }
    }
    
    // MARK: - Update Session Title
    
    func updateSessionTitle(sessionId: String, title: String) async throws {
        let url = baseURL.appendingPathComponent("sessions/\(sessionId)")
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct TitleUpdateBody: Encodable {
            let title: String
        }
        req.httpBody = try JSONEncoder().encode(TitleUpdateBody(title: title))
        
        print("[API] PATCH \(url) - Update title to: \(title)")
        
        let (_, response) = try await URLSession.shared.data(for: req)
        
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 200 || http.statusCode == 204 {
                print("[API] ✅ Title updated successfully")
                // Update local mock store
                if var local = mockStore[sessionId] {
                    let updated = Session(
                        id: local.id,
                        title: title,
                        mode: local.mode,
                        status: local.status,
                        transcriptText: local.transcriptText,
                        summary: local.summary,
                        quizMarkdown: local.quizMarkdown,
                        createdAt: local.createdAt,
                        segments: local.segments,
                        meetingSummary: local.meetingSummary,
                        lectureSummary: local.lectureSummary,
                        chapters: local.chapters,
                        tags: local.tags,
                        decisions: local.decisions,
                        tasks: local.tasks,
                        aiTags: local.aiTags
                    )
                    mockStore[sessionId] = updated
                }
            } else {
                print("[API] ❌ Title update failed: \(http.statusCode)")
                throw URLError(.badServerResponse)
            }
        }
    }
    
    // MARK: - Diarization
    
    /// Trigger speaker diarization for a session
    /// POST /sessions/{id}/diarize
    func triggerDiarization(sessionId: String, force: Bool = false) async throws -> DiarizationStatus {
        print("[API] ========== TRIGGER DIARIZATION ==========")
        print("[API] Session ID: \(sessionId)")
        print("[API] Force: \(force)")
        
        let url = baseURL.appendingPathComponent("sessions/\(sessionId)/diarize")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct DiarizeRequest: Encodable {
            let force: Bool
        }
        req.httpBody = try JSONEncoder().encode(DiarizeRequest(force: force))
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            
            if let http = response as? HTTPURLResponse {
                print("[API] Response status: \(http.statusCode)")
                
                switch http.statusCode {
                case 200, 202:
                    // Already done or accepted for processing
                    struct DiarizeResponse: Decodable {
                        let status: String
                        let message: String?
                    }
                    let resp = try decoder.decode(DiarizeResponse.self, from: data)
                    let status = DiarizationStatus(rawValue: resp.status) ?? .pending
                    print("[API] ✅ Diarization status: \(status.displayText)")
                    return status
                    
                case 409:
                    // Already processing
                    print("[API] ⚠️ Diarization already in progress")
                    return .processing
                    
                default:
                    let responseText = String(data: data, encoding: .utf8) ?? "N/A"
                    print("[API] ❌ Diarization failed: \(responseText.prefix(200))")
                    throw URLError(.badServerResponse)
                }
            }
            return .failed
        } catch {
            print("[API] ❌ Diarization error: \(error)")
            throw error
        }
    }
    
    /// Poll diarization status
    func getDiarizationStatus(sessionId: String) async throws -> DiarizationStatus {
        let session = try await getSession(id: sessionId)
        return session.diarizationStatus
    }
    
    /// Get session with diarization data
    func getSessionWithDiarization(id: String) async throws -> Session {
        print("[API] GET /sessions/\(id)?include=diarization")
        
        let url = baseURL.appendingPathComponent("sessions/\(id)")
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw URLError(.badURL)
        }
        comps.queryItems = [URLQueryItem(name: "include", value: "diarization")]
        
        guard let fullURL = comps.url else { throw URLError(.badURL) }
        
        let (data, _) = try await URLSession.shared.data(from: fullURL)
        return try decoder.decode(Session.self, from: data)
    }
}
