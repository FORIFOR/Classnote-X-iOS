import SwiftUI

enum DADSFieldStyle {
    case rounded
    case pill
}

struct DADSTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String?
    let isSecure: Bool
    let style: DADSFieldStyle
    let onSubmit: (() -> Void)?

    init(
        text: Binding<String>,
        placeholder: String,
        icon: String? = nil,
        isSecure: Bool = false,
        style: DADSFieldStyle = .rounded,
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.isSecure = isSecure
        self.style = style
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(Tokens.Typography.subheadline())
                    .foregroundStyle(Tokens.Color.textSecondary)
            }

            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(Tokens.Typography.body())
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .submitLabel(.done)
                    .onSubmit { onSubmit?() }
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(Tokens.Typography.body())
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .submitLabel(.done)
                    .onSubmit { onSubmit?() }
            }
        }
        .padding(.horizontal, Tokens.Spacing.sm)
        .padding(.vertical, Tokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Tokens.Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
        )
    }

    private var cornerRadius: CGFloat {
        switch style {
        case .rounded:
            return Tokens.Radius.small
        case .pill:
            return Tokens.Radius.pill
        }
    }
}
