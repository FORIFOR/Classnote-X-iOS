import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var showLogoutConfirm = false

    var body: some View {
        List {
            // Account section
            accountSection
            
            // Appearance section
            appearanceSection
            
            // About section
            aboutSection
            
            // Logout
            logoutSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("設定")
        .confirmationDialog(
            "ログアウトしますか？",
            isPresented: $showLogoutConfirm,
            titleVisibility: .visible
        ) {
            Button("ログアウト", role: .destructive) {
                triggerHaptic(.warning)
                model.signOut()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("録音データはローカルに保持されます")
        }
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        Section {
            HStack(spacing: 14) {
                // Avatar placeholder
                ZStack {
                    Circle()
                        .fill(AppColors.heroGradient)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.userEmail.isEmpty ? "ゲスト" : model.userEmail)
                        .font(.headline)
                    
                    Text("Google アカウントでログイン中")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Appearance Section
    
    private var appearanceSection: some View {
        Section {
            HStack(spacing: 12) {
                settingIcon(icon: "paintpalette.fill", color: AppColors.primaryIndigo)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("外観")
                        .font(.body)
                    
                    Picker("外観", selection: $model.colorScheme) {
                        ForEach(ColorSchemeSetting.allCases) { scheme in
                            Text(label(for: scheme)).tag(scheme)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("外観")
        }
    }
    
    // MARK: - Backend Section
    
    private var backendSection: some View {
        Section {
            HStack(spacing: 12) {
                settingIcon(icon: "server.rack", color: AppColors.primaryTeal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("バックエンドURL")
                        .font(.body)
                    
                    TextField("http://127.0.0.1:8000", text: $model.baseURLString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(.tertiarySystemBackground))
                        )
                }
            }
            .padding(.vertical, 4)
            
            HStack(spacing: 12) {
                settingIcon(icon: "cpu", color: .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("LLM接続")
                        .font(.body)
                    
                    Text("Ollama等ローカルLLMへのHTTP接続を利用")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("接続")
        } footer: {
            Text("現在の接続先: \(model.baseURLString)")
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section {
            NavigationLink {
                HelpView()
            } label: {
                HStack(spacing: 12) {
                    settingIcon(icon: "questionmark.circle.fill", color: AppColors.primaryBlue)
                    Text("ヘルプ")
                }
            }
            
            HStack(spacing: 12) {
                settingIcon(icon: "info.circle.fill", color: .gray)
                Text("バージョン")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("情報")
        }
    }
    
    // MARK: - Logout Section
    
    private var logoutSection: some View {
        Section {
            Button {
                showLogoutConfirm = true
            } label: {
                HStack(spacing: 12) {
                    settingIcon(icon: "rectangle.portrait.and.arrow.forward", color: AppColors.danger)
                    Text("ログアウト")
                        .foregroundStyle(AppColors.danger)
                }
            }
        }
    }
    
    // MARK: - Components
    
    private func settingIcon(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.body)
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color)
            )
    }

    private func label(for scheme: ColorSchemeSetting) -> String {
        switch scheme {
        case .light: return "ライト"
        case .dark: return "ダーク"
        case .system: return "自動"
        }
    }
}
