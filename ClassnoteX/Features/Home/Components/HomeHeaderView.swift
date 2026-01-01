import SwiftUI

struct HomeHeaderView: View {
    let onProfileTap: () -> Void
    let onSearchTap: () -> Void
    @State private var currentDate = Date()

    var body: some View {
        HStack {
            // Profile button
            Button(action: {
                Haptics.light()
                onProfileTap()
            }) {
                Circle()
                    .fill(Tokens.Color.surface)
                    .frame(width: Tokens.Sizing.iconButton, height: Tokens.Sizing.iconButton)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Tokens.Color.textSecondary)
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            // Date/Title
            VStack(spacing: 2) {
                Text(dayLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Tokens.Color.textSecondary)
                Text(dateLabel)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Tokens.Color.textPrimary)
            }

            Spacer()

            // Search button
            Button(action: {
                Haptics.light()
                onSearchTap()
            }) {
                Circle()
                    .fill(Tokens.Color.surface)
                    .frame(width: Tokens.Sizing.iconButton, height: Tokens.Sizing.iconButton)
                    .overlay(
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Tokens.Color.textSecondary)
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
    }

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")

        let calendar = Calendar.current
        if calendar.isDateInToday(currentDate) {
            return "今日"
        } else if calendar.isDateInYesterday(currentDate) {
            return "昨日"
        } else {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: currentDate)
        }
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: currentDate)
    }
}
