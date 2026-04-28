//
//  PushTokenStore.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 21.03.2026.
//

import Foundation
import Supabase
import UIKit

@MainActor
final class PushTokenStore {
    static let shared = PushTokenStore()
    private init() {}

    private let tokenKey = "apns_device_token"

    var currentEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    var deviceID: String {
        let key = "push_device_id_v1"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }

        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: key)
        return created
    }

    func saveCurrentToken(currentUserID: UUID?) async {
        guard let currentUserID else {
            print("PUSH TOKEN SAVE SKIPPED: currentUserID nil")
            return
        }

        guard let rawToken = UserDefaults.standard.string(forKey: tokenKey) else {
            print("PUSH TOKEN SAVE SKIPPED: token bulunamadı")
            return
        }

        let cleanToken = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else { return }

        let client = SupabaseManager.shared.client

        do {
            let authSession = try await client.auth.session
            guard authSession.user.id == currentUserID else {
                print("PUSH TOKEN SAVE BLOCKED: auth uid mismatch")
                return
            }

            struct Payload: Encodable {
                let user_id: UUID
                let apns_token: String
                let environment: String
                let platform: String
                let device_id: String
                let app_version: String?
                let is_active: Bool
                let updated_at: String
            }

            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

            let payload = Payload(
                user_id: currentUserID,
                apns_token: cleanToken,
                environment: currentEnvironment,
                platform: "ios",
                device_id: deviceID,
                app_version: version,
                is_active: true,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )

            try await client
                .from("push_tokens")
                .upsert(payload, onConflict: "user_id,apns_token,environment")
                .execute()

            print("✅ PUSH TOKEN SAVED:", currentEnvironment)
        } catch {
            print("SAVE PUSH TOKEN ERROR:", error.localizedDescription)
        }
    }
}
