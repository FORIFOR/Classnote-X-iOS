import SwiftUI

struct EmptyAIStateCard: View {
    let icon: String
    let title: String
    let subtitle: String?
    let primaryTitle: String
    let primarySubtitle: String?
    let primaryIcon: String
    let isLoading: Bool
    let isPrimaryDisabled: Bool
    let onPrimary: () -> Void
    let secondaryTitle: String?
    let isSecondaryDisabled: Bool
    let onSecondary: (() -> Void)?

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        primaryTitle: String,
        primarySubtitle: String? = nil,
        primaryIcon: String = "sparkles",
        isLoading: Bool = false,
        isPrimaryDisabled: Bool = false,
        secondaryTitle: String? = nil,
        isSecondaryDisabled: Bool = false,
        onPrimary: @escaping () -> Void,
        onSecondary: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.primaryTitle = primaryTitle
        self.primarySubtitle = primarySubtitle
        self.primaryIcon = primaryIcon
        self.isLoading = isLoading
        self.isPrimaryDisabled = isPrimaryDisabled
        self.secondaryTitle = secondaryTitle
        self.isSecondaryDisabled = isSecondaryDisabled
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
    }

    var body: some View {
        AppCard {
            VStack(spacing: Tokens.Spacing.md) {
                VStack(spacing: Tokens.Spacing.xs) {
                    Image(systemName: icon)
                        .font(Tokens.Typography.iconLarge())
                        .foregroundStyle(Tokens.Color.textTertiary)

                    AppText(title, style: .sectionTitle, color: Tokens.Color.textPrimary)

                    if let subtitle {
                        AppText(subtitle, style: .caption, color: Tokens.Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }

                GradientActionButton(
                    primaryTitle,
                    subtitle: primarySubtitle,
                    icon: primaryIcon,
                    isLoading: isLoading
                ) {
                    onPrimary()
                }
                .disabled(isPrimaryDisabled)
                .opacity(isPrimaryDisabled ? 0.6 : 1)

                if let secondaryTitle, let onSecondary {
                    AppButton(secondaryTitle, style: .secondary) {
                        onSecondary()
                    }
                    .disabled(isSecondaryDisabled)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Spacing.xl)
        }
    }
}
