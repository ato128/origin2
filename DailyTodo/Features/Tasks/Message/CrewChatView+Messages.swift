//
//  CrewChatView+Messages.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension CrewChatView {

    var messages: [CrewChatMessageItem] {
        crewStore.chatMessagesByCrew[crew.id] ?? []
    }

    var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        VStack(spacing: 8) {
                            if shouldShowDateSeparator(at: index) {
                                dateSeparator(for: message.createdAt)
                                    .padding(.vertical, 6)
                            }

                            messageBubble(message, index: index)
                                .id(message.id)
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("crew-chat-bottom-anchor")
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 126)
            }
            .scrollIndicators(.hidden)
            .hideKeyboardOnTap()
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy, animated: true)

                guard let myID = session.currentUser?.id else { return }

                Task(priority: .utility) {
                    try? await Task.sleep(nanoseconds: 700_000_000)

                    await crewStore.markCrewMessagesAsRead(
                        crewID: crew.id,
                        userID: myID
                    )
                }
            }
        }
    }

    func lastReadDate(for userID: UUID) -> Date? {
        guard let raw = crewStore.crewMessageReads.first(where: {
            $0.crew_id == crew.id && $0.user_id == userID
        })?.last_read_at else {
            return nil
        }

        return ISO8601DateFormatter().date(from: raw)
    }

    func messageSeenByAnyone(_ message: CrewChatMessageItem) -> Bool {
        guard let currentUserID = session.currentUser?.id else { return false }
        guard message.senderID == currentUserID else { return false }

        let otherMembers = crewMembers.filter { $0.userID != currentUserID }
        guard !otherMembers.isEmpty else { return false }

        return otherMembers.contains { member in
            guard let readDate = lastReadDate(for: member.userID) else { return false }
            return readDate.timeIntervalSince1970 >= message.createdAt.timeIntervalSince1970 - 1
        }
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
                } else if let username = profile?.username,
                          !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    name = username
                } else {
                    name = String(localized: "crew_chat_unknown_user")
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

    @ViewBuilder
    func messageStatusView(for message: CrewChatMessageItem) -> some View {
        if message.isPending {
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundStyle(message.isFromMe ? .white.opacity(0.72) : palette.secondaryText)

        } else if message.isFailed {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)

        } else if message.isFromMe {
            let seen = messageSeenByAnyone(message)

            HStack(spacing: -2) {
                Image(systemName: "checkmark")
                    .font(.caption2.bold())
                    .foregroundStyle(seen ? .blue : .white.opacity(0.80))

                Image(systemName: "checkmark")
                    .font(.caption2.bold())
                    .foregroundStyle(seen ? .blue : .white.opacity(0.80))
            }
        }
    }

    @ViewBuilder
    func messageBubble(_ message: CrewChatMessageItem, index: Int) -> some View {
        let text = message.displayText.lowercased()

        let isFocusSystemMessage =
            message.isSystemMessage ||
            text.contains("shared focus session") ||
            text.contains("started a") ||
            text.contains("ended the shared focus session") ||
            text.contains("joined the shared focus session") ||
            text.contains("paused the shared focus session") ||
            text.contains("resumed the shared focus session") ||
            text.contains("paylaşılan odak oturumu") ||
            text.contains("odak oturumunu başlattı") ||
            text.contains("odak oturumunu bitirdi") ||
            text.contains("odak oturumuna katıldı") ||
            text.contains("odak oturumunu duraklattı") ||
            text.contains("odak oturumunu devam ettirdi")

        let showSenderName = shouldShowSenderName(at: index)
        let topSpacing: CGFloat = shouldTightenSpacing(at: index) ? 2 : 8
        let isFromMe = message.isFromMe

        HStack(alignment: .bottom) {
            if isFocusSystemMessage {
                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.caption.bold())
                        .foregroundStyle(.green)

                    Text(message.displayText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.07))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
                )

                Spacer()
            } else {
                if isFromMe {
                    Spacer(minLength: 42)
                }

                VStack(alignment: isFromMe ? .trailing : .leading, spacing: 3) {
                    if !isFromMe && showSenderName {
                        Text(message.senderName)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.horizontal, 4)
                    }

                    VStack(alignment: isFromMe ? .trailing : .leading, spacing: 6) {
                        if let replyPreview = message.replyPreview {
                            HStack(spacing: 6) {
                                Rectangle()
                                    .fill(
                                        isFromMe
                                        ? Color.white.opacity(0.76)
                                        : Color.accentColor.opacity(0.90)
                                    )
                                    .frame(width: 2, height: 24)
                                    .clipShape(Capsule())

                                VStack(alignment: .leading, spacing: 1) {
                                    Text("crew_chat_reply_label")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(
                                            isFromMe
                                            ? .white.opacity(0.82)
                                            : .white.opacity(0.62)
                                        )

                                    Text(replyPreview)
                                        .font(.caption2)
                                        .foregroundStyle(
                                            isFromMe
                                            ? .white.opacity(0.90)
                                            : .white.opacity(0.58)
                                        )
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        isFromMe
                                        ? Color.white.opacity(0.12)
                                        : Color.white.opacity(0.05)
                                    )
                            )
                        }

                        Text(message.displayText)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(isFromMe ? .white : .white.opacity(0.95))
                            .multilineTextAlignment(.leading)

                        if isFromMe {
                            HStack(spacing: 5) {
                                Text(message.createdAt, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.76))

                                messageStatusView(for: message)
                            }
                            .padding(.top, 1)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                isFromMe
                                ? LinearGradient(
                                    colors: [
                                        Color(red: 0.34, green: 0.62, blue: 1.0),
                                        Color(red: 0.25, green: 0.55, blue: 0.98)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.09),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                isFromMe
                                ? Color.white.opacity(0.10)
                                : Color.white.opacity(0.08),
                                lineWidth: 0.8
                            )
                    )
                    .padding(.top, topSpacing)
                    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .onLongPressGesture(minimumDuration: 0.28) {
                        Haptics.impact(.light)
                        replyingTo = message
                    }

                    if !isFromMe {
                        HStack(spacing: 6) {
                            Text(message.createdAt, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.42))

                            messageStatusView(for: message)
                        }
                        .padding(.horizontal, 4)
                    }
                }

                if !isFromMe {
                    Spacer(minLength: 42)
                }
            }
        }
    }

    func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if animated {
                withAnimation(.easeOut(duration: 0.22)) {
                    proxy.scrollTo("crew-chat-bottom-anchor", anchor: .bottom)
                }
            } else {
                proxy.scrollTo("crew-chat-bottom-anchor", anchor: .bottom)
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
            .foregroundStyle(.white.opacity(0.62))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
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
}
