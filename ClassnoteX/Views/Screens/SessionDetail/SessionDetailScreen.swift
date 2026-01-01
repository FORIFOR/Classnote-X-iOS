import SwiftUI
import UIKit
import ImageIO
import UniformTypeIdentifiers

struct SessionDetailScreen: View {
    let session: Session
    @Environment(\.dismiss) private var dismiss

    @State private var detail: Session
    @State private var selectedTab: DetailTab = .memo
    @State private var currentUser: User?
    @State private var myReaction: ReactionType?
    @State private var reactionsSummary: ReactionsSummary = .empty
    @State private var showUsernameSetup = false
    @State private var showShareSheet = false
    @State private var showInfoSheet = false
    @State private var showDeleteConfirm = false
    @State private var isUploadingPhoto = false
    @State private var photoUploadError: String?
    @State private var signedAudio: SignedCompressedAudioResponse?
    @State private var isPlayerExpanded = false
    @State private var isEditingTitle = false
    @State private var titleDraft = ""
    @State private var isSavingTitle = false
    @State private var aiGenerationError: String?
    @FocusState private var isTitleFocused: Bool

    @StateObject private var playback: PlaybackViewModel

    init(session: Session) {
        self.session = session
        _detail = State(initialValue: session)
        _playback = StateObject(wrappedValue: PlaybackViewModel(sessionId: session.id))
    }

    enum DetailTab: String, CaseIterable {
        case memo = "メモ"
        case transcript = "文字起こし"
        case summary = "要約"
        case quiz = "テスト"
    }

