import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        TabView(selection: $model.selectedTab) {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house.fill") }
                .tag(0)

            NavigationStack { SessionsView() }
                .tabItem { Label("セッション", systemImage: "list.bullet.rectangle") }
                .tag(1)

            NavigationStack { CalendarView() }
                .tabItem { Label("カレンダー", systemImage: "calendar") }
                .tag(2)

            NavigationStack { SettingsView() }
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
                .tag(3)
        }
        // タブバー背景色調整（ライトモードでの視認性向上）
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundColor = UIColor.systemBackground
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
