import SwiftUI

struct LegacySearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(Tokens.Typography.subheadline())
                .foregroundStyle(Tokens.Color.textSecondary)
            
            TextField("タイトルで検索", text: $text)
                .font(Tokens.Typography.body())
                .foregroundStyle(Tokens.Color.textPrimary)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
            }
        }
        .padding(.horizontal, Tokens.Spacing.md)
        .frame(height: Tokens.Sizing.buttonCompactHeight)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
        )
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
    }
}
