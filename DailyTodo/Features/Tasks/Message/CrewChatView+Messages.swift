//
//  CrewChatView+Messages.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension CrewChatView {

    var messages: [CrewChatMessageItem] {
        backendMessages.sorted { $0.createdAt < $1.createdAt }
    }

    var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        VStack(spacing: 6) {
                            if shouldShowDateSeparator(at: index) {
                                dateSeparator(for: message.createdAt)
                                    .padding(.vertical, 8)
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

                Task(priority: .utility) {
                    try? await Task.sleep(nanoseconds: 700_000_000)

                    if let backendConversationID {
                        await ChatBackendClient.shared.markConversationRead(
                            conversationID: backendConversationID
                        )
                    }
                }
            }
        }
    }

    func messageSeenByAnyone(_ message: CrewChatMessageItem) -> Bool {
        guard message.isFromMe else { return false }
        guard !message.isPending, !message.isFailed else { return false }

        let messageID = message.serverID ?? message.id
        return seenMessageIDs.contains(messageID)
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
        if message.messageStatus == "uploading" {
            ProgressView()
                .scaleEffect(0.55)
                .tint(.white.opacity(0.9))

        } else if message.isPending {
            Image(systemName: "clock")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(message.isFromMe ? .white.opacity(0.55) : .white.opacity(0.36))

        } else if message.isFailed {
            // Insta DM mantığı: başarısız mesaj tek dokunuşla tekrar gönderilir
            Button {
                resendFailedCrewMessage(message)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9, weight: .bold))

                    Text("Tekrar dene")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.red.opacity(0.9))
            }
            .buttonStyle(.plain)

        } else if message.isFromMe {
            let seen = messageSeenByAnyone(message)

            HStack(spacing: -3) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(seen ? Color(crewChatMessageHex: "#2DD4FF") : .white.opacity(0.72))
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
            text.contains(tr("ccm_shared_session")) ||
            text.contains(tr("ccm_started_session")) ||
            text.contains("odak oturumunu bitirdi") ||
            text.contains(tr("ccm_joined_session")) ||
            text.contains(tr("ccm_paused_session")) ||
            text.contains("odak oturumunu devam ettirdi")

        let showSenderName = shouldShowSenderName(at: index)
        let topSpacing: CGFloat = shouldTightenSpacing(at: index) ? 1 : 7
        let isFromMe = message.isFromMe

        HStack(alignment: .bottom) {
            if isFocusSystemMessage {
                Spacer()

                HStack(spacing: 9) {
                    Image(systemName: "timer")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color(crewChatMessageHex: "#A3E635"))

                    Text(message.displayText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.84))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(crewChatMessageHex: "#A3E635").opacity(0.10),
                                    Color(crewChatMessageHex: "#1593FF").opacity(0.060),
                                    Color.white.opacity(0.045)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.09), lineWidth: 1)
                        )
                )

                Spacer()
            } else {
                if isFromMe {
                    Spacer(minLength: 54)
                }

                VStack(alignment: isFromMe ? .trailing : .leading, spacing: 3) {
                    if !isFromMe && showSenderName {
                        Text(message.senderName)
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(senderNameTint(for: message.senderName))
                            .padding(.horizontal, 5)
                            .padding(.bottom, 1)
                    }

                    VStack(alignment: isFromMe ? .trailing : .leading, spacing: 6) {
                        if let replyPreview = message.replyPreview {
                            replyPreviewView(
                                replyPreview,
                                isFromMe: isFromMe
                            )
                        }

                        if message.messageType == "image" {
                            crewImageMessageView(message)
                        } else {
                            Text(message.displayText)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(isFromMe ? .white : .white.opacity(0.96))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if isFromMe {
                            HStack(spacing: 5) {
                                Text(message.createdAt, style: .time)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.70))

                                messageStatusView(for: message)
                            }
                            .padding(.top, 1)
                        }
                    }
                    .padding(message.messageType == "image" ? 8 : 14)
                    .background(messageBubbleBackground(isFromMe: isFromMe))
                    .clipShape(crewBubbleShape(isFromMe: isFromMe))
                    .contentShape(crewBubbleShape(isFromMe: isFromMe))
                    .padding(.top, topSpacing)
                    .onLongPressGesture(minimumDuration: 0.28) {
                        Haptics.impact(.light)
                        replyingTo = message
                    }

                    if !isFromMe {
                        HStack(spacing: 6) {
                            Text(message.createdAt, style: .time)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.36))

                            messageStatusView(for: message)
                        }
                        .padding(.horizontal, 5)
                        .padding(.top, 1)
                    }
                }

                if !isFromMe {
                    Spacer(minLength: 54)
                }
            }
        }
    }

    func crewImageMessageView(_ message: CrewChatMessageItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let mediaURL = message.mediaURL,
                   let url = URL(string: mediaURL) {
                    AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 220, height: 260)
                                .overlay {
                                    ProgressView()
                                        .tint(.white.opacity(0.8))
                                }

                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 220, height: 260)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        case .failure:
                            imageFailurePlaceholder

                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 220, height: 260)
                        .overlay {
                            if message.messageStatus == "uploading" || message.isPending {
                                VStack(spacing: 10) {
                                    ProgressView()
                                        .tint(.white)

                                    Text(tr("fc_photo_loading"))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            } else if message.isFailed {
                                Button {
                                    resendFailedCrewMessage(message)
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: "arrow.clockwise.circle.fill")
                                            .font(.system(size: 26, weight: .bold))

                                        Text(tr("fc_send_failed_retry"))
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundStyle(.red.opacity(0.95))
                                }
                                .buttonStyle(.plain)
                            } else {
                                imageFailurePlaceholder
                            }
                        }
                }
            }

            if !message.displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               message.displayText != tr("fc_photo_emoji") {
                Text(message.displayText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(message.isFromMe ? .white : .white.opacity(0.96))
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
            }
        }
    }

    var imageFailurePlaceholder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .frame(width: 220, height: 260)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 26, weight: .medium))

                    Text(tr("fc_image_load_failed"))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.75))
            }
    }

    func replyPreviewView(_ replyPreview: String, isFromMe: Bool) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(
                    isFromMe
                    ? Color.white.opacity(0.78)
                    : Color(crewChatMessageHex: "#2DD4FF").opacity(0.90)
                )
                .frame(width: 3, height: 26)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text("crew_chat_reply_label")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(isFromMe ? .white.opacity(0.82) : Color(crewChatMessageHex: "#2DD4FF"))

                Text(replyPreview)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isFromMe ? .white.opacity(0.78) : .white.opacity(0.52))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isFromMe ? Color.white.opacity(0.12) : Color.white.opacity(0.050))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(isFromMe ? 0.10 : 0.07), lineWidth: 1)
                )
        )
    }

    // Birebir Updo AI baloncuk şekli: konuşan tarafta köşeli kuyruk.
    func crewBubbleShape(isFromMe: Bool) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: isFromMe ? 18 : 5,
            bottomTrailingRadius: isFromMe ? 5 : 18,
            topTrailingRadius: 18,
            style: .continuous
        )
    }

    // Birebir Updo AI baloncuğu: gönderilen cyan→mor gradient, alınan surfaceHigh + border.
    func messageBubbleBackground(isFromMe: Bool) -> some View {
        let shape = crewBubbleShape(isFromMe: isFromMe)
        return Group {
            if isFromMe {
                shape.fill(
                    LinearGradient(
                        colors: [UpdoTheme.cyan, UpdoTheme.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            } else {
                shape.fill(UpdoTheme.surfaceHigh)
                    .overlay(shape.strokeBorder(UpdoTheme.border, lineWidth: 1))
            }
        }
    }

    func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if animated {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
                    proxy.scrollTo("crew-chat-bottom-anchor", anchor: .bottom)
                }
            } else {
                proxy.scrollTo("crew-chat-bottom-anchor", anchor: .bottom)
            }
        }
    }

    func shouldShowDateSeparator(at index: Int) -> Bool {
        guard messages.indices.contains(index) else { return false }

        if index == 0 {
            return true
        }

        let calendar = Calendar.current

        return !calendar.isDate(
            messages[index].createdAt,
            inSameDayAs: messages[index - 1].createdAt
        )
    }

    func shouldShowSenderName(at index: Int) -> Bool {
        guard messages.indices.contains(index) else { return true }

        if index == 0 {
            return true
        }

        let current = messages[index]
        let previous = messages[index - 1]

        let sameSender = current.senderID == previous.senderID
        let sameDay = Calendar.current.isDate(
            current.createdAt,
            inSameDayAs: previous.createdAt
        )

        return !(sameSender && sameDay)
    }

    func shouldTightenSpacing(at index: Int) -> Bool {
        guard index > 0, messages.indices.contains(index) else { return false }

        let current = messages[index]
        let previous = messages[index - 1]

        let sameSender = current.senderID == previous.senderID
        let sameDay = Calendar.current.isDate(
            current.createdAt,
            inSameDayAs: previous.createdAt
        )

        return sameSender && sameDay
    }

    @ViewBuilder
    func dateSeparator(for date: Date) -> some View {
        Text(relativeDateTitle(for: date))
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white.opacity(0.50))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.060))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.085), lineWidth: 1)
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

    func senderNameTint(for name: String) -> Color {
        let palette: [Color] = [
            Color(crewChatMessageHex: "#2DD4FF"),
            Color(crewChatMessageHex: "#A3E635"),
            Color(crewChatMessageHex: "#FBBF24"),
            Color(crewChatMessageHex: "#FF5A44"),
            Color(crewChatMessageHex: "#C084FC")
        ]

        let value = abs(name.unicodeScalars.map { Int($0.value) }.reduce(0, +))
        return palette[value % palette.count]
    }
}

// MARK: - Color Hex

private extension Color {
    init(crewChatMessageHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch cleaned.count {
        case 3:
            a = 255
            r = (int >> 8) * 17
            g = ((int >> 4) & 0xF) * 17
            b = (int & 0xF) * 17

        case 6:
            a = 255
            r = int >> 16
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        case 8:
            a = int >> 24
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        default:
            a = 255
            r = 255
            g = 255
            b = 255
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
