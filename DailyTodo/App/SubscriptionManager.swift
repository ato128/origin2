import Foundation
import Combine
import RevenueCat

enum SubscriptionError: LocalizedError {
    case notConfigured
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Satın alma şu an kullanılamıyor."
        }
    }
}

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published private(set) var isPro: Bool = false
    /// AI'lı üst paket (RevenueCat "pro_ai" entitlement). AI ürünleri RevenueCat'te
    /// hem "pro" hem "pro_ai" entitlement'ına bağlı olmalı — isPro her iki pakette true.
    @Published private(set) var isProAI: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var availablePackages: [Package] = []

    private let proEntitlement = "pro"
    private let proAIEntitlement = "pro_ai"
    private let cacheKey = "subscription_is_pro"
    private let cacheKeyAI = "subscription_is_pro_ai"

    /// True only after `Purchases.configure` actually ran. Guards every
    /// `Purchases.shared` access so we never touch an unconfigured SDK.
    private var isConfigured = false

#if DEBUG
    // MARK: - Debug Pro override (DEBUG builds only)
    // Lets us preview Pro features without a real purchase. Compiled out of
    // Release/App Store builds entirely, so it can never ship.
    private let debugOverrideKey = "pro_debug_override"
    @Published private(set) var debugProEnabled: Bool = UserDefaults.standard.bool(forKey: "pro_debug_override")

    /// Force Pro on/off for testing. When turned off, the real entitlement is
    /// re-checked.
    func setDebugPro(_ enabled: Bool) {
        debugProEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: debugOverrideKey)

        if enabled {
            isPro = true
            isProAI = true
        } else {
            isPro = UserDefaults.standard.bool(forKey: cacheKey)
            isProAI = UserDefaults.standard.bool(forKey: cacheKeyAI)
            Task { await refresh() }
        }
    }
#endif

    private init() {
        #if DEBUG
        let override = UserDefaults.standard.bool(forKey: debugOverrideKey)
        debugProEnabled = override
        isPro = override || UserDefaults.standard.bool(forKey: cacheKey)
        isProAI = override || UserDefaults.standard.bool(forKey: cacheKeyAI)
        #else
        isPro = UserDefaults.standard.bool(forKey: cacheKey)
        isProAI = UserDefaults.standard.bool(forKey: cacheKeyAI)
        #endif
    }

    func configure() {
        let key = AppSecrets.revenueCatAPIKey

        // ⚠️ RevenueCat'in TEST STORE key'i ("test_" öneki) bir RELEASE/TestFlight
        // build'inde Purchases.configure'a verilirse SDK kasıtlı olarak assertion ile
        // ÇÖKER (checkForSimulatedStoreAPIKeyInRelease). Bu yüzden Release'te test key
        // ile ASLA configure etmiyoruz; uygulama çökmek yerine Pro'suz açılır.
        // Gerçek satın alma için Config.xcconfig'deki değeri "appl_..." production
        // key'iyle değiştir — o zaman bu guard otomatik geçer. Tek satır.
        let isTestStoreKey = key.hasPrefix("test_")
        #if DEBUG
        let canConfigure = !key.isEmpty
        #else
        let canConfigure = !key.isEmpty && !isTestStoreKey
        #endif

        guard canConfigure else {
            isConfigured = false
            if isTestStoreKey {
                Log.debug("⚠️ RevenueCat NOT configured: Release build with test_ key. Swap Config.xcconfig to an appl_ key.")
            }
            return
        }

        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: key)
        isConfigured = true
    }

    func refresh() async {
        guard isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            updateStatus(from: info)
        } catch {
            // keep cached value
        }
    }

    /// RevenueCat kimliğini Supabase kullanıcısına bağlar. Backend, premium
    /// doğrulamasını bu ID ile RevenueCat REST API'sinden yaptığı için ID'nin
    /// Supabase UID'siyle birebir (küçük harf) eşleşmesi şart.
    func syncIdentity(userID: UUID?) async {
        guard isConfigured, let userID else { return }
        let appUserID = userID.uuidString.lowercased()
        guard Purchases.shared.appUserID != appUserID else { return }
        do {
            let (info, _) = try await Purchases.shared.logIn(appUserID)
            updateStatus(from: info)
        } catch {
            // bir sonraki scene-active'de tekrar denenir
        }
    }

    func loadOfferings() async {
        guard isConfigured else { return }
        do {
            let offerings = try await Purchases.shared.offerings()
            availablePackages = offerings.current?.availablePackages ?? []
        } catch {}
    }

    func purchase(package pkg: Package) async throws {
        guard isConfigured else { throw SubscriptionError.notConfigured }
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
        guard isConfigured else { throw SubscriptionError.notConfigured }
        isLoading = true
        defer { isLoading = false }
        let info = try await Purchases.shared.restorePurchases()
        updateStatus(from: info)
    }

    private func updateStatus(from info: CustomerInfo) {
        let entitled = info.entitlements[proEntitlement]?.isActive == true
        let entitledAI = info.entitlements[proAIEntitlement]?.isActive == true
        UserDefaults.standard.set(entitled, forKey: cacheKey)
        UserDefaults.standard.set(entitledAI, forKey: cacheKeyAI)
        #if DEBUG
        isPro = debugProEnabled || entitled
        isProAI = debugProEnabled || entitledAI
        #else
        isPro = entitled
        isProAI = entitledAI
        #endif
    }
}
