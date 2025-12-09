import SwiftUI
import Combine

/// Audio-reactive waveform visualization
struct AudioWaveformView: View {
    let audioLevel: CGFloat // 0.0 - 1.0
    let isActive: Bool
    var barCount: Int = 5
    var color: Color = .white
    
    @State private var animatedLevels: [CGFloat] = []
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(isActive ? 0.9 : 0.4))
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(.spring(response: 0.15, dampingFraction: 0.6), value: audioLevel)
            }
        }
        .onAppear {
            animatedLevels = Array(repeating: 0.2, count: barCount)
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 32
        
        guard isActive else {
            return baseHeight
        }
        
        // Create natural wave pattern
        let centerIndex = CGFloat(barCount) / 2.0
        let distanceFromCenter = abs(CGFloat(index) - centerIndex)
        let falloff = 1.0 - (distanceFromCenter / centerIndex) * 0.4
        
        // Add subtle variation
        let variation = sin(Double(index) * 0.8 + Date().timeIntervalSinceReferenceDate * 3) * 0.15
        let level = (audioLevel * falloff + CGFloat(variation)).clamped(to: 0...1)
        
        return baseHeight + (maxHeight - baseHeight) * level
    }
}

/// Larger waveform for recording screen
struct RecordingWaveformView: View {
    let audioLevel: CGFloat
    let isRecording: Bool
    @State private var phase: Double = 0
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { index in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                isRecording ? Color(.systemRed) : Color(.systemBlue),
                                isRecording ? Color(.systemRed).opacity(0.7) : Color(.systemBlue).opacity(0.7)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 6, height: waveHeight(for: index))
                    .animation(.spring(response: 0.12, dampingFraction: 0.5), value: audioLevel)
            }
        }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            if isRecording {
                phase += 0.15
            }
        }
    }
    
    private func waveHeight(for index: Int) -> CGFloat {
        let minHeight: CGFloat = 12
        let maxHeight: CGFloat = 48
        
        guard isRecording else {
            // Subtle idle animation
            let idle = sin(phase + Double(index) * 0.5) * 0.1 + 0.2
            return minHeight + (maxHeight - minHeight) * CGFloat(idle)
        }
        
        // Create organic wave pattern based on audio level
        let centerOffset = abs(CGFloat(index) - 3.0) / 3.0
        let waveOffset = sin(phase + Double(index) * 0.7) * 0.2
        let level = (audioLevel * (1.0 - centerOffset * 0.3) + CGFloat(waveOffset)).clamped(to: 0...1)
        
        return minHeight + (maxHeight - minHeight) * level
    }
}

// MARK: - Clamped Extension

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    VStack(spacing: 40) {
        AudioWaveformView(audioLevel: 0.6, isActive: true)
        RecordingWaveformView(audioLevel: 0.7, isRecording: true)
    }
    .padding()
    .background(Color.black)
}
