import Foundation
import Combine
import RevenueCat

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published private(set) var isPro: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var availablePackages: [Package] = []

    private let proEntitlement = "pro"
    private let cacheKey = "subscription_is_pro"

    // MARK: - Debug Pro override (test only)
    // Lets us preview Pro features without a real purchase. Persists across
    // launches and takes precedence over RevenueCat. TODO: remove before release.
    private let debugOverrideKey = "pro_debug_override"
    @Published private(set) var debugProEnabled: Bool = UserDefaults.standard.bool(forKey: "pro_debug_override")

    private init() {
        let override = UserDefaults.standard.bool(forKey: debugOverrideKey)
        debugProEnabled = override
        isPro = override || UserDefaults.standard.bool(forKey: cacheKey)
    }

    /// Force Pro on/off for testing. When turned off, the real entitlement is
    /// re-checked.
    func setDebugPro(_ enabled: Bool) {
        debugProEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: debugOverrideKey)

        if enabled {
            isPro = true
        } else {
            isPro = UserDefaults.standard.bool(forKey: cacheKey)
            Task { await refresh() }
        }
    }

    func configure() {
        // ⚠️ AppSecrets.revenueCatAPIKey şu an Config.xcconfig'deki TEST STORE key'ini döndürüyor.
        // App Store'da gerçek satın alma için Config.xcconfig'deki değeri "appl_..." production
        // key'iyle değiştir (App Store Connect ürünleri + RevenueCat bağlantısı sonrası). Tek satır.
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: AppSecrets.revenueCatAPIKey)
    }

    func refresh() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            updateStatus(from: info)
        } catch {
            // keep cached value
        }
    }

    func loadOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            availablePackages = offerings.current?.availablePackages ?? []
        } catch {}
    }

    func purchase(package pkg: Package) async throws {
        isLoading = true
        defer { isLoading = false }
        let result = try await Purchases.shared.purchase(package: pkg)
        updateStatus(from: result.customerInfo)
        Analytics.shared.track("paywall_converted", properties: [
            "product_id": pkg.storeProduct.productIdentifier,
            "package_type": pkg.packageType.debugDescription
        ])
    }

    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }
        let info = try await Purchases.shared.restorePurchases()
        updateStatus(from: info)
    }

    private func updateStatus(from info: CustomerInfo) {
        let entitled = info.entitlements[proEntitlement]?.isActive == true
        UserDefaults.standard.set(entitled, forKey: cacheKey)
        isPro = debugProEnabled || entitled
    }
}
