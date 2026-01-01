import SwiftUI

struct RecordingSheet: View {
    @Binding var selectedDetent: PresentationDetent
    @EnvironmentObject private var recording: RecordingCoordinator
    @State private var sheetTab: SheetTab = .transcript
    @State private var autoScroll: Bool = true
    @State private var memoDraft: String = ""
    @FocusState private var isMemoFocused: Bool

    enum SheetTab: String, CaseIterable {
        case transcript = "文字起こし"
        case memo = "メモ"
        case insights = "要点"
    }

    var body: some View {
        VStack(spacing: Tokens.Spacing.sm) {
            // Compact header with time and status
            compactHeader

            // Main recording visualization
            mainRecordingView

            // Transcript section (simplified)
            if isLarge {
                tabSelector
                content
            } else {
                simpleTranscriptPreview
            }

            Spacer(minLength: 0)

            // Control buttons at bottom
            controlButtons
        }
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
        .padding(.top, Tokens.Spacing.sm)
        .padding(.bottom, Tokens.Spacing.xs)
        .onAppear {
            memoDraft = recording.memoText
        }
        .onChange(of: recording.memoText) { _, newValue in
            if memoDraft != newValue {
                memoDraft = newValue
            }
        }
    }

    // MARK: - Compact Header

    private var compactHeader: some View {
        HStack(alignment: .center) {
            // Recording status indicator
            HStack(spacing: Tokens.Spacing.xs) {
                RecordingPulseDot(isActive: !recording.isPaused)
                Text(recording.isPaused ? "一時停止" : "録音中")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Tokens.Color.textSecondary)
            }

            Spacer()

            // Menu button
            Menu {
                Button("シートを閉じる") {
                    recording.isSheetPresented = false
                }
                Button(role: .destructive) {
                    recording.requestStop()
                } label: {
                    Label("録音を破棄", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(Tokens.Typography.body())
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .frame(width: 32, height: 32)
            }
        }
    }

    // MARK: - Main Recording View

    private var mainRecordingView: some View {
        VStack(spacing: Tokens.Spacing.md) {
            // Large elapsed time display
            Text(formatTime(recording.elapsed))
                .font(.system(size: 56, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Tokens.Color.textPrimary)

            // Waveform visualization
            RecordingWaveform(level: recording.audioLevel, isPaused: recording.isPaused)
                .frame(height: 48)
                .padding(.horizontal, Tokens.Spacing.md)

            // Live AI Features Status
            liveAIStatusSection
        }
        .padding(.vertical, Tokens.Spacing.md)
    }

    // MARK: - Live AI Status Section

    private var liveAIStatusSection: some View {
        HStack(spacing: Tokens.Spacing.md) {
            // Transcription status
            LiveFeatureChip(
                icon: "waveform",
                label: "文字起こし",
                isActive: !recording.isPaused,
                hasContent: !transcriptLines.isEmpty || !recording.partialTranscript.isEmpty
            )

            // Speaker diarization status
            LiveFeatureChip(
                icon: "person.2.fill",
                label: "話者分離",
                isActive: !recording.isPaused,
                hasContent: !transcriptLines.isEmpty
            )
        }
    }

    // MARK: - Simple Transcript Preview (for medium detent)

    private var simpleTranscriptPreview: some View {
        AppCard {
            VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                HStack(spacing: Tokens.Spacing.xs) {
                    Image(systemName: "waveform")
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Tokens.Color.textSecondary)
                    Text("文字起こし")
                        .font(Tokens.Typography.sectionTitle())
                        .foregroundStyle(Tokens.Color.textPrimary)
                    Spacer()
                    if !recording.partialTranscript.isEmpty || !transcriptLines.isEmpty {
                        BlinkingDots()
                    }
                }

                if let lastLine = displayLines.last {
                    Text(lastLine.text)
                        .font(Tokens.Typography.body())
                        .foregroundStyle(Tokens.Color.textPrimary)
                        .lineLimit(2)
                } else {
                    Text("音声を待機中...")
                        .font(Tokens.Typography.body())
                        .foregroundStyle(Tokens.Color.textTertiary)
                }
            }
        }
        .frame(maxHeight: 100)
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        VStack(spacing: Tokens.Spacing.sm) {
            // Main action buttons
            HStack(spacing: Tokens.Spacing.sm) {
                // Pause/Resume button
                Button {
                    Haptics.light()
                    recording.togglePause()
                } label: {
                    HStack(spacing: Tokens.Spacing.xs) {
                        Image(systemName: recording.isPaused ? "play.fill" : "pause.fill")
                        Text(recording.isPaused ? "再開" : "一時停止")
                    }
                    .font(Tokens.Typography.button())
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Tokens.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                            .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                    )
                }
                .buttonStyle(.plain)

                // Stop button
                Button {
                    Haptics.medium()
                    recording.requestStop()
                } label: {
                    HStack(spacing: Tokens.Spacing.xs) {
                        Image(systemName: "stop.fill")
                        Text("完了")
                    }
                    .font(Tokens.Typography.button())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Tokens.Color.destructive)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            // Quick actions row
            HStack(spacing: Tokens.Spacing.sm) {
                // Marker button
                Button {
                    Haptics.light()
                    recording.addTag(label: "マーカー")
                } label: {
                    HStack(spacing: Tokens.Spacing.xxs) {
                        Image(systemName: "flag.fill")
                        Text("マーカー")
                    }
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .padding(.horizontal, Tokens.Spacing.sm)
                    .frame(height: 32)
                    .background(Tokens.Color.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin))
                }
                .buttonStyle(.plain)

                // Recent tags
                if !recording.liveTags.isEmpty {
                    ForEach(recording.liveTags.suffix(2), id: \.self) { tag in
                        TextPill("#\(tag)", color: Tokens.Color.accent)
                    }
                }

                Spacer()
            }
        }
    }

    private var transcriptLines: [TranscriptLine] {
        recording.transcriptLines
    }

    private var isLarge: Bool {
        selectedDetent == .large
    }

    private var tabSelector: some View {
        Picker("録音シート", selection: $sheetTab) {
            ForEach(SheetTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var content: some View {
        switch sheetContent {
        case .transcript:
            transcriptSection
        case .memo:
            memoSection
        case .insights:
            insightsSection
        }
    }

    private var sheetContent: SheetTab {
        isLarge ? sheetTab : .transcript
    }

    private var transcriptSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                HStack(spacing: Tokens.Spacing.xs) {
                    Image(systemName: "waveform")
                        .font(Tokens.Typography.iconMedium())
                        .foregroundStyle(Tokens.Color.textSecondary)
                    Text("ライブ文字起こし")
                        .font(Tokens.Typography.sectionTitle())
                        .foregroundStyle(Tokens.Color.textPrimary)

                    Spacer()

                    HStack(spacing: Tokens.Spacing.xs) {
                        TextPill(autoScroll ? "自動" : "手動", color: autoScroll ? Tokens.Color.accent : Tokens.Color.textSecondary)
                        Toggle("", isOn: $autoScroll)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Tokens.Color.accent))
                    }
                }

                TranscriptList(
                    lines: displayLines,
                    autoScroll: autoScroll
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            Text("メモ")
                .font(Tokens.Typography.sectionTitle())
                .foregroundStyle(Tokens.Color.textPrimary)

            TextEditor(text: $memoDraft)
                .frame(minHeight: memoEditorHeight)
                .padding(Tokens.Spacing.sm)
                .hideScrollContentBackground()
                .background(memoBackground)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                        .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                )
                .focused($isMemoFocused)

            HStack {
                Spacer()
                AppButton("保存", style: .primary) {
                    recording.memoText = memoDraft
                    recording.saveMemo()
                    isMemoFocused = false
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") {
                    recording.memoText = memoDraft
                    recording.saveMemo()
                    isMemoFocused = false
                }
            }
        }
    }

    private var insightsSection: some View {
        AppCard {
            VStack(spacing: Tokens.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(Tokens.Typography.iconMedium())
                    .foregroundStyle(Tokens.Color.textSecondary)
                Text("要点は録音完了後に生成されます")
                    .font(Tokens.Typography.body())
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
            .padding(.vertical, Tokens.Spacing.lg)
            .frame(maxWidth: .infinity)
        }
    }

    private var memoEditorHeight: CGFloat {
        isLarge ? 320 : 280
    }

    private var memoBackground: Color {
        Tokens.Color.surface
    }

    private var qualityLabel: String {
        guard !recording.isPaused else { return "停止中" }
        let level = recording.audioLevel
        if level >= 0.25 { return "良好" }
        if level >= 0.12 { return "普通" }
        if level > 0 { return "低い" }
        return "無音"
    }

    private var displayLines: [DisplayLine] {
        var lines = recording.transcriptLines.map { DisplayLine(text: $0.text, isFinal: $0.isFinal) }
        if !recording.partialTranscript.isEmpty {
            lines.append(DisplayLine(text: recording.partialTranscript, isFinal: false))
        }
        return Array(lines.suffix(10))
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let total = max(0, Int(time))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private extension View {
    @ViewBuilder
    func hideScrollContentBackground() -> some View {
        if #available(iOS 16.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

private struct TranscriptList: View {
    let lines: [DisplayLine]
    let autoScroll: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                    if lines.isEmpty {
                        TranscriptPlaceholder()
                            .padding(.vertical, Tokens.Spacing.lg)
                    } else {
                        ForEach(lines.indices, id: \.self) { index in
                            TranscriptLineRow(line: lines[index])
                                .id(index)
                        }

                        HStack(spacing: Tokens.Spacing.xxs) {
                            BlinkingDots()
                            Text("認識中...")
                                .font(Tokens.Typography.caption())
                                .foregroundStyle(Tokens.Color.textSecondary)
                        }
                        .padding(.horizontal, Tokens.Spacing.cardContent)
                        .padding(.bottom, Tokens.Spacing.sm)
                    }
                }
                .padding(.top, Tokens.Spacing.md)
            }
            .onChange(of: lines.count) { _, _ in
                guard autoScroll else { return }
                if let last = lines.indices.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .frame(minHeight: 220)
    }
}

private struct TranscriptLineRow: View {
    let line: DisplayLine

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.sm) {
            Rectangle()
                .fill(line.isFinal ? Tokens.Color.accent : Tokens.Color.border)
                .frame(width: Tokens.Spacing.xxs)
                .frame(minHeight: Tokens.Spacing.md)
                .clipShape(Capsule())

            Text(line.text)
                .font(Tokens.Typography.body())
                .foregroundStyle(Tokens.Color.textPrimary)
                .lineSpacing(Tokens.Spacing.xxs)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Tokens.Spacing.xxs)
        .padding(.horizontal, Tokens.Spacing.cardContent)
    }
}

