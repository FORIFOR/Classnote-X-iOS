import SwiftUI

struct InsightsScreen: View {
    @StateObject private var viewModel = InsightsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Color.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Tokens.Spacing.md) {
                        modeFilter

                        // Hero KPIs
                        heroSection

                        // Weekly KPIs
                        weeklySection

                        // Chart
                        chartSection

                        // Completion Stats
                        CompletionStatsRow(stats: viewModel.completionStats)
                            .padding(.horizontal, Tokens.Spacing.screenHorizontal)

                        // Mode Distribution
                        ModeDistributionView(distribution: viewModel.modeDistribution)
                            .padding(.horizontal, Tokens.Spacing.screenHorizontal)

                        // Supplement KPIs
                        supplementalKPIs

                        // Improvement Actions
                        actionsSection

                        Spacer().frame(height: Tokens.Spacing.xl)
                    }
                    .padding(.top, Tokens.Spacing.md)
                }
                .scrollIndicators(.hidden)

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Tokens.Color.background.opacity(0.8))
                }
            }
            .navigationTitle("分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Tokens.Color.textSecondary)
                    }
                }
            }
            .task {
                await viewModel.loadData()
            }
        }
    }

    // MARK: - Mode Filter

    private var modeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Spacing.xs) {
                ForEach(InsightsModeFilter.allCases, id: \.self) { filter in
                    PeriodChip(
                        title: filter.rawValue,
                        isSelected: viewModel.selectedModeFilter == filter
                    ) {
                        viewModel.changeModeFilter(filter)
                    }
                }
            }
            .padding(.horizontal, Tokens.Spacing.screenHorizontal)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            // Total Recording Time
            HeroKPICard(
                icon: "waveform",
                value: viewModel.formatMinutes(viewModel.totalMinutes),
                label: "総録音時間",
                subValue: viewModel.weeklyMinutes > 0 ? "+\(viewModel.formatHoursShort(viewModel.weeklyMinutes)) 今週" : nil,
                gradient: Tokens.Gradients.ai
            )

            // Total Sessions
            HeroKPICard(
                icon: "doc.text.fill",
                value: "\(viewModel.totalSessions)",
                label: "総セッション数",
                subValue: viewModel.weeklySessions > 0 ? "+\(viewModel.weeklySessions)件 今週" : nil,
                gradient: Tokens.Gradients.brandX
            )
        }
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
    }

    // MARK: - Weekly Section

    private var weeklySection: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            MiniKPICard(
                title: "今週の録音時間",
                value: viewModel.formatHoursShort(viewModel.weeklyMinutes),
                icon: "clock",
                tint: Tokens.Color.accent
            )
            MiniKPICard(
                title: "今週のセッション",
                value: "\(viewModel.weeklySessions)件",
                icon: "calendar",
                tint: Tokens.Color.textPrimary
            )
            MiniKPICard(
                title: "連続記録",
                value: "\(viewModel.streakDays)日",
                icon: "flame.fill",
                tint: Tokens.Color.lectureAccent
            )
        }
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            HStack {
                Text("録音時間の推移")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.Color.textPrimary)
                Spacer()
            }
            .padding(.horizontal, Tokens.Spacing.screenHorizontal)

            periodSelector

            if !viewModel.dailyMetrics.isEmpty {
                SmoothMinutesChart(data: viewModel.dailyMetrics)
                    .padding(.horizontal, Tokens.Spacing.screenHorizontal)
            } else {
                EmptyChartCard()
                    .padding(.horizontal, Tokens.Spacing.screenHorizontal)
            }
        }
    }

    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Spacing.xs) {
                ForEach(InsightsPeriod.allCases, id: \.self) { period in
                    PeriodChip(
                        title: period.rawValue,
                        isSelected: viewModel.selectedPeriod == period
                    ) {
                        viewModel.changePeriod(period)
                    }
                }
            }
            .padding(.horizontal, Tokens.Spacing.screenHorizontal)
        }
    }

    // MARK: - Supplemental KPIs

    private var supplementalKPIs: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            Text("改善に効く指標")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Tokens.Color.textPrimary)
                .padding(.horizontal, Tokens.Spacing.screenHorizontal)

            VStack(spacing: Tokens.Spacing.sm) {
                HStack(spacing: Tokens.Spacing.sm) {
                    SmallStatCard(
                        title: "平均録音時間",
                        value: viewModel.formatMinutes(viewModel.averageMinutes),
                        subtitle: "1件あたり",
                        icon: "timer",
                        tint: Tokens.Color.accent
                    )
                    SmallStatCard(
                        title: "共有セッション",
                        value: "\(viewModel.sharedSessions)件",
                        subtitle: "\(viewModel.sharedMembers)人参加",
                        icon: "person.2.fill",
                        tint: Tokens.Color.meetingAccent
                    )
                }

                HStack(spacing: Tokens.Spacing.sm) {
                    SmallStatCard(
                        title: "録音成功率",
                        value: viewModel.formatRate(viewModel.audioReadyRate),
                        subtitle: viewModel.audioSessionCount > 0 ? "\(viewModel.audioReadyCount)/\(viewModel.audioSessionCount)" : "対象なし",
                        icon: "waveform",
                        tint: Tokens.Color.textPrimary
                    )
                    if let bestDay = viewModel.bestDay {
                        SmallStatCard(
                            title: "ベストデイ",
                            value: viewModel.formatMinutes(bestDay.minutes),
                            subtitle: shortDateLabel(bestDay.date),
                            icon: "star.fill",
                            tint: Tokens.Color.lectureAccent
                        )
                    } else {
                        SmallStatCard(
                            title: "ベストデイ",
                            value: "—",
                            subtitle: "記録なし",
                            icon: "star.fill",
                            tint: Tokens.Color.textSecondary
                        )
                    }
                }
            }
            .padding(.horizontal, Tokens.Spacing.screenHorizontal)
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            Text("改善アクション")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Tokens.Color.textPrimary)
                .padding(.horizontal, Tokens.Spacing.screenHorizontal)

            VStack(spacing: Tokens.Spacing.sm) {
                ForEach(viewModel.actions) { action in
                    ActionCard(
                        icon: action.icon,
                        title: action.title,
                        message: action.message,
                        tint: actionTint(action.tint)
                    )
                }
            }
            .padding(.horizontal, Tokens.Spacing.screenHorizontal)
        }
    }

    private func actionTint(_ token: ColorToken) -> Color {
        switch token {
        case .accent:
            return Tokens.Color.accent
        case .lecture:
            return Tokens.Color.lectureAccent
        case .meeting:
            return Tokens.Color.meetingAccent
        case .success:
            return Tokens.Color.textPrimary
        }
    }

    private func shortDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

