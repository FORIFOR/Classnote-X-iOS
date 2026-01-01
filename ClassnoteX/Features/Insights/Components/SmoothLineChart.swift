import SwiftUI
import Charts

// MARK: - Smooth Minutes Chart

struct SmoothMinutesChart: View {
    let data: [DailyMetric]
    let accentColor: Color

    @State private var selectedDate: Date?
    @State private var selectedValue: Double?

    init(data: [DailyMetric], accentColor: Color = Tokens.Color.accent) {
        self.data = data
        self.accentColor = accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
            // Selected value tooltip
            if let date = selectedDate, let value = selectedValue {
                HStack(spacing: Tokens.Spacing.xs) {
                    Text(formatDate(date))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Tokens.Color.textSecondary)
                    Text(formatMinutes(value))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(accentColor)
                }
                .padding(.horizontal, Tokens.Spacing.sm)
                .transition(.opacity)
            } else {
                // Placeholder for consistent height
                Text(" ")
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, Tokens.Spacing.sm)
            }

            // Chart
            Chart(data) { item in
                // Glow effect (underneath)
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Minutes", item.minutes)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(.init(lineWidth: 10, lineCap: .round))
                .foregroundStyle(accentColor.opacity(0.15))

                // Gradient fill
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("Minutes", item.minutes)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.linearGradient(
                    colors: [accentColor.opacity(0.3), accentColor.opacity(0.05), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                ))

                // Main line
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Minutes", item.minutes)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(accentColor)

                // Selection point
                if let selectedDate, Calendar.current.isDate(item.date, inSameDayAs: selectedDate) {
                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("Minutes", item.minutes)
                    )
                    .symbolSize(80)
                    .foregroundStyle(accentColor)

                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("Minutes", item.minutes)
                    )
                    .symbolSize(40)
                    .foregroundStyle(.white)
                }
            }
            .chartYScale(domain: 0...(maxY * 1.15))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: xAxisStride)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(shortDateLabel(date))
                                .font(.system(size: 10))
                                .foregroundStyle(Tokens.Color.textTertiary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(Tokens.Color.border.opacity(0.5))
                    if let minutes = value.as(Double.self) {
                        AxisValueLabel {
                            Text("\(Int(minutes))")
                                .font(.system(size: 10))
                                .foregroundStyle(Tokens.Color.textTertiary)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    updateSelection(at: value.location, proxy: proxy, geometry: geometry)
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        selectedDate = nil
                                        selectedValue = nil
                                    }
                                }
                        )
                }
            }
            .frame(height: 180)
        }
        .padding(Tokens.Spacing.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Helpers

    private var maxY: Double {
        max(data.map(\.minutes).max() ?? 0, 10)
    }

    private var xAxisStride: Int {
        switch data.count {
        case 0...7: return 1
        case 8...14: return 2
        case 15...30: return 5
        default: return 10
        }
    }

    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        let xPosition = location.x - geometry[proxy.plotFrame!].origin.x
        guard let date: Date = proxy.value(atX: xPosition) else { return }

        // Find closest data point
        let calendar = Calendar.current
        if let closest = data.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
            withAnimation(.easeOut(duration: 0.1)) {
                selectedDate = closest.date
                selectedValue = closest.minutes
            }
            Haptics.selection()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d (E)"
        return formatter.string(from: date)
    }

    private func formatMinutes(_ minutes: Double) -> String {
        if minutes >= 60 {
            let hours = Int(minutes) / 60
            let mins = Int(minutes) % 60
            return "\(hours)時間\(mins)分"
        }
        return "\(Int(minutes))分"
    }

    private func shortDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    let sampleData = (0..<7).map { dayOffset -> DailyMetric in
        let date = Calendar.current.date(byAdding: .day, value: -6 + dayOffset, to: Date())!
        let minutes = Double.random(in: 10...120)
        return DailyMetric(date: date, minutes: minutes, sessionCount: Int.random(in: 1...5))
    }

    return SmoothMinutesChart(data: sampleData)
        .padding()
        .background(Tokens.Color.background)
}
