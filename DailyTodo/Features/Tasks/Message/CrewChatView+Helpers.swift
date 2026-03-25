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

        await crewStore.loadMembers(for: crew.id)
        await crewStore.loadMemberProfiles(for: crewStore.crewMembers)
        await crewStore.loadCrewMessageReads(for: crew.id)
        await crewStore.loadCrewTypingStatuses(for: crew.id)

        crewStore.subscribeToCrewMessagesRealtime(
            crewID: crew.id,
            currentUserID: session.currentUser?.id
        )

        if let myID = session.currentUser?.id {
            await crewStore.markCrewMessagesAsRead(
                crewID: crew.id,
                userID: myID
            )
        }
    }

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

    func currentDisplayName() -> String {
        if let email = session.currentUser?.email, !email.isEmpty {
            let prefix = email.components(separatedBy: "@").first ?? email
            return prefix
        }
        return String(localized: "crew_chat_you")
    }

    func handleTypingChange(_ newValue: String) {
        guard let myID = session.currentUser?.id else { return }

        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldBeTyping = !trimmed.isEmpty

        typingStopTask?.cancel()

        if shouldBeTyping {
            if !isCurrentlyTyping {
                isCurrentlyTyping = true

                Task {
                    await crewStore.sendTypingEvent(
                        crewID: crew.id,
                        userID: myID,
                        name: currentDisplayName(),
                        isTyping: true
                    )
                }
            }

            typingStopTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)

                if !Task.isCancelled {
                    isCurrentlyTyping = false

                    await crewStore.sendTypingEvent(
                        crewID: crew.id,
                        userID: myID,
                        name: currentDisplayName(),
                        isTyping: false
                    )
                }
            }
        } else {
            isCurrentlyTyping = false

            Task {
                await crewStore.sendTypingEvent(
                    crewID: crew.id,
                    userID: myID,
                    name: currentDisplayName(),
                    isTyping: false
                )
            }
        }
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
        typingStopTask?.cancel()
        isCurrentlyTyping = false

        if let myID = session.currentUser?.id {
            Task {
                await crewStore.sendTypingEvent(
                    crewID: crew.id,
                    userID: myID,
                    name: currentDisplayName(),
                    isTyping: false
                )
            }
        }

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
            return String(localized: "crew_chat_today")
        }

        if calendar.isDateInYesterday(date) {
            return String(localized: "crew_chat_yesterday")
        }

        return date.formatted(.dateTime.day().month().year())
    }
}
