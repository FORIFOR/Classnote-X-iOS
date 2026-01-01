import SwiftUI

// MARK: - Search Bar

/// A pill-shaped search field matching the specification design
struct SearchPill: View {
    @Binding var text: String
    let placeholder: String
    var onSubmit: (() -> Void)?

    init(
        text: Binding<String>,
        placeholder: String = "検索",
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(Tokens.Typography.subheadline())
                .foregroundStyle(Tokens.Color.textSecondary)

            TextField(placeholder, text: $text)
                .font(Tokens.Typography.body())
                .foregroundStyle(Tokens.Color.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit {
                    onSubmit?()
                }

            if !text.isEmpty {
                Button {
                    text = ""
                    Haptics.light()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(Tokens.Typography.subheadline())
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Tokens.Spacing.md)
        .padding(.vertical, Tokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                .fill(Tokens.Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
        )
    }
}

// MARK: - Inline Search Field

/// A more compact search field for headers
struct InlineSearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(Tokens.Typography.caption())
                .foregroundStyle(Tokens.Color.textSecondary)

            TextField("検索", text: $text)
                .font(Tokens.Typography.caption())
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Tokens.Spacing.sm)
        .padding(.vertical, Tokens.Spacing.xs)
        .background(
            Capsule().fill(Tokens.Color.surface)
        )
        .overlay(
            Capsule()
                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
        )
    }
}

// MARK: - Preview
