import Foundation
import SwiftUI
import Combine
#if canImport(FFmpegKit)
import FFmpegKit
#elseif canImport(ffmpegkit)
import ffmpegkit
#endif

struct AudioSource {
    let url: URL
    let meta: AudioMeta?
}

final class PlaybackViewModel: ObservableObject {
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isPlaying: Bool = false
    
    private let sessionId: String
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init(sessionId: String) {
        self.sessionId = sessionId
        
        // Sync initial state
        self.duration = AudioPlayerManager.shared.duration(for: sessionId) ?? 0
        self.currentTime = AudioPlayerManager.shared.currentTime(sessionId: sessionId) ?? 0
        self.isPlaying = AudioPlayerManager.shared.currentSessionId == sessionId && AudioPlayerManager.shared.isPlaying
        
        // Observe AudioPlayerManager changes
        AudioPlayerManager.shared.$isPlaying
            .receive(on: RunLoop.main)
            .sink { [weak self] playing in
                guard let self = self else { return }
                // Only update if it matches our session
                if AudioPlayerManager.shared.currentSessionId == self.sessionId {
                    self.isPlaying = playing
                    if playing {
                        self.startTimer()
                    } else {
                        self.stopTimer()
                    }
                } else {
                    self.isPlaying = false
                    self.stopTimer()
                }
            }
            .store(in: &cancellables)
            
        // If already playing this session, start timer
        if isPlaying {
            startTimer()
        }
    }
    
    deinit {
        stopTimer()
    }
    
    func playPause(source: AudioSource? = nil) {
        if isPlaying {
            AudioPlayerManager.shared.pause(sessionId: sessionId)
        } else {
            if AudioPlayerManager.shared.currentSessionId == sessionId {
                AudioPlayerManager.shared.resume(sessionId: sessionId)
            } else if let source {
                Task {
                    await play(source: source)
                }
            }
        }
    }

    private func play(source: AudioSource) async {
        do {
            let playableURL = try await preparePlayableURL(from: source)
            await MainActor.run {
                if AudioPlayerManager.shared.play(url: playableURL, sessionId: sessionId) {
                    // Duration might be updated after play starts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        guard let self else { return }
                        self.duration = AudioPlayerManager.shared.duration(for: self.sessionId) ?? 0
                    }
                }
            }
        } catch {
            print("[PlaybackViewModel] Failed to play audio: \(error)")
        }
    }

    private func preparePlayableURL(from source: AudioSource) async throws -> URL {
        let isRemote = !source.url.isFileURL
        var localURL = source.url
        if isRemote {
            localURL = try await downloadToTemporaryFile(from: source.url)
        }

        if requiresTranscode(source: source, localURL: localURL) {
            let decodedURL = try await AudioTranscoder.decodeToWav(inputURL: localURL)
            if isRemote {
                try? FileManager.default.removeItem(at: localURL)
            }
            return decodedURL
        }

        return localURL
    }

    private func requiresTranscode(source: AudioSource, localURL: URL) -> Bool {
        let codec = source.meta?.codec.lowercased()
        let container = source.meta?.container.lowercased()
        let ext = localURL.pathExtension.lowercased()
        if codec == "opus" || container == "ogg" || ext == "ogg" {
            return true
        }
        return false
    }

    private func downloadToTemporaryFile(from url: URL) async throws -> URL {
        let (tempURL, _) = try await URLSession.shared.download(from: url)
        let ext = url.pathExtension.isEmpty ? "dat" : url.pathExtension
        let filename = "audio_\(UUID().uuidString).\(ext)"
        let destURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destURL)
        return destURL
    }
    
    func seek(to time: Double) {
        AudioPlayerManager.shared.seek(sessionId: sessionId, to: time)
        currentTime = time
    }
    
    // Force duration update (e.g. after load)
    func updateDuration() {
        self.duration = AudioPlayerManager.shared.duration(for: sessionId) ?? 0
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let time = AudioPlayerManager.shared.currentTime(sessionId: self.sessionId) {
                self.currentTime = time
            }
            if self.duration == 0 {
                self.duration = AudioPlayerManager.shared.duration(for: self.sessionId) ?? 0
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

private enum AudioPlaybackError: Error {
    case ffmpegUnavailable
    case ffmpegFailed(String)
    case outputMissing
}

private enum AudioTranscoder {
    static func decodeToWav(inputURL: URL) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("decoded_\(UUID().uuidString).wav")
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
#if canImport(FFmpegKit) || canImport(ffmpegkit)
        let cmd = """
        -y -i "\(inputURL.path)" -ac 1 -ar 16000 -c:a pcm_s16le "\(outputURL.path)"
        """
        try await withCheckedThrowingContinuation { cont in
            FFmpegKit.executeAsync(cmd) { session in
                let rc = session?.getReturnCode()
                if rc?.isValueSuccess() == true {
                    cont.resume(returning: ())
                } else {
                    let log = session?.getAllLogsAsString() ?? "no log"
                    cont.resume(throwing: AudioPlaybackError.ffmpegFailed(log))
                }
            }
        }
#else
        throw AudioPlaybackError.ffmpegUnavailable
#endif
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw AudioPlaybackError.outputMissing
        }
        return outputURL
    }
}
