import SwiftUI
import FirebaseAuth
import UniformTypeIdentifiers
import UniformTypeIdentifiers

// MARK: - Filter Type

enum SessionFilter: String, CaseIterable {
    case all = "すべて"
    case lecture = "講義"
    case meeting = "会議"
    case shared = "共有"
    case mine = "自分"
}

// MARK: - Session List Screen

struct SessionListScreen: View {
    @EnvironmentObject private var recording: RecordingCoordinator
    @State private var sessions: [Session] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var isEditing: Bool = false
    @State private var selection = Set<String>()
    @State private var showDeleteConfirm = false
    @State private var scrollOffset: CGFloat = 0
    @State private var activeFilter: SessionFilter = .all
    @State private var showImportSheet = false
    @State private var showFileImporter = false
    @State private var showTranscriptImport = false
    @State private var showYouTubeImport = false
    @State private var importType: SessionType = .lecture
    @State private var importContext: ImportContext = .standard

    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }

    var body: some View {
        ZStack(alignment: .top) {
            Tokens.Color.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                    // Header with edit button (matching Calendar style)
                    headerRow
                    searchBar
                    filterChips
                    content
                }
                .padding(.top, Tokens.Spacing.md)
                .padding(.bottom, Tokens.Spacing.tabBarHeight)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: SessionListScrollOffsetKey.self,
                            value: proxy.frame(in: .named("sessionListScroll")).minY
                        )
                    }
                )
            }
            .scrollIndicators(.hidden)
            .coordinateSpace(name: "sessionListScroll")
            .onPreferenceChange(SessionListScrollOffsetKey.self) { value in
                scrollOffset = value
            }
        }
        .navigationDestination(for: Session.self) { session in
            SessionDetailScreen(session: session)
        }
        .overlay(alignment: .top) {
            SessionListTopBar(title: "セッション", opacity: topBarTitleOpacity)
        }
        .confirmationDialog(
            "\(selection.count)件のセッションを削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                Task { await deleteSelected() }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .onAppear {
            Task { await loadSessions() }
        }
        .sheet(isPresented: $showImportSheet) {
            ImportSourceSheet(
                selectedType: $importType,
                context: importContext,
                isImporting: recording.isImporting,
                onPickAudio: {
                    showImportSheet = false
                    showFileImporter = true
                },
                onImportYouTube: {
                    showImportSheet = false
                    showYouTubeImport = true
                },
                onPasteTranscript: {
                    showImportSheet = false
                    importContext = .standard
                    showTranscriptImport = true
                },
                onRunVoiceMemoTest: {
                    showImportSheet = false
                    runVoiceMemoTest()
                }
            )
        }
        .sheet(isPresented: $showYouTubeImport) {
            YouTubeImportSheet(selectedType: $importType, isImporting: recording.isImporting) { url, title, language in
                recording.importYouTube(url: url, type: importType, title: title, language: language)
            }
        }
        .sheet(isPresented: $showTranscriptImport) {
            TranscriptImportSheet(
                selectedType: $importType,
                isImporting: recording.isImporting
            ) { text, title in
                recording.importTranscript(text: text, type: importType, title: title)
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio, .movie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    recording.errorMessage = "音声ファイルが選択されませんでした。"
                    return
                }
                let isTest = importContext == .voiceMemoTest
                let title: String? = isTest ? "ボイスメモ共有(テスト)" : nil
                recording.importAudioFile(from: url, type: importType, title: title, persistLocalCopy: isTest)
                importContext = .standard
            case .failure:
                recording.errorMessage = "音声ファイルの読み込みに失敗しました。"
                importContext = .standard
            }
        }
        .overlay {
            if recording.isImporting {
                ImportProgressOverlay()
            }
        }
    }

    private func runVoiceMemoTest() {
        defer { importContext = .standard }
        guard let url = bundledTestAudioURL() else {
            recording.errorMessage = "テスト音声が見つかりません。"
            return
        }
        recording.importAudioFile(from: url, type: importType, title: "ボイスメモ共有(テスト)", persistLocalCopy: true)
    }

    private func bundledTestAudioURL() -> URL? {
        if let url = Bundle.main.url(forResource: "lecture_short_16k", withExtension: "wav", subdirectory: "TestAudio") {
            return url
        }
        if let url = Bundle.main.url(forResource: "lecture_short_16k", withExtension: "wav") {
            return url
        }
        if let url = Bundle.main.url(forResource: "lecture_short_16k", withExtension: "m4a", subdirectory: "TestAudio") {
            return url
        }
        return Bundle.main.url(forResource: "lecture_short_16k", withExtension: "m4a")
    }

    // Header matching Calendar style
    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                // Edit/Done Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing.toggle()
                        if !isEditing { selection.removeAll() }
                    }
                }) {
                    Text(isEditing ? "完了" : "編集")
                        .font(Tokens.Typography.button())
                        .foregroundStyle(isEditing ? Tokens.Color.accent : Tokens.Color.textSecondary)
                        .padding(.horizontal, Tokens.Spacing.md)
                        .padding(.vertical, Tokens.Spacing.xs)
                        .frame(height: Tokens.Sizing.buttonCompactHeight)
                        .background(Tokens.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                                .stroke(isEditing ? Tokens.Color.accent : Tokens.Color.border, lineWidth: Tokens.Border.thin)
                        )
                }

                // Title
                Text("セッション")
                    .font(Tokens.Typography.screenTitle())
                    .foregroundStyle(Tokens.Color.textPrimary)
            }

            Spacer()

            HStack(spacing: Tokens.Spacing.xs) {
                CapsuleActionButton(title: "テスト") {
                    importContext = .voiceMemoTest
                    showImportSheet = true
                }

                Button(action: {
                    importContext = .standard
                    showImportSheet = true
                }) {
                    Image(systemName: "plus")
                        .font(Tokens.Typography.iconMedium())
                        .foregroundStyle(Tokens.Color.textPrimary)
                        .frame(width: Tokens.Sizing.iconButton, height: Tokens.Sizing.iconButton)
                        .background(Tokens.Color.surface)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                        )
                }

                // Delete button (only in edit mode with selection)
                if isEditing && !selection.isEmpty {
                    Button(action: { showDeleteConfirm = true }) {
                        Image(systemName: "trash")
                            .font(Tokens.Typography.iconMedium())
                            .foregroundStyle(Tokens.Color.destructive)
                            .frame(width: Tokens.Sizing.iconButton, height: Tokens.Sizing.iconButton)
                            .background(Tokens.Color.surface)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Tokens.Color.destructive.opacity(0.3), lineWidth: Tokens.Border.thin)
                            )
                    }
                }
            }
        }
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
    }

    private var searchBar: some View {
        SearchPill(text: $searchText, placeholder: "タイトル、タグで検索")
            .padding(.horizontal, Tokens.Spacing.screenHorizontal)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Spacing.xs) {
                ForEach(SessionFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        isSelected: activeFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, Tokens.Spacing.screenHorizontal)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 200)
        } else if filteredSessions.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: Tokens.Spacing.sm) {
                ForEach(filteredSessions) { session in
                    if isEditing {
                        SessionCellV2(
                            session: session,
                            isEditing: true,
                            isSelected: selection.contains(session.id),
                            isMine: session.ownerUid == currentUid
                        )
                        .onTapGesture { toggleSelection(session) }
                    } else {
                        NavigationLink(value: session) {
                            SessionCellV2(
                                session: session,
                                isEditing: false,
                                isSelected: false,
                                isMine: session.ownerUid == currentUid
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Tokens.Spacing.screenHorizontal)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Tokens.Spacing.sm) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(Tokens.Typography.iconMedium())
                .foregroundColor(Tokens.Color.textSecondary)
            Text(searchText.isEmpty ? "セッションがありません" : "検索結果がありません")
                .font(Tokens.Typography.body())
                .foregroundColor(Tokens.Color.textPrimary)
            Text(searchText.isEmpty ? "録音後に自動でここに追加されます" : "「\(searchText)」に一致するセッションが見つかりませんでした")
                .font(Tokens.Typography.caption())
                .foregroundColor(Tokens.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
    }

    private var filteredSessions: [Session] {
        let uid = currentUid
        return sessions.filter { session in
            // Text search filter
            if !searchText.isEmpty {
                let inTitle = session.title.localizedCaseInsensitiveContains(searchText)
                let inTags = session.tags?.contains { $0.localizedCaseInsensitiveContains(searchText) } ?? false
                if !inTitle && !inTags { return false }
            }

            // Category filter
            switch activeFilter {
            case .all:
                return true
            case .lecture:
                return session.type == .lecture
            case .meeting:
                return session.type == .meeting
            case .shared:
                return session.ownerUid != uid
            case .mine:
                return session.ownerUid == uid
            }
        }
    }

    private func loadSessions() async {
        isLoading = true
        do {
            sessions = try await APIClient.shared.listSessions()
        } catch {
            print("Failed to list sessions: \(error)")
        }
        isLoading = false
    }

    private func toggleSelection(_ session: Session) {
        if selection.contains(session.id) {
            selection.remove(session.id)
        } else {
            selection.insert(session.id)
        }
    }

    private func deleteSelected() async {
        let ids = Array(selection)
        guard !ids.isEmpty else { return }
        for id in ids {
            try? await APIClient.shared.deleteSession(id: id)
        }
        selection.removeAll()
        await loadSessions()
    }

    private var topBarTitleOpacity: Double {
        let offset = -scrollOffset
        let start: CGFloat = 18
        let end: CGFloat = 52
        if offset <= start { return 0 }
        if offset >= end { return 1 }
        return Double((offset - start) / (end - start))
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Tokens.Color.surface : Tokens.Color.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Tokens.Color.textPrimary : Tokens.Color.surface)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Tokens.Color.border.opacity(0.5), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session Cell V2 (Redesigned)

struct SessionCellV2: View {
    let session: Session
    let isEditing: Bool
    let isSelected: Bool
    let isMine: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Edit mode checkbox
            if isEditing {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? Tokens.Color.textPrimary : Tokens.Color.textTertiary)
                    .padding(.top, 10)
            }

            // Type indicator (colored circle)
            Circle()
                .fill(session.type == .lecture ? Tokens.Gradients.lecture : Tokens.Gradients.meeting)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: session.type == .lecture ? "book.fill" : "person.2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                )

            // Main content
            VStack(alignment: .leading, spacing: 6) {
                // Title row with chevron
                HStack {
                    Text(session.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Tokens.Color.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if !isEditing {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Tokens.Color.textTertiary)
                    }
                }

                // Meta line: type, date, duration
                HStack(spacing: 6) {
                    Text(session.type == .lecture ? "講義" : "会議")
                        .foregroundColor(session.type == .lecture ? Tokens.Color.lectureAccent : Tokens.Color.meetingAccent)

                    Text("•")
                        .foregroundColor(Tokens.Color.textTertiary)

                    Text(formattedDate(session.startedAt ?? session.createdAt))
                        .foregroundColor(Tokens.Color.textSecondary)

                    if let duration = session.durationSec, duration > 0 {
                        Text("•")
                            .foregroundColor(Tokens.Color.textTertiary)
                        Text(formattedDuration(duration))
                            .foregroundColor(Tokens.Color.textSecondary)
                    }

                    // Owner badge (subtle)
                    if !isMine {
                        Spacer()
                        HStack(spacing: 2) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 9))
                            if let username = session.ownerUsername {
                                Text(username)
                            } else {
                                Text("共有")
                            }
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Tokens.Color.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Tokens.Color.background))
                    }
                }
                .font(.system(size: 13))

                // Status chips row
                if !session.statusChips.isEmpty {
                    StatusChipRow(chips: session.statusChips, maxVisible: 3)
                }

                // Summary preview (if available)
                if let summarySnippet = session.summary?.text, !summarySnippet.isEmpty {
                    Text(summarySnippet)
                        .font(.system(size: 13))
                        .foregroundColor(Tokens.Color.textSecondary)
                        .lineLimit(2)
                }

                // Tags row
                if let tags = session.tags, !tags.isEmpty {
                    SessionTagRow(tags: tags, maxVisible: 3)
                }
            }
        }
        .padding(14)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Formatters

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
            formatter.dateFormat = "M/d HH:mm"
            return formatter.string(from: date)
        }
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)分"
        } else {
            return "\(seconds)秒"
        }
    }
}

