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
    func saveCurrentToken(currentUserID: UUID?) async {
        guard let currentUserID else { return }
        guard let token = UserDefaults.standard.string(forKey: "apns_device_token"),
              !token.isEmpty else { return }

        struct Payload: Encodable {
            let user_id: UUID
            let apns_token: String
            let updated_at: String
        }

        let payload = Payload(
            user_id: currentUserID,
            apns_token: token,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        do {
            try await SupabaseManager.shared.client
                .from("push_tokens")
                .upsert(payload)
                .execute()

            print("PUSH TOKEN SAVED")
        } catch {
            print("SAVE PUSH TOKEN ERROR:", error.localizedDescription)
        }
    }
}
