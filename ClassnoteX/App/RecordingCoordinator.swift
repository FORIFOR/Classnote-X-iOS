import Foundation
import AVFoundation
import Combine
import CryptoKit
import UIKit
import Speech
#if canImport(FFmpegKit)
import FFmpegKit
#elseif canImport(ffmpegkit)
import ffmpegkit
#endif

@MainActor
final class RecordingCoordinator: ObservableObject {
    enum State {
        case idle
        case recording
        case paused
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var audioLevel: Float = 0
    @Published var isSheetPresented: Bool = false
    @Published var showStopConfirm: Bool = false
    @Published var errorMessage: String?
    @Published var completedSession: Session?
    @Published private(set) var currentSession: Session?
    @Published var memoText: String = ""
    @Published var transcriptLines: [TranscriptLine] = []
    @Published var partialTranscript: String = ""
    @Published private(set) var liveTags: [String] = []
    @Published private(set) var isUploading: Bool = false
    @Published private(set) var isStarting: Bool = false
    @Published private(set) var isImporting: Bool = false

    // New: Background and voice activity states for Recording Pill
    @Published private(set) var isInBackground: Bool = false
    @Published private(set) var hasVoiceActivity: Bool = true
    private var voiceActivityTimer: Timer?
    private var lastVoiceActivityTime: Date = Date()
    private let voiceActivityThreshold: Float = 0.02 // Minimum audio level to consider as voice
    private let voiceInactivityTimeout: TimeInterval = 5.0 // Seconds without voice to show warning

    var isActive: Bool { state != .idle }
    var isPaused: Bool { state == .paused }
    var currentMode: SessionType? { sessionType }

    private let recorder = FileRecordingModel()
    private var cancellables = Set<AnyCancellable>()
    private var sessionType: SessionType?
    private var presentSheetOnStart = true
    private var localTags: [String] = []

    init() {
        recorder.$elapsed
            .receive(on: RunLoop.main)
            .assign(to: &$elapsed)

        recorder.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .recording:
                    self.state = .recording
                    self.startVoiceActivityMonitoring()
                case .paused:
                    self.state = .paused
                    self.stopVoiceActivityMonitoring()
                case .idle, .error:
                    self.state = .idle
                    self.isSheetPresented = false
                    self.stopVoiceActivityMonitoring()
                }
            }
            .store(in: &cancellables)