private struct TranscriptPlaceholder: View {
    var body: some View {
        VStack(spacing: Tokens.Spacing.sm) {
            Image(systemName: "waveform")
                .font(Tokens.Typography.iconMedium())
                .foregroundStyle(Tokens.Color.textSecondary)
            Text("文字起こしの準備中…")
                .font(Tokens.Typography.body())
                .foregroundStyle(Tokens.Color.textSecondary)
            HStack(spacing: Tokens.Spacing.xxs) {
                BlinkingDots()
                Text("音声待ち")
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct BlinkingDots: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: Tokens.Spacing.xxs) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Tokens.Color.textSecondary)
                    .frame(width: Tokens.Spacing.xxs, height: Tokens.Spacing.xxs)
                    .opacity(dotOpacity(for: index))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever()) {
                phase = 1
            }
        }
    }

    private func dotOpacity(for index: Int) -> Double {
        let base: Double = 0.3
        let wave = abs(sin(Double(phase) * Double.pi + Double(index)))
        return base + (0.7 * wave)
    }
}

private struct RecordingPulseDot: View {
    let isActive: Bool
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(isActive ? Tokens.Color.destructive : Tokens.Color.textSecondary)
            .frame(width: Tokens.Spacing.xs, height: Tokens.Spacing.xs)
            .scaleEffect(isActive && pulse ? 1.2 : 1.0)
            .animation(isActive ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: pulse)
            .onAppear {
                if isActive {
                    pulse = true
                }
            }
            .onChange(of: isActive) { _, value in
                pulse = value
            }
    }
}

