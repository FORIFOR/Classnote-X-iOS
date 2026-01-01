import SwiftUI

// MARK: - Sign In Screen

/// Sign-in screen matching specification design.
/// Features brand logo, tagline, feature icons, and auth buttons.
struct SignInScreen: View {
    @ObservedObject var authViewModel: AuthViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Tokens.Color.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero Section
                        heroSection
                            .frame(minHeight: geometry.size.height * 0.50)

                        // Sign In Card
                        signInCard
                            .padding(.horizontal, Tokens.Spacing.screenHorizontal)
                            .padding(.bottom, Tokens.Spacing.xl)
                    }
                }
            }
        }
        .cappedDynamicType()
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: Tokens.Spacing.lg) {
            Spacer(minLength: Tokens.Spacing.lg)

            // App icon with waveform
            ZStack {
                Circle()
                    .fill(Tokens.Gradients.ai)
                    .frame(width: Tokens.Sizing.heroIcon, height: Tokens.Sizing.heroIcon)

                Image(systemName: "waveform")
                    .font(Tokens.Typography.iconLarge())
                    .foregroundStyle(Tokens.Color.surface)
            }

            // Brand title
            VStack(spacing: Tokens.Spacing.xxs) {
                HStack(spacing: 0) {
                    Text("Deep")
                        .foregroundStyle(Tokens.Color.textPrimary)
                    Text("Note")
                        .foregroundStyle(Tokens.Gradients.brandX)
                }
                .font(Tokens.Typography.brandTitle())

                // Tagline
                Text("講義と会議を、AIがノートに。")
                    .font(Tokens.Typography.body())
                    .foregroundStyle(Tokens.Color.textSecondary)
            }

            // Feature icons row
            HStack(spacing: Tokens.Spacing.lg) {
                FeatureIconView(icon: "mic.fill", label: "録音")
                FeatureIconView(icon: "text.alignleft", label: "文字起こし")
                FeatureIconView(icon: "sparkles", label: "要約")
            }
            .padding(.top, Tokens.Spacing.md)

            Spacer(minLength: Tokens.Spacing.lg)
        }
    }

    // MARK: - Sign In Card

    private var signInCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            // Card title
                VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
                    AppText("はじめましょう", style: .sectionTitle, color: Tokens.Color.textPrimary)

                    Text("アカウントでサインインして、録音データをクラウドに同期できます。")
                        .font(Tokens.Typography.body())
                        .foregroundStyle(Tokens.Color.textSecondary)
                }

            // Auth buttons
                VStack(spacing: Tokens.Spacing.sm) {
                // Google
                AuthButton(
                    label: "Googleで続ける",
                    icon: "LoginIconGoogle",
                    isSystemIcon: false,
                    style: .outlined,
                    isLoading: authViewModel.isLoadingProvider == .google
                ) {
                    authViewModel.signInWithGoogle()
                }

                // LINE
                AuthButton(
                    label: "LINEで続ける",
                    icon: "LoginIconLine",
                    isSystemIcon: false,
                    style: .solid(Color(red: 0.024, green: 0.78, blue: 0.33)), // LINE brand green #06C755
                    isLoading: authViewModel.isLoadingProvider == .line
                ) {
                    authViewModel.signInWithLine()
                }

                // Apple
                AuthButton(
                    label: "Appleで続ける",
                    icon: "apple.logo",
                    isSystemIcon: true,
                    style: .solid(Tokens.Color.textPrimary),
                    isLoading: authViewModel.isLoadingProvider == .apple
                ) {
                    authViewModel.signInWithApple()
                }
                }

            // Terms text
                Text("サインインすると、利用規約とプライバシーポリシーに同意したことになります。")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Tokens.Spacing.xs)
            }
        }
    }
}

// MARK: - Feature Icon View

private struct FeatureIconView: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: Tokens.Spacing.xs) {
            Circle()
                .fill(Tokens.Color.surface)
                .frame(width: Tokens.Sizing.buttonCompactHeight, height: Tokens.Sizing.buttonCompactHeight)
                .overlay(
                    Image(systemName: icon)
                        .font(Tokens.Typography.iconMedium())
                        .foregroundStyle(Tokens.Color.textPrimary)
                )
                .overlay(
                    Circle().stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                )

            Text(label)
                .font(Tokens.Typography.caption())
                .foregroundStyle(Tokens.Color.textSecondary)
        }
    }
}

// MARK: - Auth Button

private struct AuthButton: View {
    enum Style {
        case outlined
        case solid(Color)
        case gradient(LinearGradient)
    }

    let label: String
    let icon: String
    let isSystemIcon: Bool // Added flag
    let style: Style
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            HStack(spacing: Tokens.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else {
                    if isSystemIcon {
                        Image(systemName: icon)
                            .font(Tokens.Typography.iconMedium())
                            .foregroundStyle(foregroundColor)
                    } else {
                        // Custom Asset
                        Image(icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: Tokens.Sizing.iconSmall, height: Tokens.Sizing.iconSmall)
                    }
                }

                Text(isLoading ? "サインイン中..." : label)
                    .font(Tokens.Typography.button())
                    .foregroundStyle(foregroundColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Tokens.Sizing.buttonHeight)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private var foregroundColor: Color {
        switch style {
        case .outlined:
            return Tokens.Color.textPrimary
        case .solid, .gradient:
            return Tokens.Color.surface
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .outlined:
            Tokens.Color.surface
        case .solid(let color):
            color
        case .gradient(let gradient):
            gradient
        }
    }

    private var strokeColor: Color {
        switch style {
        case .outlined:
            return Tokens.Color.border
        case .solid, .gradient:
            return .clear
        }
    }

    private var strokeWidth: CGFloat {
        switch style {
        case .outlined:
            return Tokens.Border.thin
        case .solid, .gradient:
            return 0
        }
    }
}

// MARK: - Preview
