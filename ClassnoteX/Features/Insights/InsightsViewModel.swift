import Foundation
import Combine

// MARK: - Daily Metric

struct DailyMetric: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Double
    let sessionCount: Int
}

// MARK: - Completion Stats

struct CompletionStats {
    let transcriptRate: Double  // 0.0 - 1.0
    let summaryRate: Double
    let quizRate: Double
    let totalSessions: Int
}

// MARK: - Mode Distribution

struct ModeDistribution {
    let lectureMinutes: Double
    let meetingMinutes: Double
    let lectureCount: Int
    let meetingCount: Int

    var totalMinutes: Double { lectureMinutes + meetingMinutes }
    var lectureRatio: Double { totalMinutes > 0 ? lectureMinutes / totalMinutes : 0.5 }
    var meetingRatio: Double { totalMinutes > 0 ? meetingMinutes / totalMinutes : 0.5 }
}

// MARK: - Period Filter

enum InsightsPeriod: String, CaseIterable {
    case week = "7日"
    case month = "30日"
    case quarter = "90日"
    case all = "全期間"

    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .all: return nil
        }
    }
}

enum InsightsModeFilter: String, CaseIterable {
    case all = "すべて"
    case lecture = "講義"
    case meeting = "会議"
}

struct InsightAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let message: String
    let tint: ColorToken
}

enum ColorToken {
    case accent
    case lecture
    case meeting
    case success
}

// MARK: - Insights View Model

@MainActor
final class InsightsViewModel: ObservableObject {
    // Hero KPIs
    @Published var totalMinutes: Double = 0
    @Published var totalSessions: Int = 0
    @Published var weeklyMinutes: Double = 0
    @Published var weeklySessions: Int = 0
    @Published var streakDays: Int = 0
    @Published var averageMinutes: Double = 0
    @Published var sharedSessions: Int = 0
    @Published var sharedMembers: Int = 0
    @Published var audioReadyRate: Double? = nil
    @Published var audioReadyCount: Int = 0
    @Published var audioSessionCount: Int = 0

    // Chart Data
    @Published var dailyMetrics: [DailyMetric] = []
    @Published var selectedPeriod: InsightsPeriod = .week
    @Published var selectedModeFilter: InsightsModeFilter = .all
    @Published var bestDay: DailyMetric?

    // Completion Stats
    @Published var completionStats: CompletionStats = CompletionStats(
        transcriptRate: 0, summaryRate: 0, quizRate: 0, totalSessions: 0
    )

    // Mode Distribution
    @Published var modeDistribution: ModeDistribution = ModeDistribution(
        lectureMinutes: 0, meetingMinutes: 0, lectureCount: 0, meetingCount: 0
    )

    // Loading State
    @Published var isLoading: Bool = false
    @Published var actions: [InsightAction] = []

    private var allSessions: [Session] = []

    // MARK: - Load Data

    func loadData() async {
        isLoading = true
        do {
            allSessions = try await APIClient.shared.listSessions()
            computeAllStats()
        } catch {
            print("[InsightsViewModel] Failed to load sessions: \(error)")
        }
        isLoading = false
    }

    func changePeriod(_ period: InsightsPeriod) {
        selectedPeriod = period
        computeDailyMetrics()
    }

    func changeModeFilter(_ filter: InsightsModeFilter) {
        selectedModeFilter = filter
        computeAllStats()
    }

    // MARK: - Compute Stats

    private func computeAllStats() {
        computeHeroKPIs()
        computeDailyMetrics()
        computeCompletionStats()
        computeModeDistribution()
        computeActions()
    }

    private func computeHeroKPIs() {
        let sessions = filteredSessions
        // Total
        totalSessions = sessions.count
        totalMinutes = sessions.reduce(0.0) { sum, session in
            sum + Double(session.durationSec ?? 0) / 60.0
        }

        // Weekly (last 7 days)
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weeklySessions = sessions.filter { session in
            guard let date = session.startedAt ?? session.createdAt else { return false }
            return date >= weekAgo
        }
        self.weeklySessions = weeklySessions.count
        self.weeklyMinutes = weeklySessions.reduce(0.0) { sum, session in
            sum + Double(session.durationSec ?? 0) / 60.0
        }

        averageMinutes = totalSessions > 0 ? totalMinutes / Double(totalSessions) : 0

        let shared = sessions.filter { ($0.sharing?.memberCount ?? 0) > 0 }
        sharedSessions = shared.count
        sharedMembers = shared.reduce(0) { $0 + ($1.sharing?.memberCount ?? 0) }

        let audioSessions = sessions.filter {
            $0.audioStatus != nil || $0.audioMeta != nil || ($0.audioPath?.isEmpty == false)
        }
        audioSessionCount = audioSessions.count
        audioReadyCount = audioSessions.filter { session in
            if session.audioStatus == .ready {
                return true
            }
            if session.audioStatus == nil {
                return session.audioMeta != nil || (session.audioPath?.isEmpty == false)
            }
            return false
        }.count
        audioReadyRate = audioSessionCount > 0
            ? Double(audioReadyCount) / Double(audioSessionCount)
            : nil

        // Streak
        computeStreak()
    }

    private func computeStreak() {
        let sessions = filteredSessions
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get unique recording dates
        var recordingDates = Set<Date>()
        for session in sessions {
            if let date = session.startedAt ?? session.createdAt {
                recordingDates.insert(calendar.startOfDay(for: date))
            }
        }

        // Count consecutive days ending today or yesterday
        var streak = 0
        var checkDate = today

        // Allow for today not having a recording yet (check from yesterday)
        if !recordingDates.contains(today) {
            checkDate = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        }

        while recordingDates.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        streakDays = streak
    }

