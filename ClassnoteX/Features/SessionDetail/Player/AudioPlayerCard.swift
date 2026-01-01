import SwiftUI

// MARK: - Audio Player Card

/// Bottom audio player bar with play/pause, seek slider, and expandable playlist
struct AudioPlayerCard: View {
    let isPlaying: Bool
    let currentTime: Double
    let duration: Double
    let hasAudio: Bool
    let isExpanded: Bool
    let aiMarkers: [AIMarker]

    let onPlayPause: () -> Void
    let onSeek: (Double) -> Void
    let onToggleExpand: () -> Void

    @State private var isDragging = false
    @State private var dragValue: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            // Player controls row
            controlsRow

            // Expanded playlist
            if isExpanded && !aiMarkers.isEmpty {
                Rectangle()
                    .fill(Tokens.Color.border)
                    .frame(height: Tokens.Border.hairline)
                    .padding(.horizontal, Tokens.Spacing.md)

                playlistContent
                    .frame(maxHeight: 260)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .fill(Tokens.Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }

    // MARK: - Controls Row

    private var controlsRow: some View {
        let secondaryColor = hasAudio ? Tokens.Color.textSecondary : Tokens.Color.textTertiary

        return HStack(spacing: Tokens.Spacing.sm) {
            playButton

            VStack(spacing: Tokens.Spacing.xxs) {
                HStack {
                    Text(formatTime(isDragging ? dragValue : currentTime))
                        .font(Tokens.Typography.caption())
                        .monospacedDigit()
                        .foregroundStyle(secondaryColor)

                    Spacer()

                    Text(formatTime(duration))
                        .font(Tokens.Typography.caption())
                        .monospacedDigit()
                        .foregroundStyle(secondaryColor)
                }

                ProgressSlider(
                    value: progressValue,
                    isEnabled: hasAudio,
                    onEditingChanged: { editing, value in
                        isDragging = editing
                        dragValue = value * max(duration, 1)
                        if !editing {
                            onSeek(dragValue)
                        }
                    }
                )
                .disabled(!hasAudio)
            }

            Button(action: onToggleExpand) {
                Image(systemName: "chevron.up")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(secondaryColor)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .frame(width: Tokens.Sizing.iconButton, height: Tokens.Sizing.iconButton)
                    .background(
                        Circle().fill(Tokens.Color.surface)
                    )
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.25), value: isExpanded)
        }
        .padding(.horizontal, Tokens.Spacing.md)
        .frame(height: Tokens.Sizing.playerCardHeight)
    }

    // MARK: - Playlist Content

    private var playlistContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(aiMarkers) { marker in
                    InlinePlaylistRow(
                        marker: marker,
                        isCurrent: abs(currentTime - marker.startSec) < 3
                    ) {
                        Haptics.light()
                        onSeek(marker.startSec)
                    }

                    if marker.id != aiMarkers.last?.id {
                        Rectangle()
                            .fill(Tokens.Color.border)
                            .frame(height: Tokens.Border.hairline)
                            .padding(.horizontal, Tokens.Spacing.md)
                    }
                }
            }
        }
    }

    // MARK: - Play Button

    private var playButton: some View {
        let buttonColor = hasAudio ? Tokens.Color.textPrimary : Tokens.Color.border
        let iconColor = hasAudio ? Tokens.Color.surface : Tokens.Color.textSecondary
        return Button(action: {
            Haptics.light()
            onPlayPause()
        }) {
            ZStack {
                Circle()
                    .fill(buttonColor)

                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(Tokens.Typography.iconMedium())
                    .foregroundStyle(iconColor)
            }
            .frame(width: Tokens.Sizing.playButton, height: Tokens.Sizing.playButton)
        }
        .buttonStyle(.plain)
        .disabled(!hasAudio)
    }

    private var progressValue: Double {
        guard duration > 0 else { return 0 }
        let value = isDragging ? dragValue : currentTime
        return min(max(value / duration, 0), 1)
    }

    // MARK: - Time Formatting

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

private struct ProgressSlider: View {
    let value: Double
    let isEnabled: Bool
    let onEditingChanged: (Bool, Double) -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let clamped = min(max(value, 0), 1)
            let xPos = width * clamped

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Tokens.Color.border)
                    .frame(height: 6)

                Capsule()
                    .fill(isEnabled ? Tokens.Color.accent : Tokens.Color.border)
                    .frame(width: max(6, xPos), height: 6)

                Circle()
                    .fill(Tokens.Color.surface)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                    )
                    .offset(x: xPos - 9)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let progress = min(max(value.location.x / width, 0), 1)
                        onEditingChanged(true, progress)
                    }
                    .onEnded { value in
                        let progress = min(max(value.location.x / width, 0), 1)
                        onEditingChanged(false, progress)
                    }
            )
        }
        .frame(height: 18)
    }
}

// MARK: - Inline Playlist Row

