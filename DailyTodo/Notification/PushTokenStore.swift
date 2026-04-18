//
//  PushTokenStore.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 21.03.2026.
//

import Foundation
import Supabase

@MainActor
final class PushTokenStore {
    static let shared = PushTokenStore()
    private init() {}

    func saveCurrentToken(currentUserID: UUID?) async {
        guard let currentUserID else {
            print("PUSH TOKEN SAVE SKIPPED: currentUserID nil")
            return
        }

        guard let rawToken = UserDefaults.standard.string(forKey: "apns_device_token") else {
            print("PUSH TOKEN SAVE SKIPPED: token bulunamadı")
            return
        }

        let cleanToken = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToken.isEmpty else {
            print("PUSH TOKEN SAVE SKIPPED: token boş")
            return
        }

        let client = SupabaseManager.shared.client

        let authSession: Session
        do {
            authSession = try await client.auth.session
        } catch {
            print("SAVE PUSH TOKEN ERROR: Auth session missing.")
            return
        }

        let authUserID = authSession.user.id

        print("PUSH TOKEN AUTH UID:", authUserID.uuidString)
        print("PUSH TOKEN APP USER :", currentUserID.uuidString)

        guard authUserID == currentUserID else {
            print("PUSH TOKEN SAVE BLOCKED: auth uid ile current user eşleşmiyor")
            return
        }

        struct Payload: Encodable {
            let user_id: UUID
            let apns_token: String
            let updated_at: String
        }

        let payload = Payload(
            user_id: currentUserID,
            apns_token: cleanToken,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        do {
            try await client
                .from("push_tokens")
                .upsert(
                    payload,
                    onConflict: "user_id,apns_token"
                )
                .execute()

            print("PUSH TOKEN SAVED")
        } catch {
            print("SAVE PUSH TOKEN ERROR:", error.localizedDescription)
        }
    }
}
