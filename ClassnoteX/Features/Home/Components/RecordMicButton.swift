import SwiftUI

struct RecordMicButton: View {
    let color: Color
    let isRecording: Bool
    let action: () -> Void
    
    @State private var isPressed: Bool = false
    @State private var pulse = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(color, lineWidth: Tokens.Border.thin)
                    .frame(width: Tokens.Sizing.micOuter, height: Tokens.Sizing.micOuter)
                    .opacity(isRecording ? 0.6 : 1)
                    .scaleEffect(isRecording && pulse ? 1.08 : 1.0)
                    .animation(
                        isRecording ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default,
                        value: pulse
                    )

                Circle()
                    .fill(color)
                    .frame(width: Tokens.Sizing.micInner, height: Tokens.Sizing.micInner)
                    .overlay(
                        Image(systemName: isRecording ? "record.circle.fill" : "mic.fill")
                            .font(Tokens.Typography.iconLarge())
                            .foregroundStyle(Tokens.Color.surface)
                    )
            }
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
        .onAppear {
            if isRecording {
                pulse = true
            }
        }
        .onChange(of: isRecording) { _, value in
            pulse = value
        }
    }
}

// Helper for press state tracking
struct PressableButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                isPressed = pressed
            }
    }
}
