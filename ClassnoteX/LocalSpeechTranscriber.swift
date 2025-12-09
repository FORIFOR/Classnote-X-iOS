import Foundation
import Speech
import AVFoundation
import Combine

// MARK: - Delegate Protocol

protocol LocalSpeechTranscriberDelegate: AnyObject {
    func speechTranscriber(_ transcriber: LocalSpeechTranscriber, didFinishSegment text: String, index: Int, startTime: TimeInterval, isFinal: Bool)
    func speechTranscriber(_ transcriber: LocalSpeechTranscriber, didReceiveIncrement text: String)
}

// MARK: - Transcript Segment Model

struct TranscriptSegment: Identifiable, Codable {
    let id: UUID
    let index: Int
    let text: String
    let startTimeSeconds: TimeInterval
    let endTimeSeconds: TimeInterval
    let speakerTag: Int? // 0, 1, 2...
    let speakerLabel: String? // "Speaker 1"
    let createdAt: Date
    
    init(index: Int, text: String, startTimeSeconds: TimeInterval, endTimeSeconds: TimeInterval = 0) {
        self.id = UUID()
        self.index = index
        self.text = text
        self.startTimeSeconds = startTimeSeconds
        self.endTimeSeconds = endTimeSeconds
        self.speakerTag = nil
        self.speakerLabel = nil
        self.createdAt = Date()
    }
}

/// Standalone local speech transcription using SFSpeechRecognizer.
/// Manages its own audio tap from AVAudioEngine for reliable operation.
@MainActor
final class LocalSpeechTranscriber: ObservableObject {
    
    @Published var partialText: String = ""
    @Published var isRunning: Bool = false
    @Published var lastErrorMessage: String?
    @Published var segments: [TranscriptSegment] = []
    
    // Delegate for segment callbacks
    weak var delegate: LocalSpeechTranscriberDelegate?
    
    private let locale: Locale
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    
    // Own audio engine for speech recognition
    private let audioEngine = AVAudioEngine()
    private var bufferCount: Int = 0
    private var audioFile: AVAudioFile?
    @Published var recordingURL: URL?
    
    // ==== Segment Management ====
    
    /// Current segment's accumulated text
    private var currentSegmentText: String = ""
    
    /// Last delivered character count (for diff calculation)
    private var lastDeliveredCharCount: Int = 0
    
    /// Current segment index (0, 1, 2, ...)
    private var currentSegmentIndex: Int = 0
    
    /// Segment start time (seconds since recording started)
    private var segmentStartTime: TimeInterval = 0
    
    /// Recording start time
    private var recordingStartTime: Date?
    
    /// Full accumulated text (all segments)
    private var fullAccumulatedText: String = ""
    
    // ==== Configuration ====
    
    /// Maximum characters per segment before forced split
    let maxCharsPerSegment: Int = 500
    
    /// Maximum seconds per segment before forced split
    let maxSecondsPerSegment: TimeInterval = 180 // 3 minutes
    
    /// Minimum characters before allowing a split (avoid tiny segments)
    let minCharsForSplit: Int = 50
    
    init(locale: Locale = Locale(identifier: "ja-JP")) {
        self.locale = locale
        self.recognizer = SFSpeechRecognizer(locale: locale)
        print("[STT] Initialized with locale: \(locale.identifier)")
        print("[STT] Recognizer available: \(recognizer?.isAvailable ?? false)")
        print("[STT] Segment config: maxChars=\(maxCharsPerSegment), maxSeconds=\(Int(maxSecondsPerSegment))s")
    }
    
