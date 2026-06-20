//
//  PushService.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 29.03.2026.
//

import Foundation
import Supabase

final class PushService {
    static let shared = PushService()
    private init() {}

    private let endpoint = "https://srzvzaczgydwtopnlrvx.supabase.co/functions/v1/send-message-push"

    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJIUzI1NiIsInJlZiI6InNyenZ6YWN6Z3lkd3RvcG5scnZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NjIzNjAsImV4cCI6MjA4OTQzODM2MH0.8eSacyni-OQZEU6wbMZwjSPhLdQthZFGvUwHlCiaaF4"

    private var currentEnvironment: String {
        "production"
    }

    private func performRequest(bodyObject: [String: Any]) {
        guard let url = URL(string: endpoint) else {
            Log.debug("PUSH URL ERROR: endpoint invalid")
            return
        }

        guard JSONSerialization.isValidJSONObject(bodyObject) else {
            Log.debug("PUSH BODY ERROR: invalid JSON object")
            return
        }

        guard let body = try? JSONSerialization.data(withJSONObject: bodyObject) else {
            Log.debug("PUSH BODY SERIALIZE ERROR")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        Log.debug("🚀 PUSH REQUEST BODY:", String(data: body, encoding: .utf8) ?? "nil")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                Log.debug("🔴 PUSH SEND ERROR:", error.localizedDescription)
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseText = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""

            Log.debug("🟡 PUSH HTTP STATUS:", statusCode)

            if !responseText.isEmpty {
                Log.debug("🟣 PUSH RESPONSE:", responseText)
            }

            if !(200...299).contains(statusCode) {
                Log.debug("🔴 PUSH FAILED HTTP:", statusCode)
            }
        }
        .resume()
    }
    private func performBackendFocusRequest(
        path: String,
        bodyObject: [String: Any]
    ) {
        var bodyObject = bodyObject
        bodyObject["environment"] = "production"
        guard let url = URL(string: "\(ChatBackendEnvironment.httpBaseURL)/v1\(path)") else {
            Log.debug("FOCUS BACKEND PUSH URL ERROR")
            return
        }

        guard JSONSerialization.isValidJSONObject(bodyObject) else {
            Log.debug("FOCUS BACKEND PUSH BODY ERROR: invalid JSON")
            return
        }

        guard let body = try? JSONSerialization.data(withJSONObject: bodyObject) else {
            Log.debug("FOCUS BACKEND PUSH BODY SERIALIZE ERROR")
            return
        }

        guard let accessToken = SupabaseManager.shared.client.auth.currentSession?.accessToken,
              !accessToken.isEmpty else {
            Log.debug("FOCUS BACKEND PUSH ERROR: access token yok")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        Log.debug("🚀 FOCUS BACKEND PUSH URL:", url.absoluteString)
        Log.debug("🚀 FOCUS BACKEND PUSH BODY:", String(data: body, encoding: .utf8) ?? "nil")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                Log.debug("🔴 FOCUS BACKEND PUSH ERROR:", error.localizedDescription)
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseText = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""

            Log.debug("🟡 FOCUS BACKEND PUSH STATUS:", statusCode)

            if !responseText.isEmpty {
                Log.debug("🟣 FOCUS BACKEND PUSH RESPONSE:", responseText)
            }

            if !(200...299).contains(statusCode) {
                Log.debug("🔴 FOCUS BACKEND PUSH FAILED:", statusCode)
            }
        }
        .resume()
    }

    func sendFriendMessagePush(
        toUserId: String,
        friendshipID: String,
        senderName: String,
        message: String,
        badge: Int = 1
    ) {
        let cleanToUserId = toUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanFriendshipID = friendshipID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToUserId.isEmpty, !cleanFriendshipID.isEmpty else {
            Log.debug("FRIEND PUSH SKIPPED: missing toUserId or friendshipID")
            return
        }

        Log.debug("🚀 FRIEND PUSH SEND CALLED")
        Log.debug("🚀 toUserId:", cleanToUserId)
        Log.debug("🚀 friendshipID:", cleanFriendshipID)
        Log.debug("🚀 environment:", currentEnvironment)

        performRequest(bodyObject: [
            "toUserId": cleanToUserId,
            "title": senderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "DailyTodo" : senderName,
            "message": message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Yeni mesaj" : message,
            "type": "friend_chat",
            "friendship_id": cleanFriendshipID,
            "deep_link": "dailytodo://friend-chat?friendship_id=\(cleanFriendshipID)",
            "badge": badge,
            "environment": currentEnvironment
        ])
    }

    func sendCrewMessagePush(
        toUserId: String,
        crewID: String,
        crewName: String,
        message: String,
        badge: Int = 1
    ) {
        let cleanToUserId = toUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCrewID = crewID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToUserId.isEmpty, !cleanCrewID.isEmpty else {
            Log.debug("CREW PUSH SKIPPED: missing toUserId or crewID")
            return
        }

        Log.debug("🚀 CREW PUSH SEND CALLED")
        Log.debug("🚀 toUserId:", cleanToUserId)
        Log.debug("🚀 crewID:", cleanCrewID)
        Log.debug("🚀 environment:", currentEnvironment)

        performRequest(bodyObject: [
            "toUserId": cleanToUserId,
            "title": crewName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Crew" : crewName,
            "message": message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? tr("ps_new_crew_msg") : message,
            "type": "crew_chat",
            "crew_id": cleanCrewID,
            "deep_link": "dailytodo://crew-chat?crew_id=\(cleanCrewID)",
            "badge": badge,
            "environment": currentEnvironment
        ])
    }