        recorder.$errorMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                guard let self else { return }
                if let message, !message.isEmpty {
                    self.errorMessage = message
                    self.showStopConfirm = false
                }
            }
            .store(in: &cancellables)

        recorder.$partialTranscript
            .receive(on: RunLoop.main)
            .assign(to: &$partialTranscript)

        recorder.onLevel = { [weak self] level in
            self?.audioLevel = level
            self?.updateVoiceActivity(level: level)
        }

        recorder.onFinalTranscript = { [weak self] text in
            guard let self else { return }
            let line = TranscriptLine(text: text, isFinal: true)
            self.transcriptLines.append(line)
        }

        // Subscribe to background/foreground notifications
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isInBackground = true
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isInBackground = false
            }
            .store(in: &cancellables)
    }

    // MARK: - Voice Activity Monitoring

    private func updateVoiceActivity(level: Float) {
        if level > voiceActivityThreshold {
            lastVoiceActivityTime = Date()
            if !hasVoiceActivity {
                hasVoiceActivity = true
            }
        }
    }

    private func startVoiceActivityMonitoring() {
        lastVoiceActivityTime = Date()
        hasVoiceActivity = true
        voiceActivityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkVoiceActivity()
            }
        }
    }

    private func stopVoiceActivityMonitoring() {
        voiceActivityTimer?.invalidate()
        voiceActivityTimer = nil
        hasVoiceActivity = true
    }

    private func checkVoiceActivity() {
        let timeSinceLastVoice = Date().timeIntervalSince(lastVoiceActivityTime)
        let shouldHaveActivity = timeSinceLastVoice < voiceInactivityTimeout
        if hasVoiceActivity != shouldHaveActivity {
            hasVoiceActivity = shouldHaveActivity
        }
    }

    func startRecording(type: SessionType, presentSheet: Bool = true) {
        guard !isActive, !isStarting else {
            if presentSheet {
                isSheetPresented = true
            }
            return
        }

        isStarting = true
        sessionType = type
        presentSheetOnStart = presentSheet

        let audioSession = AVAudioSession.sharedInstance()
        switch audioSession.recordPermission {
        case .granted:
            beginRecording()
        case .denied:
            errorMessage = "マイクの権限がありません。設定から許可してください。"
            isStarting = false
        case .undetermined:
            audioSession.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.beginRecording()
                    } else {
                        self.errorMessage = "マイクの権限がありません。設定から許可してください。"
                        self.isStarting = false
                    }
                }
            }
        @unknown default:
            errorMessage = "マイクの権限確認に失敗しました。"
            isStarting = false
        }
    }

    func togglePause() {
        switch state {
        case .recording:
            recorder.pauseRecording()
        case .paused:
            recorder.resumeRecording()
        case .idle:
            break
        }
    }

    func requestStop() {
        if errorMessage != nil {
            errorMessage = nil
        }
        showStopConfirm = true
    }

    func finishRecording(save: Bool) {
        showStopConfirm = false
        isSheetPresented = false
        recorder.stopRecording()

        guard let session = currentSession else {
            if let url = recorder.recordedFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            reset()
            return
        }

        if save {
            Task { await finalizeSession(session) }
        } else {
            Task { await discardSession(session) }
        }
    }

    func addTag(label: String) {
        guard let session = currentSession else { return }
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            do {
                if !localTags.contains(trimmed) {
                    localTags.append(trimmed)
                    liveTags = localTags
                }
                try await APIClient.shared.updateTags(sessionId: session.id, tags: localTags)
            } catch {
                errorMessage = "タグの追加に失敗しました。"
            }
        }
    }

    func addMemo(_ text: String) {
        guard let session = currentSession else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let timestamp = formatElapsed(elapsed)
        let updated = memoText.isEmpty ? "[\(timestamp)] \(trimmed)" : "\(memoText)\n[\(timestamp)] \(trimmed)"
        memoText = updated

        Task {
            do {
                try await APIClient.shared.updateNotes(sessionId: session.id, notes: updated)
            } catch {
                errorMessage = "メモの保存に失敗しました。"
            }
        }
    }

    func saveMemo() {
        guard let session = currentSession else { return }
        Task {
            do {
                try await APIClient.shared.updateNotes(sessionId: session.id, notes: memoText)
            } catch {
                errorMessage = "メモの保存に失敗しました。"
            }
        }
    }

    func importAudioFile(
        from url: URL,
        type: SessionType,
        title: String? = nil,
        cleanupOriginalURL: URL? = nil,
        persistLocalCopy: Bool = false
    ) {
        guard !isImporting else { return }
        isImporting = true
        errorMessage = nil

        Task {
            var scoped = false
            if url.startAccessingSecurityScopedResource() {
                scoped = true
            }
            defer {
                if scoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let localURL = copyToTemporary(url)
            if let cleanupOriginalURL {
                try? FileManager.default.removeItem(at: cleanupOriginalURL)
            }
            defer {
                if let localURL {
                    try? FileManager.default.removeItem(at: localURL)
                }
            }

            do {
                let sessionTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalTitle = (sessionTitle?.isEmpty == false) ? sessionTitle! : defaultImportTitle(for: url)
                let session = try await APIClient.shared.createSession(type: type, title: finalTitle)
                if persistLocalCopy, let localURL {
                    persistLocalAudioCopy(from: localURL, sessionId: session.id)
                }
                if let localURL {
                    try await uploadExternalAudio(from: localURL, sessionId: session.id)
                } else {
                    throw RecordingUploadError.uploadFailed
                }
                try? await APIClient.shared.transcribe(sessionId: session.id)
                try? await APIClient.shared.diarize(sessionId: session.id)
                completedSession = session
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                errorMessage = "音声の取り込みに失敗しました。\(message)"
            }

            isImporting = false
        }
    }

    func importTranscript(text: String, type: SessionType, title: String? = nil) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        guard !isImporting else { return }
        isImporting = true
        errorMessage = nil

        Task {
            do {
                let sessionTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalTitle = (sessionTitle?.isEmpty == false) ? sessionTitle! : "文字起こし取り込み"
                let session = try await APIClient.shared.createSession(type: type, title: finalTitle)
                try await APIClient.shared.updateTranscript(sessionId: session.id, transcriptText: trimmedText)
                completedSession = session
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                errorMessage = "文字起こしの取り込みに失敗しました。\(message)"
            }
            isImporting = false
        }
    }

    func importYouTube(url: String, type: SessionType, title: String? = nil, language: String? = nil) {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return }
        guard !isImporting else { return }
        isImporting = true
        errorMessage = nil

        Task {
            do {
                let sessionTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
                let response = try await APIClient.shared.importYouTube(
                    url: trimmedURL,
                    mode: type,
                    title: sessionTitle?.isEmpty == false ? sessionTitle : nil,
                    language: language
                )
                let session = try await APIClient.shared.getSession(id: response.sessionId)
                completedSession = session
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                errorMessage = "YouTubeの取り込みに失敗しました。\(message)"
            }
            isImporting = false
        }
    }

    private func beginRecording() {
        // Request speech recognition authorization before starting recording
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus == .notDetermined {
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.startRecordingInternal()
                }
            }
        } else {
            startRecordingInternal()
        }
    }

    private func startRecordingInternal() {
        recorder.startRecording()
        if recorder.status == .error {
            isStarting = false
            return
        }
        isStarting = false
        if recorder.status == .recording {
            isSheetPresented = presentSheetOnStart
        }

        Task {
            do {
                let type = sessionType ?? .lecture
                let title = type == .lecture ? "講義" : "会議"
                let session = try await APIClient.shared.createSession(type: type, title: title)
                currentSession = session
                memoText = session.memoText ?? ""
                localTags = session.tags ?? []
                liveTags = localTags

                // Save mapping between session ID and local audio file
                if let fileURL = recorder.recordedFileURL {
                    let fileName = fileURL.lastPathComponent
                    LocalAudioMapping.save(sessionId: session.id, audioFileName: fileName)
                    print("[RecordingCoordinator] Mapped session \(session.id) → \(fileName)")
                }
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                errorMessage = "セッションの作成に失敗しました。\(message)"
                print("[RecordingCoordinator] createSession error: \(error)")
            }
        }
    }

    private func finalizeSession(_ session: Session) async {
        guard let url = recorder.recordedFileURL else {
            reset()
            return
        }

        isUploading = true
        var tempOpusURL: URL?
        defer {
            isUploading = false
            if let tempOpusURL {
                try? FileManager.default.removeItem(at: tempOpusURL)
            }
        }

        do {
            var uploaded = false
            var lastError: Error?

            if shouldUseOpusCompression {
                do {
                    let (payload, opusURL) = try await makeOpusPayload(from: url)
                    tempOpusURL = opusURL
                    do {
                        try await uploadAudioPayload(payload, sessionId: session.id)
                        uploaded = true
                    } catch {
                        lastError = error
                    }
                } catch {
                    lastError = error
                }
            }

            if !uploaded {
                let wavPayload = try await makeWavPayload(from: url)
                try await uploadAudioPayload(wavPayload, sessionId: session.id)
                uploaded = true
            }

            guard uploaded else {
                throw lastError ?? RecordingUploadError.uploadFailed
            }
            // Keep original WAV for local cache playback/transcription.
        } catch {
            print("Audio upload failed: \(error)")
            errorMessage = "音声の保存に失敗しました。"
        }

        let transcriptText = buildTranscriptText()
        if !transcriptText.isEmpty {
            do {
                try await APIClient.shared.updateTranscript(sessionId: session.id, transcriptText: transcriptText)
            } catch {
                print("Transcript upload failed: \(error)")
                if errorMessage == nil {
                    errorMessage = "文字起こしの同期に失敗しました。"
                }
            }
        }

        // Update session with transcript text before setting as completedSession
        var updatedSession = session
        updatedSession.transcriptText = transcriptText
        if !transcriptText.isEmpty {
            updatedSession.transcript = TranscriptStatus(hasTranscript: true, text: transcriptText)
        }
        completedSession = updatedSession
        reset()
    }

    private func discardSession(_ session: Session) async {
        if let url = recorder.recordedFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        do {
            try await APIClient.shared.deleteSession(id: session.id)
        } catch {
            errorMessage = "削除に失敗しました。"
        }
        reset()
    }

    private func uploadAudioPayload(_ payload: AudioUploadPayload, sessionId: String) async throws {
        let prepare = try await APIClient.shared.prepareAudioUpload(
            sessionId: sessionId,
            request: AudioPrepareRequest(
                contentType: payload.contentType,
                durationSec: payload.durationSec,
                sampleRate: payload.sampleRate,
                bitrate: payload.bitrateKbps,
                codec: payload.codec,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            )
        )
        try await APIClient.shared.upload(
            data: payload.data,
            to: prepare.uploadUrl,
            contentType: payload.contentType,
            method: prepare.method,
            headers: prepare.headers
        )

        let payloadSha256 = sha256Hex(payload.data)
        let meta = AudioMeta(
            variant: payload.variant,
            codec: payload.codec,
            container: payload.container,
            sampleRate: payload.sampleRate,
            channels: payload.channels,
            sizeBytes: payload.data.count,
            payloadSha256: payloadSha256,
            bitrate: payload.bitrateKbps,
            durationSec: payload.durationSec,
            originalSha256: payload.originalSha256
        )

        let commitRequest = AudioCommitRequest(
            storagePath: prepare.storagePath,
            sizeBytes: payload.data.count,
            contentType: payload.contentType,
            durationSec: payload.durationSec,
            metadata: meta,
            expectedSizeBytes: payload.data.count,
            expectedPayloadSha256: payloadSha256
        )
        try await commitAudioUploadWithRetry(sessionId: sessionId, request: commitRequest)
    }

    private func uploadExternalAudio(from url: URL, sessionId: String) async throws {
        var uploaded = false
        var lastError: Error?
        var tempOpusURL: URL?
        defer {
            if let tempOpusURL {
                try? FileManager.default.removeItem(at: tempOpusURL)
            }
        }

        if shouldUseOpusCompression {
            do {
                let (payload, opusURL) = try await makeOpusPayload(from: url)
                tempOpusURL = opusURL
                try await uploadAudioPayload(payload, sessionId: sessionId)
                uploaded = true
            } catch {
                lastError = error
            }
        }

        if !uploaded {
            let originalPayload = try await makeOriginalPayload(from: url)
            try await uploadAudioPayload(originalPayload, sessionId: sessionId)
            uploaded = true
        }

        guard uploaded else {
            throw lastError ?? RecordingUploadError.uploadFailed
        }
    }

    private func commitAudioUploadWithRetry(sessionId: String, request: AudioCommitRequest) async throws {
        let delays: [UInt64] = [
            300_000_000,
            800_000_000,
            1_600_000_000
        ]

        for (index, delay) in delays.enumerated() {
            do {
                _ = try await APIClient.shared.commitAudioUpload(sessionId: sessionId, request: request)
                return
            } catch {
                guard shouldRetryCommit(for: error), index < delays.count - 1 else {
                    throw error
                }
                try? await Task.sleep(nanoseconds: delay)
            }
        }
    }

    private func shouldRetryCommit(for error: Error) -> Bool {
        guard let apiError = error as? APIError else { return false }
        switch apiError {
        case .serverError(let statusCode, let message):
            let normalized = message.lowercased()
            return statusCode >= 500 && (normalized.contains("available") || normalized.contains("not found"))
        case .notFound:
            return true
        default:
            return false
        }
    }

    private func makeOriginalPayload(from url: URL) async throws -> AudioUploadPayload {
        let data = try await loadData(from: url)
        let info = audioInfo(for: url)
        let contentType = info.contentType
        let payload = AudioUploadPayload(
            data: data,
            contentType: contentType,
            fileExtension: info.fileExtension,
            codec: info.codec,
            container: info.container,
            sampleRate: info.sampleRate,
            channels: info.channels,
            bitrateKbps: nil,
            durationSec: audioDurationSec(from: url),
            originalSha256: nil,
            variant: "original"
        )
        return payload
    }

    private func makeWavPayload(from url: URL) async throws -> AudioUploadPayload {
        let data = try await loadData(from: url)
        return AudioUploadPayload(
            data: data,
            contentType: "audio/wav",
            fileExtension: "wav",
            codec: "pcm_s16le",
            container: "wav",
            sampleRate: 16000,
            channels: 1,
            bitrateKbps: nil,
            durationSec: audioDurationSec(from: url),
            originalSha256: nil,
            variant: "original"
        )
    }

    private func makeOpusPayload(from url: URL) async throws -> (AudioUploadPayload, URL) {
        let outputURL = AudioCompressor.makeOpusOutputURL(for: url)
        try await AudioCompressor.convertWavToOpus(
            inputURL: url,
            outputURL: outputURL,
            sampleRate: 16000,
            channels: 1,
            bitrateKbps: 24
        )
        let data = try await loadData(from: outputURL)
        let payload = AudioUploadPayload(
            data: data,
            contentType: "audio/ogg",
            fileExtension: "ogg",
            codec: "opus",
            container: "ogg",
            sampleRate: 16000,
            channels: 1,
            bitrateKbps: 24,
            durationSec: audioDurationSec(from: url),
            originalSha256: sha256Hex(try await loadData(from: url)),
            variant: "compressed"
        )
        return (payload, outputURL)
    }

    private func audioDurationSec(from url: URL) -> Double? {
        if let file = try? AVAudioFile(forReading: url) {
            let length = Double(file.length)
            let sampleRate = file.processingFormat.sampleRate
            guard sampleRate > 0 else { return nil }
            return length / sampleRate
        }
        let asset = AVURLAsset(url: url)
        let duration = asset.duration.seconds
        return duration.isFinite ? duration : nil
    }

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func loadData(from url: URL) async throws -> Data {
        try await Task.detached {
            try Data(contentsOf: url)
        }.value
    }

    private func reset() {
        recorder.reset()
        currentSession = nil
        memoText = ""
        transcriptLines = []
        partialTranscript = ""
        sessionType = nil
        localTags = []
        liveTags = []
        audioLevel = 0
        elapsed = 0
        state = .idle
    }

    private func copyToTemporary(_ url: URL) -> URL? {
        let filename = url.lastPathComponent
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)_\(filename)")
        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: url, to: tempURL)
            return tempURL
        } catch {
            print("Failed to copy import file: \(error)")
            return nil
        }
    }

    private func persistLocalAudioCopy(from url: URL, sessionId: String) {
        guard let dir = AudioFileLocator.recordingsDirectory() else { return }
        let ext = url.pathExtension.isEmpty ? "wav" : url.pathExtension
        let filename = "import_\(sessionId).\(ext)"
        let destURL = dir.appendingPathComponent(filename)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: url, to: destURL)
            LocalAudioMapping.save(sessionId: sessionId, audioFileName: filename)
        } catch {
            print("[RecordingCoordinator] Failed to persist local audio copy: \(error)")
        }
    }

    private func defaultImportTitle(for url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        return name.isEmpty ? "音声取り込み" : name
    }

    private func audioInfo(for url: URL) -> (contentType: String, codec: String, container: String, sampleRate: Int, channels: Int, fileExtension: String) {
        let fileExtension = url.pathExtension.lowercased()
        let format = try? AVAudioFile(forReading: url).processingFormat
        let sampleRate = Int(format?.sampleRate ?? 16000)
        let channels = Int(format?.channelCount ?? 1)

        switch fileExtension {
        case "m4a", "mp4":
            return ("audio/mp4", "aac", "mp4", sampleRate, channels, fileExtension)
        case "wav":
            return ("audio/wav", "pcm_s16le", "wav", sampleRate, channels, fileExtension)
        case "aiff", "aif":
            return ("audio/aiff", "pcm_s16le", "aiff", sampleRate, channels, fileExtension)
        case "mp3":
            return ("audio/mpeg", "mp3", "mp3", sampleRate, channels, fileExtension)
        default:
            return ("audio/mpeg", "unknown", fileExtension.isEmpty ? "audio" : fileExtension, sampleRate, channels, fileExtension)
        }
    }

    private func buildTranscriptText() -> String {
        var lines = transcriptLines.map { $0.text }
        if !partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(partialTranscript)
        }
        return lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func formatElapsed(_ time: TimeInterval) -> String {
        let total = max(0, Int(time))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var shouldUseOpusCompression: Bool {
#if targetEnvironment(simulator)
        return false
#else
        return true
#endif
    }
}

