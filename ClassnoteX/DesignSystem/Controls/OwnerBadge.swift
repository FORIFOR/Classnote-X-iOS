import SwiftUI

// MARK: - Owner Badge

/// Badge to indicate session ownership: "自分" (mine) or "共有" (shared)
struct OwnerBadge: View {
    let isMine: Bool
    let username: String?

    init(isMine: Bool, username: String? = nil) {
        self.isMine = isMine
        self.username = username
    }

    var body: some View {
        HStack(spacing: Tokens.Spacing.xxs) {
            Image(systemName: isMine ? "crown.fill" : "person.2.fill")
                .font(Tokens.Typography.caption())

            Text(badgeText)
                .font(Tokens.Typography.caption())
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, Tokens.Spacing.xs)
        .padding(.vertical, Tokens.Spacing.xxs)
        .background(Tokens.Color.surface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
        )
    }

    private var badgeText: String {
        if isMine {
            return "自分"
        }
        if let username = username {
            return "@\(username)"
        }
        return "共有"
    }

    private var foregroundColor: Color {
        isMine ? Tokens.Color.textPrimary : Tokens.Color.textSecondary
    }
}

// MARK: - Session Status Badge

/// Badge for session status (recording, processing, ready)
struct StatusBadge: View {
    enum Status: String {
        case recording = "録音中"
        case processing = "処理中"
        case ready = "要約済み"
        case failed = "失敗"

        var color: Color {
            switch self {
            case .recording, .failed: return Tokens.Color.destructive
            case .processing, .ready: return Tokens.Color.accent
            }
        }

        var icon: String {
            switch self {
            case .recording: return "waveform"
            case .processing: return "arrow.triangle.2.circlepath"
            case .ready: return "checkmark"
            case .failed: return "xmark"
            }
        }
    }

    let status: Status

    var body: some View {
        HStack(spacing: Tokens.Spacing.xxs) {
            if status == .recording {
                PulsingDot(color: status.color)
            } else {
                Image(systemName: status.icon)
                    .font(Tokens.Typography.caption())
            }

            Text(status.rawValue)
                .font(Tokens.Typography.caption())
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, Tokens.Spacing.xs)
        .padding(.vertical, Tokens.Spacing.xxs)
        .background(Tokens.Color.surface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
        )
    }
}

// MARK: - Pulsing Dot

/// Animated pulsing dot for recording indicator
struct PulsingDot: View {
    let color: Color
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Participant Avatars Row

/// Row of circular avatars for session participants
struct ParticipantsRow: View {
    let participants: [Participant]
    let maxVisible: Int

    init(_ participants: [Participant], maxVisible: Int = 4) {
        self.participants = participants
        self.maxVisible = maxVisible
    }

    var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(participants.prefix(maxVisible).enumerated()), id: \.element.id) { index, participant in
                ParticipantAvatar(participant: participant, isOwner: index == 0)
                    .zIndex(Double(maxVisible - index))
            }

            if participants.count > maxVisible {
                OverflowBadge(count: participants.count - maxVisible)
            }
        }
    }
}

// MARK: - Participant

struct Participant: Identifiable {
    let id: String
    let username: String
    let photoURL: URL?
}

// MARK: - Participant Avatar

struct ParticipantAvatar: View {
    let participant: Participant
    let isOwner: Bool
    var size: CGFloat = Tokens.Sizing.avatarSmall

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Avatar circle
            Circle()
                .fill(avatarBackground)
                .frame(width: size, height: size)
                .overlay(
                    Text(initial)
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.textSecondary)
                )
                .overlay(
                    Circle()
                        .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                )

            // Owner crown
            if isOwner {
                Image(systemName: "crown.fill")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Tokens.Color.accent)
                    .offset(x: 2, y: 2)
            }
        }
    }

    private var avatarBackground: Color {
        Tokens.Color.surface
    }

    private var initial: String {
        String(participant.username.prefix(1)).uppercased()
    }
}

// MARK: - Overflow Badge

private struct OverflowBadge: View {
    let count: Int

    var body: some View {
        Circle()
            .fill(Tokens.Color.surface)
            .frame(width: Tokens.Sizing.avatarSmall, height: Tokens.Sizing.avatarSmall)
            .overlay(
                Text("+\(count)")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Tokens.Color.textSecondary)
            )
            .overlay(
                Circle()
                    .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
            )
    }
}

// MARK: - Preview
