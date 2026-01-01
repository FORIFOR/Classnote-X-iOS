import SwiftUI

enum DADSButtonVariant {
    case primary
    case secondary
    case destructive
    case ghost
}

struct DADSButtonStyle: ButtonStyle {
    let variant: DADSButtonVariant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tokens.Typography.button())
            .foregroundStyle(foregroundColor)
            .padding(.vertical, Tokens.Spacing.sm)
            .padding(.horizontal, Tokens.Spacing.md)
            .frame(minHeight: Tokens.Sizing.buttonCompactHeight)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .contentShape(Rectangle())
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary, .destructive:
            return Tokens.Color.surface
        case .secondary:
            return Tokens.Color.textPrimary
        case .ghost:
            return Tokens.Color.textSecondary
        }
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .primary:
            Tokens.Gradients.ai
        case .destructive:
            Tokens.Color.destructive
        case .secondary:
            RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                .fill(Tokens.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                        .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                )
        case .ghost:
            Color.clear
        }
    }
}

struct DADSButton: View {
    let title: String
    let icon: String?
    let variant: DADSButtonVariant
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        variant: DADSButtonVariant = .secondary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.variant = variant
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
                        .font(Tokens.Typography.button())
                }
                Text(title)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(DADSButtonStyle(variant: variant))
    }
}
