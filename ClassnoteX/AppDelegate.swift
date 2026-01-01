import SwiftUI
import FirebaseCore
import GoogleSignIn
import LineSDK

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        LoginManager.shared.setup(channelID: LINELoginConfig.channelID, universalLinkURL: nil)
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        if LoginManager.shared.nonisolatedApplication(app, open: url, options: options) {
            return true
        }
        return false
    }
}
