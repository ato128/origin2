//
//  CrewChatView+Messages.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension CrewChatView {
    var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        VStack(spacing: 8) {
                            if shouldShowDateSeparator(at: index) {
                                dateSeparator(for: message.createdAt)
                                    .padding(.vertical, 8)
                            }

                            messageBubble(message, index: index)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .hideKeyboardOnTap()
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy, animated: true)

                guard let myID = session.currentUser?.id else { return }

                Task {
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
                } else if let username = profile?.username, !username.isEmpty {
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
                .foregroundStyle(message.isFromMe ? .white.opacity(0.78) : palette.secondaryText)
        } else if message.isFailed {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        } else if message.isFromMe {
            let seen = messageSeenByAnyone(message)

            HStack(spacing: -2) {
                Image(systemName: "checkmark")
                    .font(.caption2.bold())
                    .foregroundStyle(seen ? .blue : .white.opacity(0.82))

                Image(systemName: "checkmark")
                    .font(.caption2.bold())
                    .foregroundStyle(seen ? .blue : .white.opacity(0.82))
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
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(palette.secondaryCardFill)
                        .overlay(
                            Capsule()
                                .stroke(palette.cardStroke, lineWidth: 1)
                        )
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
                            .foregroundStyle(palette.secondaryText)
                            .padding(.horizontal, 4)
                    }

                    VStack(alignment: isFromMe ? .trailing : .leading, spacing: 6) {
                        if let replyPreview = message.replyPreview {
                            HStack(spacing: 6) {
                                Rectangle()
                                    .fill(
                                        isFromMe
                                        ? Color.white.opacity(0.78)
                                        : Color.accentColor.opacity(0.9)
                                    )
                                    .frame(width: 2, height: 24)
                                    .clipShape(Capsule())

                                VStack(alignment: .leading, spacing: 1) {
                                    Text("crew_chat_reply_label")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(
                                            isFromMe
                                            ? .white.opacity(0.82)
                                            : palette.secondaryText
                                        )

                                    Text(replyPreview)
                                        .font(.caption2)
                                        .foregroundStyle(
                                            isFromMe
                                            ? .white.opacity(0.92)
                                            : palette.secondaryText
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
                                        ? Color.white.opacity(0.10)
                                        : Color.white.opacity(appTheme == AppTheme.light.rawValue ? 0.28 : 0.04)
                                    )
                            )
                        }

                        Text(message.displayText)
                            .font(.subheadline)
                            .foregroundStyle(isFromMe ? .white : palette.primaryText)
                            .multilineTextAlignment(.leading)

                        if isFromMe {
                            HStack(spacing: 5) {
                                Text(message.createdAt, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.78))

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
                                ? Color.accentColor.opacity(appTheme == AppTheme.light.rawValue ? 0.68 : 0.24)
                                : palette.secondaryCardFill
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(isFromMe ? 0.14 : 0.00),
                                                Color.clear
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                isFromMe
                                ? Color.white.opacity(0.10)
                                : palette.cardStroke.opacity(0.7),
                                lineWidth: 1
                            )
                    )
                    .padding(.top, topSpacing)

                    if !isFromMe {
                        HStack(spacing: 6) {
                            Text(message.createdAt, style: .time)
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryText)

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
}
