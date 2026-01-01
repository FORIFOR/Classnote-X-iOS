import SwiftUI

/// Inline audio player that expands/collapses in place
struct InlineExpandablePlayer: View {
    let isPlaying: Bool
    let currentTime: Double
    let duration: Double
    let hasAudio: Bool
    @Binding var isExpanded: Bool
    let aiMarkers: [AIMarker]
    let onPlayPause: () -> Void
    let onSeek: (Double) -> Void

    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed: Mini player bar
            collapsedView

            // Expanded: Full controls + playlist
            if isExpanded {
                expandedContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity.combined(with: .move(edge: .bottom))
                    ))
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
        .shadow(
            color: Tokens.Shadows.card(for: colorScheme).color,
            radius: Tokens.Shadows.card(for: colorScheme).radius,
            x: Tokens.Shadows.card(for: colorScheme).x,
            y: Tokens.Shadows.card(for: colorScheme).y
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
    }

    // MARK: - Collapsed View

    private var collapsedView: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            playButton

            if isExpanded {
                // Expanded: Full slider
                sliderSection
            } else {
                // Collapsed: Compact time display
                compactTimeDisplay
            }

            expandButton
        }
        .padding(.horizontal, Tokens.Spacing.md)
        .padding(.vertical, Tokens.Spacing.sm)
    }

    private var compactTimeDisplay: some View {
        let secondaryColor = hasAudio ? Tokens.Color.textSecondary : Tokens.Color.textTertiary

        return VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
            HStack(spacing: Tokens.Spacing.xxs) {
                Text(formatTime(currentTime))
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(secondaryColor)
                    .monospacedDigit()
                Text("/")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Tokens.Color.textTertiary)
                Text(formatTime(duration))
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(secondaryColor)
                    .monospacedDigit()
            }

            MiniProgressBar(value: progressValue, accentColor: Tokens.Color.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sliderSection: some View {
        let secondaryColor = hasAudio ? Tokens.Color.textSecondary : Tokens.Color.textTertiary

        return VStack(spacing: Tokens.Spacing.xxs) {
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

            SeekSlider(
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
        .frame(maxWidth: .infinity)
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(spacing: 0) {
            if !aiMarkers.isEmpty {
                Divider()
                    .padding(.horizontal, Tokens.Spacing.md)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(aiMarkers) { marker in
                            MarkerRow(
                                marker: marker,
                                isCurrent: abs(currentTime - marker.startSec) < 3
                            ) {
                                Haptics.light()
                                onSeek(marker.startSec)
                            }

                            if marker.id != aiMarkers.last?.id {
                                Divider()
                                    .padding(.horizontal, Tokens.Spacing.md)
                            }
                        }
                    }
                    .padding(.vertical, Tokens.Spacing.xs)
                }
                .frame(maxHeight: 240)
            } else {
                emptyPlaylistState
            }
        }
    }

    private var emptyPlaylistState: some View {
        VStack(spacing: Tokens.Spacing.xs) {
            Image(systemName: "music.note.list")
                .font(Tokens.Typography.iconMedium())
                .foregroundStyle(Tokens.Color.textTertiary)
            Text("マーカーがありません")
                .font(Tokens.Typography.caption())
                .foregroundStyle(Tokens.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Spacing.lg)
    }

    // MARK: - Components

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
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(!hasAudio)
    }

    private var expandButton: some View {
        let secondaryColor = hasAudio ? Tokens.Color.textSecondary : Tokens.Color.textTertiary

        return Button(action: {
            Haptics.light()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isExpanded.toggle()
            }
        }) {
            Image(systemName: "chevron.up")
                .font(Tokens.Typography.caption())
                .foregroundStyle(secondaryColor)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Tokens.Color.background)
                        .overlay(
                            Circle()
                                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var progressValue: Double {
        guard duration > 0 else { return 0 }
        let value = isDragging ? dragValue : currentTime
        return min(max(value / duration, 0), 1)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - Mini Progress Bar

private struct MiniProgressBar: View {
    let value: Double
    let accentColor: Color

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let clamped = min(max(value, 0), 1)
            let fill = width * clamped

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Tokens.Color.border)
                    .frame(height: 4)

                Capsule()
                    .fill(accentColor)
                    .frame(width: max(4, fill), height: 4)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Seek Slider

private struct SeekSlider: View {
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
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .offset(x: xPos - 8)
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
        .frame(height: 16)
    }
}

// MARK: - Marker Row

private struct MarkerRow: View {
    let marker: AIMarker
    let isCurrent: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Tokens.Spacing.sm) {
                Text(formatTime(marker.startSec))
                    .font(Tokens.Typography.caption())
                    .monospacedDigit()
                    .foregroundStyle(isCurrent ? Tokens.Color.accent : Tokens.Color.textSecondary)
                    .frame(width: 48, alignment: .leading)

                Text(marker.title)
                    .font(Tokens.Typography.body())
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "sparkles")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Tokens.Gradients.ai)

                if isCurrent {
                    Image(systemName: "waveform")
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.accent)
                        .symbolEffect(.pulse, isActive: true)
                }
            }
            .padding(.horizontal, Tokens.Spacing.md)
            .padding(.vertical, Tokens.Spacing.sm)
            .background(isCurrent ? Tokens.Color.accent.opacity(0.08) : Color.clear)
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
