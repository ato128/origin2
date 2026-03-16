//
//  FriendChatView+Helpers.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI
import SwiftData



extension FriendChatView {
    
   
    
    func sendMessage() {
        let clean = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let storedText = encodedMessageText(from: clean)

        let message = FriendMessage(
            friendID: friend.id,
            senderName: "Me",
            text: storedText,
            isFromMe: true,
            isRead: true
        )

        modelContext.insert(message)
        try? modelContext.save()

        draftMessage = ""
        replyingTo = nil
        isComposerFocused = false

        animateMessages = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                animateMessages = true
            }
        }
    }

    func encodedMessageText(from clean: String) -> String {
        guard let replyingTo else { return clean }

        let preview = visibleMessageText(from: replyingTo.text)
            .replacingOccurrences(of: "\n", with: " ")

        return "\(replyMarker)\(preview)\(bodyMarker)\(clean)"
    }

    func replyPreviewText(from fullText: String) -> String? {
        guard
            fullText.hasPrefix(replyMarker),
            let bodyRange = fullText.range(of: bodyMarker)
        else {
            return nil
        }

        let previewStart = fullText.index(fullText.startIndex, offsetBy: replyMarker.count)
        let preview = String(fullText[previewStart..<bodyRange.lowerBound])
        return preview.isEmpty ? nil : preview
    }

    func visibleMessageText(from fullText: String) -> String {
        guard
            fullText.hasPrefix(replyMarker),
            let bodyRange = fullText.range(of: bodyMarker)
        else {
            return fullText
        }

        let bodyStart = bodyRange.upperBound
        return String(fullText[bodyStart...])
    }

    func markMessagesAsRead() {
        let unreadMessages = allMessages.filter { message in
            message.friendID == friend.id && !message.isFromMe && !message.isRead
        }

        guard !unreadMessages.isEmpty else { return }

        for message in unreadMessages {
            message.isRead = true
        }

        try? modelContext.save()
    }

    func seedMessagesIfNeeded() {
        guard messages.isEmpty else { return }

        let seed = [
            FriendMessage(friendID: friend.id, senderName: friend.name, text: "Hey! How does your week look?", isFromMe: false),
            FriendMessage(friendID: friend.id, senderName: "Me", text: "Pretty busy, especially Thursday.", isFromMe: true),
            FriendMessage(friendID: friend.id, senderName: friend.name, text: "Let's sync after class.", isFromMe: false)
        ]

        for item in seed {
            modelContext.insert(item)
        }

        try? modelContext.save()
    }

    func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastID = messages.last?.id else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}