    var body: some View {
        ZStack {
            Tokens.Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                compactMetaRow
                tabSelector
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await refreshSession()
                await loadUser()
                await loadReactions()
            }
        }
        .fullScreenCover(isPresented: $showUsernameSetup) {
            UsernameSetupView { updatedUser in
                currentUser = updatedUser
                showUsernameSetup = false
                showShareSheet = true
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(
                sessionId: detail.id,
                memberCount: detail.sharing?.memberCount ?? 0,
                members: detail.members ?? []
            )
        }
        .sheet(isPresented: $showInfoSheet) {
            SessionInfoSheet(
                session: detail,
                reactionsSummary: reactionsSummary,
                myReaction: myReaction,
                shareLabel: shareLabel,
                audioStatusText: audioStatusText,
                transcriptStatusText: transcriptStatusText,
                summaryStatusText: summaryStatusText,
                quizStatusText: quizStatusText,
                transcriptStatusColor: transcriptStatusColor,
                summaryStatusColor: summaryStatusColor,
                quizStatusColor: quizStatusColor,
                onReaction: { type in
                    updateReaction(type)
                },
                onDelete: {
                    showDeleteConfirm = true
                }
            )
        }
        .safeAreaInset(edge: .bottom) {
            if audioSource != nil {
                InlineExpandablePlayer(
                    isPlaying: playback.isPlaying,
                    currentTime: playback.currentTime,
                    duration: playback.duration,
                    hasAudio: audioSource != nil,
                    isExpanded: $isPlayerExpanded,
                    aiMarkers: detail.aiMarkers ?? [],
                    onPlayPause: { playback.playPause(source: audioSource) },
                    onSeek: { playback.seek(to: $0) }
                )
                .padding(.horizontal, Tokens.Spacing.screenHorizontal)
                .padding(.bottom, Tokens.Spacing.tabBarHeight + Tokens.Spacing.xs)
            }
        }
        .confirmationDialog(
            "このセッションを削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                Task {
                    try? await APIClient.shared.deleteSession(id: detail.id)
                    dismiss()
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .alert(
            "写真のアップロードに失敗しました",
            isPresented: Binding(
                get: { photoUploadError != nil },
                set: { if !$0 { photoUploadError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(photoUploadError ?? "")
        }
        .alert(
            "AI生成に失敗しました",
            isPresented: Binding(
                get: { aiGenerationError != nil },
                set: { if !$0 { aiGenerationError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(aiGenerationError ?? "しばらくしてからもう一度お試しください。")
        }
    }

    private var header: some View {
        AppNavHeader(
            title: isEditingTitle ? "" : detail.title,
            onBack: { dismiss() },
            trailingAction: {
                AnyView(
                    HStack(spacing: Tokens.Spacing.xs) {
                        if isEditingTitle {
                            Button(action: cancelTitleEdit) {
                                Circle()
                                    .fill(Tokens.Color.surface)
                                    .frame(width: Tokens.Sizing.iconButton, height: Tokens.Sizing.iconButton)
                                    .overlay(Image(systemName: "xmark").foregroundColor(Tokens.Color.textSecondary))
                            }
                            .buttonStyle(.plain)
                            .disabled(isSavingTitle)

                            Button(action: saveTitle) {
                                Circle()
                                    .fill(Tokens.Color.textPrimary)
                                    .frame(width: Tokens.Sizing.iconButton, height: Tokens.Sizing.iconButton)
                                    .overlay {
                                        if isSavingTitle {
                                            ProgressView()
                                                .tint(Tokens.Color.surface)
                                                .scaleEffect(0.75)
                                        } else {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(Tokens.Color.surface)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .disabled(isSavingTitle)
                        } else {
                            Button(action: handleShare) {
                                Circle()
                                    .fill(Tokens.Color.surface)
                                    .frame(width: Tokens.Sizing.iconButton, height: Tokens.Sizing.iconButton)
                                    .overlay(Image(systemName: "square.and.arrow.up").foregroundColor(Tokens.Color.textPrimary))
                            }

                            Button(action: { showInfoSheet = true }) {
                                Circle()
                                    .fill(Tokens.Color.surface)
                                    .frame(width: Tokens.Sizing.iconButton, height: Tokens.Sizing.iconButton)
                                    .overlay(Image(systemName: "ellipsis").foregroundColor(Tokens.Color.textPrimary))
                            }
                        }
                    }
                )
            }
        )
        .overlay {
            if isEditingTitle {
                TextField("セッション名", text: $titleDraft)
                    .textFieldStyle(.plain)
                    .font(Tokens.Typography.screenTitle()) // Or smaller? screenTitle is 32. Maybe sectionTitle or custom for input
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .padding(.horizontal, Tokens.Spacing.sm)
                    .padding(.vertical, Tokens.Spacing.xs)
                    .background(Tokens.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous))
                    .focused($isTitleFocused)
                    .submitLabel(.done)
                    .onSubmit { saveTitle() }
                    .padding(.horizontal, Tokens.Spacing.xl)
            } else {
                // Tappable title area in header center
                Color.clear
                    .frame(width: 200, height: 44)
                    .contentShape(Rectangle())
                    .onTapGesture { startTitleEdit() }
            }
        }
    }

    private var tabSelector: some View {
        SessionDetailSegmentedControl(tabs: DetailTab.allCases, selection: $selectedTab)
            .padding(.horizontal, Tokens.Spacing.screenHorizontal)
            .padding(.top, Tokens.Spacing.sm)
            .padding(.bottom, Tokens.Spacing.xs)
    }

    private var compactMetaRow: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            SessionModeBadge(type: detail.type)

            AppText(compactMetaText, style: .caption, color: Tokens.Color.textSecondary)
                .lineLimit(1)

            Spacer()

            HStack(spacing: Tokens.Spacing.xs) {
                StatusIcon(name: "doc.text", isActive: transcriptStatusText == "あり")
                StatusIcon(name: "sparkles", isActive: summaryStatusText == "あり")
                StatusIcon(name: "brain.head.profile", isActive: quizStatusText == "あり")
            }
        }
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
        .padding(.vertical, Tokens.Spacing.xs)
    }

    private var content: some View {
        TabView(selection: $selectedTab) {
            MemoTab(
                session: $detail,
                onSaveMemo: { text in
                    Task { await updateMemo(text) }
                },
                onAddPhoto: { image in
                    Task { await uploadPhoto(image) }
                },
                isPhotoUploading: isUploadingPhoto
            )
            .tag(DetailTab.memo)

            TranscriptTab(
                session: $detail,
                generationError: $aiGenerationError,
                canLocalRegenerate: localAudioURL != nil,
                onRegenerate: {
                    Task { await generateTranscript() }
                },
                onRegenerateLocal: {
                    Task { await generateLocalTranscript() }
                },
                onDiarize: {
                    Task { await generateDiarization() }
                }
            )
            .tag(DetailTab.transcript)

            SummaryTab(session: $detail, generationError: $aiGenerationError) {
                Task { await generateSummary() }
            }
            .tag(DetailTab.summary)

            QuizTab(session: $detail, generationError: $aiGenerationError) {
                Task { await generateQuiz() }
            }
            .tag(DetailTab.quiz)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, Tokens.Spacing.md)
    }

    private var shareLabel: String? {
        guard let sharing = detail.sharing, sharing.memberCount > 0 else { return nil }
        return "共有 \(sharing.memberCount)人"
    }

    private var compactMetaText: String {
        var parts: [String] = [detail.dateFormatted]
        if detail.durationSec != nil {
            parts.append(detail.durationFormatted)
        }
        return parts.joined(separator: " • ")
    }

    private var audioStatusText: String {
        switch detail.audioStatus ?? .unknown {
        case .ready:
            return "準備完了"
        case .uploading, .uploaded:
            return "アップロード中"
        case .processing, .pending:
            return "処理中"
        case .failed:
            return "失敗"
        case .expired:
            return "期限切れ"
        case .unknown:
            return detail.hasAudio ? "あり" : "なし"
        }
    }

    private var transcriptStatusText: String {
        let hasText = !(detail.transcript?.text ?? detail.transcriptText ?? "").isEmpty
        if detail.transcript?.hasTranscript == true || hasText {
            return "あり"
        }
        return "未生成"
    }

    private var summaryStatusText: String {
        if detail.summary?.hasSummary == true {
            return "あり"
        }
        return "未生成"
    }

    private var quizStatusText: String {
        if detail.quiz?.hasQuiz == true {
            return "あり"
        }
        return "未生成"
    }

    private var transcriptStatusColor: Color {
        transcriptStatusText == "あり" ? Tokens.Color.accent : Tokens.Color.textSecondary
    }

    private var summaryStatusColor: Color {
        summaryStatusText == "あり" ? Tokens.Color.accent : Tokens.Color.textSecondary
    }

    private var quizStatusColor: Color {
        quizStatusText == "あり" ? Tokens.Color.accent : Tokens.Color.textSecondary
    }

    // ... (rest of local/private methods stay the same) ...
    private var localAudioURL: URL? {
        AudioFileLocator.findAudioURL(for: detail)
    }

    private var audioSource: AudioSource? {
        if let localURL = localAudioURL {
            return AudioSource(url: localURL, meta: nil)
        }
        if let signedAudio {
            return AudioSource(url: signedAudio.audioUrl, meta: signedAudio.compressionMetadata)
        }
        return nil
    }

    private func refreshSession() async {
        do {
            detail = try await APIClient.shared.getSession(id: session.id)
            do {
                let notes = try await APIClient.shared.listImageNotes(sessionId: detail.id)
                detail.photos = notes.map { PhotoRef(id: $0.id, url: $0.url, createdAt: $0.createdAt) }
            } catch {
                print("Failed to load image notes: \(error)")
            }
            await loadAudioURLIfNeeded()
        } catch {
            print("Failed to fetch session: \(error)")
        }
    }

    private func loadAudioURLIfNeeded() async {
        guard detail.audioStatus == .ready || detail.audioMeta != nil || detail.audioPath != nil else {
            return
        }
        if let signedAudio, signedAudio.expiresAt > Date().addingTimeInterval(60) {
            return
        }
        do {
            signedAudio = try await APIClient.shared.getAudioURL(sessionId: detail.id)
        } catch {
            print("Failed to load audio URL: \(error)")
        }
    }

    private func loadUser() async {
        currentUser = try? await APIClient.shared.getMe()
    }

    private func loadReactions() async {
        do {
            let response = try await APIClient.shared.getReactions(sessionId: detail.id)
            reactionsSummary = response.summary
            myReaction = response.myReaction
        } catch {
            reactionsSummary = detail.reactionsSummary ?? .empty
            myReaction = nil
        }
    }

    private func updateReaction(_ type: ReactionType) {
        Task {
            do {
                if myReaction == type {
                    try await APIClient.shared.removeReaction(sessionId: detail.id)
                } else {
                    try await APIClient.shared.sendReaction(sessionId: detail.id, type: type)
                }
                await loadReactions()
            } catch {
                print("Failed to send reaction: \(error)")
            }
        }
    }

    private func handleShare() {
        if let currentUser, currentUser.hasUsername {
            showShareSheet = true
            return
        }

        Task {
            let me = try? await APIClient.shared.getMe()
            await MainActor.run {
                currentUser = me
                if me?.hasUsername == true {
                    showShareSheet = true
                } else {
                    showUsernameSetup = true
                }
            }
        }
    }

    private func updateMemo(_ text: String) async {
        do {
            try await APIClient.shared.updateNotes(sessionId: detail.id, notes: text)
            detail.memoText = text
        } catch {
            print("Failed to save memo: \(error)")
        }
    }

    private func startTitleEdit() {
        titleDraft = detail.title
        isEditingTitle = true
        isTitleFocused = true
    }

    private func cancelTitleEdit() {
        isEditingTitle = false
        isTitleFocused = false
        titleDraft = ""
    }

    private func saveTitle() {
        guard !isSavingTitle else { return }
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            cancelTitleEdit()
            return
        }
        guard trimmed != detail.title else {
            cancelTitleEdit()
            return
        }
        isSavingTitle = true
        Task {
            do {
                let updated = try await APIClient.shared.updateSession(id: detail.id, title: trimmed)
                await MainActor.run {
                    detail.title = updated.title
                    isSavingTitle = false
                    isEditingTitle = false
                    isTitleFocused = false
                }
            } catch {
                await MainActor.run {
                    isSavingTitle = false
                }
                print("Failed to update title: \(error)")
            }
        }
    }

    private func generateTranscript() async {
        do {
            try await APIClient.shared.transcribe(sessionId: detail.id)
            await refreshSession()
        } catch {
            print("Failed to generate transcript: \(error)")
            aiGenerationError = "文字起こしの生成に失敗しました。音声データが正しくアップロードされているか確認してください。"
        }
    }

    private func generateLocalTranscript() async {
        guard let localURL = localAudioURL else {
            aiGenerationError = "ローカル音声が見つかりませんでした。"
            return
        }
        do {
            let text = try await LocalBatchTranscriber.transcribe(url: localURL)
            detail.transcriptText = text
            detail.transcript = TranscriptStatus(hasTranscript: true, text: text)
            do {
                try await APIClient.shared.updateTranscript(sessionId: detail.id, transcriptText: text)
            } catch {
                print("Failed to sync local transcript: \(error)")
                if aiGenerationError == nil {
                    aiGenerationError = "ローカル文字起こしの同期に失敗しました。"
                }
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            aiGenerationError = "ローカル文字起こしに失敗しました。\(message)"
        }
    }

    private func generateSummary() async {
        do {
            try await APIClient.shared.summarize(sessionId: detail.id)
            await refreshSession()
        } catch {
            print("Failed to generate summary: \(error)")
            aiGenerationError = "要約の生成に失敗しました。文字起こしが完了しているか確認してください。"
        }
    }

    private func generateQuiz() async {
        do {
            try await APIClient.shared.generateQuiz(sessionId: detail.id)
            await refreshSession()
        } catch {
            print("Failed to generate quiz: \(error)")
            aiGenerationError = "クイズの生成に失敗しました。文字起こしが完了しているか確認してください。"
        }
    }

    private func generateDiarization() async {
        if let localURL = localAudioURL {
            do {
                let result = try await LocalDiarizer.diarize(audioURL: localURL)
                detail.diarizedTranscript = result.blocks
                if (detail.transcriptText ?? "").isEmpty {
                    detail.transcriptText = result.transcriptText
                    detail.transcript = TranscriptStatus(hasTranscript: true, text: result.transcriptText)
                    do {
                        try await APIClient.shared.updateTranscript(sessionId: detail.id, transcriptText: result.transcriptText)
                    } catch {
                        print("Failed to sync local transcript: \(error)")
                    }
                }
                return
            } catch {
                print("Failed to run local diarization: \(error)")
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                aiGenerationError = "ローカル話者分離に失敗しました。\(message)"
                return
            }
        }

        do {
            try await APIClient.shared.diarize(sessionId: detail.id)
            await refreshSession()
        } catch {
            print("Failed to generate diarization: \(error)")
            aiGenerationError = "話者分離に失敗しました。文字起こしが完了しているか確認してください。"
        }
    }

    private func uploadPhoto(_ image: UIImage) async {
        guard !isUploadingPhoto else { return }
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }

        do {
            let primary = try ImageCompressor.compress(image: image, preferHeic: true)
            do {
                try await uploadPhotoPayload(primary)
            } catch {
                if primary.format == .heic {
                    let fallback = try ImageCompressor.compress(image: image, preferHeic: false)
                    try await uploadPhotoPayload(fallback)
                } else {
                    throw error
                }
            }
            await refreshSession()
        } catch {
            print("Photo upload failed: \(error)")
            photoUploadError = "写真の保存に失敗しました。"
        }
    }

    private func uploadPhotoPayload(_ payload: CompressedImage) async throws {
        let uploadInfo = try await APIClient.shared.getImageUploadURL(sessionId: detail.id, contentType: payload.mimeType)
        let method = uploadInfo.method ?? "PUT"
        try await APIClient.shared.upload(
            data: payload.data,
            to: uploadInfo.uploadUrl,
            contentType: payload.mimeType,
            method: method,
            headers: uploadInfo.headers
        )
    }

}

private struct SessionDetailSegmentedControl<Tab: Hashable>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    @Namespace private var capsuleNamespace
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let segmentWidth = width / CGFloat(tabs.count)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Tokens.Color.border)
                    .frame(height: Tokens.Sizing.iconButton)

                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { _, tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selection = tab
                            }
                        } label: {
                            AppText(tabLabel(tab), style: .tabLabel)
                                .foregroundColor(selection == tab
                                    ? Tokens.Color.textPrimary
                                    : Tokens.Color.textSecondary
                                )
                                .frame(width: segmentWidth, height: Tokens.Sizing.iconButton)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            ZStack {
                                if selection == tab {
                                    Capsule()
                                        .fill(Tokens.Color.surface)
                                        .matchedGeometryEffect(id: "pill", in: capsuleNamespace)
                                        .padding(Tokens.Spacing.xxs)
                                        .shadow(
                                            color: Tokens.Shadows.card(for: colorScheme).color,
                                            radius: Tokens.Shadows.card(for: colorScheme).radius,
                                            x: 0,
                                            y: 1
                                        )
                                }
                            }
                        )
                    }
                }
            }
        }
        .frame(height: Tokens.Sizing.iconButton)
    }

    private func tabLabel(_ tab: Tab) -> String {
        if let tab = tab as? SessionDetailScreen.DetailTab {
            return tab.rawValue
        }
        return "\(tab)"
    }
}

