//
//  CrewChatView+Composer.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//
import SwiftUI

extension CrewChatView {

    var composerBar: some View {
        VStack(spacing: 6) {
            if let currentReply = replyingTo {
                replyPreviewBar(currentReply)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .center, spacing: 10) {
                Button {
                    showFocusDurationSheet = true
                } label: {
                    Image(systemName: "timer")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .frame(width: 42, height: 42)
                        .background(glassCircleBackground)
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    TextField(
                        String(
                            format: NSLocalizedString("crew_chat_message_placeholder", comment: ""),
                            crew.name
                        ),
                        text: $draftMessage
                    )
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .focused($isComposerFocused)
                    .onChange(of: draftMessage) { _, newValue in
                        handleTypingChange(newValue)
                    }

                    composerActionButton
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(composerCapsuleBackground)
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 10)
        .animation(.easeOut(duration: 0.18), value: replyingTo?.id)
    }

    @ViewBuilder
    func replyPreviewBar(_ currentReply: CrewChatMessageItem) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 2.5, height: 28)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                let replyingName = currentReply.isFromMe
                    ? NSLocalizedString("crew_chat_reply_yourself", comment: "")
                    : currentReply.senderName

                Text("crew_chat_replying_to \(replyingName)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text(currentReply.displayText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Button {
                replyingTo = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.7)
        )
        .padding(.horizontal, 16)
    }

    var composerActionButton: some View {
        let canSend = !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return Button {
            if canSend {
                sendMessage()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        canSend
                        ? Color.accentColor
                        : Color.clear
                    )
                    .frame(width: 30, height: 30)

                Image(systemName: canSend ? "arrow.up" : "mic.fill")
                    .font(.system(size: canSend ? 13 : 17, weight: .bold))
                    .foregroundStyle(
                        canSend
                        ? .white
                        : .white.opacity(0.78)
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(!canSend && !draftMessage.isEmpty)
        .animation(.easeOut(duration: 0.16), value: canSend)
    }

    var composerCapsuleBackground: some View {
        Capsule()
            .fill(Color.white.opacity(0.08))
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.7)
            )
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

                Task(priority: .utility) {
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

            Task(priority: .utility) {
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

        Haptics.impact(.light)

        if let myID = session.currentUser?.id {
            Task(priority: .utility) {
                await crewStore.sendTypingEvent(
                    crewID: crew.id,
                    userID: myID,
                    name: currentDisplayName(),
                    isTyping: false
                )
            }
        }

        Task(priority: .userInitiated) {
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
}
