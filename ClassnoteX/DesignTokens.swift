import SwiftUI

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK: Design Tokens - Staff-Level Design System
// MARK: ═══════════════════════════════════════════════════════════════════

/// Design System Tokens for ClassnoteX
/// All values are Apple HIG-compliant and work in light/dark mode
enum DesignTokens {
    
    // MARK: - Spacing Scale (Based on 4pt grid)
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }
    
    // MARK: - Corner Radius Scale
    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let full: CGFloat = 9999  // Capsule
    }
    
    // MARK: - Animation Durations
    enum Duration {
        static let instant: Double = 0.1
        static let fast: Double = 0.15
        static let normal: Double = 0.25
        static let slow: Double = 0.4
        static let breathing: Double = 1.2
    }
    
    // MARK: - Shadow Presets
    enum Shadow {
        case none, subtle, card, elevated, floating
        
        var radius: CGFloat {
            switch self {
            case .none: return 0
            case .subtle: return 2
            case .card: return 8
            case .elevated: return 16
            case .floating: return 24
            }
        }
        
        var y: CGFloat {
            switch self {
            case .none: return 0
            case .subtle: return 1
            case .card: return 4
            case .elevated: return 8
            case .floating: return 12
            }
        }
        
        func color(for colorScheme: ColorScheme) -> Color {
            let opacity: Double = switch self {
            case .none: 0
            case .subtle: colorScheme == .dark ? 0.3 : 0.08
            case .card: colorScheme == .dark ? 0.4 : 0.12
            case .elevated: colorScheme == .dark ? 0.5 : 0.16
            case .floating: colorScheme == .dark ? 0.6 : 0.2
            }
            return Color.black.opacity(opacity)
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK: Semantic Colors - HIG System Colors Only
// MARK: ═══════════════════════════════════════════════════════════════════

/// Semantic color tokens using ONLY system colors
/// Guaranteed to work in light/dark mode and meet accessibility standards
enum SemanticColor {
    
    // MARK: - Backgrounds
    enum Background {
        static let primary = Color(.systemBackground)
        static let secondary = Color(.secondarySystemBackground)
        static let tertiary = Color(.tertiarySystemBackground)
        static let grouped = Color(.systemGroupedBackground)
        static let groupedSecondary = Color(.secondarySystemGroupedBackground)
    }
    
    // MARK: - Text/Labels
    enum Text {
        static let primary = Color(.label)
        static let secondary = Color(.secondaryLabel)
        static let tertiary = Color(.tertiaryLabel)
        static let quaternary = Color(.quaternaryLabel)
        static let placeholder = Color(.placeholderText)
    }
    
    // MARK: - Fills
    enum Fill {
        static let primary = Color(.systemFill)
        static let secondary = Color(.secondarySystemFill)
        static let tertiary = Color(.tertiarySystemFill)
        static let quaternary = Color(.quaternarySystemFill)
    }
    
    // MARK: - Separators
    enum Separator {
        static let standard = Color(.separator)
        static let opaque = Color(.opaqueSeparator)
    }
    
    // MARK: - Accent Colors (Primary Actions Only)
    enum Accent {
        static let tint = Color(.tintColor)
        static let blue = Color(.systemBlue)
        static let red = Color(.systemRed)
        static let green = Color(.systemGreen)
        static let orange = Color(.systemOrange)
        static let purple = Color(.systemPurple)
    }
    
    // MARK: - Recording States
    enum Recording {
        static let ready = Color(.systemBlue)
        static let listening = Color(.systemBlue)
        static let active = Color(.systemRed)
        static let processing = Color(.systemOrange)
        static let complete = Color(.systemGreen)
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK: Glass Notebook Theme - Premium Color Palette
// MARK: ═══════════════════════════════════════════════════════════════════

/// Glass Notebook color system for Work & Campus
/// Automatically adapts to light/dark mode
enum GlassNotebook {
    
    // MARK: - Backgrounds
    enum Background {
        /// Main app background: Light #F4F5F7, Dark #020617
        static var primary: Color {
            Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.008, green: 0.024, blue: 0.090, alpha: 1)  // #020617
                    : UIColor(red: 0.957, green: 0.961, blue: 0.969, alpha: 1)  // #F4F5F7
            })
        }
        
        /// Card background: Light #FFFFFF, Dark #0F172A
        static var card: Color {
            Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.059, green: 0.090, blue: 0.165, alpha: 1)  // #0F172A
                    : UIColor.white
            })
        }
        
        /// Elevated card (for overlays)
        static var elevated: Color {
            Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.110, green: 0.141, blue: 0.224, alpha: 1)  // #1C2439
                    : UIColor.white
            })
        }
    }
    
    // MARK: - Accent Colors
    enum Accent {
        /// Primary accent (Blue): Light #2563EB, Dark #38BDF8
        static var primary: Color {
            Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.220, green: 0.741, blue: 0.973, alpha: 1)  // #38BDF8
                    : UIColor(red: 0.145, green: 0.388, blue: 0.922, alpha: 1)  // #2563EB
            })
        }
        
        /// Secondary accent (Green/Purple): Light #22C55E, Dark #A855F7
        static var secondary: Color {
            Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.659, green: 0.333, blue: 0.969, alpha: 1)  // #A855F7
                    : UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1)  // #22C55E
            })
        }
        
        /// Lecture color (Green)
        static var lecture: Color {
            Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1)  // #22C55E
                    : UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1)  // #22C55E
            })
        }
        
        /// Meeting color (Blue/Cyan)
        static var meeting: Color {
            Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.220, green: 0.741, blue: 0.973, alpha: 1)  // #38BDF8
                    : UIColor(red: 0.145, green: 0.388, blue: 0.922, alpha: 1)  // #2563EB
            })
        }
    }
    
    // MARK: - Text Colors
    enum Text {
        /// Subtext/Border: Light #9CA3AF, Dark #6B7280
        static var secondary: Color {
            Color(UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.420, green: 0.447, blue: 0.502, alpha: 1)  // #6B7280
                    : UIColor(red: 0.612, green: 0.639, blue: 0.686, alpha: 1)  // #9CA3AF
            })
        }
    }
    
    // MARK: - Gradients
    enum Gradient {
        /// Primary button gradient
        static var primaryButton: LinearGradient {
            LinearGradient(
                colors: [Accent.primary, Accent.primary.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        /// Recording button gradient
        static var recordButton: LinearGradient {
            LinearGradient(
                colors: [Color.red, Color.red.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        /// Hero gradient
        static var hero: LinearGradient {
            LinearGradient(
                colors: [Accent.primary, Accent.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK: Animation Presets
// MARK: ═══════════════════════════════════════════════════════════════════

extension Animation {
    /// Button press animation (0.12-0.15s)
    static var buttonPress: Animation {
        .spring(response: 0.12, dampingFraction: 0.6)
    }
    
    /// Button release animation
    static var buttonRelease: Animation {
        .spring(response: 0.18, dampingFraction: 0.7)
    }
    
    /// Breathing animation for recording state
    static var breathing: Animation {
        .easeInOut(duration: DesignTokens.Duration.breathing)
        .repeatForever(autoreverses: true)
    }
    
    /// Smooth content transition
    static var contentTransition: Animation {
        .spring(response: 0.3, dampingFraction: 0.8)
    }
    
    /// State change animation
    static var stateChange: Animation {
        .easeInOut(duration: DesignTokens.Duration.normal)
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK: View Modifiers
// MARK: ═══════════════════════════════════════════════════════════════════

/// Premium card style with proper light/dark support
struct PremiumCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = DesignTokens.Spacing.md
    var radius: CGFloat = DesignTokens.Radius.lg
    var shadow: DesignTokens.Shadow = .card
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(SemanticColor.Background.secondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(SemanticColor.Separator.standard, lineWidth: 0.5)
            )
            .shadow(
                color: shadow.color(for: colorScheme),
                radius: shadow.radius,
                x: 0,
                y: shadow.y
            )
    }
}

/// Material card for overlays
struct MaterialCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var radius: CGFloat = DesignTokens.Radius.lg
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.1)
                            : Color.black.opacity(0.05),
                        lineWidth: 0.5
                    )
            )
    }
}

extension View {
    func premiumCard(
        padding: CGFloat = DesignTokens.Spacing.md,
        radius: CGFloat = DesignTokens.Radius.lg,
        shadow: DesignTokens.Shadow = .card
    ) -> some View {
        modifier(PremiumCardModifier(padding: padding, radius: radius, shadow: shadow))
    }
    
    func materialCard(radius: CGFloat = DesignTokens.Radius.lg) -> some View {
        modifier(MaterialCardModifier(radius: radius))
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK: Haptic Feedback
// MARK: ═══════════════════════════════════════════════════════════════════

enum Haptic {
    case light, medium, heavy
    case success, warning, error
    case selection
    
    func trigger() {
        switch self {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

// MARK: - ═══════════════════════════════════════════════════════════════════
// MARK: Typography Scale
// MARK: ═══════════════════════════════════════════════════════════════════

enum Typography {
    static let largeTitle = Font.largeTitle.weight(.bold)
    static let title = Font.title.weight(.semibold)
    static let title2 = Font.title2.weight(.semibold)
    static let title3 = Font.title3.weight(.medium)
    static let headline = Font.headline.weight(.semibold)
    static let body = Font.body
    static let callout = Font.callout
    static let subheadline = Font.subheadline
    static let footnote = Font.footnote
    static let caption = Font.caption
    static let caption2 = Font.caption2
    
    // Special: Timer display
    static let timer = Font.system(size: 64, weight: .thin, design: .rounded)
    static let timerLarge = Font.system(size: 80, weight: .ultraLight, design: .rounded)
}
