import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import UIKit

extension DocumentSnapshot {
    /// FirestoreドキュメントをCodableモデルにデコードしつつdocumentIDを注入
    func decoded<T: Decodable>(_ type: T.Type = T.self) throws -> T {
        var raw = self.data() ?? [:]
        raw["id"] = self.documentID
        let normalized = Self.normalize(raw)

        let jsonData = try JSONSerialization.data(withJSONObject: normalized, options: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = Self.iso8601Fractional.date(from: string) ?? Self.iso8601.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(string)")
        }
        return try decoder.decode(T.self, from: jsonData)
    }

    private static func normalize(_ value: Any) -> Any {
        if let timestamp = value as? Timestamp {
            return iso8601Fractional.string(from: timestamp.dateValue())
        } else if let date = value as? Date {
            return iso8601Fractional.string(from: date)
        } else if let dict = value as? [String: Any] {
            return dict.mapValues { normalize($0) }
        } else if let array = value as? [Any] {
            return array.map { normalize($0) }
        } else {
            return value
        }
    }

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

extension Encodable {
    /// CodableモデルをFirestoreへ保存可能な辞書へ変換（idは含めない）
    func toFirestoreData() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(self)
        let jsonObject = try JSONSerialization.jsonObject(with: encoded, options: [])
        guard var dict = jsonObject as? [String: Any] else {
            throw NSError(domain: "FirestoreEncoding", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        }
        dict.removeValue(forKey: "id")
        return dict
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var shouldShowRecordingSheet: Bool = false
    @Published var userEmail: String = ""
    @Published var baseURLString: String {
        didSet { Task { await updateBaseURL() } }
    }
    @Published var colorScheme: ColorSchemeSetting = .system {
        didSet { UserDefaults.standard.set(colorScheme.rawValue, forKey: "colorSchemeSetting") }
    }
    @Published var lectures: [SessionItem] = []
    @Published var meetings: [SessionItem] = []
    @Published var selectedMode: SessionMode = .lecture
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var transcriptStatus: [String: String] = [:]
    @Published var transcriptText: [String: String] = [:]
    @Published var summaryCache: [String: Summary] = [:]
    @Published var isSummarizing: [String: Bool] = [:]
    @Published var isRefreshing: [String: Bool] = [:]
    @Published var googleAccessToken: String?
    @Published var firebaseIdToken: String?
    @Published var liveSegments: [String: [RealtimeSegment]] = [:]
    @Published var livePartial: [String: RealtimeSegment] = [:]
    @Published var liveSessionId: String?
    @Published var quizCache: [String: [QuizQuestion]] = [:]
    @Published var liveLines: [LiveLine] = []
    @Published var liveCurrentText: String = ""
    // Cloud Run と一致させるサンプルレート（LINEAR16 16kHz）
    private let streamingSampleRate: Int = 16_000
    @Published var qaHistories: [String: [QAItem]] = [:]
    @Published var isAskingQA: [String: Bool] = [:]
    @Published var selectedTab: Int = 0  // 0: Home, 1: Sessions, 2: Calendar, 3: Settings

    let recordingModel = FileRecordingModel()

    private let firebase = FirebaseManager.shared
    private var cloudAPI: CloudAPIClient
    private var cancellables = Set<AnyCancellable>()
    private var lectureListener: ListenerRegistration?
    private var meetingListener: ListenerRegistration?
    private let realtimeClient = RealtimeTranscriptionClient()
    private var liveSessionTitle: String?
    private var liveSessionMode: SessionMode?

    init() {
        let storedURL = UserDefaults.standard.string(forKey: "baseURL") ?? "https://YOUR_CLOUD_RUN_URL"
        self.baseURLString = storedURL
        self.cloudAPI = CloudAPIClient(baseURL: URL(string: storedURL) ?? URL(string: "https://YOUR_CLOUD_RUN_URL")!)
        if let storedScheme = UserDefaults.standard.string(forKey: "colorSchemeSetting"),
           let scheme = ColorSchemeSetting(rawValue: storedScheme) {
            self.colorScheme = scheme
        }
        self.isAuthenticated = firebase.user != nil
        self.userEmail = firebase.user?.email ?? ""

        firebase.$user
            .receive(on: RunLoop.main)
            .sink { [weak self] user in
                guard let self else { return }
                self.isAuthenticated = user != nil
                self.userEmail = user?.email ?? ""
                if user != nil {
                    self.startListeners()
                } else {
                    self.stopListeners()
                }
            }
            .store(in: &cancellables)

        realtimeClient.onSegment = { [weak self] seg in
            Task { @MainActor in
                guard let self else { return }
                // 従来のセグメント保持
                if seg.isFinal {
                    var list = self.liveSegments[seg.sessionId] ?? []
                    list.append(seg)
                    self.liveSegments[seg.sessionId] = list
                    self.livePartial.removeValue(forKey: seg.sessionId)
                } else {
                    self.livePartial[seg.sessionId] = seg
                }
                // ライブ字幕用（partial を liveCurrentText、final を liveLines に）
                if seg.isFinal {
                    let speakerTag = seg.words.first?.speakerTag ?? 0
                    let line = LiveLine(text: seg.transcript,
                                        speakerTag: speakerTag,
                                        isFinal: true,
                                        timestamp: Date())
                    self.liveLines.append(line)
                    self.liveCurrentText = ""
                } else {
                    self.liveCurrentText = seg.transcript
                }
            }
        }
    }

    /// ホーム画面から即座に録音を開始するためのメソッド
    func startRecordingFromHome() {
        // 1. UIを即座に反応させる
        shouldShowRecordingSheet = true
        
        // 2. ローカル録音を即座に開始
        // Haptic feedback is triggered by the button in View
        recordingModel.startRecording()
        
        // 3. 非同期でクラウドセッションを開始（失敗してもローカル録音は継続）
        // デフォルト設定: 講義モード、タイトルは日時ベース
        let mode = SessionMode.lecture 
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        let title = "\(formatter.string(from: Date())) 講義"
        
        Task {
            await startLiveSessionAsync(title: title, mode: mode) { success in
                if !success {
                    // エラーハンドリング（必要ならバナー表示など）
                    print("[AppModel] Background cloud session start failed")
                }
            }
        }
    }

    func updateBaseURL() async {
        guard let url = URL(string: baseURLString) else {
            errorMessage = "バックエンドURLが不正です"
            return
        }
        await cloudAPI.updateBaseURL(url)
        UserDefaults.standard.set(baseURLString, forKey: "baseURL")
    }

    func signInEmail(email: String, password: String) async {
        do {
            try await firebase.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithGoogle() async {
        print("[Auth] ========== GOOGLE SIGN-IN STARTED ==========")
        
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })?
            .keyWindow?
            .rootViewController else {
            print("[Auth] ❌ Failed to get rootViewController")
            errorMessage = "ログイン画面を取得できませんでした"
            return
        }
        
        print("[Auth] ✅ Got rootViewController: \(type(of: rootVC))")
        
        do {
            print("[Auth] Calling GIDSignIn.sharedInstance.signIn...")
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootVC,
                hint: nil,
                additionalScopes: ["https://www.googleapis.com/auth/calendar.readonly"]
            )
            
            print("[Auth] ✅ GIDSignIn completed")
            print("[Auth] User email: \(result.user.profile?.email ?? "nil")")
            
            guard let idToken = result.user.idToken?.tokenString else {
                print("[Auth] ❌ IDToken is nil")
                throw NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "IDトークンが取得できませんでした"])
            }
            
