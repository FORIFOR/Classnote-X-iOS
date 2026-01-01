import SwiftUI

/// A unified status indicator for recording state
/// Shows different visual states: recording (blinking), paused (solid), background (icon)
struct RecordingStatusIndicator: View {
    enum StatusType {
        case recording   // Blinking red dot
        case paused      // Solid orange dot
        case background  // Moon icon
    }

    let status: StatusType
    @State private var isBlinking = false

    var body: some View {
        ZStack {
            switch status {
            case .recording:
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .opacity(isBlinking ? 0.4 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isBlinking)
                    .onAppear { isBlinking = true }
                    .onDisappear { isBlinking = false }

            case .paused:
                Circle()
                    .fill(Color.orange)
                    .frame(width: 10, height: 10)

            case .background:
                Image(systemName: "moon.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.Color.accent)
            }
        }
        .frame(width: 16, height: 16)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 24) {
        VStack {
            RecordingStatusIndicator(status: .recording)
            Text("録音中").font(.caption)
        }
        VStack {
            RecordingStatusIndicator(status: .paused)
            Text("一時停止").font(.caption)
        }
        VStack {
            RecordingStatusIndicator(status: .background)
            Text("BG").font(.caption)
        }
    }
    .padding()
}
