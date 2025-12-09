import SwiftUI

// MARK: - 3-1. Speaker Timeline

struct GlassSpeakerTimelineView: View {
    let segments: [SpeakerSegment]
    let totalDuration: Double

    private func color(for tag: String) -> Color {
        // Simple heuristic for colors based on tag
        // Ideally should match AppColors.speakerColors
        let index = abs(tag.hashValue) % 6
        // Fallback colors if AppColors not available directly here, but we import SwiftUI so we can access Theme.
        // Assuming Theme.swift defines AppColors or Palette.
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink, .teal
        ]
        return colors[index]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))

                ForEach(segments) { seg in
                    let startX = totalDuration > 0 ? geo.size.width * seg.start / totalDuration : 0
                    let width  = totalDuration > 0 ? geo.size.width * (seg.end - seg.start) / totalDuration : 0

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color(for: seg.speaker).opacity(0.6))
                        .frame(width: max(width, 2))
                        .offset(x: startX)
                }
            }
        }
        .frame(height: 10)
    }
}

// MARK: - 3-2. Chapter Seek Bar

struct ChapterSeekBarView: View {
    @ObservedObject var playback: PlaybackViewModel
    let chapters: [ChapterMarker]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Time Labels
            HStack {
                Text(formatTime(playback.currentTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatTime(playback.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // Seek Slider
            Slider(
                value: Binding(
                    get: { playback.currentTime },
                    set: { newVal in playback.seek(to: newVal) }
                ),
                in: 0...max(playback.duration, 1)
            )
            .tint(Color.blue) // Use generic blue or theme color

            // Chapter Chips
            if !chapters.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chapters) { chapter in
                            Button {
                                playback.seek(to: chapter.timeSeconds)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(formatTime(chapter.timeSeconds))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                    Text(chapter.title)
                                        .font(.caption2)
                                    Image(systemName: "play.fill")
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func formatTime(_ sec: Double) -> String {
        let total = Int(sec)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - 3-3. Playback Section

struct PlaybackSectionView: View {
    @ObservedObject var playback: PlaybackViewModel
    let speakerSegments: [SpeakerSegment]
    let chapters: [ChapterMarker]
    let audioUrl: URL? // Add URL to pass to play

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("再生")
                    .font(.headline)
                Spacer()
                Button {
                    playback.playPause(url: audioUrl)
                } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            GlassSpeakerTimelineView(
                segments: speakerSegments,
                totalDuration: playback.duration
            )

            ChapterSeekBarView(
                playback: playback,
                chapters: chapters
            )
        }
        .padding()
        .background(GlassNotebook.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
    }
}


// MARK: - 4. Summary Card

struct SummaryCardView: View {
    let title: String
    let overview: String
    let points: [String]
    let keywords: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI要約", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
            }

            Text(overview)
                .font(.subheadline)
                .foregroundStyle(.primary)

            if !points.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(points, id: \.self) { p in
                        HStack(alignment: .top, spacing: 6) {
                            Circle()
                                .fill(Color.secondary)
                                .frame(width: 4, height: 4)
                                .padding(.top, 6)
                            Text(p)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !keywords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(keywords.prefix(6), id: \.self) { kw in
                            Text("#\(kw)")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(GlassNotebook.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
    }
}

// MARK: - 5. Notes Section

struct NotesSectionView: View {
    @ObservedObject var playback: PlaybackViewModel
    @State private var draftText: String = ""
    let notes: [SessionNote]
    let onAddNote: (String, Double) -> Void
    let onTapNote: (SessionNote) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("メモ")
                    .font(.headline)
                Spacer()
                if !draftText.isEmpty {
                    Button("保存") {
                        let t = playback.currentTime
                        onAddNote(draftText, t)
                        draftText = ""
                    }
                    .font(.caption.weight(.semibold))
                }
            }

            ZStack(alignment: .topLeading) {
                if draftText.isEmpty {
                    Text("再生中の内容をメモ…")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                
                TextEditor(text: $draftText)
                    .frame(minHeight: 80, maxHeight: 120)
                    .padding(4)
                    .scrollContentBackground(.hidden) // Important for styling
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(notes) { note in
                        Button {
                            onTapNote(note) // → Jump to time
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Text(formatTime(note.timeSec))
                                    .font(.caption2.monospacedDigit())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                Text(note.text)
                                    .font(.footnote)
                                    .foregroundStyle(.primary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(GlassNotebook.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)
    }

    private func formatTime(_ sec: Double) -> String {
        let total = Int(sec)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}
