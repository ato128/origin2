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
            }
        }
    }

    func messageBubble(_ message: CrewChatMessageItem, index: Int) -> some View {
        let isFocusSystemMessage =
            message.displayText.contains("started a") && message.displayText.contains("shared focus session") ||
            message.displayText.contains("ended the shared focus session") ||
            message.displayText.contains("joined the shared focus session") ||
            message.displayText.contains("paused the shared focus session") ||
            message.displayText.contains("resumed the shared focus session")

        let showSenderName = shouldShowSenderName(at: index)
        let topSpacing: CGFloat = shouldTightenSpacing(at: index) ? 2 : 8

        return HStack(alignment: .bottom) {
            if isFocusSystemMessage || message.isSystemMessage {
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
                if message.isFromMe {
                    Spacer(minLength: 42)
                }

                VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 5) {
                    if !message.isFromMe && showSenderName {
                        Text(message.senderName)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(palette.secondaryText)
                            .padding(.horizontal, 4)
                    }

                    VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 5) {
                        if let replyPreview = message.replyPreview {
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

                        Text(message.displayText)
                            .font(.subheadline)
                            .foregroundStyle(message.isFromMe ? .white : palette.primaryText)
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
                                : palette.cardStroke.opacity(0.7),
                                lineWidth: 1
                            )
                    )
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

                    HStack(spacing: 6) {
                        Text(message.createdAt, style: .time)
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryText)

                        if message.isPending {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryText)
                        }

                        if message.isFailed {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.top, topSpacing)

                if !message.isFromMe {
                    Spacer(minLength: 42)
                }
            }
        }
    }
}
