import SwiftUI
// Models: using ClassnoteAPIClient definitions

// MARK: - Diarized Transcript View

/// Displays transcript with speaker labels and colors
struct DiarizedTranscriptView: View {
    let segments: [DiarizedSegment]
    let speakers: [Speaker]
    let currentTime: TimeInterval
    let onSeek: (TimeInterval) -> Void
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(segments) { segment in
                        DiarizedSegmentRow(
                            segment: segment,
                            speaker: speaker(for: segment),
                            isActive: isActive(segment),
                            onTap: { 
                                print("[Diarization 💬] Tapped segment by \(segment.speakerId) at \(segment.start.mmssString)")
                                onSeek(segment.start) 
                            }
                        )
                        .id(segment.id)
                    }
                }
                .padding()
            }
            .onChange(of: currentTime) { _, newTime in
                if let activeSegment = segments.first(where: { isActive($0) }) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(activeSegment.id, anchor: .center)
                    }
                }
            }
        }
    }
    
    private func speaker(for segment: DiarizedSegment) -> Speaker? {
        speakers.first { $0.id == segment.speakerId }
    }
    
    private func isActive(_ segment: DiarizedSegment) -> Bool {
        currentTime >= segment.start && currentTime < segment.end
    }
}

// MARK: - Diarized Segment Row

struct DiarizedSegmentRow: View {
    let segment: DiarizedSegment
    let speaker: Speaker?
    let isActive: Bool
    let onTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var speakerColor: Color {
        guard let speaker else { return .gray }
        return Color(hex: speaker.color)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Speaker Avatar
                Circle()
                    .fill(speakerColor.gradient)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text(speaker?.label ?? "?")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: speakerColor.opacity(0.3), radius: isActive ? 6 : 0)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Speaker name + time
                    HStack {
                        Text(speaker?.displayName ?? "話者不明")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(speakerColor)
                        
                        Text(segment.start.mmssString)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                        
                        if isActive {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.caption)
                                .foregroundStyle(speakerColor)
                                .symbolEffect(.variableColor.iterative, isActive: true)
                        }
                    }
                    
                    // Segment text
                    Text(segment.text)
                        .font(.body)
                        .foregroundStyle(isActive ? .primary : .secondary)
                        .multilineTextAlignment(.leading)
                        .textSelection(.enabled)
                }
                
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? speakerColor.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isActive ? speakerColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

// MARK: - Speaker Stats View

struct SpeakerStatsView: View {
    let speakers: [Speaker]
    let stats: [SpeakerStats]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("話者統計")
                .font(.headline)
            
            ForEach(speakers) { speaker in
                if let stat = stats.first(where: { $0.speakerId == speaker.id }) {
                    HStack {
                        Circle()
                            .fill(Color(hex: speaker.color).gradient)
                            .frame(width: 24, height: 24)
                            .overlay {
                                Text(speaker.label)
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            }
                        
                        Text(speaker.displayName)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(stat.formattedDuration)
                                .font(.subheadline.monospacedDigit().bold())
                            Text("\(stat.segmentCount)発言")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding()
        .background(GlassNotebook.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Diarization Status Banner

struct DiarizationStatusBanner: View {
    let status: DiarizationStatus
    let onRetry: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            statusIcon
            
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.subheadline.weight(.semibold))
                Text(statusDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if status == .failed {
                Button("再試行") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(statusBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .none:
            Image(systemName: "person.2.slash")
                .foregroundStyle(.secondary)
        case .pending, .processing:
            ProgressView()
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
    
    private var statusTitle: String {
        switch status {
        case .none: return "話者分離未実行"
        case .pending: return "話者分離を待機中..."
        case .processing: return "話者分離を実行中..."
        case .done: return "話者分離完了"
        case .failed: return "話者分離に失敗"
        }
    }
    
    private var statusDescription: String {
        switch status {
        case .none: return "会議モードでは話者ごとに発言を分けて表示できます"
        case .pending: return "まもなく処理を開始します"
        case .processing: return "音声を分析しています（1-2分程度）"
        case .done: return "話者ごとに発言が分類されました"
        case .failed: return "エラーが発生しました。再試行できます"
        }
    }
    
    private var statusBackground: some ShapeStyle {
        switch status {
        case .none: return AnyShapeStyle(Color.gray.opacity(0.1))
        case .pending, .processing: return AnyShapeStyle(Color.blue.opacity(0.1))
        case .done: return AnyShapeStyle(Color.green.opacity(0.1))
        case .failed: return AnyShapeStyle(Color.red.opacity(0.1))
        }
    }
}

// Note: Color(hex:) extension is defined in Theme.swift

// MARK: - Preview

#Preview {
    let speakers = [
        Speaker(id: "spk_0", label: "A", displayName: "話者A", colorHex: "#5E97F6"),
        Speaker(id: "spk_1", label: "B", displayName: "話者B", colorHex: "#9C6ADE")
    ]
    
    let segments = [
        DiarizedSegment(id: "1", start: 0, end: 5, speakerId: "spk_0", text: "こんにちは、本日はお集まりいただきありがとうございます。"),
        DiarizedSegment(id: "2", start: 5, end: 12, speakerId: "spk_1", text: "こちらこそ、よろしくお願いします。"),
        DiarizedSegment(id: "3", start: 12, end: 25, speakerId: "spk_0", text: "では早速ですが、今回の議題についてお話しさせていただきます。")
    ]
    
    return VStack(spacing: 20) {
        DiarizationStatusBanner(status: .processing) { }
        
        DiarizedTranscriptView(
            segments: segments,
            speakers: speakers,
            currentTime: 8,
            onSeek: { _ in }
        )
    }
    .padding()
    .background(GlassNotebook.Background.primary)
}
