import SwiftUI

// MARK: - TimeInterval Extension for mm:ss format

extension TimeInterval {
    var mmssString: String {
        let total = Int(self.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Chapter List View (YouTube-style)

struct ChapterListView: View {
    let chapters: [ChapterMarker]
    let currentTime: TimeInterval
    let onSeek: (TimeInterval) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("チャプター", systemImage: "list.bullet.rectangle.portrait")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GlassNotebook.Text.secondary)
                
                Spacer()
                
                Text("\(chapters.count)件")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(GlassNotebook.Background.elevated)
            
            // Chapter items
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chapters) { chapter in
                        ChapterChip(
                            chapter: chapter,
                            isActive: isActive(chapter),
                            onTap: { 
                                onSeek(chapter.timeSeconds)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(GlassNotebook.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func isActive(_ chapter: ChapterMarker) -> Bool {
        guard let index = chapters.firstIndex(where: { $0.id == chapter.id }) else { return false }
        let nextChapterTime = index < chapters.count - 1 ? chapters[index + 1].timeSeconds : Double.infinity
        return currentTime >= chapter.timeSeconds && currentTime < nextChapterTime
    }
}

// MARK: - Chapter Chip

struct ChapterChip: View {
    let chapter: ChapterMarker
    let isActive: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Time badge
                Text(chapter.timeSeconds.mmssString)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(isActive ? GlassNotebook.Accent.primary : Color.gray.opacity(0.6))
                    )
                
                // Title
                Text(chapter.title)
                    .font(.subheadline)
                    .foregroundStyle(isActive ? GlassNotebook.Accent.primary : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isActive ? GlassNotebook.Accent.primary.opacity(0.12) : GlassNotebook.Background.elevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isActive ? GlassNotebook.Accent.primary : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

// MARK: - Vertical Chapter List (for detail view)

struct ChapterTimelineView: View {
    let chapters: [ChapterMarker]
    let currentTime: TimeInterval
    let onSeek: (TimeInterval) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                Button {
                    onSeek(chapter.timeSeconds)
                } label: {
                    HStack(spacing: 12) {
                        // Time
                        Text(chapter.timeSeconds.mmssString)
                            .font(.system(.caption, design: .monospaced).weight(.medium))
                            .foregroundStyle(isActive(chapter) ? GlassNotebook.Accent.primary : .secondary)
                            .frame(width: 50, alignment: .leading)
                        
                        // Active indicator
                        Circle()
                            .fill(isActive(chapter) ? GlassNotebook.Accent.primary : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                        
                        // Title
                        Text(chapter.title)
                            .font(.subheadline)
                            .foregroundStyle(isActive(chapter) ? .primary : .secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Play icon
                        if isActive(chapter) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.caption)
                                .foregroundStyle(GlassNotebook.Accent.primary)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(isActive(chapter) ? GlassNotebook.Accent.primary.opacity(0.08) : Color.clear)
                }
                .buttonStyle(.plain)
                
                if index < chapters.count - 1 {
                    Divider()
                        .padding(.leading, 74)
                }
            }
        }
        .background(GlassNotebook.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func isActive(_ chapter: ChapterMarker) -> Bool {
        guard let index = chapters.firstIndex(where: { $0.id == chapter.id }) else { return false }
        let nextChapterTime = index < chapters.count - 1 ? chapters[index + 1].timeSeconds : Double.infinity
        return currentTime >= chapter.timeSeconds && currentTime < nextChapterTime
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ChapterListView(
            chapters: [
                ChapterMarker(timeSeconds: 0, title: "自己紹介"),
                ChapterMarker(timeSeconds: 65, title: "今日のテーマ"),
                ChapterMarker(timeSeconds: 180, title: "公平性とバイアス"),
                ChapterMarker(timeSeconds: 420, title: "Q&A")
            ],
            currentTime: 100,
            onSeek: { _ in }
        )
        
        ChapterTimelineView(
            chapters: [
                ChapterMarker(timeSeconds: 0, title: "自己紹介"),
                ChapterMarker(timeSeconds: 65, title: "今日のテーマ"),
                ChapterMarker(timeSeconds: 180, title: "公平性とバイアス"),
                ChapterMarker(timeSeconds: 420, title: "Q&A")
            ],
            currentTime: 100,
            onSeek: { _ in }
        )
    }
    .padding()
    .background(GlassNotebook.Background.primary)
}
