//
//  CrewChatView+Helpers.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//
import SwiftUI

extension CrewChatView {

    var typingNames: [String] {
        guard let myID = session.currentUser?.id else { return [] }

        return crewStore.crewTypingStatuses
            .filter { $0.crew_id == crew.id }
            .filter { $0.user_id != myID }
            .filter { $0.is_typing }
            .map(\.name)
    }

    var typingText: String? {
        guard !typingNames.isEmpty else { return nil }

        let isTurkish = Locale.current.language.languageCode?.identifier == "tr"

        if typingNames.count == 1 {
            return isTurkish
                ? "\(typingNames[0]) yazıyor..."
                : "\(typingNames[0]) is typing..."
        } else if typingNames.count == 2 {
            return isTurkish
                ? "\(typingNames[0]) ve \(typingNames[1]) yazıyor..."
                : "\(typingNames[0]) and \(typingNames[1]) are typing..."
        } else {
            return isTurkish
                ? "Birileri yazıyor..."
                : "Some people are typing..."
        }
    }

 

    func loadChatData() async {
        await crewStore.loadInitialChatMessagesIfNeeded(
            for: crew.id,
            currentUserID: session.currentUser?.id,
            force: false
        )

        await crewStore.loadNewerMessages(
            for: crew.id,
            currentUserID: session.currentUser?.id
        )

        await crewStore.loadMembers(for: crew.id)
        await crewStore.loadMemberProfiles(for: crewStore.crewMembers)
        await crewStore.loadCrewMessageReads(for: crew.id)
        await crewStore.loadCrewTypingStatuses(for: crew.id)

        crewStore.subscribeToCrewMessagesRealtime(
            crewID: crew.id,
            currentUserID: session.currentUser?.id
        )

        crewStore.subscribeToCrewAuxRealtime(crewID: crew.id)

        if let myID = session.currentUser?.id {
            await crewStore.markCrewMessagesAsRead(
                crewID: crew.id,
                userID: myID
            )

            await crewStore.resetUnreadCount(
                crewID: crew.id,
                userID: myID
            )
            
            await crewStore.resetUnreadCount(
                crewID: crew.id,
                userID: myID
            )
        }
    }
}
