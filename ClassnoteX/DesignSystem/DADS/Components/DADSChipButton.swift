import SwiftUI

enum DADSChipVariant {
    case primary(LinearGradient)
    case secondary
    case outline
    case danger
}

struct DADSChipButton: View {
    let title: String
    let icon: String?
    let variant: DADSChipVariant
    let isCompact: Bool
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        variant: DADSChipVariant = .secondary,
        compact: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.variant = variant
        self.isCompact = compact
        self.action = action
    }

    var body: some View {
        Button(action: {
            Haptics.light()
            action()
        }) {
            HStack(spacing: Tokens.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(isCompact ? Tokens.Typography.caption() : Tokens.Typography.button())
                }
                Text(title)
                    .font(isCompact ? Tokens.Typography.caption() : Tokens.Typography.button())
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, isCompact ? Tokens.Spacing.sm : Tokens.Spacing.md)
            .padding(.vertical, isCompact ? Tokens.Spacing.xs : Tokens.Spacing.sm)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
            .overlay(strokeOverlay)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .primary(let gradient):
            gradient
        case .secondary:
            RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                .fill(Tokens.Color.surface)
        case .danger:
            RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                .fill(Tokens.Color.destructive)
        case .outline:
            RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                .fill(Color.clear)
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary, .danger:
            return Tokens.Color.surface
        case .secondary:
            return Tokens.Color.textPrimary
        case .outline:
            return Tokens.Color.textSecondary
        }
    }

    @ViewBuilder
    private var strokeOverlay: some View {
        switch variant {
        case .outline:
            RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
        default:
            EmptyView()
        }
    }
}
