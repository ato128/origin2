//
//  CrewInviteMessage.swift
//  DailyTodo
//
//  A crew invite travelling through friend chat as a plain text message with
//  a marker prefix — the chat backend needs no schema change. FriendChatView
//  renders it as an invite card; MessagesView shows a clean preview line.
//
//  Wire format: "[[crew_invite]]<code>|<crew name>"
//

import Foundation

struct CrewInviteMessage {
    static let prefix = "[[crew_invite]]"

    let code: String
    let crewName: String

    static func parse(_ text: String) -> CrewInviteMessage? {
        guard text.hasPrefix(prefix) else { return nil }

        let body = String(text.dropFirst(prefix.count))
        let parts = body.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)

        guard let codePart = parts.first else { return nil }
        let code = String(codePart).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return nil }

        let name = parts.count > 1
            ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        return CrewInviteMessage(code: code, crewName: name)
    }

    static func encode(code: String, crewName: String) -> String {
        // "|" is the field separator — strip it from the name defensively.
        prefix + code + "|" + crewName.replacingOccurrences(of: "|", with: " ")
    }
}

extension Notification.Name {
    /// Posted after a crew invite is accepted in-chat, so CrewStore refreshes
    /// silently in the background wherever it lives.
    static let crewJoinedViaInvite = Notification.Name("crewJoinedViaInvite")
}
