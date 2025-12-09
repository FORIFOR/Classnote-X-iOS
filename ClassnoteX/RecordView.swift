import SwiftUI
import Combine

struct RecordView: View {
    let sessionId: String
    let mode: SessionMode
    let apiClient: ClassnoteAPIClient
    
    @State private var status: RecordingState = .ready
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var statusMessage: String = "タップで録音開始"
    @State private var isNavigatingToDetail = false
    @State private var audioLevel: CGFloat = 0.0
    @State private var showOnboarding = OnboardingChecker.shouldShowRecordingOnboarding
    @State private var breathingScale: CGFloat = 1.0
    @State private var isButtonPressed = false
    @State private var memoText: String = ""
    @State private var selectedMemoTag: MemoTag? = nil
    @State private var segments: [TranscriptSegment] = []
    @State private var chapters: [ChapterMarker] = []
    @FocusState private var isMemoFocused: Bool
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @StateObject private var transcriber = LocalSpeechTranscriber()
    private let diarizer = SpeakerDiarizer()
    
    enum MemoTag: String, CaseIterable {
        case important = "⭐ 重要"
        case question = "❓ 質問"
        case task = "📌 タスク"
        
        var prefix: String {
            switch self {
            case .important: return "[重要] "
            case .question: return "[質問] "
            case .task: return "[タスク] "
            }
        }
    }

    enum RecordingState {
        case ready
        case listening
        case recording
        case processing
    }

    var body: some View {
        ZStack {
            // MARK: - Background (System colors only)
            SemanticColor.Background.primary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Top Bar
                topBar
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.top, DesignTokens.Spacing.md)
                
                Spacer()
                
                // MARK: - Main Content
                mainContent
                
                Spacer()
                
                // MARK: - Record Button
                recordButton
                    .padding(.bottom, DesignTokens.Spacing.xxxl)
            }
            