// MARK: - Session Tag Row

struct SessionTagRow: View {
    let tags: [String]
    let maxVisible: Int

    init(tags: [String], maxVisible: Int = 3) {
        self.tags = tags
        self.maxVisible = maxVisible
    }

    var body: some View {
        HStack(spacing: Tokens.Spacing.xxs) {
            ForEach(visibleTags, id: \.self) { tag in
                Text("#\(tag)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Tokens.Color.background)
                    .clipShape(Capsule())
            }

            if remainingCount > 0 {
                Text("+\(remainingCount)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Tokens.Color.textTertiary)
            }
        }
    }

    private var visibleTags: [String] {
        Array(tags.prefix(maxVisible))
    }

    private var remainingCount: Int {
        max(0, tags.count - maxVisible)
    }
}

// Top bar matching Calendar style (simple title fade on scroll)
private struct SessionListTopBar: View {
    let title: String
    let opacity: Double

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Tokens.Color.background)
            Rectangle()
                .fill(Tokens.Color.border)
                .frame(height: Tokens.Border.hairline)
                .frame(maxHeight: .infinity, alignment: .bottom)
            AppText(title, style: .sectionTitle, color: Tokens.Color.textPrimary)
                .opacity(opacity)
        }
        .frame(height: Tokens.Sizing.buttonHeight)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(edges: .top)
    }
}

