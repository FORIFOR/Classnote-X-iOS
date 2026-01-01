import SwiftUI

struct CalendarStatsRow: View {
    let sessionCount: Int
    let audioCount: Int
    let showDelete: Bool
    let onDeleteMonth: () -> Void
    
    // Spec: "3件" (blue), "音声 0件" (gray if 0)
    
    var body: some View {
        HStack {
            // Stats
            HStack(spacing: Tokens.Spacing.lg) {
                HStack(spacing: Tokens.Spacing.xs) {
                    Image(systemName: "doc.text.fill")
                        .font(Tokens.Typography.subheadline())
                        .foregroundStyle(Tokens.Color.accent)
                    Text("\(sessionCount)件")
                        .font(Tokens.Typography.subheadline())
                        .foregroundStyle(Tokens.Color.accent)
                }
                
                HStack(spacing: Tokens.Spacing.xs) {
                    Image(systemName: "waveform")
                        .font(Tokens.Typography.subheadline())
                        .foregroundStyle(audioCount > 0 ? Tokens.Color.accent : Tokens.Color.textSecondary)
                    Text("音声 \(audioCount)件")
                        .font(Tokens.Typography.subheadline())
                        .foregroundStyle(audioCount > 0 ? Tokens.Color.accent : Tokens.Color.textSecondary)
                }
            }
            
            Spacer()
            
            if showDelete {
                Button(action: onDeleteMonth) {
                    HStack(spacing: Tokens.Spacing.xxs) {
                        Image(systemName: "trash")
                            .font(Tokens.Typography.caption())
                        Text("この月を削除")
                            .font(Tokens.Typography.caption())
                    }
                    .foregroundStyle(Tokens.Color.destructive)
                    .padding(.horizontal, Tokens.Spacing.sm)
                    .frame(height: Tokens.Sizing.buttonCompactHeight)
                    .background(Tokens.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                            .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                    )
                }
                .buttonStyle(.plain)
            }
            // Spec says "right".
        }
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
    }
}

struct FilterSegmentControl: View {
    @Binding var selection: CalendarViewModel.CalendarFilter
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(CalendarViewModel.CalendarFilter.allCases) { filter in
                Button(action: {
                    withAnimation(.snappy(duration: 0.2)) {
                        selection = filter
                    }
                }) {
                    Text(filter.rawValue)
                        .font(Tokens.Typography.subheadline())
                        .foregroundStyle(selection == filter ? Tokens.Color.textPrimary : Tokens.Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: Tokens.Sizing.buttonCompactHeight)
                        .background(
                            ZStack {
                                if selection == filter {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(Tokens.Color.surface)
                                        .padding(Tokens.Spacing.xxs)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: Tokens.Sizing.buttonHeight)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
        )
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
    }
}
