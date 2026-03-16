//
//  CrewChatView+Messages.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI
import SwiftData

extension CrewChatView {
    var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        messageBubble(message)
                            .id(message.id)
                            .offset(y: animateMessages ? 0 : CGFloat(12 + index * 4))
                            .opacity(animateMessages ? 1 : 0)
                            .scaleEffect(animateMessages ? 1 : 0.985)
                            .animation(
                                .spring(response: 0.40, dampingFraction: 0.86)
                                    .delay(Double(index) * 0.03),
                                value: animateMessages
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .hideKeyboardOnTap()
            .onAppear {
                animateMessages = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        animateMessages = true
                    }
                }

                scrollToBottom(proxy: proxy)
            }
            .onChange(of: messages.count) { _, _ in
                markMessagesAsRead()
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    func messageBubble(_ message: CrewMessage) -> some View {
        let fullText = message.text
        let messageBody = visibleMessageText(from: fullText)
        let replyPreview = replyPreviewText(from: fullText)

        let isFocusSystemMessage =
            messageBody.contains("started a") && messageBody.contains("shared focus session") ||
            messageBody.contains("ended the shared focus session") ||
            messageBody.contains("joined the shared focus session") ||
            messageBody.contains("paused the shared focus session") ||
            messageBody.contains("resumed the shared focus session")

        let isReactionMenuOpen = reactionTarget?.id == message.id
        let isPressed = pressedMessageID == message.id

        return HStack(alignment: .bottom) {
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
                if message.isFromMe { Spacer(minLength: 42) }

                VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 5) {
                    if !message.isFromMe {
                        Text(message.senderName)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(palette.secondaryText)
                            .padding(.horizontal, 4)
                    }

                    ZStack(alignment: message.isFromMe ? .bottomTrailing : .bottomLeading) {

                        if isReactionMenuOpen {
                            HStack(spacing: 10) {
                                ForEach(["👍", "❤️", "😂", "😮", "😢"], id: \.self) { emoji in
                                    Button {
                                        let gen = UIImpactFeedbackGenerator(style: .medium)
                                        gen.prepare()
                                        gen.impactOccurred()

                                        if message.reaction == emoji {
                                            message.reaction = nil
                                        } else {
                                            message.reaction = emoji
                                        }

                                        try? modelContext.save()
                                        reactionTarget = nil
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
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(palette.cardStroke, lineWidth: 1)
                                    )
                            )
                            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                            .offset(y: -58)
                            .zIndex(2)
                        }

                        VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 5) {
                            if let replyPreview {
                                HStack(spacing: 6) {
                                    Rectangle()
                                        .fill(
                                            message.isFromMe
                                            ? Color.white.opacity(0.75)
                                            : Color.accentColor.opacity(0.9)
                                        )
                                        .frame(width: 2, height: 24)
                                        .clipShape(Capsule())

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Reply")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(
                                                message.isFromMe
                                                ? .white.opacity(0.78)
                                                : palette.secondaryText
                                            )

                                        Text(replyPreview)
                                            .font(.caption2)
                                            .foregroundStyle(
                                                message.isFromMe
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
                                            message.isFromMe
                                            ? Color.white.opacity(0.08)
                                            : Color.white.opacity(appTheme == AppTheme.light.rawValue ? 0.28 : 0.04)
                                        )
                                )
                            }

                            mentionStyledText(
                                messageBody,
                                baseColor: message.isFromMe ? .white : palette.primaryText,
                                mentionColor: message.isFromMe ? .white.opacity(0.95) : Color.accentColor
                            )
                            .font(.subheadline)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    message.isFromMe
                                    ? Color.accentColor.opacity(0.90)
                                    : palette.secondaryCardFill
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    message.isFromMe
                                    ? Color.accentColor.opacity(0.18)
                                    : palette.cardStroke,
                                    lineWidth: 1
                                )
                        )

                        if let reaction = message.reaction {
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
                                    x: message.isFromMe ? 10 : -10,
                                    y: 12
                                )
                                .shadow(color: palette.shadowColor.opacity(0.18), radius: 4, y: 2)
                        }
                    }
                    .padding(.top, isReactionMenuOpen ? 52 : 0)
                    .padding(.bottom, message.reaction == nil ? 0 : 10)
                    .scaleEffect(isPressed || isReactionMenuOpen ? 1.03 : 1.0)
                    .shadow(
                        color: (isPressed || isReactionMenuOpen)
                        ? Color.black.opacity(0.16)
                        : Color.clear,
                        radius: 10,
                        y: 4
                    )
                    .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isPressed)
                    .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isReactionMenuOpen)

                    Text(message.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryText)
                        .padding(.horizontal, 4)
                }
                .opacity(reactionTarget == nil || reactionTarget?.id == message.id ? 1.0 : 0.55)
                .animation(.easeInOut(duration: 0.16), value: reactionTarget?.id)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            if value.translation.width > 65 {
                                replyingTo = message
                                isComposerFocused = true

                                let gen = UIImpactFeedbackGenerator(style: .light)
                                gen.prepare()
                                gen.impactOccurred()
                            }
                        }
                )
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.18)
                        .onChanged { _ in
                            if pressedMessageID != message.id {
                                pressedMessageID = message.id

                                let gen = UIImpactFeedbackGenerator(style: .light)
                                gen.prepare()
                                gen.impactOccurred()
                            }
                        }
                        .onEnded { _ in
                            let gen = UIImpactFeedbackGenerator(style: .medium)
                            gen.prepare()
                            gen.impactOccurred()

                            if reactionTarget?.id == message.id {
                                reactionTarget = nil
                            } else {
                                reactionTarget = message
                            }

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                pressedMessageID = nil
                            }
                        }
                )

                if !message.isFromMe { Spacer(minLength: 42) }
            }
        }
    }
    func reactionPicker(for message: CrewMessage) -> some View {
        let reactions = ["👍", "❤️", "😂", "😮", "😢"]

        return ZStack {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture {
                    reactionTarget = nil
                }

            VStack {
                Spacer()

                HStack {
                    if message.isFromMe { Spacer() }

                    HStack(spacing: 12) {
                        ForEach(reactions, id: \.self) { emoji in
                            Button {
                                let gen = UIImpactFeedbackGenerator(style: .light)
                                gen.prepare()
                                gen.impactOccurred()

                                if message.reaction == emoji {
                                    message.reaction = nil
                                } else {
                                    message.reaction = emoji
                                }

                                try? modelContext.save()
                                reactionTarget = nil
                            } label: {
                                Text(emoji)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(palette.cardFill)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(palette.cardStroke, lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                    .padding(.horizontal, 20)

                    if !message.isFromMe { Spacer() }
                }
                .padding(.bottom, 160)
            }
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: reactionTarget)
        }
    }
}