    private func computeDailyMetrics() {
        let sessions = filteredSessions
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard !sessions.isEmpty else {
            dailyMetrics = []
            bestDay = nil
            return
        }

        // Determine date range
        let days = selectedPeriod.days
        let startDate: Date
        if let days {
            startDate = calendar.date(byAdding: .day, value: -days + 1, to: today) ?? today
        } else if let earliest = sessions.compactMap({ $0.startedAt ?? $0.createdAt }).min() {
            startDate = calendar.startOfDay(for: earliest)
        } else {
            startDate = today
        }

        // Group sessions by day
        var dailyData: [Date: (minutes: Double, count: Int)] = [:]

        // Initialize all days with zero
        if startDate <= today {
            var current = startDate
            while current <= today {
                dailyData[current] = (0, 0)
                current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
            }
        }

        // Aggregate sessions
        for session in sessions {
            guard let sessionDate = session.startedAt ?? session.createdAt else { continue }
            let dayStart = calendar.startOfDay(for: sessionDate)

            if dayStart >= startDate && dayStart <= today {
                let minutes = Double(session.durationSec ?? 0) / 60.0
                let existing = dailyData[dayStart] ?? (0, 0)
                dailyData[dayStart] = (existing.minutes + minutes, existing.count + 1)
            }
        }

        // Convert to array and sort
        dailyMetrics = dailyData.map { date, data in
            DailyMetric(date: date, minutes: data.minutes, sessionCount: data.count)
        }.sorted { $0.date < $1.date }

        if dailyMetrics.allSatisfy({ $0.minutes == 0 }) {
            dailyMetrics = []
            bestDay = nil
        } else {
            bestDay = dailyMetrics.max(by: { $0.minutes < $1.minutes })
        }
    }

    private func computeCompletionStats() {
        let sessions = filteredSessions
        guard !sessions.isEmpty else {
            completionStats = CompletionStats(transcriptRate: 0, summaryRate: 0, quizRate: 0, totalSessions: 0)
            return
        }

        let total = sessions.count
        let withTranscript = sessions.filter { $0.transcript?.hasTranscript == true }.count
        let withSummary = sessions.filter { $0.summary?.hasSummary == true }.count
        let withQuiz = sessions.filter { $0.quiz?.hasQuiz == true }.count

        completionStats = CompletionStats(
            transcriptRate: Double(withTranscript) / Double(total),
            summaryRate: Double(withSummary) / Double(total),
            quizRate: Double(withQuiz) / Double(total),
            totalSessions: total
        )
    }

    private func computeModeDistribution() {
        var lectureMinutes: Double = 0
        var meetingMinutes: Double = 0
        var lectureCount = 0
        var meetingCount = 0

        for session in filteredSessions {
            let minutes = Double(session.durationSec ?? 0) / 60.0
            if session.type == .lecture {
                lectureMinutes += minutes
                lectureCount += 1
            } else {
                meetingMinutes += minutes
                meetingCount += 1
            }
        }

        modeDistribution = ModeDistribution(
            lectureMinutes: lectureMinutes,
            meetingMinutes: meetingMinutes,
            lectureCount: lectureCount,
            meetingCount: meetingCount
        )
    }

    private func computeActions() {
        var suggestions: [InsightAction] = []
        let total = totalSessions

        if total == 0 {
            suggestions.append(
                InsightAction(
                    icon: "mic.fill",
                    title: "まずは1件録音してみましょう",
                    message: "録音を始めると自動で要約やテストが使えます。",
                    tint: .accent
                )
            )
            actions = suggestions
            return
        }

        if completionStats.summaryRate < 0.4 {
            suggestions.append(
                InsightAction(
                    icon: "sparkles",
                    title: "要約を生成して理解を深める",
                    message: "未生成のセッションが多いようです。最近の録音から要約を作成しましょう。",
                    tint: .success
                )
            )
        }

        if completionStats.quizRate < 0.2 {
            suggestions.append(
                InsightAction(
                    icon: "questionmark.circle",
                    title: "テストで記憶定着を強化",
                    message: "クイズ生成率が低めです。要約があるセッションで試してみてください。",
                    tint: .lecture
                )
            )
        }

        if streakDays == 0 {
            suggestions.append(
                InsightAction(
                    icon: "flame.fill",
                    title: "連続記録を作る",
                    message: "まずは3日連続を目標に、短い録音でも継続すると伸びます。",
                    tint: .meeting
                )
            )
        }

        if suggestions.isEmpty {
            suggestions.append(
                InsightAction(
                    icon: "hand.thumbsup.fill",
                    title: "とても良いペースです",
                    message: "この調子で録音→要約→テストの流れを続けましょう。",
                    tint: .success
                )
            )
        }

        actions = suggestions
    }

    private var filteredSessions: [Session] {
        switch selectedModeFilter {
        case .all:
            return allSessions
        case .lecture:
            return allSessions.filter { $0.type == .lecture }
        case .meeting:
            return allSessions.filter { $0.type == .meeting }
        }
    }

    // MARK: - Formatters

    func formatMinutes(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "\(hours)時間\(mins)分"
        }
        return "\(mins)分"
    }

    func formatHoursShort(_ minutes: Double) -> String {
        let hours = minutes / 60.0
        if hours >= 1 {
            return String(format: "%.1f時間", hours)
        }
        return "\(Int(minutes))分"
    }

    func formatRate(_ rate: Double?) -> String {
        guard let rate else { return "—" }
        return "\(Int(rate * 100))%"
    }
}
