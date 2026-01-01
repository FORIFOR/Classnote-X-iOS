import Foundation

// MARK: - API DTOs & Domain Models

// MARK: - Enums
enum AuthProvider: String, Codable {
    case google, apple, line
}

enum SessionType: String, Codable, CaseIterable {
    case lecture
    case meeting
    
    var label: String {
        switch self {
        case .lecture: return "Lecture"
        case .meeting: return "Meeting"
        }
    }
}

enum SessionStatus: String, Codable {
    case recording
    case processing
    case ready
    case failed
    case unknown
}

enum ReactionType: String, Codable, CaseIterable, Identifiable {
    case fire = "🔥"
    case clap = "👏"
    case angel = "😇"
    case mindblown = "🤯"
    case love = "🫶"

    var id: String { rawValue }

    /// The emoji character for this reaction
    var emoji: String { rawValue }
}

// MARK: - User
struct User: Identifiable, Decodable, Equatable {
    let id: String // uid
    let email: String?
    let provider: AuthProvider?
    let plan: String?
    let username: String?
    let usernameLower: String?
    let usernameSetAt: Date?  // Immutability tracking: once set, cannot change
    let displayNameStored: String?
    let photoURL: URL?
    let createdAt: Date?
    let updatedAt: Date?
    let hasUsernameFlag: Bool?

    // UI Helpers
    var displayName: String {
        if let displayNameStored, !displayNameStored.isEmpty {
            return displayNameStored
        }
        if let username, !username.isEmpty {
            return username
        }
        if let email, let prefix = email.components(separatedBy: "@").first, !prefix.isEmpty {
            return prefix
        }
        return "User"
    }

    var hasUsername: Bool {
        hasUsernameFlag ?? (username != nil && !username!.isEmpty)
    }

    var initial: String {
        String(displayName.prefix(1)).uppercased()
    }

    private enum CodingKeys: String, CodingKey {
        case id = "uid"
        case idAlt = "id"
        case email
        case provider
        case plan
        case username
        case usernameLower
        case usernameSetAt
        case displayName
        case photoURL
        case photoUrl
        case createdAt
        case updatedAt
        case hasUsername
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decode(String.self, forKey: .idAlt)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        if let providerRaw = try container.decodeIfPresent(String.self, forKey: .provider) {
            provider = AuthProvider(rawValue: providerRaw)
        } else {
            provider = nil
        }
        plan = try container.decodeIfPresent(String.self, forKey: .plan)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        usernameLower = try container.decodeIfPresent(String.self, forKey: .usernameLower)
        usernameSetAt = try container.decodeIfPresent(Date.self, forKey: .usernameSetAt)
        displayNameStored = try container.decodeIfPresent(String.self, forKey: .displayName)
        photoURL = try container.decodeIfPresent(URL.self, forKey: .photoURL)
            ?? container.decodeIfPresent(URL.self, forKey: .photoUrl)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        hasUsernameFlag = try container.decodeIfPresent(Bool.self, forKey: .hasUsername)
    }
}

// MARK: - Session
struct Session: Identifiable, Decodable {
    let id: String // sessionId
    let ownerUid: String?
    let ownerUsername: String?
    let type: SessionType
    var title: String
    let createdAt: Date?
    let startedAt: Date?
    var endedAt: Date?
    var durationSec: Int?
    var status: SessionStatus
    var audioStatus: AudioStatus?
    var audioMeta: AudioMeta?
    var audioPath: String?

    // Content
    var memoText: String?
    var photos: [PhotoRef]?
    var tags: [String]?
    var aiMarkers: [Marker]?

    // AI Status
    var transcript: TranscriptStatus?
    var transcriptText: String?
    var diarizedTranscript: [TranscriptBlock]?
    var summary: SummaryStatus?
    var quiz: QuizStatus?

    // Sharing & Social
    var sharing: SharingInfo?
    var reactionsSummary: ReactionsSummary?
    var members: [SessionMember]?

    // MARK: - UI Helpers

    /// Check if session is owned by the given user ID
    func isMine(uid: String) -> Bool {
        ownerUid == uid
    }

