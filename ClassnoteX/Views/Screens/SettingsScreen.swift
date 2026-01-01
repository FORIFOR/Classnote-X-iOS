import SwiftUI
import UIKit
import FirebaseAuth

struct SettingsScreen: View {
    @State private var user: User?
    @State private var showUsernameSetup = false
    @State private var showLogoutConfirm = false
    @State private var isLoadingUser = false
    @State private var scrollOffset: CGFloat = 0
    @State private var showJoinByCode = false
    @State private var myShareCode: String?
    @State private var isFetchingShareCode = false
    @State private var shareCodeMessage: String?
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue
    
    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            SettingsTokens.bgPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    largeTitle

                    sectionHeader("アカウント")
                    accountCard

                    shareCodeCard
                        .padding(.top, Tokens.Spacing.sm)

                    if let shareCodeMessage {
                        Text(shareCodeMessage)
                            .font(Tokens.Typography.caption())
                            .foregroundColor(SettingsTokens.textSecondary)
                            .padding(.top, Tokens.Spacing.xs)
                    }

                    joinByCodeCard
                        .padding(.top, Tokens.Spacing.sm)

                    sectionHeader("連携")
                    integrationsCard

                    sectionHeader("表示")
                    appearanceCard

                    sectionHeader("情報")
                    infoCard

