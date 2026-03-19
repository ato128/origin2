//
//  CrewChatView+Helpers.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//
import SwiftUI

extension CrewChatView {
    var messages: [CrewMessageRowItem] {
        let backendItems = Array(
            crewStore.crewMessages
                .filter { $0.crew_id == crew.id }
                .suffix(80)
        )
        .map { CrewMessageRowItem.backend($0) }

        let optimisticItems = optimisticMessages
            .filter { $0.crewID == crew.id }
            .map { CrewMessageRowItem.optimistic($0) }

        return (backendItems + optimisticItems).sorted { $0.createdAt < $1.createdAt }
    }
    var readDateMap: [UUID: Date] {
        Dictionary(
            uniqueKeysWithValues: crewStore.crewMessageReads.compactMap { read in
                guard read.crew_id == crew.id,
                      let date = isoDate(read.last_read_at) else {
                    return nil
                }
                return (read.user_id, date)
            }
        )
    }

    var crewMembers: [WeekCrewMemberItem] {
        crewStore.crewMembers
            .filter { $0.crew_id == crew.id }
            .map { member in
                let profile = crewStore.memberProfiles.first(where: { $0.id == member.user_id })

                let name: String
                if let fullName = profile?.full_name?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !fullName.isEmpty {
                    name = fullName
                } else if let username = profile?.username, !username.isEmpty {
                    name = username
                } else {
                    name = "User"
                }

                return WeekCrewMemberItem(
                    id: member.id,
                    crewID: member.crew_id,
                    userID: member.user_id,
                    name: name,
                    role: member.role
                )
            }
    }

    var filteredMentionMembers: [WeekCrewMemberItem] {
        guard showMentionPicker else { return [] }

        if mentionQuery.isEmpty {
            return crewMembers
        }

        return crewMembers.filter {
            $0.name.localizedCaseInsensitiveContains(mentionQuery)
        }
    }

    var typingNames: [String] {
        let currentUserID = session.currentUser?.id

        return crewStore.crewTypingStatuses
            .filter { $0.crew_id == crew.id }
            .filter { $0.is_typing }
            .filter { $0.user_id != currentUserID }
            .map(\.name)
    }

    var typingIndicatorText: String {
        if typingNames.count == 1 {
            return "\(typingNames[0]) typing..."
        } else if typingNames.count == 2 {
            return "\(typingNames[0]), \(typingNames[1]) typing..."
        } else {
            return "\(typingNames[0]) and \(typingNames.count - 1) others typing..."
        }
    }

    func lastReadDate(for userID: UUID) -> Date? {
        readDateMap[userID]
    }
    func messageSeenByAnyone(_ message: CrewMessageDTO) -> Bool {
        guard let messageDate = isoDate(message.created_at) else { return false }
        guard let currentUserID = session.currentUser?.id else { return false }

        let otherMembers = crewMembers.filter { $0.userID != currentUserID }
        guard !otherMembers.isEmpty else { return false }

        return otherMembers.contains { member in
            guard let readDate = lastReadDate(for: member.userID) else { return false }
            return readDate >= messageDate
        }
    }

    func messageDeliveredToAnyone(_ message: CrewMessageDTO) -> Bool {
        guard let currentUserID = session.currentUser?.id else { return false }

        let otherMembers = crewMembers.filter { $0.userID != currentUserID }
        guard !otherMembers.isEmpty else { return false }

        return otherMembers.contains { member in
            crewStore.crewMessageReads.contains {
                $0.crew_id == crew.id && $0.user_id == member.userID
            }
        }
    }

