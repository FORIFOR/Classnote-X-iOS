import Foundation
import AVFoundation
import Combine

class AudioPlayerManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerManager()

    @Published var isPlaying = false
    @Published var currentSessionId: String?
    
    private var player: AVAudioPlayer?
    
    private override init() {
        super.init()
    }
    
    @discardableResult
    func play(url: URL, sessionId: String? = nil) -> Bool {
        print("[AudioPlayerManager] ========== PLAY AUDIO ==========")
        print("[AudioPlayerManager] Request for session: \(sessionId ?? "nil")")
        print("[AudioPlayerManager] Loading audio from: \(url.path)")
        
        // Stop any existing playback if it's a different file or force restart
        if let current = currentSessionId, current != sessionId {
            stop()
        }
        
        // If already playing the same session, just resume? 
        // No, play usually means start. But let's check.
        if isPlaying && currentSessionId == sessionId {
            print("[AudioPlayerManager] Already playing this session")
            return true
        }

        do {
            // 1. File size verification
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = (attrs[.size] as? NSNumber)?.intValue ?? -1
            print("[AudioPlayerManager] File size = \(fileSize) bytes")
            
            if fileSize <= 0 {
                print("[AudioPlayerManager] ❌ File is empty or inaccessible!")
                isPlaying = false
                currentSessionId = nil
                return false
            }
            
            // 2. Configure audio session
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            
            // 3. Load file as Data
            let data = try Data(contentsOf: url)
            
            if data.isEmpty {
                print("[AudioPlayerManager] ❌ Data is empty!")
                isPlaying = false
                currentSessionId = nil
                return false
            }
            
            // 4. Create player
            let newPlayer = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.m4a.rawValue)
            newPlayer.delegate = self
            newPlayer.enableRate = true
            newPlayer.prepareToPlay()
            
            // 5. Start playback
            if newPlayer.play() {
                player = newPlayer
                isPlaying = true
                currentSessionId = sessionId
                print("[AudioPlayerManager] ✅ Playback started for session: \(sessionId ?? "unknown")")
                return true
            } else {
                print("[AudioPlayerManager] ❌ play() returned false")
                isPlaying = false
                currentSessionId = nil
                return false
            }
        } catch {
            print("[AudioPlayerManager] ❌ Error: \(error)")
            isPlaying = false
            currentSessionId = nil
            return false
        }
    }
    
    // Convenience for just ID?
    // This requires AudioPlayerManager to know how to fetch URL from ID, which it doesn't.
    // So generic play(sessionId:) must be called with URL too or handled by caller.
    // We'll stick to play(url:sessionId:)
    
    func pause(sessionId: String? = nil) {
        // If sessionId provided, only pause if it matches
        if let targetedId = sessionId {
            guard currentSessionId == targetedId else { return }
        }
        player?.pause()
        isPlaying = false
        print("[AudioPlayerManager] Paused")
    }
    
    func resume(sessionId: String) {
        guard currentSessionId == sessionId, let player = player else { return }
        if player.play() {
            isPlaying = true
        }
    }
    
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentSessionId = nil
        print("[AudioPlayerManager] Stopped")
    }
    
    func setRate(_ rate: Float) {
        player?.rate = rate
    }
    
    // MARK: - Info Accessors
    
    func currentTime(sessionId: String) -> TimeInterval? {
        // Only return if matching session
        guard currentSessionId == sessionId else { return nil }
        return player?.currentTime
    }
    
    func duration(for sessionId: String) -> TimeInterval? {
        // Only return if matching session
        // If we want to support getting duration without playing, we'd need to peek at the file.
        // For now, assume we only know duration if we loaded it.
        guard currentSessionId == sessionId else { return nil }
        return player?.duration
    }
    
    func seek(sessionId: String, to time: TimeInterval) {
        guard currentSessionId == sessionId, let player = player else { return }
        let clampedTime = max(0, min(time, player.duration))
        player.currentTime = clampedTime
        print("[AudioPlayerManager] Seeked to \(clampedTime)")
    }
    
    // MARK: - Delegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("[AudioPlayerManager] Playback finished")
        Task { @MainActor in
            self.isPlaying = false
            // Keep currentSessionId so we can replay? Or clear it?
            // Usually keep it so we can seek back to 0. 
        }
    }
}
