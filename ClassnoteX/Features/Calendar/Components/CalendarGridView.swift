import SwiftUI

struct LegacyCalendarGridView: View {
    @ObservedObject var viewModel: CalendarViewModel
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    let weeks = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Row
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(weeks, id: \.self) { week in
                    Text(week)
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .frame(height: Tokens.Sizing.buttonCompactHeight)
                }
            }
            .padding(.bottom, Tokens.Spacing.xs)
            
            // Days Grid
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(viewModel.days) { day in
                    CalendarDayCell(
                        day: day,
                        isSelected: Calendar.current.isDate(day.date, inSameDayAs: viewModel.selectedDate)
                    )
                    .onTapGesture {
                        if day.isCurrentMonth {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.selectDate(day.date)
                            }
                        }
                    }
                }
            }
        }
        .padding(Tokens.Spacing.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
        )
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
    }
}

struct CalendarDayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    // Spec: "cell height: 54~58pt"
    // "selection: 黒丸 diameter 44pt"
    
    var body: some View {
        let badgeTextColor = colorScheme == .dark ? Tokens.Color.textPrimary : Tokens.Color.surface
        VStack(spacing: 0) {
            if day.isCurrentMonth {
                ZStack {
                    // Selection Circle
                    if isSelected {
                        Circle()
                            .fill(Tokens.Color.textPrimary)
                            .frame(width: 44, height: 44)
                            .matchedGeometryEffect(id: "SelectionCircle", in: namespace)
                    }
                    
                    // Number
                    Text("\(Calendar.current.component(.day, from: day.date))")
                        .font(Tokens.Typography.subtitle())
                        .foregroundStyle(isSelected ? Tokens.Color.surface : Tokens.Color.textPrimary)
                    
                    // Blue Badge (Session Count)
                    // Spec: "左上寄り" or numeric badge.
                    // "1" badge implies top-leading.
                    if day.count > 0 {
                        VStack {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Tokens.Color.accent)
                                        .frame(width: 22, height: 22)
                                    Text("\(day.count)")
                                        .font(Tokens.Typography.caption())
                                        .foregroundStyle(badgeTextColor)
                                }
                                .offset(x: -6, y: -6)
                                Spacer()
                            }
                            Spacer()
                        }
                        .frame(width: 44, height: 44)
                    }
                    
                    // Orange Marker (Audio/Status)
                    // Spec: "数字の下, セル下部中央"
                    if day.hasMarker {
                        VStack(spacing: 0) {
                            Spacer()
                            Circle()
                                .fill(Tokens.Color.meetingAccent)
                                .frame(width: Tokens.Spacing.xxs, height: Tokens.Spacing.xxs)
                                .offset(y: 16) // Push down below number
                        }
                        .frame(height: 44)
                    }
                }
                .frame(width: 50, height: 50) // Cell content size
                .contentShape(Rectangle())
            } else {
                // Padding/Transparent for non-current month
                Color.clear
                    .frame(width: 50, height: 50)
            }
        }
        .frame(height: 56) // Cell height fixed
    }
    
    // Namespace for smooth selection animation? Global namespace might be needed or just fade.
    @Namespace private var namespace
}
