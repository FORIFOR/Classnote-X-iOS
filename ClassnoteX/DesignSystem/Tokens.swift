import SwiftUI
import UIKit

// MARK: - Design System Tokens
// Replaces the old DS enum.
enum Tokens {

    // MARK: - Colors (Asset Catalog Backed)
    enum Color {
        // Semantic Colors
        static let background = SwiftUI.Color("BG")
        static let surface = SwiftUI.Color("CardBG") // Card background
        static let textPrimary = SwiftUI.Color("TextPrimary") // Main text (High contrast)
        static let textSecondary = SwiftUI.Color("TextSecondary") // Sub text (Medium contrast)
        static let textTertiary = SwiftUI.Color("TextTertiary") // Minimal contrast (Placeholders etc)
        static let textDisabled = textTertiary
        static let accent = SwiftUI.Color("AccentColor") // Brand color
        static let destructive = SwiftUI.Color("DangerRed") // Error/Delete
        
        static let border = SwiftUI.Color("Stroke")

        // Mode accents
        static let lectureAccent = SwiftUI.Color("LectureGradStart")
        static let meetingAccent = SwiftUI.Color("MeetingGradStart")
        
        // Legacy/Direct Colors (Migration path)
        static let bg = background
        static let cardBG = surface
        static let stroke = border
        static let dangerRed = destructive

        // Gradients
        static let lectureGrad = Tokens.Gradients.lecture
        static let meetingGrad = Tokens.Gradients.meeting
        static let aiGrad = Tokens.Gradients.ai
        static let brandXGrad = Tokens.Gradients.brandX
    }

