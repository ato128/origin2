//
//  FocusInviteService.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 12.04.2026.
//

import Foundation


final class FocusInviteService {
    static let shared = FocusInviteService()
    private init() {}

    private let functionURL = URL(string: "https://srzvzaczgydwtopnlrvx.supabase.co/functions/v1/send-message-notification")!

    func sendInvites(
        sessionID: UUID,
        crewID: UUID,
        participantIDs: [UUID],
        hostName: String,
        duration: Int,
        taskTitle: String? = nil
    ) async {
        let currentUserIDString = UserDefaults.standard.string(forKey: "current_user_id")

        let filteredParticipantIDs = participantIDs.filter {
            $0.uuidString != currentUserIDString
        }

        guard !filteredParticipantIDs.isEmpty else {
            print("FOCUS INVITE: gönderilecek katılımcı yok")
            return
        }

        guard let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !anonKey.isEmpty else {
            print("FOCUS INVITE ERROR: SUPABASE_ANON_KEY bulunamadı")
            return
        }

        for participantID in filteredParticipantIDs {
            do {
                let pushTokens = try await fetchPushTokens(for: participantID)
                guard !pushTokens.isEmpty else {
                    print("FOCUS INVITE: token yok -> \(participantID.uuidString)")
                    continue
                }

                for token in pushTokens {
                    try await sendSingleInvite(
                        anonKey: anonKey,
                        pushToken: token,
                        sessionID: sessionID,
                        crewID: crewID,
                        hostName: hostName,
                        duration: duration,
                        taskTitle: taskTitle
                    )
                }
            } catch {
                print("FOCUS INVITE SEND ERROR:", error.localizedDescription)
            }
        }
    }

    private func fetchPushTokens(for userID: UUID) async throws -> [String] {
        guard let supabaseURLString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !supabaseURLString.isEmpty,
              let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !anonKey.isEmpty else {
            print("FOCUS INVITE ERROR: SUPABASE_URL veya SUPABASE_ANON_KEY eksik")
            return []
        }

        let baseURL = supabaseURLString.hasSuffix("/")
            ? String(supabaseURLString.dropLast())
            : supabaseURLString

        guard let url = URL(string: "\(baseURL)/rest/v1/push_tokens?user_id=eq.\(userID.uuidString)&select=apns_token") else {
            print("FOCUS INVITE ERROR: push_tokens URL oluşturulamadı")
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("FOCUS INVITE ERROR: geçersiz response")
            return []
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "no-body"
            print("FOCUS INVITE TOKEN FETCH ERROR:", httpResponse.statusCode, body)
            return []
        }

        struct PushTokenRow: Decodable {
            let apns_token: String
        }

        let rows = try JSONDecoder().decode([PushTokenRow].self, from: data)
        return rows.map(\.apns_token)
    }

    private func sendSingleInvite(
        anonKey: String,
        pushToken: String,
        sessionID: UUID,
        crewID: UUID,
        hostName: String,
        duration: Int,
        taskTitle: String?
    ) async throws {
        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        let body: [String: Any] = [
            "pushToken": pushToken,
            "title": "Takım odakta",
            "body": "\(hostName) \(duration) dk focus başlattı. Katılmak ister misin?",
            "data": [
                "type": "crew_focus_invite",
                "crew_id": crewID.uuidString,
                "session_id": sessionID.uuidString,
                "host_name": hostName,
                "duration_minutes": duration,
                "task_title": taskTitle ?? ""
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("FOCUS INVITE ERROR: function response geçersiz")
            return
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8) ?? "no-body"
            print("FOCUS INVITE FUNCTION ERROR:", httpResponse.statusCode, bodyString)
            return
        }

        print("FOCUS INVITE SENT -> \(pushToken)")
    }
}
