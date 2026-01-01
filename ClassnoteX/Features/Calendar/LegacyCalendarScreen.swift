import SwiftUI
import FirebaseAuth

struct LegacyCalendarScreen: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var isEditing = false
    @State private var showDeleteConfirm = false
    @State private var showInsights = false
    @State private var scrollOffset: CGFloat = 0

    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background Layer
            Tokens.Color.background.ignoresSafeArea()
            
            // Content
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: Tokens.Spacing.md)
                    
                    // 1. Header
                    CalendarHeaderView(
                        onEdit: { isEditing.toggle() },
                        onAnalytics: { showInsights = true }
                    )
                    
                    Spacer().frame(height: Tokens.Spacing.lg)
                    
                    // 2. Month Navigation
                    MonthControlView(
                        currentMonth: viewModel.currentMonth,
                        isCurrentMonthToday: viewModel.isCurrentMonthToday,
                        onPrev: { withAnimation { viewModel.prevMonth() } },
                        onNext: { withAnimation { viewModel.nextMonth() } },
                        onToday: { withAnimation { viewModel.goToToday() } }
                    )
                    
                    Spacer().frame(height: Tokens.Spacing.md)

                    // 3. Stats & Delete
                    CalendarStatsRow(
                        sessionCount: viewModel.monthSessionCount,
                        audioCount: viewModel.monthAudioCount,
                        showDelete: isEditing,
                        onDeleteMonth: { showDeleteConfirm = true }
                    )

                    Spacer().frame(height: Tokens.Spacing.sm)

                    // 4. Filter
                    FilterSegmentControl(selection: $viewModel.filter)

                    Spacer().frame(height: Tokens.Spacing.sm)

                    // 5. Search
                    LegacySearchBar(text: $viewModel.searchText)
                    
                    Spacer().frame(height: Tokens.Spacing.md)
                    
                    // 6. Calendar Grid
                    LegacyCalendarGridView(viewModel: viewModel)
                    
                    Spacer().frame(height: Tokens.Spacing.lg)
                    
                    // 7. Day Detail Header
                    DayDetailHeader(date: viewModel.selectedDate)
                    
                    Spacer().frame(height: Tokens.Spacing.sm)
                    
                    // 8. Session List for selected day
                    if viewModel.displaySessions.isEmpty {
                        EmptyDayView()
                            .padding(.top, Tokens.Spacing.md)
                    } else {
                        LazyVStack(spacing: Tokens.Spacing.sm) {
                            ForEach(viewModel.displaySessions) { session in
                                NavigationLink(value: session) {
                                    SessionCellV2(
                                        session: session,
                                        isEditing: false,
                                        isSelected: false,
                                        isMine: session.ownerUid == currentUid
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
                    }
                    
                    // Bottom Padding for TabBar (72pt + margin)
                    Spacer().frame(height: Tokens.Spacing.tabBarHeight + Tokens.Spacing.lg)
                }
            }
            .scrollIndicators(.hidden)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: CalendarScrollOffsetKey.self,
                        value: proxy.frame(in: .named("calendarScroll")).minY
                    )
                }
            )
            .coordinateSpace(name: "calendarScroll")
            .onPreferenceChange(CalendarScrollOffsetKey.self) { value in
                scrollOffset = value
            }
        }
        .overlay(alignment: .top) {
            CalendarTopBar(title: "カレンダー", opacity: topBarTitleOpacity)
        }
        .onAppear {
            viewModel.fetchSessions()
        }
        .navigationDestination(for: Session.self) { session in
            SessionDetailScreen(session: session)
        }
        .confirmationDialog(
            "この月のセッションを削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                viewModel.deleteCurrentMonth()
            }
            Button("キャンセル", role: .cancel) {}
        }
        .sheet(isPresented: $showInsights) {
            InsightsScreen()
        }
    }

    private var topBarTitleOpacity: Double {
        let offset = -scrollOffset
        let start: CGFloat = 18
        let end: CGFloat = 52
        if offset <= start { return 0 }
        if offset >= end { return 1 }
        return Double((offset - start) / (end - start))
    }
}

// MARK: - Subviews

struct DayDetailHeader: View {
    let date: Date
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日 (E)" // 12月27日 (土)
        return formatter.string(from: date)
    }
    
    var body: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            Image(systemName: "calendar")
                .font(Tokens.Typography.sectionTitle())
                .foregroundStyle(Tokens.Color.accent)
            
            Text(dateString)
                .font(Tokens.Typography.sectionTitle())
                .foregroundStyle(Tokens.Color.textPrimary)
            
            Spacer()
        }
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
    }
}

struct EmptyDayView: View {
    var body: some View {
        AppText("予定/セッションがありません", style: .body, color: Tokens.Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct CalendarTopBar: View {
    let title: String
    let opacity: Double

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Tokens.Color.background)
            Rectangle()
                .fill(Tokens.Color.border)
                .frame(height: Tokens.Border.hairline)
                .frame(maxHeight: .infinity, alignment: .bottom)
            AppText(title, style: .sectionTitle, color: Tokens.Color.textPrimary)
                .opacity(opacity)
        }
        .frame(height: Tokens.Sizing.buttonHeight)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(edges: .top)
    }
}

private struct CalendarScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Helpers
