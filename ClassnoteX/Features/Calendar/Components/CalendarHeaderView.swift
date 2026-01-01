import SwiftUI

struct CalendarHeaderView: View {
    let onEdit: () -> Void
    let onAnalytics: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                // Edit Button
                Button(action: onEdit) {
                    Text("編集")
                        .font(Tokens.Typography.button())
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .padding(.horizontal, Tokens.Spacing.md)
                        .padding(.vertical, Tokens.Spacing.xs)
                        .frame(height: Tokens.Sizing.buttonCompactHeight)
                        .background(Tokens.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                        )
                }
                
                // Title
                Text("カレンダー")
                    .font(Tokens.Typography.screenTitle())
                    .foregroundStyle(Tokens.Color.textPrimary)
            }
            
            Spacer()
            
            // Analytics Button
            Button(action: onAnalytics) {
                Image(systemName: "chart.bar.fill")
                    .font(Tokens.Typography.iconMedium())
                    .foregroundStyle(Tokens.Color.accent)
                    .frame(width: Tokens.Sizing.iconButton, height: Tokens.Sizing.iconButton)
                    .background(Tokens.Color.surface)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                    )
            }
        }
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
    }
}