    @ViewBuilder
    func messageStatusView(for row: CrewMessageRowItem, isFromMe: Bool) -> some View {
        if isFromMe {
            if row.isOptimistic {
                Image(systemName: "clock")
                    .font(.caption2.bold())
                    .foregroundStyle(palette.secondaryText)
            } else if let message = row.backendMessage {
                let seen = messageSeenByAnyone(message)
                let delivered = messageDeliveredToAnyone(message)

                HStack(spacing: -2) {
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                        .foregroundStyle(seen ? .blue : palette.secondaryText)

                    if delivered || seen {
                        Image(systemName: "checkmark")
                            .font(.caption2.bold())
                            .foregroundStyle(seen ? .blue : palette.secondaryText)
                    }
                }
            } else {
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }

    func shouldShowDateSeparator(at index: Int) -> Bool {
        guard messages.indices.contains(index) else { return false }
        if index == 0 { return true }

        let calendar = Calendar.current
        let current = messages[index].createdAt
        let previous = messages[index - 1].createdAt

        return !calendar.isDate(current, inSameDayAs: previous)
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

    func loadChatData() async {
        await crewStore.loadMembers(for: crew.id)
        await crewStore.loadMemberProfiles(for: crewStore.crewMembers)
        await crewStore.loadCrewMessages(for: crew.id)
        await crewStore.loadCrewMessageReads(for: crew.id)
        await crewStore.loadCrewTypingStatuses(for: crew.id)

        crewStore.subscribeToCrewMessagesRealtime(crewID: crew.id)

        await crewStore.markCrewMessagesAsRead(
            crewID: crew.id,
            excludingUserID: session.currentUser?.id
        )
    }

    func sendMessage() {
        let clean = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let storedText = encodedMessageText(from: clean)
        let senderID = session.currentUser?.id
        let senderName = currentDisplayName()

        let optimistic = OptimisticCrewMessage(
            id: UUID(),
            crewID: crew.id,
            senderID: senderID,
            senderName: senderName,
            text: storedText,
            createdAt: Date()
        )

        optimisticMessages.append(optimistic)

        draftMessage = ""
        replyingTo = nil
        isComposerFocused = false
        showMentionPicker = false
        mentionQuery = ""
        typingStopTask?.cancel()
        lastSentTypingState = false

        Task {
            do {
                try await crewStore.sendCrewMessage(
                    crewID: crew.id,
                    senderID: senderID,
                    senderName: senderName,
                    text: storedText
                )

                if let userID = senderID {
                    await crewStore.sendTypingEvent(
                        crewID: crew.id,
                        userID: userID,
                        name: senderName,
                        isTyping: false
                    )
                }

                await MainActor.run {
                    optimisticMessages.removeAll { $0.id == optimistic.id }
                }
            } catch {
                await MainActor.run {
                    optimisticMessages.removeAll { $0.id == optimistic.id }
                    draftMessage = clean
                }
                print("SEND CREW MESSAGE ERROR:", error.localizedDescription)
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

    func updateMentionState(for text: String) {
        guard let lastWord = text.split(separator: " ", omittingEmptySubsequences: false).last else {
            showMentionPicker = false
            mentionQuery = ""
            return
        }

        if lastWord.hasPrefix("@") {
            mentionQuery = String(lastWord.dropFirst())
            showMentionPicker = true
        } else {
            mentionQuery = ""
            showMentionPicker = false
        }
    }

    func insertMention(_ name: String) {
        let words = draftMessage.split(separator: " ", omittingEmptySubsequences: false).map(String.init)

        guard !words.isEmpty else {
            draftMessage = "@\(name) "
            mentionQuery = ""
            showMentionPicker = false
            isComposerFocused = true
            return
        }

        var mutableWords = words

        if let last = mutableWords.last, last.hasPrefix("@") {
            mutableWords.removeLast()
        }

        let prefix = mutableWords.joined(separator: " ")

        if prefix.isEmpty {
            draftMessage = "@\(name) "
        } else {
            draftMessage = "\(prefix) @\(name) "
        }

        mentionQuery = ""
        showMentionPicker = false
        isComposerFocused = true
    }
    
    func handleTypingChange(for text: String) {
        guard let userID = session.currentUser?.id else { return }

        let isTypingNow = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let displayName = currentDisplayName()

        if isTypingNow && !lastSentTypingState {
            lastSentTypingState = true

            Task {
                await crewStore.sendTypingEvent(
                    crewID: crew.id,
                    userID: userID,
                    name: displayName,
                    isTyping: true
                )
            }
        }

        typingStopTask?.cancel()

        typingStopTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            await MainActor.run {
                if draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || lastSentTypingState {
                    lastSentTypingState = false

                    Task {
                        await crewStore.sendTypingEvent(
                            crewID: crew.id,
                            userID: userID,
                            name: displayName,
                            isTyping: false
                        )
                    }
                }
            }
        }
    }

    func mentionStyledText(
        _ text: String,
        baseColor: Color,
        mentionColor: Color
    ) -> Text {
        let words = text.split(separator: " ", omittingEmptySubsequences: false)
        guard !words.isEmpty else { return Text("").foregroundColor(baseColor) }

        var result = Text("")

        for index in words.indices {
            let word = String(words[index])
            let piece: Text

            if word.hasPrefix("@") && word.count > 1 {
                piece = Text(word).foregroundColor(mentionColor)
            } else {
                piece = Text(word).foregroundColor(baseColor)
            }

            result = result + piece

            if index != words.indices.last {
                result = result + Text(" ").foregroundColor(baseColor)
            }
        }

        return result
    }

    func isoDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return ISO8601DateFormatter().date(from: raw)
    }

    func currentDisplayName() -> String {
        if let email = session.currentUser?.email, !email.isEmpty {
            return email
        }
        return "You"
    }
}
