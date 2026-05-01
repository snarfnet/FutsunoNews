import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

@main
struct FutsunoNewsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    GADMobileAds.sharedInstance().start(completionHandler: nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        ATTrackingManager.requestTrackingAuthorization { _ in }
                    }
                }
        }
    }
}