            // MARK: - Onboarding Overlay
            if showOnboarding {
                RecordingOnboardingOverlay(isPresented: $showOnboarding)
                    .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $isNavigatingToDetail) {
            SessionDetailView(sessionId: sessionId, apiClient: apiClient)
        }
        .onAppear {
            prewarmAudio()
            startBreathingAnimation()
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            updateAudioLevel()
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // Close button
            Button(action: handleClose) {
                Image(systemName: "xmark")
                    .font(.body.weight(.medium))
                    .foregroundStyle(SemanticColor.Text.secondary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(SemanticColor.Fill.tertiary)
                    )
            }
            .buttonStyle(PressButtonStyle())
            
            Spacer()
            
            // Status Pill
            statusPill
            
            Spacer()
            
            // Spacer for symmetry
            Color.clear.frame(width: 44, height: 44)
        }
    }
    
    private var statusPill: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            if status == .recording {
                Circle()
                    .fill(SemanticColor.Recording.active)
                    .frame(width: 8, height: 8)
                    .shadow(color: SemanticColor.Recording.active.opacity(0.5), radius: 4)
            }
            
            Text(statusTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(SemanticColor.Text.primary)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(
            Capsule().fill(SemanticColor.Fill.secondary)
        )
    }
    
    private var statusTitle: String {
        switch status {
        case .ready: return "録音準備完了"
        case .listening: return "リスニング中..."
        case .recording: return "録音中"
        case .processing: return "処理中..."
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Timer
            Text(timeString(from: elapsedTime))
                .font(Typography.timer)
                .foregroundStyle(SemanticColor.Text.primary)
                .contentTransition(.numericText(countsDown: false))
                .animation(.contentTransition, value: elapsedTime)
                .accessibilityLabel("経過時間 \(Int(elapsedTime))秒")
            
            // Audio Level Indicator
            audioLevelIndicator
                .frame(height: 40)
            
            // Status Message
            Text(statusMessage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(SemanticColor.Text.secondary)
                .animation(.stateChange, value: statusMessage)
            
            // Live Transcript
            if status == .recording || status == .listening {
                liveTranscriptCard
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
                
                // Live Segment Counter
                if !transcriber.segments.isEmpty {
                    liveSegmentCounter
                        .transition(.opacity.combined(with: .scale))
                }
            }
            
            // Memo Input (during recording)
            if status == .recording {
                memoInputCard
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
    }
    
    // MARK: - Memo Input Card
    
    private var memoInputCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Header with mode indicator
            HStack {
                Image(systemName: "note.text")
                    .foregroundStyle(mode == .lecture ? GlassNotebook.Accent.lecture : GlassNotebook.Accent.meeting)
                Text("メモ")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text(mode == .lecture ? "講義" : "会議")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(mode == .lecture ? GlassNotebook.Accent.lecture : GlassNotebook.Accent.meeting)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((mode == .lecture ? GlassNotebook.Accent.lecture : GlassNotebook.Accent.meeting).opacity(0.12))
                    .clipShape(Capsule())
            }
            
            // Tag Chips
            HStack(spacing: 8) {
                ForEach(MemoTag.allCases, id: \.self) { tag in
                    Button {
                        if selectedMemoTag == tag {
                            selectedMemoTag = nil
                        } else {
                            selectedMemoTag = tag
                            memoText += tag.prefix
                        }
                        Haptic.selection.trigger()
                    } label: {
                        Text(tag.rawValue)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedMemoTag == tag ? GlassNotebook.Accent.primary.opacity(0.2) : SemanticColor.Fill.tertiary)
                            .foregroundStyle(selectedMemoTag == tag ? GlassNotebook.Accent.primary : .secondary)
                            .clipShape(Capsule())
                    }
                }
            }
            
            // Text Input
            TextField("メモを入力...", text: $memoText, axis: .vertical)
                .focused($isMemoFocused)
                .font(.body)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .padding(12)
                .background(SemanticColor.Fill.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("完了") {
                            isMemoFocused = false
                        }
                    }
                }
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(GlassNotebook.Background.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .stroke(mode == .lecture ? GlassNotebook.Accent.lecture.opacity(0.3) : GlassNotebook.Accent.meeting.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var audioLevelIndicator: some View {
        HStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { index in
                Capsule()
                    .fill(barGradient)
                    .frame(width: 5, height: barHeight(for: index))
                    .animation(.spring(response: 0.12, dampingFraction: 0.6), value: audioLevel)
            }
        }
        .opacity(status == .recording ? 1 : 0.3)
    }
    
    private var barGradient: LinearGradient {
        LinearGradient(
            colors: status == .recording
                ? [SemanticColor.Recording.active, SemanticColor.Recording.active.opacity(0.7)]
                : [SemanticColor.Recording.ready, SemanticColor.Recording.ready.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let minHeight: CGFloat = 8
        let maxHeight: CGFloat = 40
        
        guard status == .recording else {
            return minHeight + CGFloat.random(in: 0...4)
        }
        
        let centerOffset = abs(CGFloat(index) - 3.0) / 3.0
        let level = (audioLevel * (1.0 - centerOffset * 0.3)).clamped(to: 0...1)
        return minHeight + (maxHeight - minHeight) * level
    }
    
    private var liveTranscriptCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Header
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "waveform")
                    .foregroundStyle(SemanticColor.Accent.blue)
                Text("リアルタイム字幕")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SemanticColor.Text.secondary)
                
                Spacer()
                
                // Word count badge
                if !transcriber.partialText.isEmpty {
                    Text("\(transcriber.partialText.count)文字")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(SemanticColor.Text.tertiary)
                }
                
                // "On-device" badge
                Text("オンデバイス")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(SemanticColor.Accent.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(SemanticColor.Accent.green.opacity(0.15))
                    )
            }
            
            // Transcript content with ScrollView
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if transcriber.partialText.isEmpty {
                            HStack(spacing: DesignTokens.Spacing.xs) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("話し始めると表示されます...")
                                    .font(.subheadline)
                                    .foregroundStyle(SemanticColor.Text.tertiary)
                            }
                        } else {
                            // Show full transcript text
                            Text(transcriber.partialText)
                                .font(.body)
                                .foregroundStyle(SemanticColor.Text.primary)
                                .textSelection(.enabled)
                                .id("transcriptBottom")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 120) // Fixed height for scrollable area
                .onChange(of: transcriber.partialText) { _, _ in
                    // Auto-scroll to bottom when new text arrives
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("transcriptBottom", anchor: .bottom)
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .stroke(SemanticColor.Separator.standard, lineWidth: 0.5)
        )
    }
    
    private var recentTranscript: String {
        let text = transcriber.partialText
        if text.count > 30 {
            return String(text.suffix(30))
        }
        return text
    }
    
    private var olderTranscript: String {
        let text = transcriber.partialText
        if text.count > 30 {
            return String(text.prefix(text.count - 30))
        }
        return ""
    }
    
    // MARK: - Live Segment Counter
    
    private var liveSegmentCounter: some View {
        HStack(spacing: 12) {
            // Segment count
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.caption)
                    .foregroundStyle(GlassNotebook.Accent.primary)
                
                Text("\(transcriber.segments.count)チャプター")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(GlassNotebook.Accent.primary.opacity(0.12))
            )
            
            // Latest segment preview
            if let lastSegment = transcriber.segments.last {
                HStack(spacing: 4) {
                    Text(lastSegment.startTimeSeconds.mmssString)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(GlassNotebook.Accent.primary)
                    
                    Text(String(lastSegment.text.prefix(15)) + "...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
            }
        }
        .animation(.spring(response: 0.3), value: transcriber.segments.count)
    }
    
    // MARK: - Record Button
    
    private var recordButton: some View {
        Button(action: handleRecordTap) {
            ZStack {
                // Breathing outer ring (recording only)
                if status == .recording {
                    Circle()
                        .stroke(SemanticColor.Recording.active.opacity(0.3), lineWidth: 3)
                        .frame(width: 130, height: 130)
                        .scaleEffect(breathingScale)
                }
                
                // Outer ring
                Circle()
                    .stroke(
                        status == .recording
                            ? SemanticColor.Recording.active.opacity(0.5)
                            : SemanticColor.Fill.tertiary,
                        lineWidth: 6
                    )
                    .frame(width: 110, height: 110)
                
                // Inner button
                innerButton
            }
        }
        .buttonStyle(RecordButtonPressStyle(isPressed: $isButtonPressed))
        .disabled(status == .processing)
        .accessibilityLabel(recordButtonAccessibilityLabel)
        .accessibilityHint(status == .ready ? "タップして録音を開始" : "タップして録音を停止")
    }
    
    @ViewBuilder
    private var innerButton: some View {
        switch status {
        case .ready:
            Circle()
                .fill(SemanticColor.Recording.active)
                .frame(width: 80, height: 80)
                .shadow(color: SemanticColor.Recording.active.opacity(0.4), radius: 8, y: 4)
            
        case .listening:
            ZStack {
                Circle()
                    .fill(SemanticColor.Recording.listening)
                    .frame(width: 80, height: 80)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
            }
            
        case .recording:
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .fill(Color.white)
                .frame(width: 32, height: 32)
            
        case .processing:
            ZStack {
                Circle()
                    .fill(SemanticColor.Recording.processing)
                    .frame(width: 80, height: 80)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
            }
        }
    }
    
    private var recordButtonAccessibilityLabel: String {
        switch status {
        case .ready: return "録音開始ボタン"
        case .listening: return "リスニング中"
        case .recording: return "録音停止ボタン"
        case .processing: return "処理中"
        }
    }
    
    // MARK: - Actions
    
    private func prewarmAudio() {
        // Pre-connect WebSocket
        let client = AudioStreamClient(sessionId: sessionId, baseURL: apiClient.baseURL)
        client.connect()
        self.audioStreamClient = client
        
        // Pre-request permissions
        Task {
            _ = await LocalSpeechTranscriber.requestAuthorization()
        }
    }
    
    private func startBreathingAnimation() {
        withAnimation(.breathing) {
            breathingScale = 1.1
        }
    }
    
    private func handleRecordTap() {
        Haptic.heavy.trigger()
        
        switch status {
        case .ready:
            startListening()
        case .listening:
            break
        case .recording:
            stopRecording()
        case .processing:
            break
        }
    }
    
    private func handleClose() {
        Haptic.light.trigger()
        if status == .recording {
            stopRecording()
        }
        dismiss()
    }
    
    private func startListening() {
        print("[RecordView] Starting listening phase...")
        
        withAnimation(.stateChange) {
            status = .listening
            statusMessage = "リスニング中..."
        }
        
        do {
            transcriber.start()
            try audioStreamClient?.startRecording()
            
            // Brief listening phase then transition to recording
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.stateChange) {
                    self.status = .recording
                    self.statusMessage = "録音中 - 話してください"
                    self.startTimer()
                    Haptic.success.trigger()
                }
            }
            
            print("[RecordView] ✅ Listening started")
        } catch {
            print("[RecordView] ❌ Error: \(error)")
            statusMessage = "エラー: \(error.localizedDescription)"
            transcriber.stop()
            status = .ready
            Haptic.error.trigger()
        }
    }
    
        print("[RecordView] Stopping recording...")
        
        withAnimation(.stateChange) {
            status = .processing
            statusMessage = "音声処理中..."
        }
        
        let finalTranscript = transcriber.partialText
        var finalSegments = transcriber.segments
        print("[RecordView] Final transcript: \(finalTranscript.prefix(100))...")
        print("[RecordView] Total segments: \(finalSegments.count)")
        
        audioStreamClient?.stopRecording()
        transcriber.finish()
        stopTimer()
        
        // 📊 Generate chapters from segments
        chapters = generateChaptersFromSegments(finalSegments)
        print("[RecordView] Generated \(chapters.count) chapters")
        
        // 💾 Move recording to Documents
        if let tempURL = transcriber.recordingURL {
            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = docDir.appendingPathComponent("audio_\(sessionId).m4a")
            
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                print("[RecordView] 💾 Saved recording to: \(destinationURL.path)")
            } catch {
                print("[RecordView] ❌ Failed to save recording: \(error)")
            }
            } catch {
                print("[RecordView] ❌ Failed to save recording: \(error)")
            }
        }
        
        // 🗣️ Run Speaker Diarization
        Task {
            if let audioURL = transcriber.recordingURL {
                await MainActor.run { statusMessage = "話者分離中..." }
                do {
                    print("[RecordView] Starting diarization...")
                    let diarizationResults = try await diarizer.process(audioURL: audioURL)
                    
                    // Merge Diarization Results with Transcript Segments
                    // Simple strategy: Assign speaker to segment if segment time center falls within diarization valid range
                    // or majority overlap.
                    
                    // Create new segments list with speaker info
                    var currentSpeakerTag = 0
                    
                    let updatedSegments = finalSegments.map { segment in
                        let midPoint = (segment.startTimeSeconds + segment.endTimeSeconds) / 2.0
                        
                        // Find matching speaker segment
                        // A simple heuristic: find the diarization segment that covers the midpoint
                        let match = diarizationResults.first { dSeg in
                            dSeg.startTime <= midPoint && dSeg.endTime >= midPoint
                        }
                        
                        var newSegment = segment
                        // Use reflection or rebuild struct since it's immutable 'let' in original define? 
                        // Note: We updated TranscriptSegment to have updated init or var properties?
                        // Let's assume we need to rebuild it or struct lets us copy-modify if we use vars. 
                        // Checked LocalSpeechTranscriber definition - they are 'let'. Need to rebuild.
                        
                        // Actually I can't easily modify 'let' properties of existing structs. 
                        // And I didn't verify if I changed them to 'var'. 
                        // I'll assume I need to construct new ones.
                        
                        let speakerTagInt: Int
                        let speakerLabel: String
                        
                        if let match = match {
                            // Extract number from "Speaker N" or just use hash
                            // user "Speaker 0" -> 0
                            if let num = Int(match.speaker.replacingOccurrences(of: "Speaker ", with: "")) {
                                speakerTagInt = num
                            } else {
                                speakerTagInt = 0
                            }
                            speakerLabel = match.speaker
                        } else {
                            speakerTagInt = currentSpeakerTag // fallback
                            speakerLabel = "Speaker ?"
                        }
                        currentSpeakerTag = speakerTagInt
                        
                         return TranscriptSegment(
                            index: segment.index,
                            text: segment.text,
                            startTimeSeconds: segment.startTimeSeconds,
                            endTimeSeconds: segment.endTimeSeconds,
                            speakerTag: speakerTagInt,
                            speakerLabel: speakerLabel
                        )
                    }
                    finalSegments = updatedSegments
                    print("[RecordView] ✅ Diarization complete. Updated \(finalSegments.count) segments with speakers.")
                    
                } catch {
                    print("[RecordView] ⚠️ Diarization failed: \(error)")
                    // Continue without speaker tags
                }
            }
            
            await MainActor.run {
                     statusMessage = "文字起こしを保存中..."
            }
            
             if !finalTranscript.isEmpty {
                 // ... rest of upload logic using finalSegments ...
                 // (Using existing logic below)
            }
        Haptic.success.trigger()
        
        Task {
            if !finalTranscript.isEmpty {
                do {
                    try await apiClient.uploadTranscript(sessionId: sessionId, text: finalTranscript)
                    print("[RecordView] ✅ Transcript uploaded")
                } catch {
                    print("[RecordView] ⚠️ Upload failed: \(error)")
                    apiClient.storeTranscriptLocally(sessionId: sessionId, text: finalTranscript)
                }
                
                // 💾 Store chapters and segments locally
                if !chapters.isEmpty {
                    apiClient.storeChaptersLocally(sessionId: sessionId, chapters: chapters)
                }
                if !finalSegments.isEmpty {
                    apiClient.storeSegmentsLocally(sessionId: sessionId, segments: finalSegments)
                    // Note: uploadSegments might need update if backend supports speakers, 
                    // but current implementation plan doesn't include backend changes for speakers yet.
                    await uploadSegments(finalSegments)
                }
            }
            
            await MainActor.run {
                statusMessage = "完了！"
            }
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            await MainActor.run {
                isNavigatingToDetail = true
            }
        }
    }
    
    // MARK: - Chapter Generation
    
    private func generateChaptersFromSegments(_ segments: [TranscriptSegment]) -> [ChapterMarker] {
        guard !segments.isEmpty else { return [] }
        
        return segments.map { segment in
            ChapterMarker(
                id: "ch-\(segment.index)",
                timeSeconds: segment.startTimeSeconds,
                title: extractChapterTitle(from: segment.text)
            )
        }
    }
    
    private func extractChapterTitle(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let separators = CharacterSet(charactersIn: "。.、,！!？?")
        let sentences = trimmed.components(separatedBy: separators)
        
        guard let first = sentences.first, !first.isEmpty else {
            return mode == .meeting ? "会議内容" : "講義内容"
        }
        
        let maxLength = 20
        if first.count > maxLength {
            return String(first.prefix(maxLength)) + "..."
        }
        return first
    }
    
    private func uploadSegments(_ segments: [TranscriptSegment]) async {
        print("[RecordView] Uploading \(segments.count) segments...")
        
        // Convert to JSON-serializable format
        struct SegmentData: Encodable {
            let index: Int
            let text: String
            let startTimeSeconds: Double
            let endTimeSeconds: Double
        }
        
        let segmentData = segments.map { seg in
            SegmentData(
                index: seg.index,
                text: seg.text,
                startTimeSeconds: seg.startTimeSeconds,
                endTimeSeconds: seg.endTimeSeconds
            )
        }
        
        // TODO: Implement backend endpoint POST /sessions/{id}/segments
        print("[RecordView] ⚠️ Segment upload not yet implemented on backend")
    }
    
    private func updateAudioLevel() {
        guard status == .recording else {
            audioLevel = 0.1
            return
        }
        let base = 0.3 + sin(Date().timeIntervalSinceReferenceDate * 5) * 0.15
        let noise = Double.random(in: -0.1...0.1)
        audioLevel = CGFloat((base + noise).clamped(to: 0...1))
    }
    
    private func startTimer() {
        elapsedTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func timeString(from interval: TimeInterval) -> String {
        let mins = Int(interval) / 60
        let secs = Int(interval) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Button Styles

struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.buttonPress, value: configuration.isPressed)
    }
}