private struct SessionListScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private enum ImportContext {
    case standard
    case voiceMemoTest
}

private struct ImportSourceSheet: View {
    @Binding var selectedType: SessionType
    let context: ImportContext
    let isImporting: Bool
    let onPickAudio: () -> Void
    let onImportYouTube: () -> Void
    let onPasteTranscript: () -> Void
    let onRunVoiceMemoTest: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            AppText("取り込み", style: .sectionTitle, color: Tokens.Color.textPrimary)
            AppText(
                context == .voiceMemoTest
                ? "ボイスメモ共有を想定したテストです。Filesから音声を選択します。"
                : "モードを選択して取り込み方法を決めます",
                style: .caption,
                color: Tokens.Color.textSecondary
            )

            ModeSelectorPill(selection: $selectedType)

            if context == .voiceMemoTest {
                AppButton("テストを開始", icon: "waveform", style: .primary) {
                    guard !isImporting else { return }
                    dismiss()
                    onRunVoiceMemoTest()
                }
                .disabled(isImporting)
            } else {
                AppButton("音声ファイルを取り込む", icon: "waveform", style: .primary) {
                    guard !isImporting else { return }
                    dismiss()
                    onPickAudio()
                }
                .disabled(isImporting)

                AppButton("YouTube URLを取り込む", icon: "play.rectangle", style: .secondary) {
                    guard !isImporting else { return }
                    dismiss()
                    onImportYouTube()
                }
                .disabled(isImporting)

                AppButton("文字起こしを貼り付ける", icon: "text.quote", style: .secondary) {
                    guard !isImporting else { return }
                    dismiss()
                    onPasteTranscript()
                }
                .disabled(isImporting)
            }

