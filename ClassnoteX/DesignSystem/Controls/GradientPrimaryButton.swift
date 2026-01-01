import SwiftUI

// MARK: - Gradient Action Button

/// Full-width gradient button for AI actions (summarize, quiz, transcribe).
/// Features sparkles icon and centered layout.
struct GradientActionButton: View {
    let title: String
    let subtitle: String?
    let icon: String
    let gradient: LinearGradient
    let isLoading: Bool
    let action: () -> Void

    init(
        _ title: String,
        subtitle: String? = nil,
        icon: String = "sparkles",
        gradient: LinearGradient = Tokens.Gradients.ai,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.gradient = gradient
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: {
            guard !isLoading else { return }
            Haptics.medium()
            action()
        }) {
            HStack(spacing: Tokens.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Tokens.Color.surface))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: icon)
                        .font(Tokens.Typography.iconMedium())
                }

                VStack(spacing: Tokens.Spacing.xxs) {
                    Text(title)
                        .font(Tokens.Typography.button())

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(Tokens.Typography.caption())
                    }
                }
            }
            .foregroundStyle(Tokens.Color.surface)
            .frame(maxWidth: .infinity)
            .frame(height: Tokens.Sizing.buttonHeight)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// MARK: - Compact Gradient Button

/// Smaller gradient button for inline actions
struct CompactGradientButton: View {
    let title: String
    let icon: String?
    let gradient: LinearGradient
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        gradient: LinearGradient = Tokens.Gradients.ai,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.gradient = gradient
        self.action = action
    }

    var body: some View {
        Button(action: {
            Haptics.light()
            action()
        }) {
            HStack(spacing: Tokens.Spacing.xxs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(Tokens.Typography.caption())
                }

                Text(title)
                    .font(Tokens.Typography.caption())
            }
            .foregroundStyle(Tokens.Color.surface)
            .padding(.horizontal, Tokens.Spacing.sm)
            .padding(.vertical, Tokens.Spacing.xs)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
