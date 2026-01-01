import Foundation
import AVFoundation
import Combine
import UIKit
import Speech

enum RecordingStatus {
    case idle
    case recording
    case paused
    case error
}

@MainActor
final class FileRecordingModel: ObservableObject {
    @Published var status: RecordingStatus = .idle
    @Published var errorMessage: String?
    @Published var elapsed: TimeInterval = 0
    @Published var recordedFileURL: URL?
    @Published var partialTranscript: String = ""
    @Published var localSTTAvailable: Bool = false

    // MARK: - Internal State (Thread Safe via audioQueue)
    private var engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var timer: Timer?
    private var startDate: Date?
    private var accumulatedTime: TimeInterval = 0
    
    // Cloud Run 側と揃える 16kHz/16bit/mono
    private let sampleRate: Double = 16_000
    
    // Serial queue for audio processing and state mutation
    private let audioQueue = DispatchQueue(label: "FileRecordingModel.queue")
    
    private var targetFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var notificationTokens: [NSObjectProtocol] = []
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private var isInterruptionOngoing = false
    private var totalFramesWritten: UInt64 = 0
    
    private var speechRecognizer: SFSpeechRecognizer? = {
        let jaLocale = Locale(identifier: "ja-JP")
        return SFSpeechRecognizer(locale: jaLocale) ?? SFSpeechRecognizer(locale: Locale.current)
    }()
    
    // Recognition request/task - mutated on MainActor (setup), accessed on queue
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isRequestingSpeechAuth = false
    private var shouldAutoRestartSpeech = false

    var onChunk: ((Data) -> Void)?
    var onLevel: ((Float) -> Void)?
    var onFinalTranscript: ((String) -> Void)?

    var startedAt: Date? {
        startDate
    }

    init() {
        observeAudioSession()
    }

    deinit {
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        // Background task cleanup must be done on MainActor
        let taskId = backgroundTaskId
        if taskId != .invalid {
            Task { @MainActor in
                UIApplication.shared.endBackgroundTask(taskId)
            }
        }
    }

    /// 起動時に呼んでおくと初回のAudioSessionアクティベートが軽くなる
    func prepareAudioSession() {
        do {
            try configureSession()
            print("[FileRecordingModel] prepareAudioSession success")
        } catch {
            print("[FileRecordingModel] prepareAudioSession error: \(error)")
        }
    }

