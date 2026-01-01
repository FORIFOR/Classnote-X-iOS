import SwiftUI

struct MonthControlView: View {
    let currentMonth: Date
    let isCurrentMonthToday: Bool
    let onPrev: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: currentMonth)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Prev button (minimal design)
            Button(action: onPrev) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Tokens.Color.surface)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            // Month label
            Text(monthLabel)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Tokens.Color.textPrimary)

            // Next button
            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Tokens.Color.surface)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()

            // Today button (only show if not in current month)
            if !isCurrentMonthToday {
                Button(action: onToday) {
                    Text("今日")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tokens.Color.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Tokens.Color.accent.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
    }
}
