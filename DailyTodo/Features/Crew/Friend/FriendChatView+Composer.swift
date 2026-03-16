//
//  FriendChatView+Composer.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension FriendChatView {
    var composerBar: some View {
        VStack(spacing: 4) {
            if let replyingTo {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2, height: 28)
                        .clipShape(Capsule())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replying to \(replyingTo.isFromMe ? "yourself" : friend.name)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)

                        Text(visibleMessageText(from: replyingTo.text))
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    Button {
                        self.replyingTo = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(palette.secondaryText)
                            .frame(width: 22, height: 22)
                            .background(
                                Circle()
                                    .fill(palette.secondaryCardFill)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.cardFill.opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(palette.cardStroke.opacity(0.65), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message \(friend.name)...", text: $draftMessage, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(palette.primaryText)
                    .focused($isComposerFocused)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(palette.secondaryCardFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(palette.cardStroke.opacity(0.7), lineWidth: 1)
                            )
                    )

                Button {
                    sendMessage()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? palette.secondaryCardFill
                                : Color.accentColor
                            )
                            .frame(width: 46, height: 46)

                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(
                                draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? palette.secondaryText
                                : .white
                            )
                    }
                    .scaleEffect(sendPressed ? 0.92 : 1.0)
                    .animation(.spring(response: 0.22, dampingFraction: 0.70), value: sendPressed)
                }
                .buttonStyle(.plain)
                .disabled(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            sendPressed = true
                        }
                        .onEnded { _ in
                            sendPressed = false
                        }
                )
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .fill(palette.cardFill)
                .overlay(
                    Rectangle()
                        .fill(palette.cardStroke)
                        .frame(height: 0.8),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }

}