struct TranscriptLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isFinal: Bool
}

private struct AudioUploadPayload {
    let data: Data
    let contentType: String
    let fileExtension: String
    let codec: String
    let container: String
    let sampleRate: Int
    let channels: Int
    let bitrateKbps: Int?
    let durationSec: Double?
    let originalSha256: String?
    let variant: String?
}

private enum RecordingUploadError: Error {
    case uploadFailed
}

private enum AudioCompressionError: Error {
    case ffmpegUnavailable
    case ffmpegFailed(String)
    case outputMissing
}

private enum AudioCompressor {
    static func makeOpusOutputURL(for inputURL: URL) -> URL {
        let base = inputURL.deletingPathExtension().lastPathComponent
        let filename = "\(base)_\(UUID().uuidString).ogg"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }

    static func convertWavToOpus(
        inputURL: URL,
        outputURL: URL,
        sampleRate: Int,
        channels: Int,
        bitrateKbps: Int
    ) async throws {
#if canImport(FFmpegKit) || canImport(ffmpegkit)
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        let cmd = """
        -y -i "\(inputURL.path)" -ac \(channels) -ar \(sampleRate) -c:a libopus -b:a \(bitrateKbps)k "\(outputURL.path)"
        """
        try await withCheckedThrowingContinuation { cont in
            FFmpegKit.executeAsync(cmd) { session in
                let rc = session?.getReturnCode()
                if rc?.isValueSuccess() == true {
                    cont.resume(returning: ())
                } else {
                    let log = session?.getAllLogsAsString() ?? "no log"
                    cont.resume(throwing: AudioCompressionError.ffmpegFailed(log))
                }
            }
        }
        let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = (attrs?[.size] as? NSNumber)?.intValue ?? 0
        if fileSize <= 0 {
            throw AudioCompressionError.outputMissing
        }
#else
        throw AudioCompressionError.ffmpegUnavailable
#endif
    }
}
