import Foundation
import FirebaseAuth
import GoogleSignIn
import UIKit
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoadingProvider: AuthProvider?
    @Published var errorMessage: String?

    func signInWithGoogle() {
        guard isLoadingProvider == nil else { return }
        isLoadingProvider = .google
        Task {
            do {
                guard let rootVC = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive })?
                    .keyWindow?
                    .rootViewController else {
                    throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "ログイン画面を取得できませんでした"])
                }

                let result = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: rootVC,
                    hint: nil,
                    additionalScopes: []
                )

                guard let idToken = result.user.idToken?.tokenString else {
                    throw NSError(domain: "Auth", code: -2, userInfo: [NSLocalizedDescriptionKey: "IDトークンが取得できませんでした"])
                }

                let accessToken = result.user.accessToken.tokenString
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
                _ = try await Auth.auth().signIn(with: credential)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoadingProvider = nil
        }
    }

    func signInWithApple() {
        guard isLoadingProvider == nil else { return }
        isLoadingProvider = .apple
        Task {
            do {
                try await FirebaseManager.shared.startSignInWithApple()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoadingProvider = nil
        }
    }

    func signInWithLine() {
        guard isLoadingProvider == nil else { return }
        isLoadingProvider = .line
        Task {
            do {
                try await FirebaseManager.shared.startSignInWithLine()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoadingProvider = nil
        }
    }
}
