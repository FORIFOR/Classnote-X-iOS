import SwiftUI
import FirebaseAuth

// MARK: - Share Filter

enum ShareFilter: String, CaseIterable {
    case incoming = "受信"
    case outgoing = "送信"

    var icon: String {
        switch self {
        case .incoming: return "tray.and.arrow.down"
        case .outgoing: return "tray.and.arrow.up"
        }
    }
}

// MARK: - Shared Sessions Screen

struct SharedSessionsScreen: View {
    @State private var sessions: [Session] = []
    @State private var isLoading = false
    @State private var activeFilter: ShareFilter = .incoming
    @State private var showJoinSheet = false
    @State private var joinCode = ""
    @State private var isJoining = false
    @State private var joinError: String?

    @EnvironmentObject private var shareCoordinator: ShareCoordinator

    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }

    var body: some View {
        ZStack {
            Tokens.Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                filterSection
                contentSection
            }
        }
        .navigationDestination(for: Session.self) { session in
            SessionDetailScreen(session: session)
        }
        .onAppear {
            Task { await loadSessions() }
        }
        .refreshable {
            await loadSessions()
        }
        .sheet(isPresented: $showJoinSheet) {
            JoinSessionSheet(
                code: $joinCode,
                isJoining: $isJoining,
                error: $joinError,
                onJoin: joinSession
            )
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            Text("共有")
                .font(Tokens.Typography.screenTitle())
                .foregroundStyle(Tokens.Color.textPrimary)

            Spacer()

            Button {
                showJoinSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Tokens.Color.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
        .padding(.top, Tokens.Spacing.md)
        .padding(.bottom, Tokens.Spacing.sm)
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            ForEach(ShareFilter.allCases, id: \.self) { filter in
                FilterButton(
                    filter: filter,
                    isSelected: activeFilter == filter,
                    count: countForFilter(filter)
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        activeFilter = filter
                    }
                }
            }
        }
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
        .padding(.bottom, Tokens.Spacing.md)
    }

    // MARK: - Content Section

    private var contentSection: some View {
        Group {
            if isLoading && sessions.isEmpty {
                loadingState
            } else if filteredSessions.isEmpty {
                emptyState
            } else {
                sessionList
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: Tokens.Spacing.md) {
            ProgressView()
            Text("読み込み中...")
                .font(Tokens.Typography.caption())
                .foregroundStyle(Tokens.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: Tokens.Spacing.lg) {
            Spacer()

            VStack(spacing: Tokens.Spacing.md) {
                Image(systemName: activeFilter.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(Tokens.Color.textTertiary)

                Text(emptyTitle)
                    .font(Tokens.Typography.sectionTitle())
                    .foregroundStyle(Tokens.Color.textPrimary)

                Text(emptySubtitle)
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Spacing.xl)
            }

            if activeFilter == .incoming {
                Button {
                    showJoinSheet = true
                } label: {
                    HStack(spacing: Tokens.Spacing.xs) {
                        Image(systemName: "link")
                        Text("リンクで参加")
                    }
                    .font(Tokens.Typography.button())
                    .foregroundStyle(Tokens.Color.surface)
                    .padding(.horizontal, Tokens.Spacing.lg)
                    .frame(height: 48)
                    .background(Tokens.Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, Tokens.Spacing.md)
            }

            Spacer()
        }
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: Tokens.Spacing.sm) {
                ForEach(filteredSessions) { session in
                    NavigationLink(value: session) {
                        SharedSessionCard(
                            session: session,
                            isIncoming: activeFilter == .incoming,
                            isMine: session.ownerUid == currentUid
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Tokens.Spacing.screenHorizontal)
            .padding(.bottom, Tokens.Spacing.tabBarHeight + Tokens.Spacing.lg)
        }
    }

    // MARK: - Helpers

    private var filteredSessions: [Session] {
        let uid = currentUid
        return sessions.filter { session in
            switch activeFilter {
            case .incoming:
                return session.ownerUid != uid
            case .outgoing:
                return session.ownerUid == uid && (session.sharing?.memberCount ?? 0) > 0
            }
        }
        .sorted { ($0.startedAt ?? $0.createdAt ?? Date()) > ($1.startedAt ?? $1.createdAt ?? Date()) }
    }

    private func countForFilter(_ filter: ShareFilter) -> Int {
        let uid = currentUid
        return sessions.filter { session in
            switch filter {
            case .incoming:
                return session.ownerUid != uid
            case .outgoing:
                return session.ownerUid == uid && (session.sharing?.memberCount ?? 0) > 0
            }
        }.count
    }

    private var emptyTitle: String {
        switch activeFilter {
        case .incoming:
            return "共有されたセッションがありません"
        case .outgoing:
            return "共有中のセッションがありません"
        }
    }

    private var emptySubtitle: String {
        switch activeFilter {
        case .incoming:
            return "他のユーザーからセッションを共有されると\nここに表示されます"
        case .outgoing:
            return "セッションを共有すると\nここに表示されます"
        }
    }

    private func loadSessions() async {
        isLoading = true
        do {
            sessions = try await APIClient.shared.listSessions()
        } catch {
            print("[SharedSessionsScreen] Failed to load sessions: \(error)")
        }
        isLoading = false
    }

    private func joinSession() {
        guard !isJoining, !joinCode.isEmpty else { return }
        isJoining = true
        joinError = nil

        Task {
            await shareCoordinator.joinSessionByCode(joinCode)
            await MainActor.run {
                if shareCoordinator.errorMessage != nil {
                    joinError = shareCoordinator.errorMessage
                    shareCoordinator.errorMessage = nil
                } else {
                    showJoinSheet = false
                    joinCode = ""
                    Task { await loadSessions() }
                }
                isJoining = false
            }
        }
    }
}

// MARK: - Filter Button

private struct FilterButton: View {
    let filter: ShareFilter
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.xxs) {
                Image(systemName: filter.icon)
                    .font(Tokens.Typography.caption())
                Text(filter.rawValue)
                    .font(Tokens.Typography.caption())
                if count > 0 {
                    Text("\(count)")
                        .font(Tokens.Typography.dateCaps())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Tokens.Color.surface.opacity(0.3) : Tokens.Color.border)
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isSelected ? Tokens.Color.surface : Tokens.Color.textSecondary)
            .padding(.horizontal, Tokens.Spacing.md)
            .padding(.vertical, Tokens.Spacing.sm)
            .background(isSelected ? Tokens.Color.textPrimary : Tokens.Color.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Tokens.Color.border, lineWidth: Tokens.Border.thin)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared Session Card

private struct SharedSessionCard: View {
    let session: Session
    let isIncoming: Bool
    let isMine: Bool

    var body: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            // Type indicator
            ZStack {
                Circle()
                    .fill(session.type == .lecture ? Tokens.Gradients.lecture : Tokens.Gradients.meeting)
                    .frame(width: 48, height: 48)

                Image(systemName: session.type == .lecture ? "book.fill" : "person.2.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            // Content
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
                Text(session.title)
                    .font(Tokens.Typography.body())
                    .fontWeight(.medium)
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Tokens.Spacing.xs) {
                    if isIncoming, let username = session.ownerUsername {
                        HStack(spacing: 3) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                            Text("@\(username)")
                        }
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.accent)
                    } else if !isIncoming {
                        HStack(spacing: 3) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10))
                            Text("\(session.sharing?.memberCount ?? 0)人")
                        }
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.accent)
                    }

                    Text("•")
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.textTertiary)

                    Text(formattedDate(session.startedAt ?? session.createdAt))
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.textSecondary)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(Tokens.Typography.caption())
                .foregroundStyle(Tokens.Color.textTertiary)
        }
        .padding(Tokens.Spacing.md)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
        )
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return "今日 " + formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "HH:mm"
            return "昨日 " + formatter.string(from: date)
        } else {
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Join Session Sheet

private struct JoinSessionSheet: View {
    @Binding var code: String
    @Binding var isJoining: Bool
    @Binding var error: String?
    let onJoin: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: Tokens.Spacing.lg) {
                VStack(spacing: Tokens.Spacing.md) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(Tokens.Color.accent)

                    Text("セッションに参加")
                        .font(Tokens.Typography.sectionTitle())
                        .foregroundStyle(Tokens.Color.textPrimary)

                    Text("共有リンクまたは共有コードを\n入力してセッションに参加できます")
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Tokens.Spacing.lg)

                VStack(spacing: Tokens.Spacing.sm) {
                    TextField("共有リンクまたはコード", text: $code)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(Tokens.Spacing.md)
                        .background(Tokens.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                        )

                    if let error {
                        HStack(spacing: Tokens.Spacing.xxs) {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(error)
                        }
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.destructive)
                    }

                    Button(action: onJoin) {
                        HStack(spacing: Tokens.Spacing.xs) {
                            if isJoining {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(Tokens.Color.surface)
                            } else {
                                Image(systemName: "person.badge.plus")
                            }
                            Text(isJoining ? "参加中..." : "参加する")
                        }
                        .font(Tokens.Typography.button())
                        .foregroundStyle(Tokens.Color.surface)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(code.isEmpty ? Tokens.Color.border : Tokens.Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(code.isEmpty || isJoining)
                }
                .padding(.horizontal, Tokens.Spacing.screenHorizontal)

                Spacer()
            }
            .background(Tokens.Color.background)
            .navigationTitle("参加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