            Spacer(minLength: Tokens.Spacing.lg)
        }
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
        .padding(.top, Tokens.Spacing.md)
        .padding(.bottom, Tokens.Spacing.lg)
    }
}

private struct TranscriptImportSheet: View {
    @Binding var selectedType: SessionType
    let isImporting: Bool
    let onSubmit: (String, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var transcriptText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            AppText("文字起こしを取り込む", style: .sectionTitle, color: Tokens.Color.textPrimary)
            AppText("モード", style: .caption, color: Tokens.Color.textSecondary)
            ModeSelectorPill(selection: $selectedType)

            DADSTextField(
                text: $title,
                placeholder: "タイトル（任意）",
                icon: "pencil",
                style: .rounded
            )

            transcriptEditor

            AppButton("取り込む", icon: "arrow.down.circle.fill", style: .primary) {
                let trimmed = transcriptText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                onSubmit(trimmed, title)
                dismiss()
            }
            .disabled(isImporting || transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(isImporting || transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)

            AppButton("キャンセル", style: .secondary) {
                dismiss()
            }
        }
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
        .padding(.top, Tokens.Spacing.md)
        .padding(.bottom, Tokens.Spacing.lg)
    }

    private var transcriptEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $transcriptText)
                .font(Tokens.Typography.body())
                .foregroundStyle(Tokens.Color.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: Tokens.Sizing.buttonHeight * 4)

            if transcriptText.isEmpty {
                AppText("ここに文字起こしを貼り付けてください", style: .caption, color: Tokens.Color.textTertiary)
                    .padding(.horizontal, Tokens.Spacing.sm)
                    .padding(.vertical, Tokens.Spacing.sm)
            }
        }
        .padding(.horizontal, Tokens.Spacing.xs)
        .padding(.vertical, Tokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .fill(Tokens.Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
        )
    }
}