    func startRecording() {
        guard status == .idle else { return }

        // Reset state for new recording
        totalFramesWritten = 0

        let startTap = Date()
        print("[FileRecordingModel] startRecording invoked at \(startTap)")

        do {
            guard AVAudioSession.sharedInstance().recordPermission == .granted else {
                errorMessage = "マイクの権限がありません。設定から許可してください。"
                return
            }
            
            try configureSession()
            accumulatedTime = 0

            var preparedURL: URL?
            // Run setup on audioQueue to ensure consistency
            try audioQueue.sync {
                let input = engine.inputNode
                let inputFormat = input.inputFormat(forBus: 0)
                print("[FileRecordingModel] input format sr=\(inputFormat.sampleRate), ch=\(inputFormat.channelCount)")
                
                guard inputFormat.sampleRate > 0 else {
                    throw NSError(domain: "FileRecordingModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "マイクの初期化に失敗しました (SampleRate=0)"])
                }

                guard let targetFmt = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: true) else {
                     throw NSError(domain: "FileRecordingModel", code: -3, userInfo: [NSLocalizedDescriptionKey: "ターゲットフォーマットの作成に失敗しました"])
                }
                self.targetFormat = targetFmt
                
                guard let newConverter = AVAudioConverter(from: inputFormat, to: targetFmt) else {
                    throw NSError(domain: "FileRecordingModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "フォーマット変換の初期化に失敗しました"])
                }
                self.converter = newConverter

                let url = try recordingFileURL()
                // Use settings from targetFormat
                audioFile = try AVAudioFile(forWriting: url,
                                            settings: targetFmt.settings,
                                            commonFormat: targetFmt.commonFormat,
                                            interleaved: targetFmt.isInterleaved)
                preparedURL = url

                // Setup internal state for recognition
                // Note: recognitionRequest is created here (MainActor called sync queue? No, startRecording is MainActor)
                // We should be careful. Actually `startRecording` IS MainActor.
                // We can access `recognitionRequest` here safely if we don't access it concurrently.
                // But `input.installTap` runs concurrently. So we need to protect `recognitionRequest` or capture it.
            }
            
            guard let url = preparedURL else {
                throw NSError(domain: "FileRecordingModel", code: -4, userInfo: [NSLocalizedDescriptionKey: "録音ファイルの準備に失敗しました"])
            }
            recordedFileURL = url

            let input = engine.inputNode
            input.removeTap(onBus: 0)

            // Prepare recognition request SYNCHRONOUSLY before installing tap
            // This ensures recognitionRequest is ready when buffers start arriving
            prepareSpeechRecognitionSync()

            // Capture recognitionRequest reference for thread-safe access in tap
            // The tap block runs on audio thread, so we capture the request object directly
            let capturedRequest = self.recognitionRequest

            input.installTap(onBus: 0, bufferSize: 4096, format: input.inputFormat(forBus: 0)) { [weak self] buffer, _ in
                guard let self else { return }

                // Append to speech recognition (thread-safe via captured reference)
                capturedRequest?.append(buffer)

                // Write to file on audioQueue
                self.audioQueue.async {
                    self.write(buffer: buffer)
                }
            }

            engine.prepare()
            try engine.start()
            startBackgroundTaskIfNeeded()

            status = .recording
            startDate = Date()
            elapsed = 0
            print("[FileRecordingModel] engine started at \(startDate!)")
            
            startTimer()
            shouldAutoRestartSpeech = true
            
        } catch {
            status = .error
            errorMessage = "録音エラー: \(error.localizedDescription)"
            print("[FileRecordingModel] startRecording error: \(error)")
            endBackgroundTaskIfNeeded()
        }
    }

    func stopRecording() {
        shouldAutoRestartSpeech = false
        stopSpeechRecognition(finalize: true)

        if status == .recording, let start = startDate {
            accumulatedTime += Date().timeIntervalSince(start)
        }

        engine.stop()
        engine.inputNode.removeTap(onBus: 0) // Explicitly remove

        // Audio Queue cleanup - ensure file is properly closed
        audioQueue.sync {
            self.audioFile = nil  // This closes the file
            self.converter = nil
        }

        timer?.invalidate()
        timer = nil
        startDate = nil
        endBackgroundTaskIfNeeded()
        elapsed = accumulatedTime

        // Log final status with file size verification
        if let fileURL = recordedFileURL {
            let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = (attrs?[.size] as? NSNumber)?.intValue ?? -1
            print("[FileRecordingModel] ========== STOP RECORDING ==========")
            print("[FileRecordingModel] File: \(fileURL.lastPathComponent)")
            print("[FileRecordingModel] Size: \(fileSize) bytes")
            print("[FileRecordingModel] Duration: \(elapsed) seconds")
            print("[FileRecordingModel] Total frames written: \(totalFramesWritten)")

            if fileSize < 44_000 {
                print("[FileRecordingModel] ⚠️ WARNING: File is very small! Expected > 44KB for 1 second of audio")
                print("[FileRecordingModel] This may indicate audio was not written properly")
                if totalFramesWritten == 0 {
                    print("[FileRecordingModel] ⚠️ No audio frames were written - check converter/tap setup")
                }
            } else {
                let expectedSize = Int(elapsed) * 32_000 + 44  // 16kHz * 16bit * 1ch = 32KB/sec + header
                let ratio = Double(fileSize) / Double(max(expectedSize, 1))
                print("[FileRecordingModel] Expected ~\(expectedSize) bytes, ratio: \(String(format: "%.2f", ratio))")
            }
        } else {
            print("[FileRecordingModel] ⚠️ No recorded file URL!")
        }

        // Reset frame counter for next recording
        totalFramesWritten = 0
        status = .idle
    }

    func pauseRecording() {
        guard status == .recording else { return }
        shouldAutoRestartSpeech = false
        stopSpeechRecognition(finalize: true)
        
        engine.pause()
        if let start = startDate {
            accumulatedTime += Date().timeIntervalSince(start)
        }
        startDate = nil
        timer?.invalidate()
        timer = nil
        status = .paused
    }

    func resumeRecording() {
        guard status == .paused else { return }
        do {
            try configureSession()
            if !engine.isRunning {
                try engine.start()
            }
            startDate = Date()
            status = .recording
            startTimer()
            shouldAutoRestartSpeech = true
            startSpeechRecognitionIfAvailable()
        } catch {
            status = .error
            errorMessage = "録音の再開に失敗しました: \(error.localizedDescription)"
        }
    }

    func prepareForBackgroundIfNeeded() {
        guard status == .recording else { return }
        startBackgroundTaskIfNeeded()
    }

    func resumeIfNeededAfterForeground() {
        guard status == .recording else { return }
        // Ensure session is active
        do {
            try configureSession()
             if !engine.isRunning {
                try engine.start()
            }
        } catch {
             print("[FileRecordingModel] resumeIfNeededAfterForeground error: \(error)")
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let start = self.startDate else { return }
            self.elapsed = self.accumulatedTime + Date().timeIntervalSince(start)
        }
    }

    // INTERNAL: Run on audioQueue
    private func write(buffer: AVAudioPCMBuffer) {
        guard let file = audioFile, let converter = converter, let targetFormat = targetFormat else {
            return
        }

        // 入力と出力のサンプルレート差を考慮して余裕を持った容量を確保
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let estimatedFrames = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 4096)

        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: estimatedFrames) else {
            return
        }

