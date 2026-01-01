import SwiftUI

// MARK: - Pill Button

/// A pill-shaped button with multiple style variants.
/// Used throughout the app for actions, filters, and navigation.
struct PillButton: View {
    enum Variant {
        case primary(LinearGradient)   // Gradient background, white text
        case secondary                  // Gray background, dark text
        case danger                     // Red background, white text
        case ghost                      // Transparent, text only
        case outline                    // Stroke only, no fill
    }

    let title: String
    let icon: String?
    let variant: Variant
    let isCompact: Bool
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        variant: Variant = .secondary,
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
                if let icon = icon {
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

    // MARK: - Variant Styling

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
        case .ghost, .outline:
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
        case .ghost, .outline:
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

// MARK: - Icon-Only Pill Button

/// A circular or pill button with only an icon
struct IconPillButton: View {
    let icon: String
    let isCircle: Bool
    let action: () -> Void

    init(_ icon: String, circle: Bool = true, action: @escaping () -> Void) {
        self.icon = icon
        self.isCircle = circle
        self.action = action
    }

    var body: some View {
        Button(action: {
            Haptics.light()
            action()
        }) {
            Image(systemName: icon)
                .font(Tokens.Typography.button())
                .foregroundStyle(Tokens.Color.textPrimary)
                .frame(width: Tokens.Sizing.iconButton, height: Tokens.Sizing.iconButton)
                .background(
                    Group {
                        if isCircle {
                            Circle().fill(Tokens.Color.surface)
                        } else {
                            Capsule().fill(Tokens.Color.surface)
                        }
                    }
                )
                .overlay(
                    Group {
                        if isCircle {
                            Circle().stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                        } else {
                            Capsule().stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Text Pill (non-interactive label)

/// A non-interactive pill label for status display
struct TextPill: View {
    let text: String
    let color: Color?

    init(_ text: String, color: Color? = nil) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(Tokens.Typography.caption())
            .foregroundStyle(color ?? Tokens.Color.textSecondary)
            .padding(.horizontal, Tokens.Spacing.xs)
            .padding(.vertical, Tokens.Spacing.xxs)
            .background(
                Capsule().fill(Tokens.Color.surface)
            )
            .overlay(
                Capsule()
                    .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
            )
    }
}

// MARK: - Preview
