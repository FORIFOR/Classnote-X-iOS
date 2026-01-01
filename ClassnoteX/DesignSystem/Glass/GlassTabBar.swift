import SwiftUI

enum TabItem: String, CaseIterable {
    case home
    case sessions
    case calendar
    case settings

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .sessions: return "doc.text.fill"
        case .calendar: return "calendar"
        case .settings: return "gearshape.fill"
        }
    }

    var label: String {
        switch self {
        case .home: return "ホーム"
        case .sessions: return "セッション"
        case .calendar: return "カレンダー"
        case .settings: return "設定"
        }
    }
}

struct GlassTabBar: View {
    @Binding var activeTab: TabItem
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        activeTab = tab
                    }
                } label: {
                    VStack(spacing: Tokens.Spacing.xxs) {
                        Image(systemName: tab.icon)
                            .font(Tokens.Typography.headline())
                        
                        Text(tab.label)
                            // Use strict Tab Label font
                            .font(Tokens.Typography.tabLabel())
                    }
                    .foregroundColor(activeTab == tab ? Tokens.Color.textPrimary : Tokens.Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Tokens.Spacing.tabBarHeight - Tokens.Spacing.sm)
                    .background(
                        ZStack {
                            if activeTab == tab {
                                RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                                    .fill(Tokens.Color.surface)
                                    .frame(width: Tokens.Sizing.tabHighlightWidth, height: Tokens.Sizing.tabHighlightHeight)
                                    .matchedGeometryEffect(id: "TabBg", in: namespace)
                            }
                        }
                    )
                }
            }
        }
        .padding(.horizontal, Tokens.Spacing.xxs)
        .padding(.vertical, Tokens.Spacing.xxs)
        .background(GlassChrome())
        .frame(height: Tokens.Spacing.tabBarHeight)
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
    }
    
    @Namespace private var namespace
}
