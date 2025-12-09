import SwiftUI

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)  Note: Some use RGBA, but let's assume ARGB or RGBA. 
                // Given the issue, let's treat 8 digits as RRGGBBAA usually, or AARRGGBB? 
                // iOS commonly uses RRGGBBAA for web hex, but let's stick to standard RGB flows.
                // If the previous code was appending FF to the END, it implied RRGGBBAA.
                // But the bitshift (>>24) implied AARRGGBB.
                // Let's implement valid RRGGBBAA.
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Design System Colors (Apple HIG Aligned)

struct AppColors {
    // Primary brand colors - vibrant and accessible
    static let primaryBlue = Color(hex: "007AFF")       // iOS system blue
    static let primaryIndigo = Color(hex: "5856D6")     // iOS system indigo
    static let primaryTeal = Color(hex: "5AC8FA")       // iOS system teal
    
    // Semantic colors
    static let success = Color(hex: "34C759")           // iOS system green
    static let warning = Color(hex: "FF9500")           // iOS system orange
    static let danger = Color(hex: "FF3B30")            // iOS system red
    
    // Gradient presets
    static let heroGradient = LinearGradient(
        colors: [Color(hex: "5856D6"), Color(hex: "007AFF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "007AFF"), Color(hex: "5AC8FA")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // Speaker colors for transcription
    static let speakerColors: [Color] = [
        Color(hex: "007AFF"),  // Blue
        Color(hex: "AF52DE"),  // Purple
        Color(hex: "5AC8FA"),  // Teal
        Color(hex: "FF9500"),  // Orange
        Color(hex: "34C759"),  // Green
        Color(hex: "FF2D55")   // Pink
    ]
}

// MARK: - HIG Semantic Colors (System-adaptive)

struct HIGColors {
    // Backgrounds - automatically adapt to light/dark
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground = Color(.tertiarySystemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
    
    // Labels - automatically adapt to light/dark
    static let label = Color(.label)
    static let secondaryLabel = Color(.secondaryLabel)
    static let tertiaryLabel = Color(.tertiaryLabel)
    static let quaternaryLabel = Color(.quaternaryLabel)
    
    // Recording states
    static let recording = Color(.systemRed)
    static let listening = Color(.systemBlue)
    static let processing = Color(.systemOrange)
    static let success = Color(.systemGreen)
    
    // Separator
    static let separator = Color(.separator)
}

// Legacy Palette for backward compatibility
struct Palette {
    struct Light {
        static let background = Color(.systemBackground)
        static let panel = Color(.secondarySystemBackground)
        static let muted = Color(.secondaryLabel)
        static let accent = AppColors.primaryBlue
        static let accentAlt = AppColors.primaryTeal
        static let caution = AppColors.danger
        static let success = AppColors.success
        static let speakers = AppColors.speakerColors
    }
    struct Dark {
        static let background = Color(.systemBackground)
        static let panel = Color(.secondarySystemBackground)
        static let muted = Color(.secondaryLabel)
        static let accent = AppColors.primaryBlue
        static let accentAlt = AppColors.primaryTeal
        static let caution = AppColors.danger
        static let success = AppColors.success
        static let speakers = AppColors.speakerColors
    }
}

// MARK: - Card Style (Apple HIG Material Design)

struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 16
    var useMaterial: Bool = true
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(useMaterial ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(Color(.secondarySystemBackground)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        colorScheme == .dark
                            ? Color.white.opacity(0.15)
                            : Color.black.opacity(0.1),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: colorScheme == .dark
                    ? Color.black.opacity(0.5)
                    : Color.black.opacity(0.12),
                radius: 12,
                x: 0,
                y: 4
            )
    }
}

struct SolidCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .shadow(
                color: colorScheme == .dark
                    ? Color.black.opacity(0.3)
                    : Color.black.opacity(0.06),
                radius: 10,
                x: 0,
                y: 4
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
    
    func cardStyle(padding: CGFloat = 16, cornerRadius: CGFloat = 16, useMaterial: Bool = true) -> some View {
        modifier(CardStyle(padding: padding, cornerRadius: cornerRadius, useMaterial: useMaterial))
    }
    
    func solidCardStyle(padding: CGFloat = 16, cornerRadius: CGFloat = 16) -> some View {
        modifier(SolidCardStyle(padding: padding, cornerRadius: cornerRadius))
    }
}

// MARK: - Button Styles (Apple HIG with Animation & Haptics)

/// Simple scale animation button style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ScaleButtonStyle {
    static var scale: ScaleButtonStyle { ScaleButtonStyle() }
}

/// Primary CTA button with gradient, shadow, and spring animation
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var gradient: LinearGradient = AppColors.accentGradient
    var textColor: Color = .white
    var minHeight: CGFloat = 50
    var cornerRadius: CGFloat = 14
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(gradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.2 : 0))
            )
            .shadow(
                color: AppColors.primaryBlue.opacity(isEnabled ? 0.3 : 0.1),
                radius: configuration.isPressed ? 4 : 10,
                x: 0,
                y: configuration.isPressed ? 2 : 6
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .opacity(isEnabled ? 1.0 : 0.5)
    }
}

