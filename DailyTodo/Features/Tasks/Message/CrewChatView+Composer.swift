//
//  CrewChatView+Composer.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//
import SwiftUI

extension CrewChatView {

    var composerBar: some View {
        VStack(spacing: 8) {
            if let currentReply = replyingTo {
                replyPreviewBar(currentReply)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 10) {
                    TextField(
                        String(
                            format: NSLocalizedString("crew_chat_message_placeholder", comment: ""),
                            crew.name
                        ),
                        text: $draftMessage
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .tint(Color(crewChatComposerHex: "#2DD4FF"))
                    .focused($isComposerFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        sendMessage()
                    }
                    .onChange(of: draftMessage) { _, newValue in
                        handleTypingChange(newValue)
                    }

                    composerActionButton
                }
                .padding(.horizontal, 16)
                .frame(height: 46)
                .background(composerCapsuleBackground)
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 10)
        .animation(.easeOut(duration: 0.18), value: replyingTo?.id)
    }

    @ViewBuilder
    func replyPreviewBar(_ currentReply: CrewChatMessageItem) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color(crewChatComposerHex: "#2DD4FF"))
                .frame(width: 3, height: 30)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 3) {
                let replyingName = currentReply.isFromMe
                    ? NSLocalizedString("crew_chat_reply_yourself", comment: "")
                    : currentReply.senderName

                Text("crew_chat_replying_to \(replyingName)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(crewChatComposerHex: "#2DD4FF"))
                    .lineLimit(1)

                Text(currentReply.displayText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Button {
                replyingTo = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.080))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(crewChatComposerHex: "#1593FF").opacity(0.070),
                            Color(crewChatComposerHex: "#7C3AED").opacity(0.055),
                            Color.white.opacity(0.045)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
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
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    Color(crewChatComposerHex: "#1593FF"),
                                    Color(crewChatComposerHex: "#7C3AED")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(Color.clear)
                    )
                    .frame(width: 31, height: 31)

                Image(systemName: canSend ? "arrow.up" : "mic.fill")
                    .font(.system(size: canSend ? 13 : 17, weight: .black))
                    .foregroundStyle(
                        canSend
                        ? .white
                        : .white.opacity(0.72)
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(!canSend && !draftMessage.isEmpty)
        .animation(.easeOut(duration: 0.16), value: canSend)
    }

    var composerCapsuleBackground: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color(crewChatComposerHex: "#1593FF").opacity(0.075),
                        Color(crewChatComposerHex: "#7C3AED").opacity(0.060),
                        Color.white.opacity(0.055)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 12, y: 6)
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

// MARK: - Color Hex

private extension Color {
    init(crewChatComposerHex hex: String) {
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
