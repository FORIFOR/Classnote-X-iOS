import SwiftUI

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    let delay: Double

    init(duration: Double = 1.5, delay: Double = 0) {
        self.duration = duration
        self.delay = delay
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color.white.opacity(0.4), location: 0.3),
                            .init(color: Color.white.opacity(0.6), location: 0.5),
                            .init(color: Color.white.opacity(0.4), location: 0.7),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                    .mask(content)
                }
            )
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                    .delay(delay)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer(duration: Double = 1.5, delay: Double = 0) -> some View {
        modifier(ShimmerModifier(duration: duration, delay: delay))
    }
}

// MARK: - Skeleton View

struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    init(width: CGFloat? = nil, height: CGFloat = 16, cornerRadius: CGFloat = 4) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Tokens.Color.border.opacity(0.5))
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - Skeleton Line Group

struct SkeletonLineGroup: View {
    let lineCount: Int
    let spacing: CGFloat
    let lastLineWidthRatio: CGFloat

    init(lineCount: Int = 3, spacing: CGFloat = Tokens.Spacing.xs, lastLineWidthRatio: CGFloat = 0.6) {
        self.lineCount = lineCount
        self.spacing = spacing
        self.lastLineWidthRatio = lastLineWidthRatio
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(0..<lineCount, id: \.self) { index in
                GeometryReader { geometry in
                    SkeletonView(
                        width: index == lineCount - 1 ? geometry.size.width * lastLineWidthRatio : geometry.size.width,
                        height: 14
                    )
                }
                .frame(height: 14)
            }
        }
    }
}

// MARK: - Pulsing Modifier

struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false
    let minOpacity: Double
    let maxOpacity: Double
    let duration: Double

    init(minOpacity: Double = 0.4, maxOpacity: Double = 1.0, duration: Double = 0.8) {
        self.minOpacity = minOpacity
        self.maxOpacity = maxOpacity
        self.duration = duration
    }

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? maxOpacity : minOpacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func pulsing(minOpacity: Double = 0.4, maxOpacity: Double = 1.0, duration: Double = 0.8) -> some View {
        modifier(PulsingModifier(minOpacity: minOpacity, maxOpacity: maxOpacity, duration: duration))
    }
}

// MARK: - Scale Pulse Modifier

struct ScalePulseModifier: ViewModifier {
    @State private var isPulsing = false
    let minScale: CGFloat
    let maxScale: CGFloat
    let duration: Double

    init(minScale: CGFloat = 0.95, maxScale: CGFloat = 1.0, duration: Double = 0.6) {
        self.minScale = minScale
        self.maxScale = maxScale
        self.duration = duration
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? maxScale : minScale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func scalePulse(minScale: CGFloat = 0.95, maxScale: CGFloat = 1.0, duration: Double = 0.6) -> some View {
        modifier(ScalePulseModifier(minScale: minScale, maxScale: maxScale, duration: duration))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        // Shimmer effect on text
        Text("Loading...")
            .font(.headline)
            .shimmer()

        // Skeleton lines
        VStack(alignment: .leading, spacing: 12) {
            SkeletonView(height: 20)
            SkeletonView(height: 14)
            SkeletonView(width: 200, height: 14)
        }
        .padding()
        .background(Tokens.Color.surface)
        .cornerRadius(12)

        // Skeleton line group
        SkeletonLineGroup(lineCount: 4)
            .padding()
            .background(Tokens.Color.surface)
            .cornerRadius(12)

        // Pulsing dot (like recording indicator)
        Circle()
            .fill(Color.red)
            .frame(width: 12, height: 12)
            .pulsing()

        // Scale pulse
        Circle()
            .fill(Tokens.Color.accent)
            .frame(width: 60, height: 60)
            .scalePulse()
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Tokens.Color.background)
}
