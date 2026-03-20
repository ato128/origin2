//
//  CrewChatView+Composer.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//
import SwiftUI

extension CrewChatView {
    var composerBar: some View {
        VStack(spacing: 4) {
            if let currentReply = replyingTo {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2, height: 28)
                        .clipShape(Capsule())

                    VStack(alignment: .leading, spacing: 2) {
                        let replyingName = currentReply.isFromMe ? "yourself" : currentReply.senderName
                        Text(currentReply.displayText)

                        Text("Replying to \(replyingName)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)

                        Text(currentReply.displayText)
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 6)

                    Button {
                        replyingTo = nil
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
                Button {
                    showFocusDurationSheet = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.18))
                            .frame(width: 42, height: 42)

                        Image(systemName: "timer")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.green)
                    }
                }
                .buttonStyle(.plain)

                TextField("Message \(crew.name)...", text: $draftMessage, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(palette.primaryText)
                    .focused($isComposerFocused)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .onChange(of: draftMessage) { _, newValue in
                        handleTypingChange(newValue)
                    }
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
                }
                .buttonStyle(.plain)
                .disabled(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

