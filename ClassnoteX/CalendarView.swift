import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var model: AppModel
    @State private var selectedDate: Date = Date()
    @State private var query: String = ""
    @State private var modeFilter: ModeFilter = .all
    @State private var animateContent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                monthNavigator
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                
                filtersSection
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                
                calendarGrid
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                
                sessionsForDate
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(GlassNotebook.Background.primary.ignoresSafeArea())
        .navigationTitle("カレンダー")
        .onAppear {
            print("[CalendarView] ========== VIEW APPEARED ==========")
            print("[CalendarView] Selected date: \(selectedDate)")
            print("[CalendarView] model.lectures count: \(model.lectures.count)")
            print("[CalendarView] model.meetings count: \(model.meetings.count)")
            
            let allCount = allSessions.count
            print("[CalendarView] allSessions count: \(allCount)")
            
            if allCount == 0 {
                print("[CalendarView] ⚠️ No sessions in AppModel")
                print("[CalendarView] Firestore listeners may not be active or no data exists")
            } else {
                print("[CalendarView] ✅ Sessions available:")
                for (i, session) in allSessions.prefix(5).enumerated() {
                    print("[CalendarView]   Session \(i+1): id=\(session.wrappedId), mode=\(session.mode ?? "nil"), date=\(session.createdAt?.description ?? "nil")")
                }
            }
            
            print("[CalendarView] eventsByDay keys: \(eventsByDay.keys.count) days with events")
            print("[CalendarView] sessionsForSelectedDate count: \(sessionsForSelectedDate.count)")
            print("[CalendarView] ========== END ==========")
            
            withAnimation(.smoothSpring.delay(0.1)) {
                animateContent = true
            }
        }
        .task {
            // Fetch sessions from REST API instead of relying on Firestore
            await model.reloadSessionsFromAPI()
        }
    }

    // MARK: - Month Navigator
    
    private var monthNavigator: some View {
        HStack {
            Button {
                triggerHaptic(.light)
                withAnimation(.smoothSpring) {
                    selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.primaryBlue)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(AppColors.primaryBlue.opacity(0.1))
                    )
            }
            
            Spacer()
            
            Text(monthTitle(for: selectedDate))
                .font(.title2.weight(.bold))
            
            Spacer()
            
            Button {
                triggerHaptic(.light)
                withAnimation(.smoothSpring) {
                    selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.primaryBlue)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(AppColors.primaryBlue.opacity(0.1))
                    )
            }
        }
    }
    
    // MARK: - Filters
    
    private var filtersSection: some View {
        VStack(spacing: 12) {
            Picker("モード", selection: $modeFilter) {
                Text("すべて").tag(ModeFilter.all)
                Text("講義").tag(ModeFilter.lecture)
                Text("会議").tag(ModeFilter.meeting)
            }
            .pickerStyle(.segmented)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("タイトルで検索", text: $query)
                    .textFieldStyle(.plain)
                
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.tertiarySystemBackground))
            )
        }
    }

    // MARK: - Calendar Grid
    
    private var calendarGrid: some View {
        VStack(spacing: 12) {
            // Weekday headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary.opacity(0.8))
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Days grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                ForEach(monthDays(for: selectedDate), id: \.self) { component in
                    dayCell(component)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
    
    private func dayCell(_ component: DayComponent) -> some View {
        Group {
            if let date = component.date {
                let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                let isToday = Calendar.current.isDateInToday(date)
                let count = eventsByDay[Calendar.current.startOfDay(for: date)] ?? 0
                
                Button {
                    triggerHaptic(.selection)
                    withAnimation(.quickSpring) {
                        selectedDate = date
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text("\(component.day)")
                            .font(.body.weight(isSelected ? .bold : .regular))
                            .foregroundStyle(dayTextColor(isSelected: isSelected, isToday: isToday))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(dayBackground(isSelected: isSelected, isToday: isToday))
                            )
                        
                        // Event indicator
                        Circle()
                            .fill(AppColors.primaryBlue)
                            .frame(width: 6, height: 6)
                            .opacity(count > 0 ? 1 : 0)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(height: 50)
            }
        }
    }
    
    private func dayBackground(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected {
            return AppColors.primaryBlue
        }
        if isToday {
            return AppColors.primaryBlue.opacity(0.15)
        }
        return .clear
    }
    
    private func dayTextColor(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected {
            return .white
        }
        if isToday {
            return AppColors.primaryBlue
        }
        return .primary
    }

    // MARK: - Sessions for Date
    
    // API Client
    private var apiClient: ClassnoteAPIClient {
        ClassnoteAPIClient(baseURL: URL(string: "https://classnote-api-900324644592.asia-northeast1.run.app")!)
    }

    private var sessionsForDate: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: formattedSelectedDate, icon: "calendar")
            
            if sessionsForSelectedDate.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.minus")
                    // ... (existing content)
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)
                    
                    Text("この日のセッションはありません")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sessionsForSelectedDate.enumerated()), id: \.element.wrappedId) { index, session in
                        NavigationLink(destination: SessionDetailView(sessionId: session.wrappedId, apiClient: apiClient)) {
                            calendarSessionRow(session)
                        }
                        .buttonStyle(.plain)
                        
                        if index < sessionsForSelectedDate.count - 1 {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }
    
    private func calendarSessionRow(_ session: SessionItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill((session.mode == "meeting" ? AppColors.primaryTeal : AppColors.primaryBlue).opacity(0.12))
                    .frame(width: 40, height: 40)
                
                Image(systemName: session.mode == "meeting" ? "person.2.fill" : "book.fill")
                    .foregroundStyle(session.mode == "meeting" ? AppColors.primaryTeal : AppColors.primaryBlue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title ?? "無題")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(formattedTime(for: session))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let duration = session.durationSec {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text("\(Int(duration/60))分")
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.7))
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers
    
    private var weekdaySymbols: [String] {
        Calendar.current.shortWeekdaySymbols
    }
    
    private var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日 (E)"
        return formatter.string(from: selectedDate)
    }

    private var allSessions: [SessionItem] {
        model.lectures + model.meetings
    }

    private var filteredByMode: [SessionItem] {
        switch modeFilter {
        case .all: return allSessions
        case .lecture: return allSessions.filter { $0.mode == SessionMode.lecture.rawValue }
        case .meeting: return allSessions.filter { $0.mode == SessionMode.meeting.rawValue }
        }
    }

    private var filteredByQuery: [SessionItem] {
        guard !query.isEmpty else { return filteredByMode }
        return filteredByMode.filter { $0.title?.localizedCaseInsensitiveContains(query) == true }
    }

    private var eventsByDay: [Date: Int] {
        let cal = Calendar.current
        return filteredByQuery.reduce(into: [:]) { dict, session in
            if let date = session.createdAt.map({ cal.startOfDay(for: $0) }) {
                dict[date, default: 0] += 1
            }
        }
    }

    private var sessionsForSelectedDate: [SessionItem] {
        let cal = Calendar.current
        return filteredByQuery.filter { session in
            guard let created = session.createdAt else { return false }
            return cal.isDate(created, inSameDayAs: selectedDate)
        }.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    private func monthDays(for date: Date) -> [DayComponent] {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: date),
              let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: date))
        else { return [] }

        let firstWeekday = cal.component(.weekday, from: firstDay)
        var days: [DayComponent] = Array(repeating: DayComponent(date: nil, day: 0), count: firstWeekday - 1)

        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(DayComponent(date: d, day: day))
            }
        }
        return days
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: date)
    }

    private func formattedTime(for session: SessionItem) -> String {
        guard let date = session.createdAt else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private struct DayComponent: Hashable {
    let date: Date?
    let day: Int
}

private enum ModeFilter: Hashable {
    case all, lecture, meeting
}
