import Foundation
import PostHog

final class Analytics {
    static let shared = Analytics()

    private(set) var currentUserID: String?

    private init() {}

    func configure() {
        let config = PostHogConfig(apiKey: AppSecrets.postHogAPIKey, host: AppSecrets.postHogHost)
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false
        PostHogSDK.shared.setup(config)
    }

    func identify(userID: String) {
        currentUserID = userID
        PostHogSDK.shared.identify(userID)
    }

    func reset() {
        currentUserID = nil
        PostHogSDK.shared.reset()
    }

    func track(_ event: String, properties: [String: Any] = [:]) {
        var props = properties
        if let userID = currentUserID {
            props["user_id"] = userID
        }
        PostHogSDK.shared.capture(event, properties: props)
    }
}
