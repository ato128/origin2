//
//  PushTokenStore.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 21.03.2026.
//

import Foundation
import UIKit

@MainActor
final class PushTokenStore {
    static let shared = PushTokenStore()
    private init() {}

    private let tokenKey = "apns_device_token"
    private let lastSavedTokenKey = "chat_backend_last_saved_apns_token"
    private let lastSavedEnvironmentKey = "chat_backend_last_saved_apns_environment"
    private let lastSaveAttemptAtKey = "chat_backend_push_token_last_attempt_at"

    private var isSaving = false
    private var pendingSaveTask: Task<Void, Never>?

    var currentEnvironment: String {
            Self.detectAPNsEnvironment()
        }

        /// APNs environment'ı runtime'da tespit eder.
        /// Provisioning profile'dan aps-environment değerini okur.
        /// Bu sayede TestFlight, App Store, Development build'leri ayırt edilir.
        static func detectAPNsEnvironment() -> String {
            #if targetEnvironment(simulator)
            // Simülatör daima sandbox
            return "sandbox"
            #else
            // Gerçek cihaz: provisioning profile'dan oku
            guard let path = Bundle.main.path(
                forResource: "embedded",
                ofType: "mobileprovision"
            ) else {
                // Profile bulunamadıysa: App Store build (genellikle production)
                return "production"
            }

            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))

                // Provisioning profile binary'inde plist gömülü
                guard let plistRange = data.range(of: "<plist".data(using: .utf8)!),
                      let endRange = data.range(of: "</plist>".data(using: .utf8)!) else {
                    return "production"
                }

                let plistData = data.subdata(
                    in: plistRange.lowerBound..<endRange.upperBound
                )

                guard let plist = try PropertyListSerialization.propertyList(
                    from: plistData,
                    options: [],
                    format: nil
                ) as? [String: Any],
                      let entitlements = plist["Entitlements"] as? [String: Any],
                      let apsEnvironment = entitlements["aps-environment"] as? String
                else {
                    return "production"
                }

                // aps-environment "development" veya "production" döner
                // Bizim sandbox / production'a çevirelim
                return apsEnvironment == "development" ? "sandbox" : "production"
            } catch {
                print("❌ APNS ENV DETECT ERROR:", error.localizedDescription)
                return "production"
            }
            #endif
        }

    var currentToken: String? {
        UserDefaults.standard
            .string(forKey: tokenKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func storeToken(_ token: String) {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToken.isEmpty else {
            print("⚪️ PUSH TOKEN STORE SKIPPED: empty token")
            return
        }

        UserDefaults.standard.set(cleanToken, forKey: tokenKey)
        UserDefaults.standard.synchronize()

        print("✅ PUSH TOKEN STORED:", currentEnvironment)
        print("✅ PUSH TOKEN START:", String(cleanToken.prefix(14)))
    }

    func saveCurrentTokenWithRetry(reason: String) {
        pendingSaveTask?.cancel()

        pendingSaveTask = Task { [weak self] in
            guard let self else { return }

            try? await Task.sleep(nanoseconds: 700_000_000)

            guard !Task.isCancelled else { return }

            await self.saveCurrentTokenNow(reason: reason)
        }
    }

    func saveCurrentTokenNow(reason: String) async {
        guard !isSaving else {
            print("⚪️ PUSH TOKEN SAVE SKIPPED: already saving")
            return
        }

        guard let cleanToken = currentToken, !cleanToken.isEmpty else {
            print("⚪️ PUSH TOKEN SAVE SKIPPED: token bulunamadı")
            return
        }

        let environment = currentEnvironment

        if isAlreadySaved(token: cleanToken, environment: environment) {
            print("⚪️ PUSH TOKEN SAVE SKIPPED: already saved for \(environment)")
            return
        }

        isSaving = true
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastSaveAttemptAtKey)

        defer {
            isSaving = false
        }

        print("🟡 PUSH TOKEN SAVE START:", reason)
        print("🟡 PUSH TOKEN ENV:", environment)
        print("🟡 PUSH TOKEN START:", String(cleanToken.prefix(14)))

        let success = await ChatBackendClient.shared.savePushTokenWithRetry(
            apnsToken: cleanToken,
            environment: environment,
            maxAttempts: 4
        )

        if success {
            UserDefaults.standard.set(cleanToken, forKey: lastSavedTokenKey)
            UserDefaults.standard.set(environment, forKey: lastSavedEnvironmentKey)
            UserDefaults.standard.synchronize()

            print("✅ PUSH TOKEN SAVE COMPLETE:", environment)
        } else {
            print("❌ PUSH TOKEN SAVE FAILED AFTER RETRY")
        }
    }

    func forceResaveCurrentToken(reason: String) {
        UserDefaults.standard.removeObject(forKey: lastSavedTokenKey)
        UserDefaults.standard.removeObject(forKey: lastSavedEnvironmentKey)
        UserDefaults.standard.synchronize()

        saveCurrentTokenWithRetry(reason: reason)
    }

    private func isAlreadySaved(token: String, environment: String) -> Bool {
        let savedToken = UserDefaults.standard.string(forKey: lastSavedTokenKey)
        let savedEnvironment = UserDefaults.standard.string(forKey: lastSavedEnvironmentKey)

        return savedToken == token && savedEnvironment == environment
    }
}