            print("[Auth] ✅ Got IDToken (length: \(idToken.count))")
            
            let accessToken = result.user.accessToken.tokenString
            print("[Auth] ✅ Got AccessToken (length: \(accessToken.count))")
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            print("[Auth] Signing in to Firebase...")
            
            let authResult = try await Auth.auth().signIn(with: credential)
            print("[Auth] ✅ Firebase signIn successful")
            print("[Auth] Firebase UID: \(authResult.user.uid)")
            print("[Auth] Firebase email: \(authResult.user.email ?? "nil")")
            
            googleAccessToken = accessToken
            isAuthenticated = true
            userEmail = firebase.user?.email ?? ""
            
            print("[Auth] ✅ isAuthenticated = true")
            print("[Auth] ========== GOOGLE SIGN-IN COMPLETE ==========")
            
            startListeners()
        } catch {
            print("[Auth] ❌ Error: \(error)")
            print("[Auth] Error domain: \((error as NSError).domain)")
            print("[Auth] Error code: \((error as NSError).code)")
            errorMessage = error.localizedDescription
        }
    }

    func signUpEmail(email: String, password: String) async {
        do {
            try await firebase.signUp(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        print("[Auth] ========== SIGN OUT STARTED ==========")
        print("[Auth] Current isAuthenticated: \(isAuthenticated)")
        print("[Auth] Current userEmail: \(userEmail)")
        
        do {
            print("[Auth] Calling firebase.signOut()...")
            try firebase.signOut()
            print("[Auth] ✅ Firebase signOut completed")
            
            print("[Auth] Calling GIDSignIn.sharedInstance.signOut()...")
            GIDSignIn.sharedInstance.signOut()
            print("[Auth] ✅ Google signOut completed")
            
            print("[Auth] Resetting local state...")
            isAuthenticated = false
            userEmail = ""
            googleAccessToken = nil
            
            print("[Auth] Stopping listeners...")
            stopListeners()
            
            print("[Auth] ✅ isAuthenticated = \(isAuthenticated)")
            print("[Auth] ========== SIGN OUT COMPLETE ==========")
        } catch {
            print("[Auth] ❌ SignOut error: \(error)")
            errorMessage = error.localizedDescription
        }
    }

    func startListeners() {
        stopListeners()
        guard let userId = firebase.user?.uid else { return }
        let db = Firestore.firestore()
        lectureListener = db.collection("lectures")
            .whereField("ownerId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error { Task { @MainActor in self.errorMessage = error.localizedDescription } ; return }
                guard let docs = snapshot?.documents else { return }
                let items = docs.compactMap { try? $0.decoded(SessionItem.self) }
                Task { @MainActor in self.lectures = items }
            }
        meetingListener = db.collection("meetings")
            .whereField("ownerId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error { Task { @MainActor in self.errorMessage = error.localizedDescription } ; return }
                guard let docs = snapshot?.documents else { return }
                let items = docs.compactMap { try? $0.decoded(SessionItem.self) }
                Task { @MainActor in self.meetings = items }
            }
    }

    func stopListeners() {
        lectureListener?.remove()
        lectureListener = nil
        meetingListener?.remove()
        meetingListener = nil
    }
    
    // MARK: - REST API Session Reload (replaces Firestore listeners)
    
    /// Fetches sessions from Cloud Run API instead of Firestore
    func reloadSessionsFromAPI() async {
        print("[AppModel] ========== RELOAD SESSIONS FROM API ==========")
        let userId = userEmail.isEmpty ? "guest" : userEmail
        print("[AppModel] User ID: \(userId)")
        
        let apiClient = ClassnoteAPIClient(
            baseURL: URL(string: "https://classnote-api-900324644592.asia-northeast1.run.app")!
        )
        
        do {
            let sessions = try await apiClient.getSessions(userId: userId)
            print("[AppModel] ✅ Fetched \(sessions.count) sessions from API")
            
            // Convert Session to SessionItem and split by mode
            var lectureItems: [SessionItem] = []
            var meetingItems: [SessionItem] = []
            
            for session in sessions {
                let item = SessionItem(
                    id: session.id,
                    ownerId: userId,
                    mode: session.mode,
                    title: session.title,
                    createdAt: session.createdAt,
                    audioPath: nil,
                    transcriptPath: nil,
                    status: session.status,
                    durationSec: nil,
                    summary: nil,
                    participants: nil,
                    segments: nil
                )
                
                if session.mode == "meeting" {
                    meetingItems.append(item)
                } else {
                    lectureItems.append(item)
                }
            }
            
            // Sort by createdAt descending
            lectureItems.sort { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            meetingItems.sort { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            
            self.lectures = lectureItems
            self.meetings = meetingItems
            
            print("[AppModel] lectures count: \(lectureItems.count)")
            print("[AppModel] meetings count: \(meetingItems.count)")
            
            for (i, lecture) in lectureItems.prefix(3).enumerated() {
                print("[AppModel]   Lecture \(i+1): id=\(lecture.id), title=\(lecture.title ?? "nil")")
            }
        } catch {
            print("[AppModel] ❌ Failed to fetch sessions: \(error)")
            errorMessage = "セッションの取得に失敗しました"
        }
        
        print("[AppModel] ========== END ==========")
    }

    func startLiveSession(title: String, mode: SessionMode) async -> Bool {
        do {
            let token = try await firebase.idToken()
            firebaseIdToken = token
            guard let uid = firebase.user?.uid else {
                errorMessage = "ユーザー情報が取得できません"
                print("[AppModel] startLiveSession failed: missing uid")
                return false
            }
            print("[AppModel] startLiveSession request: title=\(title), mode=\(mode.rawValue), uid=\(uid)")
            let session = try await cloudAPI.createSession(mode: mode, title: title, userId: uid, token: token)
            print("[AppModel] session created: id=\(session.id)")
            liveSessionId = session.id
            liveSessionTitle = title
            liveSessionMode = mode
            liveSegments[session.id] = []
            liveLines = []
            liveCurrentText = ""

            guard let wsURL = makeWebSocketURL(sessionId: session.id, token: token) else {
                errorMessage = "WebSocket URLが不正です"
                print("[AppModel] invalid WebSocket URL for session \(session.id)")
                return false
            }
            realtimeClient.connect(url: wsURL, languageCode: "ja-JP", speakerCount: 2, sampleRate: streamingSampleRate, model: "default")
            recordingModel.onChunk = { [weak self] data in
                self?.realtimeClient.sendAudioChunk(data)
            }
            print("[AppModel] WebSocket connected for session \(session.id)")
            return true
        } catch {
            errorMessage = error.localizedDescription
            print("[AppModel] startLiveSession error: \(error)")
            return false
        }
    }

    /// UIをブロックしないための非同期版。完了時にコールバックで成功/失敗を返す。
    func startLiveSessionAsync(title: String, mode: SessionMode, completion: @escaping (Bool) -> Void) async {
        let currentUID = firebase.user?.uid
        let baseURL = baseURLString
        Task.detached {
            do {
                guard let uid = currentUID else {
                    await MainActor.run {
                        self.errorMessage = "ユーザー情報が取得できません"
                        completion(false)
                    }
                    return
                }
                let token = try await self.firebase.idToken()
                print("[AppModel] (async) startLiveSession request: title=\(title), mode=\(mode.rawValue), uid=\(uid)")
                let session = try await self.cloudAPI.createSession(mode: mode, title: title, userId: uid, token: token)
                print("[AppModel] (async) session created: id=\(session.id)")

                await MainActor.run {
                    self.liveSessionId = session.id
                    self.liveSessionTitle = title
                    self.liveSessionMode = mode
                    self.liveSegments[session.id] = []
                    self.liveLines = []
                    self.liveCurrentText = ""

                    guard let wsURL = self.makeWebSocketURL(sessionId: session.id, token: token) else {
                        self.errorMessage = "WebSocket URLが不正です"
                        print("[AppModel] invalid WebSocket URL for session \(session.id)")
                        completion(false)
                        return
                    }
                    print("[AppModel] (async) connecting WebSocket: \(wsURL)")
                    self.realtimeClient.connect(url: wsURL, languageCode: "ja-JP", speakerCount: 2, sampleRate: self.streamingSampleRate, model: "default")
                    self.recordingModel.onChunk = { [weak self] data in
                        print("[AppModel] send audio chunk: \(data.count) bytes")
                        self?.realtimeClient.sendAudioChunk(data)
                    }
                    print("[AppModel] (async) WebSocket connected for session \(session.id)")
                    completion(true)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    print("[AppModel] (async) startLiveSession error: \(error)")
                    completion(false)
                }
            }
        }
    }

    func stopLiveSession(title: String, mode: SessionMode) async {
        let sessionId = liveSessionId
        print("[AppModel] stopLiveSession begin. sessionId=\(sessionId ?? "nil")")
        recordingModel.onChunk = nil
        realtimeClient.sendStop()
        realtimeClient.disconnect()
        await createAndUploadSession(title: title, mode: mode, sessionId: sessionId)
        liveSessionId = nil
        liveSessionTitle = nil
        liveSessionMode = nil
        liveCurrentText = ""
        liveLines = []
        print("[AppModel] stopLiveSession complete.")
    }

    private func makeWebSocketURL(sessionId: String, token: String) -> URL? {
        guard var comps = URLComponents(string: baseURLString) else { return nil }
        comps.scheme = (comps.scheme == "https") ? "wss" : "ws"
        comps.path = "/ws/stream/\(sessionId)"
        comps.queryItems = [URLQueryItem(name: "token", value: token)]
        return comps.url
    }

    func createAndUploadSession(title: String, mode: SessionMode, sessionId: String? = nil) async {
        guard let fileURL = recordingModel.recordedFileURL else {
            errorMessage = "録音ファイルが見つかりません"
            print("[AppModel] upload skipped: file not found")
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let token = try await firebase.idToken()
            let sessionIdToUse: String
            if let sessionId {
                sessionIdToUse = sessionId
            } else {
                guard let uid = firebase.user?.uid else {
                    errorMessage = "ユーザー情報が取得できません"
                    print("[AppModel] upload failed: missing uid")
                    return
                }
                print("[AppModel] create session for upload: title=\(title), mode=\(mode.rawValue), uid=\(uid)")
                let session = try await cloudAPI.createSession(mode: mode, title: title, userId: uid, token: token)
                sessionIdToUse = session.id
            }
            print("[AppModel] upload start: sessionId=\(sessionIdToUse)")
            let upload = try await cloudAPI.uploadURL(sessionId: sessionIdToUse, mode: mode, contentType: "audio/wav", token: token)
            guard let uploadURL = upload.resolvedURL, let signedURL = URL(string: uploadURL) else {
                throw NSError(domain: "UploadURL", code: -1, userInfo: [NSLocalizedDescriptionKey: "アップロードURLが取得できませんでした"])
            }

            // 重いI/Oをバックグラウンドで実行し、UIフリーズを防ぐ
            let fileURLCopy = fileURL
            let cloudAPI = self.cloudAPI
            try await Task.detached(priority: .utility) {
                let data = try Data(contentsOf: fileURLCopy)
                try await cloudAPI.putSignedURL(url: signedURL, data: data, contentType: "audio/wav")
            }.value

            try await cloudAPI.startTranscribe(sessionId: sessionIdToUse, mode: mode, token: token)
            print("[AppModel] upload + startTranscribe succeeded for session \(sessionIdToUse)")
            Task { @MainActor in
                await self.pollTranscript(sessionId: sessionIdToUse, attempts: 8, delaySec: 4)
                if self.summaryCache[sessionIdToUse] == nil {
                    await self.summarize(sessionId: sessionIdToUse)
                }
                if self.quizCache[sessionIdToUse] == nil {
                    _ = await self.fetchQuiz(sessionId: sessionIdToUse, count: 5)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            print("[AppModel] createAndUploadSession error: \(error)")
        }
    }

    func refreshTranscript(sessionId: String) async {
        isRefreshing[sessionId] = true
        defer { isRefreshing[sessionId] = false }
        do {
            let token = try await firebase.idToken()
            let resp = try await cloudAPI.refreshTranscript(sessionId: sessionId, token: token)
            if let status = resp.status {
                transcriptStatus[sessionId] = status
            }
            if let text = resp.transcriptText, !text.isEmpty {
                transcriptText[sessionId] = text
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pollTranscript(sessionId: String, attempts: Int = 6, delaySec: UInt64 = 3) async {
        for _ in 0..<attempts {
            await refreshTranscript(sessionId: sessionId)
            if let text = transcriptText[sessionId], !text.isEmpty { break }
            try? await Task.sleep(nanoseconds: delaySec * 1_000_000_000)
        }
    }

    func summarize(sessionId: String) async {
        isSummarizing[sessionId] = true
        defer { isSummarizing[sessionId] = false }
        do {
            let token = try await firebase.idToken()
            let resp = try await cloudAPI.summarize(sessionId: sessionId, token: token)
            if let summary = resp.summary {
                summaryCache[sessionId] = summary
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchQuiz(sessionId: String, count: Int) async -> Bool {
        do {
            let token = try await firebase.idToken()
            let resp = try await cloudAPI.generateQuiz(sessionId: sessionId, count: count, token: token)
            quizCache[sessionId] = resp.questions
            return true
        } catch {
            errorMessage = error.localizedDescription
            print("[AppModel] fetchQuiz error: \(error)")
            return false
        }
    }

    func askQuestion(sessionId: String, question: String) async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isAskingQA[sessionId] = true
        defer { isAskingQA[sessionId] = false }
        do {
            let token = try await firebase.idToken()
            let resp = try await cloudAPI.askQuestion(sessionId: sessionId, question: trimmed, token: token)
            let answer = resp.answer ?? "回答を取得できませんでした。"
            var history = qaHistories[sessionId] ?? []
            history.append(QAItem(question: trimmed, answer: answer, createdAt: Date()))
            qaHistories[sessionId] = history
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    func addNote(_ text: String, at timeSec: Double, to sessionId: String) {
        // Update local memory for lectures
        if let idx = lectures.firstIndex(where: { $0.wrappedId == sessionId }) {
            var notes = lectures[idx].localNotes ?? []
            notes.append(SessionNote(timeSec: timeSec, text: text))
            lectures[idx].localNotes = notes
        }
        // Update local memory for meetings
        if let idx = meetings.firstIndex(where: { $0.wrappedId == sessionId }) {
            var notes = meetings[idx].localNotes ?? []
            notes.append(SessionNote(timeSec: timeSec, text: text))
            meetings[idx].localNotes = notes
        }
        
        // TODO: Persist to backend or local storage
        // For now, this is in-memory in AppModel, but since AppModel is not persistent across launches (unless we save it),
        // these notes will disappear on restart. 
        // We really should save to UserDefaults or FileSystem if backend API isn't ready.
        // But for "dummy ok", in-memory is the bare minimum.
    }
    
    func session(for id: String) -> SessionItem? {
        lectures.first(where: { $0.wrappedId == id }) ?? meetings.first(where: { $0.wrappedId == id })
    }
}

enum ColorSchemeSetting: String, CaseIterable, Identifiable {
    case light, dark, system
    var id: String { rawValue }
}

struct SessionItem: Codable, Identifiable {
    var id: String
    let ownerId: String?
    let mode: String?
    let title: String?
    let createdAt: Date?
    let audioPath: String?
    let transcriptPath: String?
    let status: String?
    let durationSec: Double?
    let summary: Summary?
    let participants: [Participant]?
    let segments: [Segment]?
    var localNotes: [SessionNote]? // Local-only notes for now

    enum CodingKeys: String, CodingKey {
        case ownerId
        case mode
        case title
        case createdAt
        case audioPath
        case transcriptPath
        case status
        case durationSec
        case summary
        case participants
        case segments
    }

    var wrappedId: String { id }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId)
        mode = try container.decodeIfPresent(String.self, forKey: .mode)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        audioPath = try container.decodeIfPresent(String.self, forKey: .audioPath)
        transcriptPath = try container.decodeIfPresent(String.self, forKey: .transcriptPath)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        durationSec = try container.decodeIfPresent(Double.self, forKey: .durationSec)
        summary = try container.decodeIfPresent(Summary.self, forKey: .summary)
        participants = try container.decodeIfPresent([Participant].self, forKey: .participants)
        segments = try container.decodeIfPresent([Segment].self, forKey: .segments)

        let idContainer = try decoder.container(keyedBy: AdditionalKeys.self)
        id = (try? idContainer.decode(String.self, forKey: .id)) ?? UUID().uuidString
    }
    
    /// Memberwise initializer for programmatic creation
    init(
        id: String,
        ownerId: String?,
        mode: String?,
        title: String?,
        createdAt: Date?,
        audioPath: String?,
        transcriptPath: String?,
        status: String?,
        durationSec: Double?,
        summary: Summary?,
        participants: [Participant]?,
        segments: [Segment]?
    ) {
        self.id = id
        self.ownerId = ownerId
        self.mode = mode
        self.title = title
        self.createdAt = createdAt
        self.audioPath = audioPath
        self.transcriptPath = transcriptPath
        self.status = status
        self.durationSec = durationSec
        self.summary = summary
        self.participants = participants
        self.segments = segments
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(ownerId, forKey: .ownerId)
        try container.encodeIfPresent(mode, forKey: .mode)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(audioPath, forKey: .audioPath)
        try container.encodeIfPresent(transcriptPath, forKey: .transcriptPath)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(durationSec, forKey: .durationSec)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encodeIfPresent(participants, forKey: .participants)
        try container.encodeIfPresent(segments, forKey: .segments)
    }

    private enum AdditionalKeys: String, CodingKey {
        case id
    }
}

struct Summary: Codable {
    let overview: String?
    let points: [String]?
    let keywords: [String]?
}

struct Participant: Codable, Identifiable {
    var id: String { name ?? UUID().uuidString }
    let tag: Int?
    let name: String?
}

struct Segment: Codable, Identifiable {
    var id: String { "\(speakerTag ?? 0)-\(startSec ?? 0)" }
    let speakerTag: Int?
    let startSec: Double?
    let endSec: Double?
    let text: String?
}
