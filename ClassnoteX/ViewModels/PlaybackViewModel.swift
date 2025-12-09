import SwiftUI
import Combine

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
    
    func playPause(url: URL? = nil) {
        if isPlaying {
            AudioPlayerManager.shared.pause(sessionId: sessionId)
        } else {
            if AudioPlayerManager.shared.currentSessionId == sessionId {
                AudioPlayerManager.shared.resume(sessionId: sessionId)
            } else if let url = url {
                AudioPlayerManager.shared.play(url: url, sessionId: sessionId)
                // Duration might be updated after play starts
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.duration = AudioPlayerManager.shared.duration(for: self.sessionId) ?? 0
                }
            }
        }
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
