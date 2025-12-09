import SwiftUI
import GoogleSignInSwift

struct AuthView: View {
    @EnvironmentObject var model: AppModel
    @State private var isGoogleLoading: Bool = false
    @State private var isAppleComingSoon: Bool = false
    @State private var animateHero = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Hero section with gradient background
                    heroSection
                        .frame(minHeight: geometry.size.height * 0.45)
                    
                    // Sign-in options
                    signInSection
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                        .padding(.bottom, 48)
                }
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    AppColors.primaryBlue.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .alert("Apple IDでのサインインは準備中です", isPresented: $isAppleComingSoon) {
            Button("OK", role: .cancel) { }
        }
        .onAppear {
            withAnimation(.gentleSpring.delay(0.2)) {
                animateHero = true
            }
        }
    }

    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Animated app icon
            ZStack {
                // Background glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppColors.primaryBlue.opacity(0.3),
                                AppColors.primaryIndigo.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 120
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 20)
                    .opacity(animateHero ? 1 : 0)
                
                // Icon
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.primaryIndigo, AppColors.primaryBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: AppColors.primaryBlue.opacity(0.3), radius: 20, x: 0, y: 10)
                    .scaleEffect(animateHero ? 1 : 0.8)
                    .opacity(animateHero ? 1 : 0)
            }
            
            VStack(spacing: 12) {
                Text("ClassnoteX")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .opacity(animateHero ? 1 : 0)
                    .offset(y: animateHero ? 0 : 20)
                
                Text("講義と会議を、AIがノートに。")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                    .opacity(animateHero ? 1 : 0)
                    .offset(y: animateHero ? 0 : 20)
            }
            
            // Features preview
            featuresRow
                .opacity(animateHero ? 1 : 0)
                .offset(y: animateHero ? 0 : 20)
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    private var featuresRow: some View {
        HStack(spacing: 20) {
            featureItem(icon: "mic.fill", title: "録音")
            featureItem(icon: "text.alignleft", title: "文字起こし")
            featureItem(icon: "sparkles", title: "要約")
        }
        .padding(.top, 16)
    }
    
    private func featureItem(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppColors.primaryBlue)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(AppColors.primaryBlue.opacity(0.1))
                )
            
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Sign-in Section
    
    private var signInSection: some View {
        VStack(spacing: 20) {
            // Section header
            VStack(spacing: 8) {
                Text("はじめましょう")
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("アカウントでサインインして、録音データをクラウドに同期できます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            VStack(spacing: 14) {
                // Google Sign-in
                googleSignInButton
                
                // Apple Sign-in (coming soon)
                appleSignInButton
            }
            
            // Privacy note
            Text("サインインすると、利用規約とプライバシーポリシーに同意したことになります。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 8)
        )
    }
    
    private var googleSignInButton: some View {
        Button {
            guard !isGoogleLoading else { return }
            triggerHaptic(.medium)
            isGoogleLoading = true
            Task {
                await model.signInWithGoogle()
                await MainActor.run { isGoogleLoading = false }
            }
        } label: {
            HStack(spacing: 12) {
                if isGoogleLoading {
                    ProgressView()
                        .tint(.primary)
                } else {
                    Image("google_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .opacity(0) // Placeholder, using SF Symbol instead
                        .overlay(
                            Image(systemName: "g.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.primary)
                        )
                }
                
                Text(isGoogleLoading ? "サインイン中..." : "Googleで続ける")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(.separator), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isGoogleLoading)
        .accessibilityIdentifier("googleSignInButton")
    }
    
    private var appleSignInButton: some View {
        Button {
            triggerHaptic(.light)
            isAppleComingSoon = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "apple.logo")
                    .font(.title2)
                
                Text("Appleで続ける")
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black)
            )
            .overlay(
                // "準備中" badge
                Text("準備中")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange))
                    .offset(x: 60, y: -20)
                , alignment: .topTrailing
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("appleSignInButton")
    }
}
