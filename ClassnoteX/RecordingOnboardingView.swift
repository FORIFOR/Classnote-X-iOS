import SwiftUI

/// First-time onboarding for recording feature (2 steps, shows once)
struct RecordingOnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    @State private var animateMic = false
    @AppStorage("hasSeenRecordingOnboarding") private var hasSeenOnboarding = false
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    advanceOrDismiss()
                }
            
            VStack(spacing: 32) {
                Spacer()
                
                // Content Card
                VStack(spacing: 24) {
                    // Step indicator
                    HStack(spacing: 8) {
                        ForEach(0..<2, id: \.self) { index in
                            Capsule()
                                .fill(index == currentStep ? Color(.systemBlue) : Color(.systemGray4))
                                .frame(width: index == currentStep ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: currentStep)
                        }
                    }
                    
                    // Icon
                    Group {
                        if currentStep == 0 {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemBlue).opacity(0.15))
                                    .frame(width: 100, height: 100)
                                    .scaleEffect(animateMic ? 1.15 : 1.0)
                                    .opacity(animateMic ? 0.5 : 1.0)
                                
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(Color(.systemBlue))
                            }
                        } else {
                            HStack(spacing: 4) {
                                ForEach(0..<5, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(.systemBlue))
                                        .frame(width: 6, height: waveHeight(for: i))
                                        .animation(
                                            .easeInOut(duration: 0.4)
                                            .repeatForever()
                                            .delay(Double(i) * 0.1),
                                            value: animateMic
                                        )
                                }
                            }
                            .frame(height: 60)
                        }
                    }
                    .frame(height: 100)
                    
                    // Text
                    VStack(spacing: 12) {
                        Text(stepTitle)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(HIGColors.label)
                        
                        Text(stepDescription)
                            .font(.subheadline)
                            .foregroundStyle(HIGColors.secondaryLabel)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Button
                    Button(action: advanceOrDismiss) {
                        Text(currentStep == 0 ? "次へ" : "はじめる")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.systemBlue))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(HIGColors.background)
                )
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                animateMic = true
            }
        }
    }
    
    private var stepTitle: String {
        switch currentStep {
        case 0: return "タップして録音開始"
        case 1: return "自然に話すだけ"
        default: return ""
        }
    }
    
    private var stepDescription: String {
        switch currentStep {
        case 0: return "中央のボタンをタップすると\n録音が始まります"
        case 1: return "AIがリアルタイムで文字起こし。\n句読点も自動で追加されます"
        default: return ""
        }
    }
    
    private func waveHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [20, 35, 50, 35, 20]
        return animateMic ? heights[index] : 15
    }
    
    private func advanceOrDismiss() {
        triggerHaptic(.light)
        if currentStep < 1 {
            withAnimation(.spring(response: 0.35)) {
                currentStep += 1
            }
        } else {
            hasSeenOnboarding = true
            withAnimation(.easeOut(duration: 0.25)) {
                isPresented = false
            }
        }
    }
}

/// Check if onboarding should show
struct OnboardingChecker {
    static var shouldShowRecordingOnboarding: Bool {
        !UserDefaults.standard.bool(forKey: "hasSeenRecordingOnboarding")
    }
}

#Preview {
    RecordingOnboardingView(isPresented: .constant(true))
}