    // MARK: - Gradients (Asset Catalog Backed)
    enum Gradients {
        static let lecture = LinearGradient(
            colors: [SwiftUI.Color("LectureGradStart"), SwiftUI.Color("LectureGradEnd")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let meeting = LinearGradient(
            colors: [SwiftUI.Color("MeetingGradStart"), SwiftUI.Color("MeetingGradEnd")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let ai = LinearGradient(
            colors: [SwiftUI.Color("AIGradStart"), SwiftUI.Color("AIGradEnd")],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let brandX = LinearGradient(
            colors: [SwiftUI.Color("BrandXGradStart"), SwiftUI.Color("BrandXGradEnd")],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Corner Radius
    enum Radius {
        static let card: CGFloat = 14       // Minimal card radius
        static let smallCard: CGFloat = 10  // Small cards / Inner items
        static let button: CGFloat = 10     // Buttons
        static let pill: CGFloat = 999      // Pills / Capsules
        static let circle: CGFloat = 999
        static let tabBarPill: CGFloat = 28
        static let small: CGFloat = 8
    }

    // MARK: - Spacing
    // Strict scale: 4, 8, 12, 16, 24, 32
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 32
        
        static let screenHorizontal: CGFloat = 16
        static let cardContent: CGFloat = 16
        static let tabBarHeight: CGFloat = 72
    }
    
    // Legacy Layout Support
    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
        static let itemSpacing: CGFloat = 8
        static let tabBarHeight: CGFloat = 72
        static let tabBarBottomPadding: CGFloat = 0
    }

    // MARK: - Border
    enum Border {
        static var hairline: CGFloat { 1 / UIScreen.main.scale }
        static let thin: CGFloat = 1
    }

    // MARK: - Sizing
    enum Sizing {
        static let buttonHeight: CGFloat = 48
        static let buttonCompactHeight: CGFloat = 44
        static let iconButton: CGFloat = 36
        static let iconSmall: CGFloat = 20
        static let avatar: CGFloat = 40
        static let avatarSmall: CGFloat = 32
        static let playButton: CGFloat = 48
        static let tabIcon: CGFloat = 22
        static let tabHighlightWidth: CGFloat = 68
        static let tabHighlightHeight: CGFloat = 48
        static let heroIcon: CGFloat = 72
        static let micOuter: CGFloat = 156
        static let micInner: CGFloat = 120
        static let miniBarHeight: CGFloat = 56
        static let playerCardHeight: CGFloat = 96
    }

    // MARK: - Shadows
    enum Shadows {
        struct Config {
            let color: SwiftUI.Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }

        static func card(for scheme: ColorScheme) -> Config {
            switch scheme {
            case .dark:
                return Config(color: .black.opacity(0.35), radius: 10, x: 0, y: 2)
            case .light:
                fallthrough
            @unknown default:
                return Config(color: .black.opacity(0.08), radius: 10, x: 0, y: 2)
            }
        }

        static func primaryButton(for scheme: ColorScheme) -> Config {
            switch scheme {
            case .dark:
                return Config(color: .black.opacity(0.3), radius: 12, x: 0, y: 3)
            case .light:
                fallthrough
            @unknown default:
                return Config(color: .black.opacity(0.12), radius: 12, x: 0, y: 3)
            }
        }
        
        static func glow(color: SwiftUI.Color, for scheme: ColorScheme) -> Config {
             let opacity: Double = scheme == .dark ? 0.6 : 0.4
             return Config(color: color.opacity(opacity), radius: 40, x: 0, y: 10)
         }
    }

    // MARK: - Typography
    enum Typography {
        // 1. Brand Title (Heavy/Semibold) - Home screen top
        static func brandTitle() -> Font { scaledFont(size: 32, weight: .bold, textStyle: .title2) }
        
        // 2. Screen Title (Semibold) - Page headers
        static func screenTitle() -> Font { scaledFont(size: 24, weight: .semibold, textStyle: .title3) }
        
        // 3. Section Title (Semibold) - H2 / Card headers
        static func sectionTitle() -> Font { scaledFont(size: 17, weight: .semibold, textStyle: .headline) }
        
        // 4. Body (Regular) - Main text
        static func body() -> Font { scaledFont(size: 15, weight: .regular, textStyle: .body) }
        
        // 5. Caption (Regular) - Helper text
        static func caption() -> Font { scaledFont(size: 12, weight: .regular, textStyle: .caption1) }
        
        // 6. Date/Caps (Medium/Bold) - Tabs, Tags, Metadata
        static func dateCaps() -> Font { scaledFont(size: 11, weight: .semibold, textStyle: .caption2) }
        
        // 7. Button (Semibold) - Actions
        static func button() -> Font { scaledFont(size: 15, weight: .semibold, textStyle: .headline) }
        
        // 8. Tab Label (Medium)
        static func tabLabel() -> Font { scaledFont(size: 11, weight: .medium, textStyle: .caption2) }

        // Aliases for transition
        static func title() -> Font { sectionTitle() }
        static func headline() -> Font { scaledFont(size: 16, weight: .semibold, textStyle: .headline) }
        static func subheadline() -> Font { scaledFont(size: 14, weight: .regular, textStyle: .subheadline) }
        static func brandDate() -> Font { scaledFont(size: 12, weight: .semibold, textStyle: .caption1) }
        static func modePill() -> Font { scaledFont(size: 14, weight: .semibold, textStyle: .headline) }
        static func primaryTitle() -> Font { scaledFont(size: 20, weight: .semibold, textStyle: .title3) }
        static func subtitle() -> Font { scaledFont(size: 14, weight: .semibold, textStyle: .subheadline) }
        static func iconLarge() -> Font { scaledFont(size: 32, weight: .bold, textStyle: .title2) }
        static func iconMedium() -> Font { scaledFont(size: 20, weight: .semibold, textStyle: .headline) }

        private static func scaledFont(size: CGFloat, weight: UIFont.Weight, textStyle: UIFont.TextStyle) -> Font {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            let scaled = UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
            return Font(scaled)
        }
    }

    // MARK: - Blur Styles
    enum Blur {
        static func tabBar(for scheme: ColorScheme) -> UIBlurEffect.Style {
            scheme == .dark ? .systemUltraThinMaterialDark : .systemThinMaterial
        }

        static func card(for scheme: ColorScheme) -> UIBlurEffect.Style {
            scheme == .dark ? .systemMaterialDark : .systemMaterial
        }
    }

    // MARK: - Animations
    enum Animation {
        /// Standard ease-in-out for most transitions
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)

        /// Bouncy spring for playful interactions
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)

        /// Quick spring for snappy feedback
        static let quickSpring = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.7)

        /// Slow spring for smooth, deliberate movements
        static let slowSpring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.85)

        /// Pulse animation for attention (e.g., recording indicator)
        static let pulse = SwiftUI.Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)

        /// Fast pulse for urgent states
        static let fastPulse = SwiftUI.Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)

        /// Shimmer animation for loading skeletons
        static let shimmer = SwiftUI.Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)

        /// Fade in/out duration
        static let fade = SwiftUI.Animation.easeInOut(duration: 0.2)
    }
}

// Backward Compatibility
typealias DS = Tokens

// MARK: - Haptics

enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - AppText
/// A wrapper around standard Text to enforce Design System typography.
/// Usage: AppText("Hello", style: .body)
struct AppText: View {
    let text: String
    let style: TextStyle
    let color: Color?
    
    init(_ text: String, style: TextStyle = .body, color: Color? = nil) {
        self.text = text
        self.style = style
        self.color = color
    }
    
    enum TextStyle {
        case brandTitle
        case screenTitle
        case sectionTitle
        case body
        case caption
        case dateCaps
        case button
        case tabLabel
        
