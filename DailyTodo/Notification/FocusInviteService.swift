//
//  FocusInviteService.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 12.04.2026.
//

import Foundation
import Supabase

final class FocusInviteService {
    static let shared = FocusInviteService()
    private init() {}

    private let functionURL = URL(string: "https://srzvzaczgydwtopnlrvx.supabase.co/functions/v1/send-message-push")!

    func sendInvites(
        sessionID: UUID,
        crewID: UUID,
        participantIDs: [UUID],
        hostName: String,
        duration: Int,
        taskTitle: String? = nil
    ) async {
        let currentUserIDString = UserDefaults.standard.string(forKey: "current_user_id")

        let filteredParticipantIDs = Array(
            Set(
                participantIDs.filter { $0.uuidString != currentUserIDString }
            )
        )

        guard !filteredParticipantIDs.isEmpty else {
            print("FOCUS INVITE: gönderilecek katılımcı yok")
            return
        }

        guard let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !anonKey.isEmpty else {
            print("FOCUS INVITE ERROR: SUPABASE_ANON_KEY bulunamadı")
            return
        }

        let normalizedTaskTitle = taskTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        for participantID in filteredParticipantIDs {
            do {
                try await sendSingleInvite(
                    anonKey: anonKey,
                    toUserID: participantID,
                    sessionID: sessionID,
                    crewID: crewID,
                    hostName: hostName,
                    duration: duration,
                    taskTitle: normalizedTaskTitle
                )
            } catch {
                print("FOCUS INVITE SEND ERROR [\(participantID.uuidString)]:", error.localizedDescription)
            }
        }
    }

    private func sendSingleInvite(
        anonKey: String,
        toUserID: UUID,
        sessionID: UUID,
        crewID: UUID,
        hostName: String,
        duration: Int,
        taskTitle: String?
    ) async throws {
        guard let inviteSecret = Bundle.main.object(forInfoDictionaryKey: "FOCUS_INVITE_SECRET") as? String,
              !inviteSecret.isEmpty else {
            print("FOCUS INVITE ERROR: FOCUS_INVITE_SECRET bulunamadı")
            return
        }

        guard let accessToken = SupabaseManager.shared.client.auth.currentSession?.accessToken,
              !accessToken.isEmpty else {
            print("FOCUS INVITE ERROR: access token yok")
            return
        }

        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(inviteSecret, forHTTPHeaderField: "x-focus-invite-secret")

        let deepLink = "dailytodo://focus?crew_id=\(crewID.uuidString)&session_id=\(sessionID.uuidString)"

        let bodyText: String
        if let taskTitle, !taskTitle.isEmpty {
            bodyText = "\(hostName) \(duration) dk focus başlattı. Görev: \(taskTitle). Katılmak ister misin?"
        } else {
            bodyText = "\(hostName) \(duration) dk focus başlattı. Katılmak ister misin?"
        }

        var body: [String: Any] = [
            "toUserId": toUserID.uuidString,
            "title": "Takım odakta",
            "message": bodyText,
            "type": "crew_focus_invite",
            "crew_id": crewID.uuidString,
            "session_id": sessionID.uuidString,
            "host_name": hostName,
            "duration_minutes": duration,
            "deep_link": deepLink,
            "badge": 1
        ]

        if let taskTitle, !taskTitle.isEmpty {
            body["task_title"] = taskTitle
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("FOCUS INVITE ACCESS TOKEN EMPTY:", accessToken.isEmpty)
        print("FOCUS INVITE HEADERS:", request.allHTTPHeaderFields ?? [:])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("FOCUS INVITE ERROR: function response geçersiz")
            return
        }

        let bodyString = String(data: data, encoding: .utf8) ?? "no-body"
        print("FOCUS INVITE STATUS:", httpResponse.statusCode)
        print("FOCUS INVITE RESPONSE:", bodyString)

        guard (200...299).contains(httpResponse.statusCode) else {
            print("FOCUS INVITE FUNCTION ERROR:", httpResponse.statusCode, bodyString)
            return
        }

        print("FOCUS INVITE SENT -> \(toUserID.uuidString)")
    }

    // ════════════════════════════════════════════════════════════════
    // YENİ — Focus End Notifications
    // ════════════════════════════════════════════════════════════════

    /// Crew focus bitince tüm participantlara "tamamlandı" push'u gönderir.
    /// Host bunu çağırır. Kendisine de push gider (gerekirse — şu an gönderiyoruz
    /// çünkü diğer cihazlarında da bildirim görsün).
    ///
    /// `participantIDs`: focus'taki tüm aktif katılımcıların user_id'leri (host dahil)
    func sendEndNotifications(
        crewID: UUID,
        crewName: String,
        participantIDs: [UUID],
        durationMinutes: Int,
        previousMinutes: Int? = nil
    ) async {
        let currentUserIDString = UserDefaults.standard.string(forKey: "current_user_id")

        // Host kendisine push gönderebilir (diğer cihazları için).
        // Eğer istemezsek burada filter ederiz. Şimdilik herkese.
        let uniqueIDs = Array(Set(participantIDs))

        guard !uniqueIDs.isEmpty else {
            print("FOCUS END PUSH: gönderilecek kullanıcı yok")
            return
        }

        print("FOCUS END PUSH SEND -> \(uniqueIDs.count) kullanıcıya")

        for userID in uniqueIDs {
            // Kendisine gönderme (kişisel cihaz local notification yapacak)
            if userID.uuidString == currentUserIDString {
                continue
            }

            PushService.shared.sendCrewFocusEndedPush(
                toUserId: userID.uuidString,
                crewID: crewID.uuidString,
                crewName: crewName,
                durationMinutes: durationMinutes,
                previousMinutes: previousMinutes
            )
        }
    }

    /// Crew focus'tan birisi ayrılınca diğerlerine push gönderir.
    /// `leaverID`: ayrılan kişinin user_id'si (kendisine push gitmez)
    /// `participantIDs`: focus'taki diğer aktif katılımcılar
    func sendLeftNotifications(
        crewID: UUID,
        crewName: String,
        leaverID: UUID,
        leaverName: String,
        otherParticipantIDs: [UUID]
    ) async {
        // Ayrılanı listeden çıkar (kendisine "X ayrıldı" gitmesin)
        let filteredIDs = Array(
            Set(otherParticipantIDs.filter { $0 != leaverID })
        )

        guard !filteredIDs.isEmpty else {
            print("FOCUS LEFT PUSH: bildirilecek diğer kullanıcı yok")
            return
        }

        print("FOCUS LEFT PUSH SEND -> \(filteredIDs.count) kullanıcıya")

        for userID in filteredIDs {
            PushService.shared.sendCrewFocusLeftPush(
                toUserId: userID.uuidString,
                crewID: crewID.uuidString,
                crewName: crewName,
                leaverName: leaverName
            )
        }
    }
}
