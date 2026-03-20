//
//  CrewChatView+Helpers.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//
import SwiftUI

extension CrewChatView {
    var messages: [CrewChatMessageItem] {
        crewStore.chatMessagesByCrew[crew.id] ?? []
    }

    func loadChatData() async {
        await crewStore.loadInitialChatMessages(
            for: crew.id,
            currentUserID: session.currentUser?.id
        )
    }

    func sendMessage() {
        let clean = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let storedText = encodedMessageText(from: clean)
        let senderID = session.currentUser?.id
        let senderName = currentDisplayName()

        draftMessage = ""
        replyingTo = nil
        isComposerFocused = false

        Task {
            await crewStore.sendCrewMessageOptimistic(
                crewID: crew.id,
                senderID: senderID,
                senderName: senderName,
                text: storedText
            )
        }
    }

    func encodedMessageText(from clean: String) -> String {
        guard let replyingTo else { return clean }

        let preview = replyingTo.displayText.replacingOccurrences(of: "\n", with: " ")
        return "\(replyMarker)\(preview)\(bodyMarker)\(clean)"
    }

    func visibleMessageText(from fullText: String) -> String {
        guard
            fullText.hasPrefix(replyMarker),
            let bodyRange = fullText.range(of: bodyMarker)
        else {
            return fullText
        }

        return String(fullText[bodyRange.upperBound...])
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

    func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let lastID = messages.last?.id else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if animated {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }

    func currentDisplayName() -> String {
        if let email = session.currentUser?.email, !email.isEmpty {
            return email
        }
        return "You"
    }

    func shouldShowDateSeparator(at index: Int) -> Bool {
        guard messages.indices.contains(index) else { return false }
        if index == 0 { return true }

        let calendar = Calendar.current
        return !calendar.isDate(messages[index].createdAt, inSameDayAs: messages[index - 1].createdAt)
    }

    func shouldShowSenderName(at index: Int) -> Bool {
        guard messages.indices.contains(index) else { return true }
        if index == 0 { return true }

        let current = messages[index]
        let previous = messages[index - 1]

        let sameSender = current.senderID == previous.senderID
        let sameDay = Calendar.current.isDate(current.createdAt, inSameDayAs: previous.createdAt)

        return !(sameSender && sameDay)
    }

    func shouldTightenSpacing(at index: Int) -> Bool {
        guard index > 0, messages.indices.contains(index) else { return false }

        let current = messages[index]
        let previous = messages[index - 1]

        let sameSender = current.senderID == previous.senderID
        let sameDay = Calendar.current.isDate(current.createdAt, inSameDayAs: previous.createdAt)

        return sameSender && sameDay
    }

    @ViewBuilder
    func dateSeparator(for date: Date) -> some View {
        Text(relativeDateTitle(for: date))
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(palette.cardFill)
                    .overlay(
                        Capsule()
                            .stroke(palette.cardStroke, lineWidth: 1)
                    )
            )
    }

    func relativeDateTitle(for date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        }

        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        return date.formatted(.dateTime.day().month().year())
    }
}