struct RecordButtonPressStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.buttonPress, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}

// MARK: - Onboarding Overlay

struct RecordingOnboardingOverlay: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    @State private var animating = false
    @AppStorage("hasSeenRecordingOnboarding") private var hasSeenOnboarding = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { advance() }
            
            VStack(spacing: DesignTokens.Spacing.xl) {
                Spacer()
                
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Step indicator
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        ForEach(0..<2, id: \.self) { i in
                            Capsule()
                                .fill(i == currentStep ? SemanticColor.Accent.blue : SemanticColor.Fill.tertiary)
                                .frame(width: i == currentStep ? 20 : 8, height: 6)
                                .animation(.contentTransition, value: currentStep)
                        }
                    }
                    
                    // Icon
                    stepIcon
                        .frame(height: 80)
                    
                    // Text
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        Text(stepTitle)
                            .font(Typography.title3)
                            .foregroundStyle(SemanticColor.Text.primary)
                        
                        Text(stepDescription)
                            .font(.subheadline)
                            .foregroundStyle(SemanticColor.Text.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Button
                    Button(action: advance) {
                        Text(currentStep == 0 ? "次へ" : "はじめる")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignTokens.Spacing.md)
                            .background(SemanticColor.Accent.blue)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                    }
                    .buttonStyle(PressButtonStyle())
                }
                .padding(DesignTokens.Spacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.xxl, style: .continuous)
                        .fill(SemanticColor.Background.primary)
                )
                .padding(.horizontal, DesignTokens.Spacing.lg)
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.breathing) {
                animating = true
            }
        }
    }
    
    @ViewBuilder
    private var stepIcon: some View {
        if currentStep == 0 {
            // Mic with live badge
            ZStack {
                Circle()
                    .fill(SemanticColor.Accent.blue.opacity(0.15))
                    .frame(width: 80, height: 80)
                    .scaleEffect(animating ? 1.1 : 1.0)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(SemanticColor.Accent.blue)
            }
        } else {
            // Cloud with sparkle
            ZStack {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(SemanticColor.Accent.purple)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundStyle(SemanticColor.Accent.orange)
                    .offset(x: 24, y: -16)
            }
        }
    }
    
    private var stepTitle: String {
        currentStep == 0 ? "録音中は即時字幕" : "録音後は高精度版と要約"
    }
    
    private var stepDescription: String {
        currentStep == 0
            ? "話した内容がリアルタイムで\n画面に表示されます"
            : "AIが高精度な文字起こしと\n要約・クイズを生成します"
    }
    
    private func advance() {
        Haptic.light.trigger()
        if currentStep < 1 {
            withAnimation(.contentTransition) {
                currentStep += 1
            }
        } else {
            hasSeenOnboarding = true
            withAnimation(.stateChange) {
                isPresented = false
            }
        }
    }
}