    /// Formatted duration string (returns "--" if unknown)
    var durationFormatted: String {
        guard let durationSec, durationSec > 0 else { return "--" }
        let hours = durationSec / 3600
        let minutes = (durationSec % 3600) / 60
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        }
        return "\(minutes)分"
    }

    /// Status display label (nil for unknown to allow hiding)
    var statusLabel: String? {
        switch status {
        case .recording: return "録音中"
        case .processing: return "処理中"
        case .ready: return "要約済み"
        case .failed: return "失敗"
        case .unknown: return nil
        }
    }

    /// Date formatted for display
    var dateFormatted: String {
        guard let date = startedAt ?? createdAt else { return "--" }
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'今日' HH:mm"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'昨日' HH:mm"
        } else {
            formatter.dateFormat = "M/d HH:mm"
        }
        return formatter.string(from: date)
    }

    /// Helper to check if session has audio
    var hasAudio: Bool {
        if let audioPath, !audioPath.isEmpty { return true }
        if let meta = audioMeta { return true } // Simplified check
        // Check legacy or other flags if needed
        return false
    }

    private enum CodingKeys: String, CodingKey {
        case id = "sessionId"
        case idAlt = "id"
        case ownerUid
        case ownerUsername
        case ownerUserId
        case userId
        case type
        case mode
        case kind
        case title
        case createdAt
        case startedAt
        case endedAt
        case durationSec
        case status
        case audioStatus
        case audioMeta
        case audioPath
        case memoText
        case notes
        case photos
        case tags
        case aiMarkers
        case transcript
        case transcriptText
        case diarizedTranscript
        case summary
        case summaryMarkdown
        case quiz
        case quizMarkdown
        case sharing
        case sharedWithCount
        case sharedUserIds
        case reactionsSummary
        case reactionCounts
        case members
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decode(String.self, forKey: .idAlt)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? createdAt
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        if let durationInt = try container.decodeIfPresent(Int.self, forKey: .durationSec) {
            durationSec = durationInt
        } else if let durationDouble = try container.decodeIfPresent(Double.self, forKey: .durationSec) {
            durationSec = Int(durationDouble)
        } else {
            durationSec = nil
        }

        let statusRaw = try container.decodeIfPresent(String.self, forKey: .status)
        status = statusRaw.flatMap(SessionStatus.init(rawValue:)) ?? .unknown
        audioStatus = try container.decodeIfPresent(AudioStatus.self, forKey: .audioStatus)
        audioMeta = try container.decodeIfPresent(AudioMeta.self, forKey: .audioMeta)
        audioPath = try container.decodeIfPresent(String.self, forKey: .audioPath)

        let modeRaw = try container.decodeIfPresent(String.self, forKey: .type)
            ?? container.decodeIfPresent(String.self, forKey: .mode)
            ?? container.decodeIfPresent(String.self, forKey: .kind)
        type = modeRaw.flatMap(SessionType.init(rawValue:)) ?? .lecture

        ownerUid = try container.decodeIfPresent(String.self, forKey: .ownerUid)
            ?? container.decodeIfPresent(String.self, forKey: .ownerUserId)
            ?? container.decodeIfPresent(String.self, forKey: .userId)
        ownerUsername = try container.decodeIfPresent(String.self, forKey: .ownerUsername)

        memoText = try container.decodeIfPresent(String.self, forKey: .memoText)
            ?? container.decodeIfPresent(String.self, forKey: .notes)
        photos = try container.decodeIfPresent([PhotoRef].self, forKey: .photos)

        if let tagStrings = try container.decodeIfPresent([String].self, forKey: .tags) {
            tags = tagStrings
        } else if let tagMarkers = try container.decodeIfPresent([TagMarker].self, forKey: .tags) {
            tags = tagMarkers.map { $0.label }
        } else {
            tags = nil
        }

        aiMarkers = try container.decodeIfPresent([Marker].self, forKey: .aiMarkers)
        transcriptText = try container.decodeIfPresent(String.self, forKey: .transcriptText)
        diarizedTranscript = try container.decodeIfPresent([TranscriptBlock].self, forKey: .diarizedTranscript)
        transcript = try container.decodeIfPresent(TranscriptStatus.self, forKey: .transcript)
        if transcript == nil, let transcriptText, !transcriptText.isEmpty {
            transcript = TranscriptStatus(hasTranscript: true, text: transcriptText)
        }

        summary = try container.decodeIfPresent(SummaryStatus.self, forKey: .summary)
        if summary == nil, let markdown = try container.decodeIfPresent(String.self, forKey: .summaryMarkdown), !markdown.isEmpty {
            summary = SummaryStatus(hasSummary: true, text: markdown)
        }

        quiz = try container.decodeIfPresent(QuizStatus.self, forKey: .quiz)
        if quiz == nil, let markdown = try container.decodeIfPresent(String.self, forKey: .quizMarkdown), !markdown.isEmpty {
            quiz = QuizStatus(hasQuiz: true, items: nil)
        }

        sharing = try container.decodeIfPresent(SharingInfo.self, forKey: .sharing)
        if sharing == nil {
            let sharedCount = try container.decodeIfPresent(Int.self, forKey: .sharedWithCount)
            let sharedIds = try container.decodeIfPresent([String].self, forKey: .sharedUserIds)
            let count = sharedCount ?? sharedIds?.count ?? 0
            sharing = SharingInfo(isShared: count > 0, shareLinkId: nil, memberCount: count)
        }

        reactionsSummary = try container.decodeIfPresent(ReactionsSummary.self, forKey: .reactionsSummary)
        if reactionsSummary == nil, let reactionCounts = try container.decodeIfPresent([String: Int].self, forKey: .reactionCounts) {
            reactionsSummary = ReactionsSummary.fromCounts(reactionCounts)
        }

        members = try container.decodeIfPresent([SessionMember].self, forKey: .members)
    }
}

extension Session: Hashable {
    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct PhotoRef: Identifiable, Codable, Equatable {
    let id: String
    let url: URL
    let createdAt: Date?
}

struct TagMarker: Identifiable, Codable, Equatable {
    let id: String
    let tSec: Double
    let label: String
    let createdByUid: String
    let createdAt: Date?