private struct AudioQualityMeter: View {
    let level: Float
    let isPaused: Bool

    private var activeBars: Int {
        guard !isPaused else { return 0 }
        if level >= 0.2 { return 3 }
        if level >= 0.1 { return 2 }
        if level > 0.02 { return 1 }
        return 0
    }

    var body: some View {
        HStack(spacing: Tokens.Spacing.xxs) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(index < activeBars ? Tokens.Color.accent : Tokens.Color.border)
                    .frame(width: Tokens.Spacing.xs, height: Tokens.Spacing.sm)
            }
        }
    }
}

private struct RecordingWaveform: View {
    let level: Float
    let isPaused: Bool
    private let bars = 20

    var body: some View {
        HStack(alignment: .center, spacing: Tokens.Spacing.xxs) {
            ForEach(0..<bars, id: \.self) { index in
                Capsule()
                    .fill(isPaused ? Tokens.Color.textSecondary : Tokens.Color.destructive)
                    .frame(width: Tokens.Spacing.xxs, height: barHeight(index: index))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.12), value: level)
    }

    private func barHeight(index: Int) -> CGFloat {
        let base: CGFloat = 4
        let clamped = max(0, min(level, 1))
        let boosted = pow(clamped, 0.45)
        let active = clamped > 0.01 ? max(0.15, boosted) : 0
        let amplitude = CGFloat(isPaused ? 0.08 : active)
        let pattern = 0.6 + (CGFloat(index % 5) * 0.1)
        return base + amplitude * 44 * pattern
    }
}

