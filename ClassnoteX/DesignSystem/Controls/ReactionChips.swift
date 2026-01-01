import SwiftUI

// Models are defined in SessionModels.swift:
// - ReactionType (🔥👏😇🤯🫶)
// - ReactionsSummary

// MARK: - Reaction Chip

/// A single reaction chip with emoji and count
struct ReactionChip: View {
    let type: ReactionType
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.light()
            action()
        }) {
            HStack(spacing: Tokens.Spacing.xxs) {
                Text(type.emoji)
                    .font(Tokens.Typography.iconMedium())

                if count > 0 {
                    Text("\(count)")
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(isSelected ? Tokens.Color.textPrimary : Tokens.Color.textSecondary)
                }
            }
            .padding(.horizontal, Tokens.Spacing.sm)
            .padding(.vertical, Tokens.Spacing.xs)
            .background(background)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Tokens.Color.textPrimary : Tokens.Color.border, lineWidth: Tokens.Border.thin)
            )
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        Tokens.Color.surface
    }
}

// MARK: - Reactions Row

/// A row of all 5 reaction chips
struct ReactionsRow: View {
    let summary: ReactionsSummary
    let myReaction: ReactionType?
    let onTap: (ReactionType) -> Void

    var body: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            ForEach(ReactionType.allCases) { type in
                ReactionChip(
                    type: type,
                    count: summary.count(for: type),
                    isSelected: myReaction == type
                ) {
                    onTap(type)
                }
            }
        }
    }
}

// MARK: - Compact Reactions Display

/// Compact display for session cards showing total reactions
struct CompactReactions: View {
    let summary: ReactionsSummary

    var body: some View {
        if !summary.isEmpty {
            HStack(spacing: Tokens.Spacing.xxs) {
                ForEach(topReactions.prefix(3), id: \.type) { item in
                    Text(item.type.emoji)
                        .font(Tokens.Typography.caption())
                }

                if totalCount > 0 {
                    Text("\(totalCount)")
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
            }
        }
    }

    private var topReactions: [(type: ReactionType, count: Int)] {
        ReactionType.allCases
            .map { ($0, summary.count(for: $0)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
    }

    private var totalCount: Int {
        summary.fire + summary.clap + summary.angel + summary.mindblown + summary.heartHands
    }
}
