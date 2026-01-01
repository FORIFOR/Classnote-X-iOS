import Foundation
import FirebaseAuth
import FirebaseCore
import AuthenticationServices
import CryptoKit
import UIKit
import Combine
import LineSDK

// MARK: - LINE Login Configuration
enum LINELoginConfig {
    // LINE Channel ID - LINE Developers Consoleで取得
    static let channelID = "2008667999"
}

final class FirebaseManager: NSObject, ObservableObject {
    static let shared = FirebaseManager()

    @Published var user: FirebaseAuth.User?
    private var currentNonce: String?
    private var appleSignInContinuation: CheckedContinuation<Void, Error>?

    private override init() {
        super.init()
        self.user = Auth.auth().currentUser
        Auth.auth().addStateDidChangeListener { _, user in
            Task { @MainActor in
                self.user = user
            }
        }
    }

    // Email/Password ログイン（開発中の暫定導線）
    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        await MainActor.run { self.user = result.user }
    }

    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        await MainActor.run { self.user = result.user }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    func idToken(forceRefresh: Bool = false) async throws -> String {
        guard let user = Auth.auth().currentUser else { throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "未ログインです"]) }
        return try await user.getIDTokenResult(forcingRefresh: forceRefresh).token
    }

    // MARK: - LINE Sign In

    func startSignInWithLine() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task { @MainActor in
                LoginManager.shared.login(permissions: [.profile, .openID]) { [weak self] result in
                    guard let self else {
                        continuation.resume(throwing: NSError(domain: "LINELogin", code: -9, userInfo: [NSLocalizedDescriptionKey: "認証状態を取得できませんでした"]))
                        return
                    }
                    switch result {
                    case .success(let loginResult):
                        guard let idToken = loginResult.accessToken.IDTokenRaw else {
                            continuation.resume(throwing: NSError(domain: "LINELogin", code: -6, userInfo: [NSLocalizedDescriptionKey: "id_tokenが取得できませんでした"]))
                            return
                        }
                        let idTokenNonce = loginResult.IDTokenNonce
                        Task {
                            do {
                                let firebaseToken = try await self.exchangeIDTokenForFirebaseToken(idToken: idToken, idTokenNonce: idTokenNonce)
                                _ = try await Auth.auth().signIn(withCustomToken: firebaseToken)
                                continuation.resume(returning: ())
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    /// Send id_token to backend and get Firebase custom token
    private func exchangeIDTokenForFirebaseToken(idToken: String, idTokenNonce: String?) async throws -> String {
#if DEBUG
        logLineTokenClaims(idToken)
#endif
        let url = URL(string: "https://classnote-api-900324644592.asia-northeast1.run.app/auth/line")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: String] = [
            "idToken": idToken,
            "id_token": idToken
        ]
        if let idTokenNonce {
            body["idTokenNonce"] = idTokenNonce
            body["id_token_nonce"] = idTokenNonce
            body["nonce"] = idTokenNonce
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "LINELogin", code: -7, userInfo: [NSLocalizedDescriptionKey: "サーバーからの応答が不正です"])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            let detail = extractDetailMessage(from: data) ?? message
            print("[LINELogin] Firebase token exchange failed (\(httpResponse.statusCode)): \(message)")
            throw NSError(domain: "LINELogin", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "認証に失敗しました: \(detail)"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "LINELogin", code: -8, userInfo: [NSLocalizedDescriptionKey: "Firebaseトークンの取得に失敗しました"])
        }
        if let firebaseToken = json["firebaseToken"] as? String {
            return firebaseToken
        }
        if let firebaseToken = json["firebaseCustomToken"] as? String {
            return firebaseToken
        }
        if let firebaseToken = json["firebase_custom_token"] as? String {
            return firebaseToken
        }
        if let firebaseToken = json["customToken"] as? String {
            return firebaseToken
        }
        throw NSError(domain: "LINELogin", code: -8, userInfo: [NSLocalizedDescriptionKey: "Firebaseトークンの取得に失敗しました"])
    }

    private func extractDetailMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let detail = json["detail"] as? String
        else {
            return nil
        }
        return detail
    }

#if DEBUG
    private func logLineTokenClaims(_ idToken: String) {
        let parts = idToken.split(separator: ".")
        guard parts.count >= 2 else { return }
        let payload = String(parts[1])
        let padded = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .padding(toLength: ((payload.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
        guard let data = Data(base64Encoded: padded),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return
        }
        let aud = json["aud"] ?? "nil"
        let iss = json["iss"] ?? "nil"
        print("[LINELogin] Token claims: aud=\(aud) iss=\(iss)")
    }
#endif

    // MARK: - Apple Sign In

    func startSignInWithApple() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.appleSignInContinuation = continuation

            let nonce = randomNonceString()
            currentNonce = nonce
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return hashString
    }
}

extension FirebaseManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            appleSignInContinuation?.resume(throwing: NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "認証情報を取得できませんでした"]))
            appleSignInContinuation = nil
            return
        }
        guard let nonce = currentNonce else {
            appleSignInContinuation?.resume(throwing: NSError(domain: "AppleSignIn", code: -2, userInfo: [NSLocalizedDescriptionKey: "認証に必要な情報が不足しています"]))
            appleSignInContinuation = nil
            return
        }
        guard let appleIDToken = appleIDCredential.identityToken else {
            appleSignInContinuation?.resume(throwing: NSError(domain: "AppleSignIn", code: -3, userInfo: [NSLocalizedDescriptionKey: "IDトークンを取得できませんでした"]))
            appleSignInContinuation = nil
            return
        }
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            appleSignInContinuation?.resume(throwing: NSError(domain: "AppleSignIn", code: -4, userInfo: [NSLocalizedDescriptionKey: "IDトークンの解析に失敗しました"]))
            appleSignInContinuation = nil
            return
        }

        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString, rawNonce: nonce, fullName: appleIDCredential.fullName)
        Task {
            do {
                _ = try await Auth.auth().signIn(with: credential)
                appleSignInContinuation?.resume()
            } catch {
                appleSignInContinuation?.resume(throwing: error)
            }
            appleSignInContinuation = nil
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // ユーザーがキャンセルした場合は特別扱い
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain && nsError.code == ASAuthorizationError.canceled.rawValue {
            appleSignInContinuation?.resume(throwing: NSError(domain: "AppleSignIn", code: 0, userInfo: [NSLocalizedDescriptionKey: "ログインがキャンセルされました"]))
        } else {
            appleSignInContinuation?.resume(throwing: error)
        }
        appleSignInContinuation = nil
    }
}

extension FirebaseManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        return ASPresentationAnchor()
    }
}

extension FirebaseManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        return ASPresentationAnchor()
    }
}