private struct InlinePlaylistRow: View {
    let marker: AIMarker
    let isCurrent: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Tokens.Spacing.sm) {
                // Time label: "00:00"
                Text(formatTime(marker.startSec))
                    .font(Tokens.Typography.caption())
                    .monospacedDigit()
                    .foregroundStyle(isCurrent ? Tokens.Color.accent : Tokens.Color.textSecondary)
                    .frame(width: 48, alignment: .leading)

                // Title
                Text(marker.title)
                    .font(Tokens.Typography.body())
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .lineLimit(1)

                Spacer()

                // AI badge
                Image(systemName: "sparkles")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Tokens.Gradients.ai)

                // Playing indicator
                if isCurrent {
                    Image(systemName: "waveform")
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.accent)
                }
            }
            .padding(.horizontal, Tokens.Spacing.md)
            .padding(.vertical, Tokens.Spacing.sm)
            .background(Tokens.Color.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous)
                    .stroke(isCurrent ? Tokens.Color.accent : Tokens.Color.border, lineWidth: Tokens.Border.hairline)
            )
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Expanded Playlist Sheet

/// Expanded view showing user tags and AI markers
struct PlaylistSheet: View {
    let tags: [String]
    let aiMarkers: [AIMarker]
    let currentTime: Double
    let onSeek: (Double) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Tokens.Spacing.md) {
                        if entries.isEmpty {
                            EmptyStateView(
                                icon: "list.bullet",
                                title: "マーカーがありません",
                                message: "録音中のタグやAIマーカーがここに表示されます"
                            )
                        } else {
                            GlassCard {
                                VStack(spacing: 0) {
                                    ForEach(entries) { entry in
                                        PlaylistItem(
                                            timeLabel: entry.timeLabel,
                                            title: entry.title,
                                            subtitle: entry.subtitle,
                                            isAI: entry.isAI,
                                            isCurrent: isCurrentItem(entry.time),
                                            isSeekable: entry.isSeekable
                                        ) {
                                            if let time = entry.time {
                                                onSeek(time)
                                            }
                                        }
                                        if entry.id != entries.last?.id {
                                            Rectangle()
                                                .fill(Tokens.Color.border)
                                                .frame(height: Tokens.Border.hairline)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(Tokens.Spacing.screenHorizontal)
                }
            }
            .navigationTitle("プレイリスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        onDismiss()
                    }
                }
            }
        }
    }

    private func isCurrentItem(_ time: Double?) -> Bool {
        guard let time else { return false }
        return abs(currentTime - time) < 3
    }

    private var entries: [PlaylistEntry] {
        let tagEntries = tags.map { tag in
            PlaylistEntry(
                id: "tag-\(tag)",
                time: nil,
                timeLabel: "",
                title: tag,
                subtitle: nil,
                isAI: false,
                isSeekable: false
            )
        }
        let markerEntries = aiMarkers.map { marker in
            let timeLabel = "\(formatTime(marker.startSec))–\(formatTime(marker.endSec))"
            let tagText = marker.tags?.map { "#\($0)" }.joined(separator: " ")
            return PlaylistEntry(
                id: "ai-\(marker.id)",
                time: marker.startSec,
                timeLabel: timeLabel,
                title: marker.title,
                subtitle: tagText?.isEmpty == true ? nil : tagText,
                isAI: true,
                isSeekable: true
            )
        }
        return (tagEntries + markerEntries).sorted { ($0.time ?? 0) < ($1.time ?? 0) }
    }

    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Playlist Item

private struct PlaylistItem: View {
    let timeLabel: String
    let title: String
    let subtitle: String?
    let isAI: Bool
    let isCurrent: Bool
    let isSeekable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.light()
            action()
        }) {
            HStack(spacing: Tokens.Spacing.sm) {
                // Time
                Text(timeLabel)
                    .font(Tokens.Typography.caption())
                    .monospacedDigit()
                    .foregroundStyle(isCurrent ? Tokens.Color.accent : Tokens.Color.textSecondary)
                    .frame(width: 72, alignment: .leading)

                VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
                    Text(title)
                        .font(Tokens.Typography.body())
                        .foregroundStyle(Tokens.Color.textPrimary)
                        .lineLimit(1)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(Tokens.Typography.caption())
                            .foregroundStyle(Tokens.Color.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // AI badge
                if isAI {
                    Image(systemName: "sparkles")
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Gradients.ai)
                }

                // Current indicator
                if isCurrent {
                    Image(systemName: "waveform")
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.accent)
                }
            }
            .padding(.horizontal, Tokens.Spacing.cardContent)
            .padding(.vertical, Tokens.Spacing.sm)
            .background(Tokens.Color.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous)
                    .stroke(isCurrent ? Tokens.Color.accent : Tokens.Color.border, lineWidth: Tokens.Border.hairline)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isSeekable)
    }
}

// Models are defined in SessionModels.swift:
// - TagMarker
// - AIMarker (typealias for Marker)

private struct PlaylistEntry: Identifiable {
    let id: String
    let time: Double?
    let timeLabel: String
    let title: String
    let subtitle: String?
    let isAI: Bool
    let isSeekable: Bool
}