private struct DeleteSessionButton: View {
    let action: () -> Void

    var body: some View {
        AppButton("このセッションを削除", icon: "trash", style: .destructive, action: action)
            .padding(.horizontal, Tokens.Spacing.xl)
    }
}

private struct SessionModeBadge: View {
    let type: SessionType

    private var title: String {
        type == .lecture ? "講義" : "会議"
    }

    private var gradient: LinearGradient {
        type == .lecture ? Tokens.Gradients.lecture : Tokens.Gradients.meeting
    }

    var body: some View {
        Text(title)
            .font(Tokens.Typography.caption())
            .foregroundStyle(Tokens.Color.surface)
            .padding(.horizontal, Tokens.Spacing.sm)
            .padding(.vertical, Tokens.Spacing.xxs)
            .background(gradient)
            .clipShape(Capsule())
    }
}

private struct SessionMetaStat: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
            HStack(spacing: Tokens.Spacing.xxs) {
                Image(systemName: icon)
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Tokens.Color.textSecondary)
                AppText(title, style: .caption, color: Tokens.Color.textSecondary)
            }
            AppText(value, style: .body, color: Tokens.Color.textPrimary)
        }
    }
}

private struct StatusChip: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: Tokens.Spacing.xxs) {
            AppText(title, style: .caption, color: Tokens.Color.textSecondary)
            AppText(value, style: .caption, color: color)
        }
        .padding(.horizontal, Tokens.Spacing.xs)
        .padding(.vertical, Tokens.Spacing.xxs)
        .background(Tokens.Color.surface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
        )
    }
}

