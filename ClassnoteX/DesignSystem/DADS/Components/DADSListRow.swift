import SwiftUI

struct DADSListRow<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let leading: Leading
    let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            leading

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DADS.Typography.body())
                    .foregroundStyle(DADS.Colors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(DADS.Typography.caption())
                        .foregroundStyle(DADS.Colors.textSecondary)
                }
            }

            Spacer(minLength: 8)
            trailing
        }
        .padding(DADS.Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DADS.Radius.card, style: .continuous)
                .fill(DADS.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DADS.Radius.card, style: .continuous)
                .stroke(DADS.Colors.border, lineWidth: 1)
        )
    }
}
