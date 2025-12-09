import Foundation
import AVFoundation
import Combine
import UIKit
import Speech

@MainActor
final class FileRecordingModel: ObservableObject {
    @Published var status: RecordingStatus = .idle
    @Published var errorMessage: String?
    @Published var elapsed: TimeInterval = 0
    @Published var recordedFileURL: URL?
    @Published var partialTranscript: String = ""
    @Published var localSTTAvailable: Bool = false

    private var engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var timer: Timer?
    private var startDate: Date?
    // Cloud Run 側と揃える 16kHz/16bit/mono（低レイテンシ・音声認識向け）
    // NOTE: SFSpeechRecognizerも16kHzで動作可能だが、デバイスのネイティブ入力形式から変換が必要な場合がある
    private let sampleRate: Double = 16_000
    private let audioQueue = DispatchQueue(label: "FileRecordingModel.queue")
    private var targetFormat: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var notificationTokens: [NSObjectProtocol] = []
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private var isInterruptionOngoing = false

    /// Streaming 用のPCMチャンクを受け取るフック
    var onChunk: ((Data) -> Void)?

    var startedAt: Date? {
        startDate
    }

    init() {
        observeAudioSession()
    }

    deinit {
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        endBackgroundTaskIfNeeded()
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
        do {
            guard AVAudioSession.sharedInstance().recordPermission == .granted else {
                errorMessage = "マイクの権限がありません。設定から許可してください。"
                return
            }
            let startTap = Date()
            print("[FileRecordingModel] startRecording invoked at \(startTap)")
            try configureSession()

            // 入力フォーマット（デバイス依存）でタップし、後段で指定サンプルレート/16bit/monoに変換する
            let input = engine.inputNode
            let inputFormat = input.inputFormat(forBus: 0)
            print("[FileRecordingModel] input format sr=\(inputFormat.sampleRate), ch=\(inputFormat.channelCount)")
            let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: true)!
            self.targetFormat = targetFormat
            self.converter = AVAudioConverter(from: inputFormat, to: targetFormat)
            let url = try recordingFileURL()
            // フォーマットずれを避けるため commonFormat/interleaved を明示
            audioFile = try AVAudioFile(forWriting: url,
                                        settings: targetFormat.settings,
                                        commonFormat: targetFormat.commonFormat,
                                        interleaved: targetFormat.isInterleaved)
            recordedFileURL = url

            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                guard let self else { return }
                self.audioQueue.async {
                    self.write(buffer: buffer, targetFormat: targetFormat)
                }
            }

            engine.prepare()
            try engine.start()
            startBackgroundTaskIfNeeded()

            status = .recording
            startDate = Date()
            elapsed = 0
            print("[FileRecordingModel] engine started at \(startDate!) (delta: \(startDate!.timeIntervalSince(startTap)) sec)")
            startTimer()
            print("[FileRecordingModel] startRecording success. file=\(url.lastPathComponent)")
        } catch {
            status = .error
            errorMessage = error.localizedDescription
            print("[FileRecordingModel] startRecording error: \(error)")
            endBackgroundTaskIfNeeded()
        }
    }

    func stopRecording() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        audioFile = nil
        timer?.invalidate()
        timer = nil
        startDate = nil
        endBackgroundTaskIfNeeded()
        status = .idle
        print("[FileRecordingModel] stopRecording. file=\(recordedFileURL?.lastPathComponent ?? "nil")")
    }

    func prepareForBackgroundIfNeeded() {
        guard status == .recording else { return }
        startBackgroundTaskIfNeeded()
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[FileRecordingModel] keep active in background failed: \(error)")
        }
    }

    func resumeIfNeededAfterForeground() {
        guard status == .recording else { return }
        do {
            try configureSession()
            if !engine.isRunning {
                try engine.start()
            }
        } catch {
            status = .error
            errorMessage = "録音の再開に失敗しました: \(error.localizedDescription)"
            print("[FileRecordingModel] resume after foreground error: \(error)")
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let start = self.startDate else { return }
            Task { @MainActor in
                self.elapsed = Date().timeIntervalSince(start)
            }
        }
    }

    private func write(buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) {
        guard let file = audioFile else { return }
        guard let converter = converter else {
            print("[FileRecordingModel] converter not ready. input=\(buffer.format), target=\(targetFormat)")
            return
        }

        // 入力と出力のサンプルレート差を考慮して余裕を持った容量を確保
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let estimatedFrames = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 4096)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: estimatedFrames) else {
            print("[FileRecordingModel] pcmBuffer alloc failed. capacity=\(estimatedFrames)")
            return
        }

        var error: NSError?
        let status = converter.convert(to: pcmBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if let error {
            print("[FileRecordingModel] convert error: \(error)")
            return
        }

        guard status == .haveData || status == .inputRanDry else {
            print("[FileRecordingModel] convert status unexpected: \(status.rawValue)")
            return
        }

        if pcmBuffer.frameLength == 0 {
            print("[FileRecordingModel] convert produced empty buffer")
            return
        }
        // 念のためフォーマット一致を確認
        if pcmBuffer.format != targetFormat || file.processingFormat != targetFormat {
            print("[FileRecordingModel] format mismatch. buffer=\(pcmBuffer.format), fileFormat=\(file.processingFormat), target=\(targetFormat)")
            return
        }

        do {
            try file.write(from: pcmBuffer)
        } catch {
            print("[FileRecordingModel] file write error: \(error)")
        }

        if let data = pcmData(from: pcmBuffer), !data.isEmpty {
            onChunk?(data)
        }
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,
                                mode: .spokenAudio,
                                options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
        try session.setPreferredSampleRate(sampleRate)
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

    private func observeAudioSession() {
        let center = NotificationCenter.default
        let inter = center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: nil) { [weak self] note in
            self?.handleInterruption(note)
        }
        let route = center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil) { [weak self] note in
            self?.handleRouteChange(note)
        }
        let reset = center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: nil) { [weak self] _ in
            self?.handleMediaServicesReset()
        }
        notificationTokens = [inter, route, reset]
    }

    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }

        switch type {
        case .began:
            isInterruptionOngoing = true
            engine.pause()
            print("[FileRecordingModel] interruption began")
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
        guard status == .recording else { return }
        do {
            try configureSession()
            if !engine.isRunning {
                try engine.start()
            }
            print("[FileRecordingModel] resumed after interruption")
        } catch {
            status = .error
            errorMessage = "録音の再開に失敗しました: \(error.localizedDescription)"
            print("[FileRecordingModel] resume error: \(error)")
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        print("[FileRecordingModel] route change: \(reason.rawValue)")
    }

    private func handleMediaServicesReset() {
        print("[FileRecordingModel] media services were reset, rebuilding engine")
        let wasRecording = status == .recording
        engine.stop()
        engine = AVAudioEngine()
        if wasRecording {
            status = .idle
            startRecording()
        }
    }

    private func startBackgroundTaskIfNeeded() {
        guard backgroundTaskId == .invalid else { return }
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "RecordingBackground") { [weak self] in
            self?.endBackgroundTaskIfNeeded()
        }
    }

    nonisolated private func endBackgroundTaskIfNeeded() {
        Task { @MainActor in
            guard backgroundTaskId != .invalid else { return }
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }

    private func pcmData(from buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.int16ChannelData?.pointee else { return nil }
        let frameLength = Int(buffer.frameLength)
        let data = Data(bytes: channelData, count: frameLength * MemoryLayout<Int16>.size)
        return data
    }
}
