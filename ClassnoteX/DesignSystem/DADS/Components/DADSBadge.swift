import SwiftUI

enum DADSBadgeStyle {
    case neutral
    case accent
    case danger
    case custom(foreground: Color, background: Color)
}

struct DADSBadge: View {
    let text: String
    let style: DADSBadgeStyle

    init(_ text: String, style: DADSBadgeStyle = .neutral) {
        self.text = text
        self.style = style
    }

    var body: some View {
        Text(text)
            .font(DADS.Typography.caption())
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, Tokens.Spacing.xs)
            .padding(.vertical, Tokens.Spacing.xxs)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    private var foregroundColor: Color {
        switch style {
        case .neutral:
            return DADS.Colors.textSecondary
        case .accent:
            return DADS.Colors.textPrimary
        case .danger:
            return Tokens.Color.surface
        case .custom(let foreground, _):
            return foreground
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .neutral:
            return DADS.Colors.border
        case .accent:
            return DADS.Colors.surface
        case .danger:
            return DADS.Colors.danger
        case .custom(_, let background):
            return background
        }
    }
}
