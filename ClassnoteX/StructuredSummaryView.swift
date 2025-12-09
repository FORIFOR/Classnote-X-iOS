import SwiftUI

// MARK: - Structured Summary View

/// A view that parses structured summary text (with 【Headers】 and * lists)
/// and effectively renders it as a series of styled cards.
struct StructuredSummaryView: View {
    let text: String
    
    // Parsed sections
    private var sections: [SummarySection] {
        parseSummaryText(text)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ForEach(sections) { section in
                SummarySectionCard(section: section)
            }
        }
    }
    
    // MARK: - Parsing Logic
    
    struct SummarySection: Identifiable {
        let id = UUID()
        let title: String
        let items: [SummaryItem]
    }
    
    struct SummaryItem: Identifiable {
        let id = UUID()
        let text: String
        let indentLevel: Int // 0 for strict root, 1 for nested
        let isBold: Bool
    }
    
    private func parseSummaryText(_ text: String) -> [SummarySection] {
        var sections: [SummarySection] = []
        var currentSectionTitle: String? = nil
        var currentItems: [SummaryItem] = []
        
        // Helper to commit current section
        func commitSection() {
            if let title = currentSectionTitle, !currentItems.isEmpty {
                sections.append(SummarySection(title: title, items: currentItems))
            } else if currentSectionTitle == nil && !currentItems.isEmpty {
                // Content before any header (e.g. general summary)
                sections.append(SummarySection(title: "概要", items: currentItems))
            }
            currentItems = []
        }
        
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            // Detect Section Header: 【Title】
            if trimmed.hasPrefix("【") && trimmed.hasSuffix("】") {
                commitSection()
                currentSectionTitle = String(trimmed.dropFirst().dropLast())
                continue
            }
            
            // Detect List Items: * Item or - Item
            if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") {
                let content = String(trimmed.dropFirst(2))
                // Calculate simple indent based on leading spaces in original line
                let leadingSpaces = line.prefix(while: { $0 == " " }).count
                let indent = leadingSpaces / 2 // Simple assumption: 2 spaces = 1 indent
                
                currentItems.append(SummaryItem(
                    text: content,
                    indentLevel: indent,
                    isBold: false
                ))
            }
            // Detect Nested List Items (indented in original text)
            else if let match = line.range(of: "^\\s+[*|-] ", options: .regularExpression) {
                let leadingSpaces = line.distance(from: line.startIndex, to: match.lowerBound)
                let indent = (leadingSpaces / 2) + 1 // Base(1) + spaces
                
                let contentStart = line.index(match.lowerBound, offsetBy: leadingSpaces + 2) // skip spaces + "* "
                let content = String(line[contentStart...])
                
                currentItems.append(SummaryItem(
                    text: content,
                    indentLevel: indent,
                    isBold: false
                ))
            }
            // Detect Key-Value or Bold lines (e.g., "Account Auth:")
            else if trimmed.hasSuffix(":") {
                 currentItems.append(SummaryItem(
                    text: trimmed,
                    indentLevel: 0,
                    isBold: true
                ))
            }
            // Plain text (treat as level 0 item)
            else {
                // If previous item was bold (header-like), treat this as nested? No, keep simple
                currentItems.append(SummaryItem(
                    text: trimmed,
                    indentLevel: 0,
                    isBold: false
                ))
            }
        }
        
        commitSection() // Commit last section
        
        return sections
    }
}

// MARK: - Section Card

struct SummarySectionCard: View {
    let section: StructuredSummaryView.SummarySection
    
    var sectionColor: Color {
        switch section.title {
        case "決定事項": return GlassNotebook.Accent.lecture // Green
        case "TODO": return Color.orange
        case "論点の流れ": return GlassNotebook.Accent.meeting // Purple
        case "会議議事録要約": return GlassNotebook.Accent.primary // Blue
        default: return GlassNotebook.Accent.primary
        }
    }
    
    var sectionIcon: String {
        switch section.title {
        case "決定事項": return "checkmark.circle.fill"
        case "TODO": return "list.bullet.clipboard.fill"
        case "論点の流れ": return "arrow.turn.down.right"
        default: return "doc.text.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: sectionIcon)
                    .font(.headline)
                    .foregroundStyle(sectionColor)
                
                Text(section.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(16)
            .background(sectionColor.opacity(0.1))
            
            Divider()
                .overlay(sectionColor.opacity(0.2))
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                ForEach(section.items) { item in
                    HStack(alignment: .top, spacing: 8) {
                        // Bullet point or Spacer based on indent
                        if item.indentLevel > 0 {
                            Spacer()
                                .frame(width: CGFloat(item.indentLevel * 12)) // Indent
                            
                            Circle()
                                .fill(sectionColor.opacity(0.6))
                                .frame(width: 4, height: 4)
                                .padding(.top, 8)
                        } else if item.isBold {
                            // No bullet for bold headers
                        } else {
                            Circle()
                                .fill(sectionColor)
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)
                        }
                        
                        Text(parseMarkdownBold(item.text))
                            .font(.body)
                            .fontWeight(item.isBold ? .bold : .regular)
                            .foregroundStyle(.primary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    // Simple helper to remove **markers** for display (SwiftUI Text supports markdown but we want clean text if mixed)
    // Actually Text(markdown:) works well, so we return LocalizedStringKey
    func parseMarkdownBold(_ text: String) -> LocalizedStringKey {
        return LocalizedStringKey(text)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        GlassNotebook.Background.primary.ignoresSafeArea()
        ScrollView {
            StructuredSummaryView(text: """
            【会議議事録要約】
            会議名: プロジェクト定例
            日時: 2024/12/09

            【決定事項】
            * アカウント認証方法の検討:
              * Googleアカウント、Apple IDでのログインを実装する。
              * LINE認証の導入を検討する。
            * アプリの機能実装優先順位:
              * 最優先: 時間割機能

            【TODO】
            * アカウント認証:
              * LINE認証の実現可能性調査
            * アプリ機能:
              * 時間割機能の開発

            【論点の流れ】
            1. アカウント重複問題と認証方法の検討:
               * 現状、メールアドレスのみでは重複アカウントが発生しやすい。
               * 施策としてLINE認証などが挙がった。
            """)
            .padding()
        }
    }
}
