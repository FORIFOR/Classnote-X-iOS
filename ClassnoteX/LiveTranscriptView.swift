import SwiftUI

/// Premium live transcript view with progressive styling
struct LiveTranscriptView: View {
    let text: String
    let isListening: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            if text.isEmpty && isListening {
                // Listening state
                listeningPlaceholder
            } else if !text.isEmpty {
                // Active transcription
                transcriptContent
            }
        }
        .animation(.easeOut(duration: 0.2), value: text)
    }
    
    private var listeningPlaceholder: some View {
        HStack(spacing: 12) {
            // Animated dots
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color(.systemBlue))
                        .frame(width: 6, height: 6)
                        .opacity(0.6)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                            value: isListening
                        )
                }
            }
            
            Text("リスニング中...")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(HIGColors.secondaryLabel)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(HIGColors.secondaryBackground)
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    private var transcriptContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Split into segments for progressive styling
            let segments = splitIntoSegments(text)
            
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                let isRecent = index == segments.count - 1
                let opacity = opacityFor(index: index, total: segments.count)
                let weight: Font.Weight = isRecent ? .semibold : .regular
                
                Text(segment)
                    .font(.body.weight(weight))
                    .foregroundStyle(
                        isRecent 
                            ? HIGColors.label
                            : HIGColors.secondaryLabel.opacity(opacity)
                    )
                    .multilineTextAlignment(.leading)
                    .animation(.easeOut(duration: 0.15), value: segment)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(HIGColors.secondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(HIGColors.separator, lineWidth: 0.5)
        )
    }
    
    private func splitIntoSegments(_ text: String) -> [String] {
        // Split by natural breaks (punctuation)
        let separators = CharacterSet(charactersIn: "。、！？,.!?")
        var segments: [String] = []
        var current = ""
        
        for char in text {
            current.append(char)
            if char.unicodeScalars.first.map({ separators.contains($0) }) == true {
                segments.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            }
        }
        
        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            segments.append(current.trimmingCharacters(in: .whitespaces))
        }
        
        // Limit to last 3 segments for readability
        if segments.count > 3 {
            return Array(segments.suffix(3))
        }
        
        return segments
    }
    
    private func opacityFor(index: Int, total: Int) -> Double {
        // Most recent = full opacity, older = faded
        let position = Double(total - 1 - index)
        return max(0.5, 1.0 - position * 0.25)
    }
}

// MARK: - Compact Variant for Recording Screen

struct CompactTranscriptView: View {
    let text: String
    let isListening: Bool
    
    var body: some View {
        Group {
            if text.isEmpty && isListening {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .foregroundStyle(.secondary)
                    Text("話し始めると字幕が表示されます")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if !text.isEmpty {
                // Show last portion with gradient fade
                Text(recentText)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            }
        }
        .animation(.easeOut(duration: 0.2), value: text)
    }
    
    private var recentText: String {
        // Show last ~80 characters
        if text.count > 80 {
            return "..." + String(text.suffix(80))
        }
        return text
    }
}

#Preview {
    VStack(spacing: 20) {
        LiveTranscriptView(
            text: "これはテストです。音声認識のテストを行っています。なかなか良い精度で動作しています。",
            isListening: true
        )
        
        CompactTranscriptView(
            text: "リアルタイムで文字起こしをしています",
            isListening: true
        )
    }
    .padding()
}