    func sendFocusRoomPush(
        toUserId: String,
        crewID: String,
        crewName: String,
        message: String = tr("ps_focus_room_started"),
        badge: Int = 1
    ) {
        let cleanToUserId = toUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCrewID = crewID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToUserId.isEmpty, !cleanCrewID.isEmpty else {
            Log.debug("FOCUS PUSH SKIPPED: missing toUserId or crewID")
            return
        }

        Log.debug("🚀 FOCUS PUSH SEND CALLED")
        Log.debug("🚀 toUserId:", cleanToUserId)
        Log.debug("🚀 crewID:", cleanCrewID)
        Log.debug("🚀 environment:", currentEnvironment)

        performRequest(bodyObject: [
            "toUserId": cleanToUserId,
            "title": crewName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Focus" : crewName,
            "message": message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? tr("ps_focus_room_started") : message,
            "type": "focus_room",
            "crew_id": cleanCrewID,
            "deep_link": "dailytodo://crew-chat?crew_id=\(cleanCrewID)",
            "badge": badge,
            "environment": currentEnvironment
        ])
    }

    func sendCrewFocusInvitePush(
        toUserId: String,
        crewID: String,
        crewName: String,
        message: String = "Crew focus daveti geldi",
        badge: Int = 1
    ) {
        let cleanToUserId = toUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCrewID = crewID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToUserId.isEmpty, !cleanCrewID.isEmpty else {
            Log.debug("CREW FOCUS INVITE PUSH SKIPPED: missing toUserId or crewID")
            return
        }

        Log.debug("🚀 CREW FOCUS INVITE PUSH SEND CALLED")
        Log.debug("🚀 toUserId:", cleanToUserId)
        Log.debug("🚀 crewID:", cleanCrewID)
        Log.debug("🚀 environment:", currentEnvironment)

        performRequest(bodyObject: [
            "toUserId": cleanToUserId,
            "title": crewName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Crew Focus" : crewName,
            "message": message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Crew focus daveti geldi" : message,
            "type": "crew_focus_invite",
            "crew_id": cleanCrewID,
            "deep_link": "dailytodo://crew-chat?crew_id=\(cleanCrewID)",
            "badge": badge,
            "environment": currentEnvironment
        ])
    }

    // ════════════════════════════════════════════════════════════════
    // YENİ — Focus Ended Push
    // ════════════════════════════════════════════════════════════════

    /// Crew focus bitince participantlara gönderilir.
    /// `durationMinutes`: tamamlanmış dakika (UI'da tr("ps_x_min_done") göstermek için).
    func sendCrewFocusEndedPush(
        toUserId: String,
        crewID: String,
        crewName: String,
        durationMinutes: Int,
        previousMinutes: Int?,
        badge: Int = 0
    ) {
        let cleanToUserId = toUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCrewID = crewID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToUserId.isEmpty, !cleanCrewID.isEmpty else {
            Log.debug("CREW FOCUS ENDED PUSH SKIPPED: missing toUserId or crewID")
            return
        }

        let cleanCrewName = crewName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Crew Focus"
            : crewName

        var body: [String: Any] = [
            "toUserIDs": [cleanToUserId],
            "crewID": cleanCrewID,
            "crewName": cleanCrewName,
            "durationMinutes": durationMinutes,
            "badge": badge
        ]

        if let previousMinutes {
            body["previousMinutes"] = previousMinutes
        }

        performBackendFocusRequest(
            path: "/focus/ended",
            bodyObject: body
        )
    }
    /// Crew focus'tan birisi ayrılınca diğerlerine gönderilir.
    /// `leaverName`: ayrılan kişinin görünen adı.
    func sendCrewFocusLeftPush(
        toUserId: String,
        crewID: String,
        crewName: String,
        leaverName: String,
        badge: Int = 0
    ) {
        let cleanToUserId = toUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCrewID = crewID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToUserId.isEmpty, !cleanCrewID.isEmpty else {
            Log.debug("CREW FOCUS LEFT PUSH SKIPPED: missing toUserId or crewID")
            return
        }

        let cleanCrewName = crewName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Crew Focus"
            : crewName

        let cleanLeaverName = leaverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Birisi"
            : leaverName

        performBackendFocusRequest(
            path: "/focus/left",
            bodyObject: [
                "toUserIDs": [cleanToUserId],
                "crewID": cleanCrewID,
                "crewName": cleanCrewName,
                "leaverName": cleanLeaverName,
                "badge": badge
            ]
        )
    }
    /// Crew focus'a birisi katılınca mevcut participantlara gönderilir.
    /// `joinedName`: katılan kişinin görünen adı.
    func sendCrewFocusJoinedPush(
        toUserId: String,
        crewID: String,
        crewName: String,
        sessionID: String,
        joinedName: String,
        badge: Int = 0
    ) {
        let cleanToUserId = toUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCrewID = crewID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSessionID = sessionID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToUserId.isEmpty, !cleanCrewID.isEmpty, !cleanSessionID.isEmpty else {
            Log.debug("CREW FOCUS JOINED PUSH SKIPPED: missing toUserId, crewID or sessionID")
            return
        }

        let cleanCrewName = crewName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Crew Focus"
            : crewName

        let cleanJoinedName = joinedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Birisi"
            : joinedName

        performBackendFocusRequest(
            path: "/focus/joined",
            bodyObject: [
                "toUserIDs": [cleanToUserId],
                "crewID": cleanCrewID,
                "crewName": cleanCrewName,
                "sessionID": cleanSessionID,
                "joinedName": cleanJoinedName,
                "badge": badge
            ]
        )
    }
}