                    logoutCard
                        .padding(.top, Tokens.Spacing.md)
                }
                .padding(.horizontal, SettingsTokens.screenPadding)
                .padding(.bottom, Tokens.Spacing.tabBarHeight)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: SettingsScrollOffsetKey.self,
                            value: proxy.frame(in: .named("settingsScroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "settingsScroll")
            .onPreferenceChange(SettingsScrollOffsetKey.self) { value in
                scrollOffset = value
            }

            topBar
        }
        .onAppear {
            Task { await loadUser() }
        }
        .fullScreenCover(isPresented: $showUsernameSetup) {
            UsernameSetupView { updatedUser in
                user = updatedUser
                showUsernameSetup = false
            }
        }
        .confirmationDialog(
            "ログアウトしますか？",
            isPresented: $showLogoutConfirm,
            titleVisibility: .visible
        ) {
            Button("ログアウト", role: .destructive) {
                try? Auth.auth().signOut()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この端末からサインアウトします。")
        }
        .sheet(isPresented: $showJoinByCode) {
            JoinByCodeSheet()
        }
    }
    
    private var accountCard: some View {
        Button {
            Haptics.light()
            if user?.username == nil {
                showUsernameSetup = true
            }
        } label: {
            SettingsCard {
                HStack(spacing: Tokens.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(SettingsTokens.separator)
                            .frame(width: Tokens.Sizing.avatar, height: Tokens.Sizing.avatar)
                        Text(initialLetter)
                            .font(Tokens.Typography.headline())
                            .foregroundColor(SettingsTokens.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
                        Text(providerLabel)
                            .font(Tokens.Typography.caption())
                            .foregroundColor(SettingsTokens.textSecondary)
                            .padding(.horizontal, Tokens.Spacing.xs)
                            .padding(.vertical, Tokens.Spacing.xxs)
                            .background(SettingsTokens.separator)
                            .clipShape(Capsule())

                        Text(user?.email ?? "—")
                            .font(Tokens.Typography.body())
                            .foregroundColor(SettingsTokens.textPrimary)
                            .lineLimit(1)

                        if let username = user?.username, !username.isEmpty {
                            Text("@\(username)")
                                .font(Tokens.Typography.caption())
                                .foregroundColor(SettingsTokens.textSecondary)
                                .lineLimit(1)
                        } else {
                            Text("ユーザー名未設定")
                                .font(Tokens.Typography.caption())
                                .foregroundColor(SettingsTokens.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(Tokens.Typography.caption())
                        .foregroundColor(SettingsTokens.iconGray)
                }
                .padding(.vertical, SettingsTokens.cardInnerPaddingV)
                .padding(.horizontal, SettingsTokens.cardInnerPaddingH)
                .redacted(reason: isLoadingUser ? .placeholder : [])
            }
        }
        .buttonStyle(.plain)
    }

    private var shareCodeCard: some View {
        Button {
            if let myShareCode {
                UIPasteboard.general.string = myShareCode
                Haptics.success()
                shareCodeMessage = "コピーしました"
            } else {
                fetchMyShareCode()
            }
        } label: {
            SettingsCard {
                SettingsRow(
                    title: "共有コード",
                    icon: "qrcode",
                    iconBackground: Color(red: 0.55, green: 0.35, blue: 0.85), // Purple
                    trailing: {
                        if isFetchingShareCode {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if let myShareCode {
                            HStack(spacing: 6) {
                                Text(myShareCode)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(SettingsTokens.textPrimary)
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12))
                                    .foregroundColor(SettingsTokens.linkBlue)
                            }
                        } else {
                            Text("タップして取得")
                                .font(.system(size: 13))
                                .foregroundColor(SettingsTokens.linkBlue)
                        }
                    },
                    showsChevron: false
                )
            }
        }
        .buttonStyle(.plain)
    }
    
    private var integrationsCard: some View {
        SettingsCard {
            VStack(spacing: 0) {
                Button {
                    Haptics.light()
                } label: {
                    SettingsRow(
                        title: "Googleカレンダー",
                        icon: "calendar",
                        iconBackground: Color(red: 0.26, green: 0.52, blue: 0.96), // Google Blue
                        trailing: {
                            // TODO: Check actual integration status
                            Text("未連携")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(SettingsTokens.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(SettingsTokens.separator.opacity(0.5))
                                .clipShape(Capsule())
                        }
                    )
                }
                .buttonStyle(.plain)

                SettingsSeparator()

                Button {
                    Haptics.light()
                } label: {
                    SettingsRow(
                        title: "プラン",
                        icon: "creditcard.fill",
                        iconBackground: Color(red: 0.2, green: 0.78, blue: 0.35), // Green
                        trailing: {
                            Text(user?.plan ?? "Free")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(red: 0.2, green: 0.78, blue: 0.35))
                                .clipShape(Capsule())
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var appearanceCard: some View {
        SettingsCard {
            Menu {
                ForEach(AppearanceMode.allCases) { mode in
                    Button(mode.title) {
                        appearanceModeRaw = mode.rawValue
                    }
                }
            } label: {
                SettingsRow(
                    title: "外観モード",
                    icon: "paintpalette.fill",
                    iconBackground: SettingsTokens.appearancePurple,
                    trailing: {
                        HStack(spacing: Tokens.Spacing.xxs) {
                            Text(appearanceMode.title)
                                .font(Tokens.Typography.subheadline())
                                .foregroundColor(SettingsTokens.linkBlue)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(Tokens.Typography.caption())
                                .foregroundColor(SettingsTokens.iconGray)
                        }
                    },
                    showsChevron: false
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var infoCard: some View {
        SettingsCard {
            VStack(spacing: 0) {
                Button {
                    Haptics.light()
                } label: {
                    SettingsRow(
                        title: "ヘルプ",
                        icon: "questionmark",
                        iconBackground: SettingsTokens.linkBlue
                    )
                }
                .buttonStyle(.plain)

                SettingsSeparator()

                SettingsRow(
                    title: "バージョン",
                    icon: "info",
                    iconBackground: SettingsTokens.iconGray,
                    trailing: {
                        Text(appVersion)
                            .font(.subheadline)
                            .foregroundColor(SettingsTokens.textSecondary)
                    },
                    showsChevron: false
                )
            }
        }
    }
    
    private var logoutCard: some View {
        Button {
            Haptics.medium()
            showLogoutConfirm = true
        } label: {
            Text("ログアウト")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(SettingsTokens.destructiveRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Tokens.Spacing.md)
        }
        .buttonStyle(.plain)
    }

    private var joinByCodeCard: some View {
        Button {
            Haptics.light()
            showJoinByCode = true
        } label: {
            SettingsCard {
                SettingsRow(
                    title: "共有リンクで参加",
                    icon: "person.badge.plus",
                    iconBackground: SettingsTokens.linkBlue
                )
            }
        }
        .buttonStyle(.plain)
    }
    
    private var providerLabel: String {
        switch user?.provider {
        case .google: return "Google"
        case .apple: return "Apple"
        case .line: return "LINE"
        case .none: return "Account"
        }
    }

    private var initialLetter: String {
        guard let user else { return "—" }
        return user.initial
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    
    private func loadUser() async {
        isLoadingUser = true
        do {
            user = try await APIClient.shared.getMe()
        } catch {
            print("Failed to load user: \(error)")
        }
        isLoadingUser = false
    }

    private func fetchMyShareCode() {
        guard !isFetchingShareCode else { return }
        isFetchingShareCode = true
        shareCodeMessage = nil
        Task {
            do {
                let response = try await APIClient.shared.createOrRefreshShareCode()
                await MainActor.run {
                    myShareCode = response.shareCode
                    shareCodeMessage = "共有コードを取得しました"
                }
            } catch let error as APIError {
                await MainActor.run {
                    shareCodeMessage = error.errorDescription ?? "共有コードの取得に失敗しました"
                }
                print("[SettingsScreen] fetchMyShareCode error: \(error)")
            } catch {
                await MainActor.run {
                    shareCodeMessage = "共有コードの取得に失敗しました"
                }
                print("[SettingsScreen] fetchMyShareCode unexpected error: \(error)")
            }
            await MainActor.run {
                isFetchingShareCode = false
            }
        }
    }
}

private enum SettingsTokens {
    static let bgPrimary = Tokens.Color.background
    static let cardBackground = Tokens.Color.surface
    static let separator = Tokens.Color.border
    static let textPrimary = Tokens.Color.textPrimary
    static let textSecondary = Tokens.Color.textSecondary
    static let linkBlue = Tokens.Color.accent
    static let destructiveRed = Tokens.Color.destructive
    static let iconGray = Tokens.Color.textSecondary
    static let appearancePurple = Tokens.Color.accent
    static let planGreen = Tokens.Color.accent

    static let screenPadding: CGFloat = Tokens.Spacing.screenHorizontal
    static let sectionHeaderLeft: CGFloat = Tokens.Spacing.lg
    static let cardRadius: CGFloat = Tokens.Radius.card
    static let rowHeight: CGFloat = Tokens.Sizing.buttonHeight + Tokens.Spacing.xs
    static let cardInnerPaddingH: CGFloat = Tokens.Spacing.md
    static let cardInnerPaddingV: CGFloat = Tokens.Spacing.sm
    static let separatorInset: CGFloat = Tokens.Spacing.md + Tokens.Sizing.iconButton + Tokens.Spacing.sm
}

private struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SettingsTokens.cardBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

private struct SettingsRow<Trailing: View>: View {
    let title: String
    let icon: String
    let iconBackground: Color
    let titleColor: Color
    let showsChevron: Bool
    let trailing: Trailing

    init(
        title: String,
        icon: String,
        iconBackground: Color,
        titleColor: Color = SettingsTokens.textPrimary,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        showsChevron: Bool = true
    ) {
        self.title = title
        self.icon = icon
        self.iconBackground = iconBackground
        self.titleColor = titleColor
        self.trailing = trailing()
        self.showsChevron = showsChevron
    }

    var body: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous)
                .fill(iconBackground)
                .frame(width: Tokens.Sizing.iconButton, height: Tokens.Sizing.iconButton)
                .overlay(
                    Image(systemName: icon)
                        .font(Tokens.Typography.iconMedium())
                        .foregroundColor(Tokens.Color.surface)
                )

            Text(title)
                .font(Tokens.Typography.body())
                .foregroundColor(titleColor)

            Spacer()

            trailing

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(Tokens.Typography.caption())
                    .foregroundColor(SettingsTokens.iconGray)
            }
        }
        .frame(minHeight: SettingsTokens.rowHeight)
        .padding(.horizontal, SettingsTokens.cardInnerPaddingH)
        .contentShape(Rectangle())
    }
}

private struct SettingsSeparator: View {
    var body: some View {
        Rectangle()
            .fill(SettingsTokens.separator)
            .frame(height: 1)
            .padding(.leading, SettingsTokens.separatorInset)
    }
}

private extension SettingsScreen {
    var topBar: some View {
        ZStack {
            Rectangle()
                .fill(SettingsTokens.bgPrimary)
            Rectangle()
                .fill(SettingsTokens.separator)
                .frame(height: Tokens.Border.hairline)
                .frame(maxHeight: .infinity, alignment: .bottom)

            AppText("設定", style: .sectionTitle, color: SettingsTokens.textPrimary)
                .opacity(topBarTitleOpacity)
        }
        .frame(height: Tokens.Sizing.buttonHeight)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(edges: .top)
    }

    var largeTitle: some View {
        Text("設定")
            .font(Tokens.Typography.screenTitle())
            .foregroundColor(SettingsTokens.textPrimary)
            .padding(.top, Tokens.Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Tokens.Typography.caption())
            .foregroundColor(SettingsTokens.textSecondary)
            .padding(.top, Tokens.Spacing.md)
            .padding(.bottom, Tokens.Spacing.sm)
            .padding(.leading, SettingsTokens.sectionHeaderLeft - SettingsTokens.screenPadding)
    }

    var topBarTitleOpacity: Double {
        let offset = -scrollOffset
        let start: CGFloat = 16
        let end: CGFloat = 40
        if offset <= start { return 0 }
        if offset >= end { return 1 }
        return Double((offset - start) / (end - start))
    }
}

private struct SettingsScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct JoinByCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var shareCoordinator: ShareCoordinator
    @State private var code = ""
    @State private var message: String?
    @State private var isJoining = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                Text("共有リンクで参加")
                    .font(Tokens.Typography.sectionTitle())
                    .foregroundColor(SettingsTokens.textPrimary)

                Text("共有リンクのURL、または末尾のトークンを貼り付けて参加します。")
                    .font(Tokens.Typography.caption())
                    .foregroundColor(SettingsTokens.textSecondary)

                TextField("共有リンクのURL / トークン", text: $code)
                    .textInputAutocapitalization(.never)
                    .font(Tokens.Typography.body())
                    .foregroundColor(SettingsTokens.textPrimary)
                    .padding(Tokens.Spacing.sm)
                    .background(SettingsTokens.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous)
                            .stroke(SettingsTokens.separator, lineWidth: Tokens.Border.thin)
                    )

                if let message {
                    Text(message)
                        .font(Tokens.Typography.subheadline())
                        .foregroundColor(SettingsTokens.textSecondary)
                }

                Button {
                    joinByCode()
                } label: {
                    Text("参加する")
                        .font(Tokens.Typography.button())
                        .foregroundColor(Tokens.Color.surface)
                        .frame(maxWidth: .infinity)
                        .frame(height: Tokens.Sizing.buttonCompactHeight)
                        .background(SettingsTokens.linkBlue)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
                }
                .disabled(isJoining || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding(Tokens.Spacing.md)
            .navigationTitle("参加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func joinByCode() {
        guard !isJoining else { return }
        isJoining = true
        message = nil
        shareCoordinator.errorMessage = nil
        Task {
            await shareCoordinator.joinSessionByCode(code)
            await MainActor.run {
                if shareCoordinator.errorMessage == nil {
                    message = "参加しました"
                    dismiss()
                } else {
                    message = "参加に失敗しました"
                    shareCoordinator.errorMessage = nil
                }
                isJoining = false
            }
        }
    }
}