    static func requestAuthorization() async -> Bool {
        print("[STT] Requesting speech recognition authorization...")
        let result = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                print("[STT] Authorization status: \(status.rawValue) (\(Self.statusName(status)))")
                cont.resume(returning: status == .authorized)
            }
        }
        return result
    }
    
    private static func statusName(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .authorized: return "authorized"
        @unknown default: return "unknown"
        }
    }
    
    /// Start speech recognition with its own audio tap
    func start() {
        print("[STT] ========== START CALLED ==========")
        stop()
        reset() // Clear all segment state
        bufferCount = 0
        recordingStartTime = Date() // Mark recording start time
        segmentStartTime = 0 // First segment starts at 0
        
        guard let recognizer else {
            print("[STT] ERROR: Recognizer is nil")
            lastErrorMessage = "Speech recognizer is nil"
            return
        }
        
        guard recognizer.isAvailable else {
            print("[STT] ERROR: Recognizer not available")
            lastErrorMessage = "Speech recognizer is not available"
            return
        }
        
        print("[STT] Recognizer is available, proceeding...")
        
        // Prepare audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            print("[STT] Current audio session category: \(audioSession.category.rawValue)")
            print("[STT] Setting audio session...")
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("[STT] Audio session configured successfully")
            print("[STT] Sample rate: \(audioSession.sampleRate) Hz")
            print("[STT] Input channels: \(audioSession.inputNumberOfChannels)")
        } catch {
            lastErrorMessage = "Audio session error: \(error.localizedDescription)"
            print("[STT] ERROR: Audio session setup failed: \(error)")
            return
        }
        
        // Create recognition request
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        
        if #available(iOS 13.0, *) {
            req.requiresOnDeviceRecognition = false
            print("[STT] On-device recognition: false (using cloud)")
        }
        
        self.request = req
        self.isRunning = true
        self.lastErrorMessage = nil
        self.partialText = ""
        
        print("[STT] Starting recognition task...")
        
        // Start recognition task with incremental processing
        self.task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                
                if let result {
                    let fullText = result.bestTranscription.formattedString
                    let isFinal = result.isFinal
                    
                    // ① Extract only new text (incremental)
                    let fullCount = fullText.count
                    let newText: String
                    if fullCount > self.lastDeliveredCharCount {
                        let startIndex = fullText.index(fullText.startIndex, offsetBy: self.lastDeliveredCharCount)
                        newText = String(fullText[startIndex...])
                    } else {
                        newText = ""
                    }
                    
                    // ② If there's new text, accumulate and notify
                    if !newText.isEmpty {
                        self.currentSegmentText += newText
                        self.lastDeliveredCharCount = fullCount
                        
                        // Update UI with full text
                        self.partialText = self.fullAccumulatedText + self.currentSegmentText
                        
                        // Notify delegate of increment
                        self.delegate?.speechTranscriber(self, didReceiveIncrement: newText)
                        
                        // Log every 100 chars
                        if self.currentSegmentText.count % 100 < newText.count {
                            print("[STT] 📝 Segment \(self.currentSegmentIndex): \(self.currentSegmentText.count) chars")
                        }
                    }
                    
                    // ③ Check if should split segment
                    if self.shouldSplitSegment(isFinal: isFinal) {
                        self.closeCurrentSegment(isFinal: isFinal)
                        
                        // If not final, restart STT session for fresh context
                        if !isFinal {
                            self.restartRecognitionTask()
                        }
                    }
                }
                
                if let error {
                    let nsError = error as NSError
                    // Filter out expected cancellation errors
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                        // Request cancelled, expected on stop
                        return
                    }
                    if nsError.domain == "kLSRErrorDomain" && nsError.code == 301 {
                        // Recognition request was canceled by user, not an error
                        print("[STT] Recognition stopped (user-initiated)")
                        return
                    }
                    print("[STT] ❌ Recognition error: \(error)")
                    print("[STT] Error domain: \(nsError.domain), code: \(nsError.code)")
                    self.lastErrorMessage = error.localizedDescription
                    self.isRunning = false
                }
            }
        }
        
        // Get audio format info
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        print("[STT] Audio format: \(recordingFormat)")
        print("[STT] Format sample rate: \(recordingFormat.sampleRate)")
        print("[STT] Format channels: \(recordingFormat.channelCount)")
        
        // Create temporary audio file with m4a/AAC format for reliable playback
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording.m4a")
        self.recordingURL = tempURL
        
        // AAC encoding settings - this format is universally supported
        let aacSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: recordingFormat.sampleRate,
            AVNumberOfChannelsKey: recordingFormat.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            self.audioFile = try AVAudioFile(forWriting: tempURL, settings: aacSettings)
            print("[STT] 💾 Created audio file at: \(tempURL.path)")
            print("[STT] 📝 Audio file settings: m4a/AAC, \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount)ch")
        } catch {
            print("[STT] ❌ Failed to create audio file: \(error)")
        }
        
        // Install audio tap
        print("[STT] Installing audio tap...")
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
            guard let self else { return }
            
            // Write to file
            do {
                try self.audioFile?.write(from: buffer)
            } catch {
                if self.bufferCount % 100 == 0 {
                    print("[STT] ❌ File write error: \(error)")
                }
            }
            
            self.request?.append(buffer)
            
            // Log every 50 buffers to avoid spam
            Task { @MainActor in
                self.bufferCount += 1
                if self.bufferCount % 50 == 0 {
                    print("[STT] 🎤 Buffers received: \(self.bufferCount)")
                }
            }
        }
        
        // Start audio engine
        print("[STT] Preparing audio engine...")
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            print("[STT] ✅ Audio engine started successfully - LISTENING")
        } catch {
            lastErrorMessage = "Audio engine error: \(error.localizedDescription)"
            print("[STT] ❌ Audio engine start error: \(error)")
            isRunning = false
        }
    }
    
    // MARK: - Segment Management
    
    /// Check if current segment should be split
    private func shouldSplitSegment(isFinal: Bool) -> Bool {
        // Apple returned isFinal - always split
        if isFinal { return true }
        
        // Text too short for forced split
        if currentSegmentText.count < minCharsForSplit { return false }
        
        // Character threshold reached
        if currentSegmentText.count >= maxCharsPerSegment {
            print("[STT] ⚡ Segment split triggered: char limit (\(currentSegmentText.count) >= \(maxCharsPerSegment))")
            return true
        }
        
        // Time threshold reached
        if let startTime = recordingStartTime {
            let elapsed = Date().timeIntervalSince(startTime) - segmentStartTime
            if elapsed >= maxSecondsPerSegment {
                print("[STT] ⚡ Segment split triggered: time limit (\(Int(elapsed))s >= \(Int(maxSecondsPerSegment))s)")
                return true
            }
        }
        
        return false
    }
    
    /// Close current segment and save it
    private func closeCurrentSegment(isFinal: Bool) {
        guard !currentSegmentText.isEmpty else { return }
        
        let index = currentSegmentIndex
        let text = currentSegmentText
        let startTime = segmentStartTime
        let endTime = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        
        print("[STT] ✅ Segment \(index) closed: \(text.count) chars, isFinal=\(isFinal)")
        print("[STT] 📝 Segment content preview: \"\(String(text.prefix(50)))...\"")
        
        // Create segment
        let segment = TranscriptSegment(
            index: index,
            text: text,
            startTimeSeconds: startTime,
            endTimeSeconds: endTime
        )
        // Initial segments have no speaker assigned until diarization runs
        var segmentWithSpeaker = segment 
        // We will assign speaker later in post-processing
        
        segments.append(segment)
        
        // Accumulate to full text
        fullAccumulatedText += text + "\n"
        
        // Notify delegate
        delegate?.speechTranscriber(self, didFinishSegment: text, index: index, startTime: startTime, isFinal: isFinal)
        
        // Reset for next segment
        startNewSegment()
    }
    
    /// Start a new segment
    private func startNewSegment() {
        currentSegmentText = ""
        lastDeliveredCharCount = 0
        currentSegmentIndex += 1
        segmentStartTime = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        print("[STT] 🆕 Starting segment \(currentSegmentIndex)")
    }
    
    /// Restart only the STT session (keep audio engine running)
    private func restartRecognitionTask() {
        print("[STT] 🔄 Restarting recognition task...")
        
        // Cancel current task and request
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        
        // Create new request
        guard let recognizer else { return }
        
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if #available(iOS 13.0, *) {
            req.requiresOnDeviceRecognition = false
        }
        self.request = req
        
        // Start new task with same handler
        self.task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                
                if let result {
                    let fullText = result.bestTranscription.formattedString
                    let isFinal = result.isFinal
                    
                    // Extract only new text
                    let fullCount = fullText.count
                    let newText: String
                    if fullCount > self.lastDeliveredCharCount {
                        let startIndex = fullText.index(fullText.startIndex, offsetBy: self.lastDeliveredCharCount)
                        newText = String(fullText[startIndex...])
                    } else {
                        newText = ""
                    }
                    
                    if !newText.isEmpty {
                        self.currentSegmentText += newText
                        self.lastDeliveredCharCount = fullCount
                        self.partialText = self.fullAccumulatedText + self.currentSegmentText
                        self.delegate?.speechTranscriber(self, didReceiveIncrement: newText)
                    }
                    
                    if self.shouldSplitSegment(isFinal: isFinal) {
                        self.closeCurrentSegment(isFinal: isFinal)
                        if !isFinal {
                            self.restartRecognitionTask()
                        }
                    }
                }
                
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 { return }
                    if nsError.domain == "kLSRErrorDomain" && nsError.code == 301 { return }
                    print("[STT] ❌ Recognition error: \(error)")
                }
            }
        }
        
        print("[STT] ✅ Recognition task restarted")
    }
    
    // MARK: - Stop & Cleanup
    
    /// Stop recognition and clean up
    func stop() {
        print("[STT] ========== STOP CALLED ==========")
        print("[STT] Total buffers processed: \(bufferCount)")
        print("[STT] Total segments: \(segments.count)")
        
        // Close any remaining segment
        if !currentSegmentText.isEmpty {
            print("[STT] Closing final segment...")
            closeCurrentSegment(isFinal: true)
        }
        
        if audioEngine.isRunning {
            print("[STT] Stopping audio engine...")
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            print("[STT] Audio engine stopped, tap removed")
        }
        
        // Close audio file
        audioFile = nil
        print("[STT] 💾 Audio file closed")
        
        request?.endAudio()
        task?.cancel()
        
        task = nil
        request = nil
        isRunning = false
        
        print("[STT] Cleanup complete")
        print("[STT] Final full text: \(fullAccumulatedText.count) chars in \(segments.count) segments")
    }
    
    /// Alias for stop
    func finish() {
        print("[STT] Finish called (alias for stop)")
        stop()
    }
    
    /// Reset all segment state for new recording
    func reset() {
        segments.removeAll()
        currentSegmentText = ""
        lastDeliveredCharCount = 0
        currentSegmentIndex = 0
        segmentStartTime = 0
        recordingStartTime = nil
        fullAccumulatedText = ""
        partialText = ""
        print("[STT] 🔄 State reset for new recording")
    }
    
    /// Append external buffer (optional)
    func append(_ buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
    }
    
    /// Get current recording time in seconds
    var currentRecordingTime: TimeInterval {
        recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
    }
}
