import SwiftUI

// MARK: - Integrated Playback Card

/// A unified playback card with seek bar, play button, and expandable chapter timeline
struct IntegratedPlaybackCard: View {
    let chapters: [ChapterMarker]
    let duration: TimeInterval
    @Binding var currentTime: TimeInterval
    @Binding var isPlaying: Bool
    let onSeek: (TimeInterval) -> Void
    let onPlayPause: () -> Void
    
    @State private var isExpanded: Bool = false
    @State private var dragProgress: CGFloat? = nil
    
    private var progress: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(currentTime / duration)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Main Playback Controls
            playbackControlsCard
            
            // MARK: - Expandable Chapter Timeline
            if isExpanded && !chapters.isEmpty {
                chapterTimeline
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }
    
    // MARK: - Playback Controls Card
    
    private var playbackControlsCard: some View {
        VStack(spacing: 12) {
            // Progress bar with chapters markers
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                
                // Progress fill
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(GlassNotebook.Accent.primary.gradient)
                        .frame(width: max(0, geo.size.width * (dragProgress ?? progress)))
                }
                .frame(height: 8)
                
                // Chapter markers
                GeometryReader { geo in
                    ForEach(chapters) { chapter in
                        let position = duration > 0 ? chapter.timeSeconds / duration : 0
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                            .shadow(color: .black.opacity(0.2), radius: 1)
                            .position(x: geo.size.width * CGFloat(position), y: 4)
                    }
                }
                .frame(height: 8)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let geo = value.location.x / UIScreen.main.bounds.width
                        dragProgress = min(max(geo, 0), 1)
                    }
                    .onEnded { value in
                        if let progress = dragProgress {
                            let newTime = Double(progress) * duration
                            print("[PlaybackCard 🖱️] Seek bar released at: \(newTime.mmssString) (\(Int(progress * 100))%)")
                            onSeek(newTime)
                        }
                        dragProgress = nil
                    }
            )
            
            // Time labels and controls
            HStack {
                // Current time
                Text(currentTime.mmssString)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Play/Pause button
                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(GlassNotebook.Accent.primary)
                        .symbolEffect(.bounce, value: isPlaying)
                }
                
                Spacer()
                
                // Duration
                Text(duration.mmssString)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            
            // Expand button for chapters
            if !chapters.isEmpty {
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                    print("[PlaybackCard 📂] Chapter list \(isExpanded ? "collapsed" : "expanded")")
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .font(.caption)
                        Text("\(chapters.count)チャプター")
                            .font(.caption.weight(.medium))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(GlassNotebook.Accent.primary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(
                        Capsule()
                            .fill(GlassNotebook.Accent.primary.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
    
    // MARK: - Chapter Timeline
    
    private var chapterTimeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                        ChapterTimelineRow(
                            chapter: chapter,
                            index: index,
                            isActive: isActiveChapter(chapter),
                            isNext: isNextChapter(chapter),
                            onTap: {
                                print("[PlaybackCard 🔖] Tapped chapter: '\(chapter.title)' at \(chapter.timeSeconds.mmssString)")
                                onSeek(chapter.timeSeconds)
                                if !isPlaying {
                                    onPlayPause()
                                }
                            }
                        )
                        .id(chapter.id)
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 300)
            .onChange(of: currentTime) { _, _ in
                if let active = chapters.first(where: { isActiveChapter($0) }) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(active.id, anchor: .center)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(GlassNotebook.Background.card)
        )
        .padding(.top, -8)
        .padding(.horizontal, 4)
    }
    
    // MARK: - Helpers
    
    private func isActiveChapter(_ chapter: ChapterMarker) -> Bool {
        guard let index = chapters.firstIndex(where: { $0.id == chapter.id }) else { return false }
        let nextTime = index < chapters.count - 1 ? chapters[index + 1].timeSeconds : duration
        return currentTime >= chapter.timeSeconds && currentTime < nextTime
    }
    
    private func isNextChapter(_ chapter: ChapterMarker) -> Bool {
        guard let activeIndex = chapters.firstIndex(where: { isActiveChapter($0) }),
              let chapterIndex = chapters.firstIndex(where: { $0.id == chapter.id }) else { return false }
        return chapterIndex == activeIndex + 1
    }
}

// MARK: - Chapter Timeline Row

struct ChapterTimelineRow: View {
    let chapter: ChapterMarker
    let index: Int
    let isActive: Bool
    let isNext: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Time badge
                Text(chapter.timeSeconds.mmssString)
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundColor(isActive ? .white : GlassNotebook.Accent.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isActive ? GlassNotebook.Accent.primary : GlassNotebook.Accent.primary.opacity(0.15))
                    )
                
                // Chapter title
                VStack(alignment: .leading, spacing: 2) {
                    Text(chapter.title)
                        .font(.subheadline.weight(isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? .primary : .secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if isActive {
                        Text("再生中")
                            .font(.caption2)
                            .foregroundStyle(GlassNotebook.Accent.primary)
                    }
                }
                
                Spacer()
                
                // Play indicator
                if isActive {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(GlassNotebook.Accent.primary)
                        .symbolEffect(.variableColor.iterative, isActive: true)
                } else {
                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? GlassNotebook.Accent.primary.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var currentTime: TimeInterval = 125
        @State private var isPlaying = false
        
        let chapters = [
            ChapterMarker(timeSeconds: 0, title: "イントロダクション"),
            ChapterMarker(timeSeconds: 65, title: "AIの基本概念について説明します"),
            ChapterMarker(timeSeconds: 180, title: "機械学習の種類と特徴"),
            ChapterMarker(timeSeconds: 320, title: "実践的な応用例"),
            ChapterMarker(timeSeconds: 480, title: "質疑応答")
        ]
        
        var body: some View {
            VStack {
                Spacer()
                
                IntegratedPlaybackCard(
                    chapters: chapters,
                    duration: 600,
                    currentTime: $currentTime,
                    isPlaying: $isPlaying,
                    onSeek: { time in
                        currentTime = time
                        print("Seek to: \(time)")
                    },
                    onPlayPause: {
                        isPlaying.toggle()
                    }
                )
                .padding()
            }
            .background(GlassNotebook.Background.primary)
        }
    }
    
    return PreviewWrapper()
}