// MARK: - Hero KPI Card

private struct HeroKPICard: View {
    let icon: String
    let value: String
    let label: String
    let subValue: String?
    let gradient: LinearGradient

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            // Icon
            ZStack {
                Circle()
                    .fill(gradient.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(gradient)
            }

            // Value
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Tokens.Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // Label
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Tokens.Color.textSecondary)

            // Sub Value (weekly diff)
            if let subValue {
                Text(subValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Spacing.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Period Chip

private struct PeriodChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.light()
            action()
        }) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Tokens.Color.surface : Tokens.Color.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Tokens.Color.textPrimary : Tokens.Color.surface)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Tokens.Color.border.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct MiniKPICard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.Color.textSecondary)
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Tokens.Color.textPrimary)
            }

            Spacer()
        }
        .padding(Tokens.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

private struct SmallStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            HStack(spacing: Tokens.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Tokens.Color.textSecondary)
            }

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Tokens.Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(Tokens.Color.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Spacing.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

private struct ActionCard: View {
    let icon: String
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.textPrimary)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Tokens.Color.textSecondary)
            }

            Spacer()
        }
        .padding(Tokens.Spacing.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

private struct EmptyChartCard: View {
    var body: some View {
        VStack(spacing: Tokens.Spacing.sm) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Tokens.Color.textTertiary)
            Text("記録がありません")
                .font(.system(size: 13))
                .foregroundStyle(Tokens.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Tokens.Spacing.lg)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview {
    InsightsScreen()
}