        var font: Font {
            switch self {
            case .brandTitle: return Tokens.Typography.brandTitle()
            case .screenTitle: return Tokens.Typography.screenTitle()
            case .sectionTitle: return Tokens.Typography.sectionTitle()
            case .body: return Tokens.Typography.body()
            case .caption: return Tokens.Typography.caption()
            case .dateCaps: return Tokens.Typography.dateCaps()
            case .button: return Tokens.Typography.button()
            case .tabLabel: return Tokens.Typography.tabLabel()
            }
        }
        
        var defaultColor: Color {
            switch self {
            case .brandTitle, .screenTitle, .sectionTitle: return Tokens.Color.textPrimary
            case .body: return Tokens.Color.textPrimary
            case .caption, .dateCaps, .tabLabel: return Tokens.Color.textSecondary
            case .button: return Tokens.Color.surface // Usually white, but context dependent
            }
        }
    }
    
    var body: some View {
        Text(text)
            .font(style.font)
            .foregroundStyle(color ?? style.defaultColor)
            // Add slight line spacing for body text for readability
            .lineSpacing(style == .body ? Tokens.Spacing.xxs : 0)
    }
}

// MARK: - AppButton
/// Standardized Buttons: Primary, Secondary, Destructive
enum AppButtonStyle {
    case primary
    case secondary
    case destructive
}

struct AppButton: View {
    let title: String
    let icon: String?
    let style: AppButtonStyle
    let action: () -> Void
    
    // Size variants could be added here if needed, but for now we enforce ~48pt+
    
    init(_ title: String, icon: String? = nil, style: AppButtonStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(Tokens.Typography.button())
                }
                AppText(title, style: .button, color: foregroundColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Tokens.Sizing.buttonHeight)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary: return Tokens.Color.textPrimary // Or Accent
        case .secondary: return Tokens.Color.surface
        case .destructive: return Tokens.Color.destructive
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive: return Tokens.Color.surface
        case .secondary: return Tokens.Color.textPrimary
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .primary, .destructive: return .clear
        case .secondary: return Tokens.Color.border
        }
    }

    private var borderWidth: CGFloat {
        style == .secondary ? Tokens.Border.thin : 0
    }
}

// MARK: - AppCard
/// A standard container with fixed radius, padding, and background.
struct AppCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        let shadow = Tokens.Shadows.card(for: colorScheme)
        content
            .padding(Tokens.Spacing.cardContent)
            .background(Tokens.Color.surface)
            .cornerRadius(Tokens.Radius.card)
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                    .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
            )
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - AppNavHeader
/// Standard header for custom navigation bars
struct AppNavHeader: View {
    let title: String
    let onBack: (() -> Void)?
    let trailingAction: (() -> AnyView)?
    
    init(title: String, onBack: (() -> Void)? = nil, trailingAction: (() -> AnyView)? = nil) {
        self.title = title
        self.onBack = onBack
        self.trailingAction = trailingAction
    }
    
    var body: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    Circle()
                        .fill(Tokens.Color.surface)
                        .frame(width: Tokens.Sizing.iconButton, height: Tokens.Sizing.iconButton)
                        .overlay(Image(systemName: "chevron.left").foregroundStyle(Tokens.Color.textPrimary))
                }
            } else {
                Spacer().frame(width: Tokens.Sizing.iconButton) // Balance
            }
            
            Spacer()
            
            AppText(title, style: .sectionTitle) // or screenTitle depending on hierarchy
                .lineLimit(1)
            
            Spacer()
            
            if let trailingAction {
                trailingAction()
            } else {
                Spacer().frame(width: Tokens.Sizing.iconButton) // Balance
            }
        }
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
        .padding(.top, Tokens.Spacing.sm)
        .frame(height: 56)
    }
}

// MARK: - AppListRow
struct AppListRow<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: Trailing
    let showDivider: Bool

    init(
        title: String,
        subtitle: String? = nil,
        showDivider: Bool = false,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showDivider = showDivider
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: Tokens.Spacing.sm) {
            HStack(spacing: Tokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
                    AppText(title, style: .body, color: Tokens.Color.textPrimary)
                        .lineLimit(2)
                    if let subtitle, !subtitle.isEmpty {
                        AppText(subtitle, style: .caption, color: Tokens.Color.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                trailing
            }
            if showDivider {
                Rectangle()
                    .fill(Tokens.Color.border)
                    .frame(height: Tokens.Border.hairline)
            }
        }
        .padding(.vertical, Tokens.Spacing.sm)
        .padding(.horizontal, Tokens.Spacing.md)
    }
}

// MARK: - AppBadge
struct AppBadge: View {
    let text: String
    let isEmphasized: Bool

    init(_ text: String, emphasized: Bool = false) {
        self.text = text
        self.isEmphasized = emphasized
    }

    var body: some View {
        AppText(text, style: .dateCaps, color: isEmphasized ? Tokens.Color.textPrimary : Tokens.Color.textSecondary)
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
