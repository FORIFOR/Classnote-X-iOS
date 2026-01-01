import SwiftUI

// MARK: - Single Completion Ring

struct CompletionRing: View {
    let progress: Double  // 0.0 - 1.0
    let icon: String
    let label: String
    let color: Color
    let size: CGFloat

    @State private var animatedProgress: Double = 0

    init(progress: Double, icon: String, label: String, color: Color, size: CGFloat = 64) {
        self.progress = progress
        self.icon = icon
        self.label = label
        self.color = color
        self.size = size
    }

    var body: some View {
        VStack(spacing: Tokens.Spacing.xs) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 6)

                // Progress ring
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Icon
                Image(systemName: icon)
                    .font(.system(size: size * 0.3, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(width: size, height: size)

            // Label
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Tokens.Color.textSecondary)

            // Percentage
            Text("\(Int(progress * 100))%")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Tokens.Color.textPrimary)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Completion Stats Row

struct CompletionStatsRow: View {
    let stats: CompletionStats

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            Text("AI生成完成率")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Tokens.Color.textPrimary)

            HStack(spacing: 0) {
                Spacer()

                CompletionRing(
                    progress: stats.transcriptRate,
                    icon: "text.alignleft",
                    label: "文字起こし",
                    color: .blue
                )

                Spacer()

                CompletionRing(
                    progress: stats.summaryRate,
                    icon: "doc.text",
                    label: "要約",
                    color: .purple
                )

                Spacer()

                CompletionRing(
                    progress: stats.quizRate,
                    icon: "questionmark.circle",
                    label: "クイズ",
                    color: .orange
                )

                Spacer()
            }
        }
        .padding(Tokens.Spacing.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Mode Distribution Donut

struct ModeDistributionView: View {
    let distribution: ModeDistribution

    @State private var animatedLectureRatio: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            Text("モード比率")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Tokens.Color.textPrimary)

            HStack(spacing: Tokens.Spacing.lg) {
                // Donut Chart
                ZStack {
                    // Meeting (background, full circle)
                    Circle()
                        .stroke(Tokens.Color.meetingAccent, lineWidth: 16)

                    // Lecture (foreground, partial)
                    Circle()
                        .trim(from: 0, to: animatedLectureRatio)
                        .stroke(
                            Tokens.Color.lectureAccent,
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    // Center label
                    VStack(spacing: 2) {
                        Text("\(distribution.lectureCount + distribution.meetingCount)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Tokens.Color.textPrimary)
                        Text("件")
                            .font(.system(size: 11))
                            .foregroundStyle(Tokens.Color.textSecondary)
                    }
                }
                .frame(width: 100, height: 100)

                // Legend
                VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                    LegendItem(
                        color: Tokens.Color.lectureAccent,
                        label: "講義",
                        count: distribution.lectureCount,
                        minutes: distribution.lectureMinutes
                    )

                    LegendItem(
                        color: Tokens.Color.meetingAccent,
                        label: "会議",
                        count: distribution.meetingCount,
                        minutes: distribution.meetingMinutes
                    )
                }

                Spacer()
            }
        }
        .padding(Tokens.Spacing.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                animatedLectureRatio = distribution.lectureRatio
            }
        }
        .onChange(of: distribution.lectureRatio) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animatedLectureRatio = newValue
            }
        }
    }
}

private struct LegendItem: View {
    let color: Color
    let label: String
    let count: Int
    let minutes: Double

    var body: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Tokens.Color.textPrimary)

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(count)件")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.Color.textPrimary)
                Text(formatMinutes(minutes))
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
        }
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "\(hours)h\(mins)m"
        }
        return "\(mins)分"
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        CompletionStatsRow(stats: CompletionStats(
            transcriptRate: 0.72,
            summaryRate: 0.45,
            quizRate: 0.18,
            totalSessions: 100
        ))

        ModeDistributionView(distribution: ModeDistribution(
            lectureMinutes: 450,
            meetingMinutes: 280,
            lectureCount: 45,
            meetingCount: 32
        ))
    }
    .padding()
    .background(Tokens.Color.background)
}
