import Foundation
import Combine
import SwiftUI

@MainActor
final class CalendarViewModel: ObservableObject {
    // MARK: - Filter Types
    enum CalendarFilter: String, CaseIterable, Identifiable {
        case all = "すべて"
        case lecture = "講義"
        case meeting = "会議"
        
        var id: String { rawValue }
    }
    
    // MARK: - Published State
    @Published var currentMonth: Date
    @Published var selectedDate: Date
    
    @Published var sessions: [Session] = []
    @Published var filter: CalendarFilter = .all
    @Published var searchText: String = ""
    
    // MARK: - Computed State
    @Published private(set) var days: [CalendarDay] = []
    @Published private(set) var displaySessions: [Session] = []
    
    // Aggregates for the month view
    @Published private(set) var sessionCounts: [Date: Int] = [:]
    @Published private(set) var audioCounts: [Date: Bool] = [:] // Presence of audio
    
    // Stats for the stats row
    var monthSessionCount: Int {
        let monthStart = currentMonth.startOfMonth
        let monthEnd = currentMonth.endOfMonth
        return sessions.filter { session in
            guard let date = session.startedAt ?? session.createdAt else { return false }
            return date >= monthStart && date <= monthEnd
        }
        .filter { filterSession($0, with: filter, search: searchText) }
        .count
    }
    
    var monthAudioCount: Int {
        let monthStart = currentMonth.startOfMonth
        let monthEnd = currentMonth.endOfMonth
        return sessions.filter { session in
            guard let date = session.startedAt ?? session.createdAt else { return false }
            return date >= monthStart && date <= monthEnd && session.hasAudio
        }
        .filter { filterSession($0, with: filter, search: searchText) }
        .count
    }
    
    private var cancellables = Set<AnyCancellable>()
    private let calendar = Calendar.current
    
    init() {
        let now = Date()
        self.currentMonth = now.startOfMonth
        self.selectedDate = now
        
        setupBindings()
        fetchSessions() // Initial fetch
    }
    
    private func setupBindings() {
        // update grid and aggregations when sessions, month, filter, or search change
        Publishers.CombineLatest4($sessions, $currentMonth, $filter, $searchText)
            .map { [weak self] sessions, month, filter, search in
                self?.generateDays(for: month, sessions: sessions, filter: filter, search: search) ?? []
            }
            .assign(to: &$days)
        
        // Update display sessions for the selected day
        Publishers.CombineLatest4($sessions, $selectedDate, $filter, $searchText)
            .map { [weak self] sessions, date, filter, search in
                self?.filterSessions(sessions, for: date, filter: filter, search: search) ?? []
            }
            .assign(to: &$displaySessions)
    }
    
    func fetchSessions() {
        Task {
            do {
                let all = try await APIClient.shared.listSessions()
                self.sessions = all
            } catch {
                print("Failed to fetch sessions: \(error)")
            }
        }
    }
    
    // MARK: - Actions
    