    init(id: String, tSec: Double, label: String, createdByUid: String, createdAt: Date? = nil) {
        self.id = id
        self.tSec = tSec
        self.label = label
        self.createdByUid = createdByUid
        self.createdAt = createdAt
    }
}

/// AI-generated markers for playlist/timeline
struct Marker: Identifiable, Codable, Equatable {
    let id: String
    let startSec: Double
    let endSec: Double
    let title: String
    let tags: [String]?

    init(id: String, startSec: Double, endSec: Double, title: String, tags: [String]? = nil) {
        self.id = id
        self.startSec = startSec
        self.endSec = endSec
        self.title = title
        self.tags = tags
    }
}

/// Type alias for clarity
typealias AIMarker = Marker

struct TranscriptStatus: Codable, Equatable {
    let hasTranscript: Bool
    let lang: String?
    let text: String?

    init(hasTranscript: Bool, lang: String? = nil, text: String? = nil) {
        self.hasTranscript = hasTranscript
        self.lang = lang
        self.text = text
    }
}

struct SummaryStatus: Codable, Equatable {
    let hasSummary: Bool
    let text: String?

    init(hasSummary: Bool, text: String? = nil) {
        self.hasSummary = hasSummary
        self.text = text
    }
}

struct QuizStatus: Codable, Equatable {
    let hasQuiz: Bool
    let items: [QuizItem]?

    init(hasQuiz: Bool, items: [QuizItem]? = nil) {
        self.hasQuiz = hasQuiz
        self.items = items
    }
}

struct QuizItem: Identifiable, Codable, Equatable {
    let id: String
    let question: String
    let choices: [String]
    let answerIndex: Int
    let feedback: String?

    init(id: String, question: String, choices: [String], answerIndex: Int, feedback: String? = nil) {
        self.id = id
        self.question = question
        self.choices = choices
        self.answerIndex = answerIndex
        self.feedback = feedback
    }
}

struct SharingInfo: Codable, Equatable {
    let isShared: Bool
    let shareLinkId: String?
    let memberCount: Int

    init(isShared: Bool = false, shareLinkId: String? = nil, memberCount: Int = 0) {
        self.isShared = isShared
        self.shareLinkId = shareLinkId
        self.memberCount = memberCount
    }
}

struct ReactionsSummary: Codable, Equatable {
    let fire: Int
    let clap: Int
    let angel: Int
    let mindblown: Int
    let heartHands: Int

    var isEmpty: Bool {
        fire == 0 && clap == 0 && angel == 0 && mindblown == 0 && heartHands == 0
    }

    var total: Int {
        fire + clap + angel + mindblown + heartHands
    }

    func count(for type: ReactionType) -> Int {
        switch type {
        case .fire: return fire
        case .clap: return clap
        case .angel: return angel
        case .mindblown: return mindblown
        case .love: return heartHands
        }
    }

    static func fromCounts(_ counts: [String: Int]) -> ReactionsSummary {
        let fire = counts["🔥"] ?? 0
        let clap = counts["👏"] ?? 0
        let angel = counts["😇"] ?? 0
        let mindblown = counts["🤯"] ?? 0
        let heartHands = counts["🫶"] ?? 0
        return ReactionsSummary(fire: fire, clap: clap, angel: angel, mindblown: mindblown, heartHands: heartHands)
    }

    static let empty = ReactionsSummary(fire: 0, clap: 0, angel: 0, mindblown: 0, heartHands: 0)
}

struct SessionMember: Identifiable, Decodable, Equatable {
    let id: String
    let username: String
    let role: SessionMemberRole
    let photoURL: URL?

    var initials: String {
        let tokens = username
            .split(separator: "_")
            .flatMap { $0.split(separator: ".") }
            .flatMap { $0.split(separator: "-") }
        let letters = tokens.compactMap { $0.first }
        return String(letters.prefix(2)).uppercased()
    }

    private enum CodingKeys: String, CodingKey {
        case id = "uid"
        case userId
        case username
        case displayNameSnapshot
        case role
        case photoURL
        case photoUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decode(String.self, forKey: .userId)
        let displayName = try container.decodeIfPresent(String.self, forKey: .displayNameSnapshot)
        let username = try container.decodeIfPresent(String.self, forKey: .username)
        self.username = displayName ?? username ?? id
        role = try container.decode(SessionMemberRole.self, forKey: .role)
        photoURL = try container.decodeIfPresent(URL.self, forKey: .photoURL)
            ?? container.decodeIfPresent(URL.self, forKey: .photoUrl)
    }
}

enum SessionMemberRole: String, Codable {
    case owner
    case viewer
}

// MARK: - API Requests/Responses

struct CreateSessionRequest: Encodable {
    let title: String
    let mode: SessionType
}

struct ClaimUsernameRequest: Encodable {
    let username: String
}

struct TranscriptBlock: Identifiable, Codable, Equatable {
    let id: String
    let speaker: String
    let text: String
    let startTime: Double
    let endTime: Double
}
