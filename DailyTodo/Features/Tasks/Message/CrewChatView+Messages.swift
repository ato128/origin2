//
//  CrewChatView+Messages.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension CrewChatView {
    @ViewBuilder
    var typingIndicatorView: some View {
        if !typingNames.isEmpty {
            HStack {
                HStack(spacing: 8) {
                    TypingDotsView()

                    Text(typingIndicatorText)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(palette.secondaryCardFill)
                        .overlay(
                            Capsule()
                                .stroke(palette.cardStroke, lineWidth: 1)
                        )
                )

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, row in
                        VStack(spacing: 8) {
                            if shouldShowDateSeparator(at: index) {
                                dateSeparator(for: row.createdAt)
                                    .padding(.vertical, 10)
                            }

                            messageBubble(row, index: index)
                                .id(row.id)
                                .transition(.opacity)
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
            }
        }
    }

    @ViewBuilder
    func messageBubble(_ row: CrewMessageRowItem, index: Int) -> some View {
        let isFromMe = row.senderID == session.currentUser?.id
        let fullText = row.text
        let messageBody = visibleMessageText(from: fullText)
        let replyPreview = replyPreviewText(from: fullText)
        let createdAt = row.createdAt
        let backendMessage = row.backendMessage
        let isReactionMenuOpen = backendMessage != nil && reactionTarget?.id == backendMessage?.id
        let isPressed = backendMessage != nil && pressedMessageID == backendMessage?.id

        let isFocusSystemMessage =
            messageBody.contains("started a") && messageBody.contains("shared focus session") ||
            messageBody.contains("ended the shared focus session") ||
            messageBody.contains("joined the shared focus session") ||
            messageBody.contains("paused the shared focus session") ||
            messageBody.contains("resumed the shared focus session")

        let showSenderName = shouldShowSenderName(at: index)
        let topSpacing: CGFloat = shouldTightenSpacing(at: index) ? 2 : 8

        HStack(alignment: .bottom) {
            if isFocusSystemMessage {
                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.caption.bold())
                        .foregroundStyle(.green)

                    Text(messageBody)
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

                VStack(alignment: isFromMe ? .trailing : .leading, spacing: 5) {
                    if !isFromMe && showSenderName {
                        Text(row.senderName)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(palette.secondaryText)
                            .padding(.horizontal, 4)
                    }

                    ZStack(alignment: isFromMe ? .bottomTrailing : .bottomLeading) {
                        if let backendMessage, isReactionMenuOpen {
                            reactionMenu(for: backendMessage)
                        }

                        VStack(alignment: isFromMe ? .trailing : .leading, spacing: 5) {
                            if let replyPreview {
                                HStack(spacing: 6) {
                                    Rectangle()
                                        .fill(
                                            isFromMe
                                            ? Color.white.opacity(0.75)
                                            : Color.accentColor.opacity(0.9)
                                        )
                                        .frame(width: 2, height: 24)
                                        .clipShape(Capsule())

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Reply")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(
                                                isFromMe
                                                ? .white.opacity(0.78)
                                                : palette.secondaryText
                                            )

                                        Text(replyPreview)
                                            .font(.caption2)
                                            .foregroundStyle(
                                                isFromMe
                                                ? .white.opacity(0.90)
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
                                            ? Color.white.opacity(0.08)
                                            : Color.white.opacity(appTheme == AppTheme.light.rawValue ? 0.28 : 0.04)
                                        )
                                )
                            }

                            mentionStyledText(
                                messageBody,
                                baseColor: isFromMe ? .white : palette.primaryText,
                                mentionColor: isFromMe ? .white.opacity(0.95) : Color.accentColor
                            )
                            .font(.subheadline)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    isFromMe
                                    ? Color.accentColor.opacity(0.90)
                                    : palette.secondaryCardFill
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    isFromMe
                                    ? Color.accentColor.opacity(0.18)
                                    : palette.cardStroke,
                                    lineWidth: 1
                                )
                        )
                        .compositingGroup()

                        if let reaction = row.reaction, !reaction.isEmpty {
                            Text(reaction)
                                .font(.caption)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(palette.cardFill)
                                        .overlay(
                                            Capsule()
                                                .stroke(palette.cardStroke, lineWidth: 1)
                                        )
                                )
                                .offset(
                                    x: isFromMe ? 10 : -10,
                                    y: 12
                                )
                                .shadow(color: palette.shadowColor.opacity(0.10), radius: 2, y: 1)
                        }
                    }
                    .padding(.top, isReactionMenuOpen ? 52 : 0)
                    .padding(.bottom, ((row.reaction ?? "").isEmpty ? 0 : 10))
                    .scaleEffect(isPressed ? 1.01 : 1.0)
                    .shadow(
                        color: isPressed ? Color.black.opacity(0.08) : Color.clear,
                        radius: 4,
                        y: 2
                    )
                    .animation(.easeOut(duration: 0.14), value: isPressed)
                    .animation(.easeOut(duration: 0.14), value: isReactionMenuOpen)

                    HStack(spacing: 6) {
                        Text(createdAt, style: .time)
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryText)

                        messageStatusView(for: row, isFromMe: isFromMe)
                    }
                    .padding(.horizontal, 4)
                    .opacity(row.isOptimistic ? 0.85 : 1.0)
                }
                .padding(.top, topSpacing)
                .opacity(reactionTarget == nil || reactionTarget?.id == backendMessage?.id ? 1.0 : 0.55)
                .animation(.easeOut(duration: 0.12), value: reactionTarget?.id)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            if value.translation.width > 65, let backendMessage {
                                replyingTo = backendMessage
                                isComposerFocused = true

                                let gen = UIImpactFeedbackGenerator(style: .light)
                                gen.prepare()
                                gen.impactOccurred()
                            }
                        }
                )

                if !isFromMe {
                    Spacer(minLength: 42)
                }
            }
        }
    }

    func reactionMenu(for message: CrewMessageDTO) -> some View {
        HStack(spacing: 10) {
            ForEach(["👍", "❤️", "😂", "😮", "😢"], id: \.self) { emoji in
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .medium)
                    gen.prepare()
                    gen.impactOccurred()

                    Task {
                        do {
                            let newReaction = message.reaction == emoji ? nil : emoji
                            try await crewStore.updateCrewMessageReaction(
                                messageID: message.id,
                                reaction: newReaction
                            )
                            await crewStore.loadCrewMessages(for: crew.id)
                            reactionTarget = nil
                        } catch {
                            print("UPDATE REACTION ERROR:", error.localizedDescription)
                        }
                    }
                } label: {
                    Text(emoji)
                        .font(.title3)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(palette.cardFill)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(palette.cardFill)
                .overlay(
                    Capsule()
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
        .offset(y: -58)
        .zIndex(2)
    }
}