    func nextMonth() {
        if let next = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = next
            // Reset selected date to start of month to avoid confusion? Spec says "selected day is 'その月の1日'へ移動"
            selectedDate = next.startOfMonth
        }
    }
    
    func prevMonth() {
        if let prev = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = prev
            selectedDate = prev.startOfMonth
        }
    }
    
    func selectDate(_ date: Date) {
        // Simple assignment, binding handles updates
        selectedDate = date
    }

    func goToToday() {
        let now = Date()
        currentMonth = now.startOfMonth
        selectedDate = now
    }

    var isCurrentMonthToday: Bool {
        calendar.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
    }
    
    func deleteCurrentMonth() {
        let monthStart = currentMonth.startOfMonth
        let monthEnd = currentMonth.endOfMonth
        let targets = sessions.filter { session in
            guard let date = session.startedAt ?? session.createdAt else { return false }
            return date >= monthStart && date <= monthEnd
        }
        guard !targets.isEmpty else { return }
        Task {
            for session in targets {
                try? await APIClient.shared.deleteSession(id: session.id)
            }
            await MainActor.run {
                sessions.removeAll { session in
                    targets.contains(where: { $0.id == session.id })
                }
            }
        }
    }
    
    // MARK: - Logic
    
    private func filterSession(_ session: Session, with filter: CalendarFilter, search: String) -> Bool {
        // Filter Type
        if filter != .all {
            let type: SessionType = (filter == .lecture ? .lecture : .meeting)
            if session.type != type { return false }
        }
        
        // Search
        if !search.isEmpty {
            let query = search.lowercased()
            let titleMatch = session.title.lowercased().contains(query)
            let tagMatch = (session.tags ?? []).contains { $0.lowercased().contains(query) }
            if !titleMatch && !tagMatch { return false }
        }
        
        return true
    }
    
    private func filterSessions(_ sessions: [Session], for date: Date, filter: CalendarFilter, search: String) -> [Session] {
        return sessions.filter { session in
            guard let sDate = session.startedAt ?? session.createdAt else { return false }
            // Same day check
            if !calendar.isDate(sDate, inSameDayAs: date) { return false }
            return filterSession(session, with: filter, search: search)
        }
        .sorted { ($0.startedAt ?? $0.createdAt ?? Date()) > ($1.startedAt ?? $1.createdAt ?? Date()) }
    }
    
    private func generateDays(for month: Date, sessions: [Session], filter: CalendarFilter, search: String) -> [CalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }
        
        let monthStart = monthInterval.start
        // let monthEnd = monthInterval.end
        
        // Find first day of the grid (Sunday)
        let firstWeekday = calendar.component(.weekday, from: monthStart) // 1=Sun, 2=Mon...
        let offsetDays = firstWeekday - 1 // Days to subtract to get to Sunday
        
        guard let startGrid = calendar.date(byAdding: .day, value: -offsetDays, to: monthStart) else { return [] }
        
        // 6 rows * 7 cols = 42 days fixed
        var generated: [CalendarDay] = []
        
        for i in 0..<42 {
            if let date = calendar.date(byAdding: .day, value: i, to: startGrid) {
                // Check if date is in current month
                let isCurrentMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)

                if !isCurrentMonth {
                    // Spec: "先月/来月の空白セルは表示しない（または透明で占有）" -> We create a day but mark as hidden/padding
                    // Pass index for stable ID generation
                    generated.append(CalendarDay(date: date, isCurrentMonth: false, count: 0, hasMarker: false, index: i))
                } else {
                    // Aggregate counts for this day
                    let daySessions = sessions.filter { s in
                        guard let sDate = s.startedAt ?? s.createdAt else { return false }
                        return calendar.isDate(sDate, inSameDayAs: date) && self.filterSession(s, with: filter, search: search)
                    }

                    let count = daySessions.count
                    let hasAudio = daySessions.contains { $0.hasAudio } // "オレンジの小点... 録音データあり を推奨"

                    generated.append(CalendarDay(date: date, isCurrentMonth: true, count: count, hasMarker: hasAudio))
                }
            }
        }
        
        return generated
    }
}

// MARK: - Helper Models

struct CalendarDay: Identifiable, Equatable, Hashable {
    /// Stable ID based on date to prevent unnecessary view recreation
    /// Format: "d:yyyyMMdd" for real dates, "p:index" for placeholder cells
    let id: String
    let date: Date
    let isCurrentMonth: Bool
    let count: Int
    let hasMarker: Bool

    init(date: Date, isCurrentMonth: Bool, count: Int, hasMarker: Bool, index: Int? = nil) {
        self.date = date
        self.isCurrentMonth = isCurrentMonth
        self.count = count
        self.hasMarker = hasMarker

        if isCurrentMonth {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            self.id = "d:\(formatter.string(from: date))"
        } else if let index = index {
            self.id = "p:\(index)"
        } else {
            // Fallback: use date string even for non-current month
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            self.id = "x:\(formatter.string(from: date))"
        }
    }
}

// MARK: - Date Extensions

private extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self
    }
    
    var endOfMonth: Date {
        guard let next = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth) else { return self }
        return Calendar.current.date(byAdding: .second, value: -1, to: next) ?? self
    }
}
