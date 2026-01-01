import SwiftUI

struct BrandHeader: View {
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMM d" // SATURDAY, DEC 27
        return formatter.string(from: Date()).uppercased()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
            // DeepNote
            HStack(spacing: 0) {
                Text("Deep")
                    .font(Tokens.Typography.brandTitle())
                    .foregroundStyle(Tokens.Color.textPrimary) // Near black
                
                Text("Note")
                    .font(Tokens.Typography.brandTitle())
                    .foregroundStyle(Tokens.Gradients.brandX) // Gradient accent
            }
            
            // Date
            Text(dateString)
                .font(Tokens.Typography.brandDate())
                .tracking(1)
                .foregroundStyle(Tokens.Color.textSecondary)
        }
    }
}