private struct StatusIcon: View {
    let name: String
    let isActive: Bool

    var body: some View {
        Image(systemName: name)
            .font(Tokens.Typography.caption())
            .foregroundStyle(isActive ? Tokens.Color.accent : Tokens.Color.textTertiary)
    }
}

private struct SessionInfoSheet: View {
    let session: Session
    let reactionsSummary: ReactionsSummary
    let myReaction: ReactionType?
    let shareLabel: String?
    let audioStatusText: String
    let transcriptStatusText: String
    let summaryStatusText: String
    let quizStatusText: String
    let transcriptStatusColor: Color
    let summaryStatusColor: Color
    let quizStatusColor: Color
    let onReaction: (ReactionType) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.lg) {
                    AppText("セッション情報", style: .screenTitle)

                    AppCard {
                        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                            HStack(spacing: Tokens.Spacing.sm) {
                                SessionModeBadge(type: session.type)
                                AppText(session.dateFormatted, style: .caption, color: Tokens.Color.textSecondary)
                                Spacer()
                                if let shareLabel {
                                    AppText(shareLabel, style: .caption, color: Tokens.Color.textSecondary)
                                }
                            }

                            HStack(spacing: Tokens.Spacing.lg) {
                                SessionMetaStat(
                                    icon: "clock",
                                    title: "録音時間",
                                    value: session.durationFormatted
                                )
                                SessionMetaStat(
                                    icon: "waveform",
                                    title: "音声",
                                    value: audioStatusText
                                )
                            }

                            HStack(spacing: Tokens.Spacing.xs) {
                                StatusChip(title: "文字起こし", value: transcriptStatusText, color: transcriptStatusColor)
                                StatusChip(title: "要約", value: summaryStatusText, color: summaryStatusColor)
                                StatusChip(title: "テスト", value: quizStatusText, color: quizStatusColor)
                            }
                        }
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                            AppText("リアクション", style: .sectionTitle)
                            ReactionsRow(summary: reactionsSummary, myReaction: myReaction) { type in
                                onReaction(type)
                            }
                        }
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                            AppText("タグ", style: .sectionTitle)
                            if let tags = session.tags, !tags.isEmpty {
                                HStack(spacing: Tokens.Spacing.xs) {
                                    ForEach(tags, id: \.self) { tag in
                                        TextPill("#\(tag)", color: Tokens.Color.textSecondary)
                                    }
                                }
                            } else {
                                AppText("タグはまだありません", style: .caption, color: Tokens.Color.textSecondary)
                            }
                        }
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                            AppText("参加者", style: .sectionTitle)
                            let members = sortedMembers
                            if !members.isEmpty {
                                VStack(spacing: Tokens.Spacing.xs) {
                                    ForEach(members) { member in
                                        HStack(spacing: Tokens.Spacing.sm) {
                                            Circle()
                                                .fill(Tokens.Color.surface)
                                                .frame(width: Tokens.Sizing.avatarSmall, height: Tokens.Sizing.avatarSmall)
                                                .overlay(AppText(member.initials, style: .dateCaps))
                                                .overlay(
                                                    Circle()
                                                        .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                                                )

                                            AppText("@\(member.username)", style: .body)
                                            Spacer()
                                            if member.role == .owner {
                                                AppText("オーナー", style: .caption, color: Tokens.Color.textSecondary)
                                            }
                                        }
                                    }
                                }
                            } else {
                                AppText("参加者はまだいません", style: .caption, color: Tokens.Color.textSecondary)
                            }
                        }
                    }

                    AppCard {
                        AppButton("このセッションを削除", icon: "trash", style: .destructive) {
                            dismiss()
                            onDelete()
                        }
                    }
                }
                .padding(Tokens.Spacing.screenHorizontal)
            }
            .navigationTitle("情報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var sortedMembers: [SessionMember] {
        guard let members = session.members else { return [] }
        return members.sorted { lhs, rhs in
            if lhs.role == rhs.role { return lhs.username < rhs.username }
            return lhs.role == .owner
        }
    }
}