        var error: NSError?
        var hasProvidedData = false

        let _ = converter.convert(to: pcmBuffer, error: &error) { _, outStatus in
            if hasProvidedData {
                outStatus.pointee = .noDataNow
                return nil
            } else {
                hasProvidedData = true
                outStatus.pointee = .haveData
                return buffer
            }
        }

        if let error {
            print("[FileRecordingModel] convert error: \(error)")
            return
        }

        if pcmBuffer.frameLength > 0 {
            do {
                try file.write(from: pcmBuffer)
                totalFramesWritten += UInt64(pcmBuffer.frameLength)
            } catch {
                print("[FileRecordingModel] file write error: \(error)")
            }

            if let level = calculateLevel(from: pcmBuffer) {
                Task { @MainActor in
                    self.onLevel?(level)
                }
            }

            if let data = pcmData(from: pcmBuffer), !data.isEmpty {
                onChunk?(data)
            }
        }
    }

    // ... (configureSession, recordingFileURL, observeAudioSession, handleInterruption, handleRouteChange as before) ...
    // Note: handleRouteChange needs to be careful not to cause loops.
    
    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        // Use .measurement mode for optimal speech recognition compatibility
        // .spokenAudio can cause issues with some audio routes
        try session.setCategory(.playAndRecord,
                                mode: .measurement,
                                options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
        // Match actual input sample rate (typically 48kHz) for better compatibility
        // The converter will handle downsampling to 16kHz for file output
        try session.setPreferredSampleRate(48_000)
        try session.setActive(true, options: [.notifyOthersOnDeactivation])
    }

    private func recordingFileURL() throws -> URL {
        let dir = try FileManager.default.url(for: .documentDirectory,
                                              in: .userDomainMask,
                                              appropriateFor: nil,
                                              create: true)
            .appendingPathComponent("Recordings", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "lecture_\(formatter.string(from: Date())).wav"
        return dir.appendingPathComponent(filename)
    }
    
    // Notifications
     private func observeAudioSession() {
        let center = NotificationCenter.default
        let inter = center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: nil) { [weak self] note in
            Task { @MainActor in self?.handleInterruption(note) }
        }
        let route = center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil) { [weak self] note in
             // Logging route change
             self?.handleRouteChange(note)
        }
         // Avoid resetting on media services reset implicitly, usually handled by engine config
        notificationTokens = [inter, route]
    }

    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }

        switch type {
        case .began:
            isInterruptionOngoing = true
            pauseRecording()
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            if options.contains(.shouldResume) {
                resumeAfterInterruption()
            }
            isInterruptionOngoing = false
        @unknown default:
            break
        }
    }
    
    private func resumeAfterInterruption() {
         resumeRecording()
    }

    private func handleRouteChange(_ notification: Notification) {
        // Just log for now
        if let info = notification.userInfo,
           let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
           let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) {
            print("[FileRecordingModel] route change: \(reason.rawValue)")
        }
    }

    private func startBackgroundTaskIfNeeded() {
        guard backgroundTaskId == .invalid else { return }
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "RecordingBackground") { [weak self] in
            Task { @MainActor in
                self?.endBackgroundTaskIfNeeded()
            }
        }
        print("[FileRecordingModel] BackgroundTask started: \(backgroundTaskId.rawValue)")
    }

    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskId != .invalid else { return }
        let taskId = backgroundTaskId
        backgroundTaskId = .invalid
        UIApplication.shared.endBackgroundTask(taskId)
        print("[FileRecordingModel] BackgroundTask ended: \(taskId.rawValue)")
    }

    // Helper functions (pcmData, calculateLevel) need to be thread safe / pure functions.
    private func pcmData(from buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.int16ChannelData?.pointee else { return nil }
        let frameLength = Int(buffer.frameLength)
        let data = Data(bytes: channelData, count: frameLength * MemoryLayout<Int16>.size)
        return data
    }

    private func calculateLevel(from buffer: AVAudioPCMBuffer) -> Float? {
        guard let channelData = buffer.int16ChannelData?.pointee else { return nil }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return nil }
        let step = max(1, frameLength / 200)
        var sum: Float = 0
        var count: Float = 0
        for i in Swift.stride(from: 0, to: frameLength, by: step) {
            let sample = Float(channelData[i]) / Float(Int16.max)
            sum += sample * sample
            count += 1
        }
        guard count > 0 else { return nil }
        let rms = sqrt(sum / count)
        return min(max(rms * 2, 0), 1)
    }

    func reset() {
        shouldAutoRestartSpeech = false
        stopSpeechRecognition(finalize: false)
        accumulatedTime = 0
        elapsed = 0
        recordedFileURL = nil
        partialTranscript = ""
        localSTTAvailable = false
        errorMessage = nil
    }

    // STT Logic

    /// Synchronously prepare speech recognition request (call before installing tap)
    /// This ensures recognitionRequest is ready when audio buffers start arriving
    private func prepareSpeechRecognitionSync() {
        // Check authorization status synchronously (don't request here, should be done beforehand)
        let status = SFSpeechRecognizer.authorizationStatus()
        guard status == .authorized else {
            localSTTAvailable = false
            print("[FileRecordingModel] Speech not authorized: \(status.rawValue)")
            return
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            localSTTAvailable = false
            print("[FileRecordingModel] Speech recognizer not available")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(iOS 13.0, *) {
            request.requiresOnDeviceRecognition = false
        }

        self.recognitionRequest = request
        self.localSTTAvailable = true

        self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                self.handleSpeechResult(result, error: error)
            }
        }
        print("[FileRecordingModel] Speech recognition started synchronously")
    }

    /// Async version for resume scenarios (maintains backward compatibility)
    private func startSpeechRecognitionIfAvailable() {
        requestSpeechAuthorizationIfNeeded { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.localSTTAvailable = false
                return
            }
            self.prepareSpeechRecognitionSync()
        }
    }

    private func requestSpeechAuthorizationIfNeeded(_ completion: @escaping (Bool) -> Void) {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
             completion(true)
        case .notDetermined:
             if !isRequestingSpeechAuth {
                 isRequestingSpeechAuth = true
                 SFSpeechRecognizer.requestAuthorization { [weak self] newStatus in
                     Task { @MainActor in
                         self?.isRequestingSpeechAuth = false
                         completion(newStatus == .authorized)
                     }
                 }
             } else {
                 completion(false)
             }
        default:
             completion(false)
        }
    }

   private func stopSpeechRecognition(finalize: Bool) {
        if finalize {
            recognitionRequest?.endAudio()
            recognitionTask?.finish()
        } else {
            recognitionTask?.cancel()
            recognitionRequest?.endAudio()
        }
        recognitionRequest = nil
        recognitionTask = nil
    }

    private func handleSpeechResult(_ result: SFSpeechRecognitionResult?, error: Error?) {
        if let error {
            let nsError = error as NSError

            // Error code 1110: "No speech detected" - this is NOT a fatal error
            // It happens when there's silence or very quiet audio
            // We should NOT stop recording, just restart STT if appropriate
            if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                print("[FileRecordingModel] STT: No speech detected (normal for silence)")
                // Don't stop STT abruptly, just mark as needing restart
                stopSpeechRecognition(finalize: false)
                // Auto-restart if still recording
                if shouldAutoRestartSpeech && status == .recording {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.startSpeechRecognitionIfAvailable()
                    }
                }
                return
            }

            // Error code 216: Recognition request was canceled (expected during stop)
            if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                print("[FileRecordingModel] STT: Recognition canceled (expected)")
                return
            }

            // Other errors - log but don't crash
            print("[FileRecordingModel] STT error: \(error.localizedDescription) (code: \(nsError.code))")
            stopSpeechRecognition(finalize: false)

            // Try to restart for recoverable errors
            if shouldAutoRestartSpeech && status == .recording {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.startSpeechRecognitionIfAvailable()
                }
            }
            return
        }

        guard let result else { return }
        partialTranscript = result.bestTranscription.formattedString

        if result.isFinal {
            let trimmed = partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                onFinalTranscript?(trimmed)
            }
            partialTranscript = ""
            // Restart STT for continuous recognition
            stopSpeechRecognition(finalize: false)
            if shouldAutoRestartSpeech && status == .recording {
                startSpeechRecognitionIfAvailable()
            }
        }
    }
}