/// Filled button style shared across the app (backward compatible)
struct FilledButtonStyle: ButtonStyle {
    var color: Color
    var textColor: Color = .white
    var minHeight: CGFloat = 50
    var font: Font = .headline.weight(.semibold)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.2 : 0))
            )
            .shadow(color: color.opacity(0.25), radius: configuration.isPressed ? 4 : 10, x: 0, y: configuration.isPressed ? 2 : 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Primary filled button style (backward compatible)
struct PrimaryFilledButtonStyle: ButtonStyle {
    var color: Color = AppColors.primaryBlue
    var textColor: Color = .white
    var minHeight: CGFloat = 50
    var font: Font = .headline.weight(.semibold)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.2 : 0))
            )
            .shadow(color: color.opacity(0.3), radius: configuration.isPressed ? 4 : 12, x: 0, y: configuration.isPressed ? 2 : 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Danger/Stop button style with red gradient
struct DangerFilledButtonStyle: ButtonStyle {
    var color: Color = AppColors.danger
    var textColor: Color = .white
    var minHeight: CGFloat = 50
    var font: Font = .headline.weight(.semibold)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.2 : 0))
            )
            .shadow(color: color.opacity(0.3), radius: configuration.isPressed ? 4 : 10, x: 0, y: configuration.isPressed ? 2 : 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Secondary/outline button style
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    var color: Color = AppColors.primaryBlue
    var minHeight: CGFloat = 50
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(color.opacity(configuration.isPressed ? 0.15 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// ButtonStyle type eraser for conditional styling
struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

// MARK: - Reusable Components

/// Empty state view for lists and content areas
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: 200)
                    .padding(.top, 8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

/// Section header with icon
struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    var trailing: AnyView? = nil
    
    init(title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
        self.trailing = nil
    }
    
    init<V: View>(title: String, icon: String? = nil, @ViewBuilder trailing: () -> V) {
        self.title = title
        self.icon = icon
        self.trailing = AnyView(trailing())
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.primaryBlue)
            }
            
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            if let trailing = trailing {
                trailing
            }
        }
    }
}

/// Pulsing indicator for recording state
struct PulsingIndicator: View {
    @State private var isPulsing = false
    var color: Color = AppColors.danger
    var size: CGFloat = 12
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.5), lineWidth: 2)
                    .scaleEffect(isPulsing ? 2.0 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
    }
}

/// Chip/Tag view for status indicators
struct ChipView: View {
    let icon: String?
    let text: String
    var color: Color = AppColors.primaryBlue
    var style: ChipStyle = .filled
    
    enum ChipStyle {
        case filled, outlined
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(style == .filled ? color.opacity(0.2) : Color.clear)
        )
        .overlay(
            Capsule()
                .strokeBorder(color.opacity(style == .outlined ? 1.0 : 0), lineWidth: 1.5)
        )
        .foregroundStyle(color)
    }
}

// MARK: - Haptic Feedback

enum HapticType {
    case light, medium, heavy, success, warning, error, selection
}

func triggerHaptic(_ type: HapticType) {
    switch type {
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

// MARK: - Animation Extensions

extension Animation {
    static var smoothSpring: Animation {
        .spring(response: 0.35, dampingFraction: 0.7)
    }
    
    static var quickSpring: Animation {
        .spring(response: 0.25, dampingFraction: 0.6)
    }
    
    static var gentleSpring: Animation {
        .spring(response: 0.5, dampingFraction: 0.8)
    }
    
    // Breathing animations for recording UI
    static var breatheIn: Animation {
        .easeInOut(duration: 0.15)
    }
    
    static var breatheOut: Animation {
        .easeInOut(duration: 0.12)
    }
    
    static var pulse: Animation {
        .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
    }
}

// MARK: - View Extensions

extension View {
    /// Add tap animation with haptic feedback
    func tapAnimation(scale: CGFloat = 0.97, haptic: HapticType = .light) -> some View {
        self.modifier(TapAnimationModifier(scale: scale, haptic: haptic))
    }
}

struct TapAnimationModifier: ViewModifier {
    let scale: CGFloat
    let haptic: HapticType
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.quickSpring, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            triggerHaptic(haptic)
                        }
                    }
                    .onEnded { _ in isPressed = false }
            )
    }
}
