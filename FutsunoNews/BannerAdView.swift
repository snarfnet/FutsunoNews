import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = adUnitID
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        if uiView.rootViewController == nil,
           let windowScene = uiView.window?.windowScene,
           let root = windowScene.windows.first?.rootViewController {
            uiView.rootViewController = root
            uiView.load(GADRequest())
        }
    }
}
