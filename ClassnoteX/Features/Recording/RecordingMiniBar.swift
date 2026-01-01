import SwiftUI

struct RecordingMiniBar: View {
    @EnvironmentObject private var recording: RecordingCoordinator
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            // 1. Status Indicator
            RecordingStatusIndicator(status: statusIndicatorType)

            // 2. Mode Chip
            if let modeLabel {
                ModeChip(title: modeLabel, type: recording.currentMode ?? .lecture)
            }

            // 3. Elapsed Time
            Text(formatTime(recording.elapsed))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(Tokens.Color.textPrimary)

            // 4. Status Text
            Text(statusText)
                .font(.system(size: 12))
                .foregroundStyle(statusTextColor)
                .lineLimit(1)

            Spacer()

            // 5. Action Buttons
            HStack(spacing: Tokens.Spacing.xs) {
                // Pause/Play
                CircleIconButton(
                    icon: recording.isPaused ? "play.fill" : "pause.fill",
                    foreground: Tokens.Color.textPrimary
                ) {
                    recording.togglePause()
                }

                // Stop (long press)
                HoldToStopButton {
                    recording.requestStop()
                }
            }

            // 6. Chevron indicator
            Image(systemName: "chevron.up")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Tokens.Color.textTertiary)
        }
        .padding(.horizontal, Tokens.Spacing.md)
        .frame(height: Tokens.Sizing.buttonHeight)
        .background(
            ZStack {
                BlurView(style: Tokens.Blur.tabBar(for: colorScheme))
                RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                    .fill(Tokens.Color.surface.opacity(0.6))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
        )
        .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous))
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
    }

    // MARK: - Computed Properties

    private var statusIndicatorType: RecordingStatusIndicator.StatusType {
        if recording.isInBackground {
            return .background
        } else if recording.isPaused {
            return .paused
        } else {
            return .recording
        }
    }

    private var statusText: String {
        if recording.isInBackground {
            return "バックグラウンド録音中"
        }
        if !recording.hasVoiceActivity && !recording.isPaused {
            return "音声が検出されていません"
        }
        if recording.isPaused {
            return "一時停止中"
        }
        return "録音中 • 文字起こし中"
    }

    private var statusTextColor: Color {
        if !recording.hasVoiceActivity && !recording.isPaused && !recording.isInBackground {
            return Tokens.Color.textSecondary.opacity(0.7)
        }
        return Tokens.Color.textSecondary
    }

    private var modeLabel: String? {
        // Use currentMode from coordinator, fallback to session type
        if let mode = recording.currentMode {
            return mode == .lecture ? "講義" : "会議"
        }
        guard let type = recording.currentSession?.type else { return nil }
        return type == .lecture ? "講義" : "会議"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let total = max(0, Int(time))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct ModeChip: View {
    let title: String
    let type: SessionType

    private var gradient: LinearGradient {
        type == .lecture ? Tokens.Gradients.lecture : Tokens.Gradients.meeting
    }

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, Tokens.Spacing.xs)
            .padding(.vertical, 3)
            .background(gradient)
            .clipShape(Capsule())
    }
}

private struct CircleIconButton: View {
    let icon: String
    let foreground: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.light()
            action()
        }) {
            Image(systemName: icon)
                .font(Tokens.Typography.caption())
                .foregroundStyle(foreground)
                .frame(width: Tokens.Sizing.iconButton, height: Tokens.Sizing.iconButton)
                .background(
                    Circle().fill(Tokens.Color.surface)
                )
                .overlay(
                    Circle().stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct HoldToStopButton: View {
    let action: () -> Void
    @State private var isPressing = false
    @State private var progress: CGFloat = 0
    private let duration: Double = 0.6

    var body: some View {
        ZStack {
            Circle()
                .fill(Tokens.Color.surface)
            Circle()
                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Tokens.Color.destructive, lineWidth: 2)
                .rotationEffect(.degrees(-90))

            Image(systemName: "stop.fill")
                .font(Tokens.Typography.caption())
                .foregroundStyle(Tokens.Color.destructive)
        }
        .frame(width: Tokens.Sizing.iconButton, height: Tokens.Sizing.iconButton)
        .contentShape(Circle())
        .onLongPressGesture(minimumDuration: duration, pressing: { pressing in
            isPressing = pressing
            if pressing {
                withAnimation(.linear(duration: duration)) {
                    progress = 1
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    progress = 0
                }
            }
        }, perform: {
            Haptics.medium()
            action()
            progress = 0
        })
    }
}
