import Foundation
import PostHog

/// Product analytics (PostHog, EU region).
///
/// Usage analytics is not needed to run the app, so it is collected only with
/// the user's explicit consent (KVKK art. 5/1) — off until they turn it on at
/// sign-up or in Profile, and switched off again the moment they withdraw it.
final class Analytics {
    static let shared = Analytics()

    private(set) var currentUserID: String?

    private static let consentKey = "analyticsConsentV1"

    /// Whether the user has agreed to usage analytics. Absent = not agreed.
    static var hasConsent: Bool {
        UserDefaults.standard.bool(forKey: consentKey)
    }

    private init() {}

    func configure() {
        let config = PostHogConfig(apiKey: AppSecrets.postHogAPIKey, host: AppSecrets.postHogHost)
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false
        // Nothing leaves the device until consent is given.
        config.optOut = !Self.hasConsent
        PostHogSDK.shared.setup(config)
    }

    /// Records the user's choice and applies it immediately.
    func setConsent(_ granted: Bool) {
        UserDefaults.standard.set(granted, forKey: Self.consentKey)
        if granted {
            PostHogSDK.shared.optIn()
            if let currentUserID { PostHogSDK.shared.identify(currentUserID) }
        } else {
            // Drop the identity and anything still queued, then stop.
            PostHogSDK.shared.reset()
            PostHogSDK.shared.optOut()
        }
    }

    func identify(userID: String) {
        currentUserID = userID
        guard Self.hasConsent else { return }
        PostHogSDK.shared.identify(userID)
    }

    func reset() {
        currentUserID = nil
        PostHogSDK.shared.reset()
    }

    func track(_ event: String, properties: [String: Any] = [:]) {
        guard Self.hasConsent else { return }
        var props = properties
        if let userID = currentUserID {
            props["user_id"] = userID
        }
        PostHogSDK.shared.capture(event, properties: props)
    }
}