private struct DisplayLine: Identifiable {
    let id = UUID()
    let text: String
    let isFinal: Bool
}

// MARK: - Live Feature Chip

private struct LiveFeatureChip: View {
    let icon: String
    let label: String
    let isActive: Bool
    let hasContent: Bool

    @State private var pulse = false

    private var statusText: String {
        if !isActive {
            return "停止中"
        } else if hasContent {
            return "処理中"
        } else {
            return "待機中"
        }
    }

    private var statusColor: Color {
        if !isActive {
            return Tokens.Color.textTertiary
        } else if hasContent {
            return Tokens.Color.accent
        } else {
            return Tokens.Color.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            // Animated indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 32, height: 32)

                if isActive {
                    Circle()
                        .fill(statusColor.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .scaleEffect(pulse ? 1.3 : 1.0)
                        .opacity(pulse ? 0 : 1)
                }

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(Tokens.Typography.caption())
                    .fontWeight(.medium)
                    .foregroundStyle(Tokens.Color.textPrimary)

                HStack(spacing: Tokens.Spacing.xxs) {
                    if isActive && hasContent {
                        PulsingDot(color: statusColor)
                    }
                    Text(statusText)
                        .font(Tokens.Typography.dateCaps())
                        .foregroundStyle(statusColor)
                }
            }
        }
        .padding(.horizontal, Tokens.Spacing.sm)
        .padding(.vertical, Tokens.Spacing.xs)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                .stroke(isActive && hasContent ? statusColor.opacity(0.5) : Tokens.Color.border, lineWidth: Tokens.Border.thin)
        )
        .onAppear {
            if isActive {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            } else {
                pulse = false
            }
        }
    }
}