private enum YouTubeTranscriptLanguage: String, CaseIterable, Identifiable {
    case auto = "自動"
    case japanese = "日本語"
    case english = "英語"

    var id: String { rawValue }

    var code: String? {
        switch self {
        case .auto:
            return nil
        case .japanese:
            return "ja"
        case .english:
            return "en"
        }
    }
}

private struct YouTubeImportSheet: View {
    @Binding var selectedType: SessionType
    let isImporting: Bool
    let onSubmit: (String, String?, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var urlText: String = ""
    @State private var title: String = ""
    @State private var language: YouTubeTranscriptLanguage = .japanese

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            AppText("YouTube URL取り込み", style: .sectionTitle, color: Tokens.Color.textPrimary)
            AppText("字幕がある動画のみ取り込みできます。音声はダウンロードしません。", style: .caption, color: Tokens.Color.textSecondary)

            AppCard {
                VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                    featureRow(icon: "text.quote", text: "字幕（transcript）を取得して保存")
                    featureRow(icon: "sparkles", text: "要約とテストを自動生成")
                    featureRow(icon: "checkmark.shield", text: "音声は扱わず権利リスクを回避")
                }
            }

            AppText("モード", style: .caption, color: Tokens.Color.textSecondary)
            ModeSelectorPill(selection: $selectedType)

            DADSTextField(
                text: $urlText,
                placeholder: "YouTube URL",
                icon: "link",
                style: .rounded
            )
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if let message = validationMessage {
                AppText(message, style: .caption, color: Tokens.Color.destructive)
            }

            DADSTextField(
                text: $title,
                placeholder: "タイトル（任意）",
                icon: "pencil",
                style: .rounded
            )

            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                AppText("字幕言語", style: .caption, color: Tokens.Color.textSecondary)
                Picker("字幕言語", selection: $language) {
                    ForEach(YouTubeTranscriptLanguage.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .tint(Tokens.Color.accent)
            }

            AppButton("取り込む", icon: "arrow.down.circle.fill", style: .primary) {
                let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard isValidYouTubeURL(trimmed) else { return }
                onSubmit(trimmed, title, language.code)
                dismiss()
            }
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.6)

            AppButton("キャンセル", style: .secondary) {
                dismiss()
            }
        }
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
        .padding(.top, Tokens.Spacing.md)
        .padding(.bottom, Tokens.Spacing.lg)
    }

    private var canSubmit: Bool {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !isImporting && isValidYouTubeURL(trimmed)
    }

    private var validationMessage: String? {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        return isValidYouTubeURL(trimmed) ? nil : "YouTubeのURLを確認してください。"
    }

    private func isValidYouTubeURL(_ text: String) -> Bool {
        extractVideoId(from: text) != nil
    }

    private func extractVideoId(from text: String) -> String? {
        let pattern = "(?:v=|youtu\\.be/|shorts/)([A-Za-z0-9_-]{6,})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
        guard match.numberOfRanges >= 2 else { return nil }
        let idRange = match.range(at: 1)
        guard let swiftRange = Range(idRange, in: text) else { return nil }
        return String(text[swiftRange])
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: Tokens.Spacing.xs) {
            Image(systemName: icon)
                .font(Tokens.Typography.caption())
                .foregroundStyle(Tokens.Color.accent)
            AppText(text, style: .caption, color: Tokens.Color.textSecondary)
        }
    }
}

private struct ImportProgressOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Tokens.Color.textPrimary.opacity(0.2))
                .ignoresSafeArea()

            VStack(spacing: Tokens.Spacing.sm) {
                ProgressView()
                AppText("取り込み中…", style: .caption, color: Tokens.Color.textSecondary)
            }
            .padding(Tokens.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                    .fill(Tokens.Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                    .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
            )
        }
    }
}

private struct CapsuleActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AppText(title, style: .caption, color: Tokens.Color.textSecondary)
                .padding(.horizontal, Tokens.Spacing.sm)
                .padding(.vertical, Tokens.Spacing.xxs)
                .background(
                    Capsule().fill(Tokens.Color.surface)
                )
                .overlay(
                    Capsule().stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                )
        }
        .buttonStyle(.plain)
    }
}
