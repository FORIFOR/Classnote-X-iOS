import SwiftUI

// MARK: - Session Tag Chip View

struct SessionTagChip: View {
    let tag: SessionTag
    let isEditing: Bool
    var onDelete: (() -> Void)?
    var onTap: (() -> Void)?
    
    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 4) {
                Text("#\(tag.text)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(GlassNotebook.Accent.primary)
                
                if isEditing {
                    Button {
                        onDelete?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(GlassNotebook.Accent.primary.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session Tags Row (Horizontal Scroll)

struct SessionTagsRow: View {
    let tags: [SessionTag]
    let maxTags: Int
    var onTagTap: ((SessionTag) -> Void)?
    
    init(tags: [SessionTag], maxTags: Int = 5, onTagTap: ((SessionTag) -> Void)? = nil) {
        self.tags = Array(tags.prefix(maxTags))
        self.maxTags = maxTags
        self.onTagTap = onTagTap
    }
    
    var body: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tags) { tag in
                        SessionTagChip(
                            tag: tag,
                            isEditing: false,
                            onTap: { onTagTap?(tag) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Session Tags Header (for Detail View)

struct SessionTagsHeader: View {
    let tags: [SessionTag]
    @State private var showEditor = false
    var onEdit: (() -> Void)?
    var onTagTap: ((SessionTag) -> Void)?
    
    var body: some View {
        if !tags.isEmpty || onEdit != nil {
            HStack(alignment: .center, spacing: 8) {
                // Tags
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags) { tag in
                            SessionTagChip(
                                tag: tag,
                                isEditing: false,
                                onTap: { onTagTap?(tag) }
                            )
                        }
                    }
                }
                
                // Edit button
                if let onEdit = onEdit {
                    Button {
                        onEdit()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("編集")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(GlassNotebook.Text.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(GlassNotebook.Background.elevated)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

// MARK: - Tag Editor Sheet

struct TagEditorSheet: View {
    @Binding var tags: [SessionTag]
    let suggestedTags: [SessionTag]
    @State private var newTagText: String = ""
    @Environment(\.dismiss) private var dismiss
    
    private let maxTagLength = 10
    
    var body: some View {
        NavigationStack {
            List {
                // Current Tags
                Section {
                    if tags.isEmpty {
                        Text("タグがありません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(tags) { tag in
                            HStack {
                                Text("#\(tag.text)")
                                    .foregroundStyle(GlassNotebook.Accent.primary)
                                
                                Spacer()
                                
                                if tag.isUserAdded {
                                    Text("手動追加")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                } else {
                                    HStack(spacing: 4) {
                                        Image(systemName: "sparkles")
                                            .font(.caption)
                                        Text("AI")
                                            .font(.caption)
                                    }
                                    .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            tags.remove(atOffsets: indexSet)
                        }
                    }
                } header: {
                    Text("現在のタグ")
                }
                
                // Add New Tag
                Section {
                    HStack {
                        TextField("新しいタグ（10文字以内）", text: $newTagText)
                            .onChange(of: newTagText) { _, newValue in
                                if newValue.count > maxTagLength {
                                    newTagText = String(newValue.prefix(maxTagLength))
                                }
                            }
                        
                        Button {
                            addNewTag()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(GlassNotebook.Accent.primary)
                        }
                        .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("タグを追加")
                } footer: {
                    Text("\(newTagText.count)/\(maxTagLength) 文字")
                }
                
                // AI Suggested Tags
                if !suggestedTags.isEmpty {
                    Section {
                        ForEach(suggestedTags.filter { suggested in
                            !tags.contains { $0.text == suggested.text }
                        }) { suggested in
                            Button {
                                addSuggestedTag(suggested)
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.orange)
                                    Text("#\(suggested.text)")
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    if let score = suggested.score {
                                        Text("\(Int(score * 100))%")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(GlassNotebook.Accent.primary)
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("AIが提案するタグ")
                        }
                    }
                }
            }
            .navigationTitle("タグを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func addNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !tags.contains(where: { $0.text == trimmed }) else { return }
        
        let newTag = SessionTag(text: trimmed, isUserAdded: true)
        tags.append(newTag)
        newTagText = ""
    }
    
    private func addSuggestedTag(_ suggested: SessionTag) {
        guard !tags.contains(where: { $0.text == suggested.text }) else { return }
        tags.append(suggested)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        SessionTagsRow(
            tags: [
                SessionTag(text: "AI倫理"),
                SessionTag(text: "公平性"),
                SessionTag(text: "バイアス"),
                SessionTag(text: "大学講義"),
                SessionTag(text: "試験範囲")
            ]
        )
        
        SessionTagsHeader(
            tags: [
                SessionTag(text: "AI倫理"),
                SessionTag(text: "公平性")
            ],
            onEdit: {}
        )
    }
    .padding()
    .background(GlassNotebook.Background.primary)
}