private struct CompressedImage {
    enum Format {
        case heic
        case jpeg
    }

    let data: Data
    let mimeType: String
    let fileExtension: String
    let format: Format
}

private enum ImageCompressionError: Error {
    case encodingFailed
}

private enum ImageCompressor {
    static func compress(
        image: UIImage,
        preferHeic: Bool,
        maxPixel: CGFloat = 2048,
        heicQuality: CGFloat = 0.7,
        jpegQuality: CGFloat = 0.82
    ) throws -> CompressedImage {
        let resized = resizedImage(from: image, maxPixel: maxPixel)
        if preferHeic, let heicData = encodeHEIC(from: resized, quality: heicQuality) {
            return CompressedImage(data: heicData, mimeType: "image/heic", fileExtension: "heic", format: .heic)
        }
        if let jpegData = resized.jpegData(compressionQuality: jpegQuality) {
            return CompressedImage(data: jpegData, mimeType: "image/jpeg", fileExtension: "jpg", format: .jpeg)
        }
        throw ImageCompressionError.encodingFailed
    }

    private static func encodeHEIC(from image: UIImage, quality: CGFloat) -> Data? {
        guard #available(iOS 11.0, *) else { return nil }
        guard let cgImage = image.cgImage else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.heic.identifier as CFString, 1, nil) else {
            return nil
        }
        let props = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(dest, cgImage, props)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    private static func resizedImage(from image: UIImage, maxPixel: CGFloat) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let maxSide = max(pixelWidth, pixelHeight)
        guard maxSide > maxPixel else { return image }
        let ratio = maxPixel / maxSide
        let newSize = CGSize(width: pixelWidth * ratio, height: pixelHeight * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
