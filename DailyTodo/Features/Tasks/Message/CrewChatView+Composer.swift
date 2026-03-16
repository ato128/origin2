//
//  CrewChatView+Composer.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension CrewChatView{
    var composerBar: some View {
        VStack(spacing: 4) {
            if let replyingTo {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2, height: 28)
                        .clipShape(Capsule())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replying to \(replyingTo.isFromMe ? "yourself" : replyingTo.senderName)")
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

            if showMentionPicker && !filteredMentionMembers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filteredMentionMembers) { member in
                            Button {
                                insertMention(member.name)
                            } label: {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(hexColor(crew.colorHex).opacity(0.18))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Text(String(member.name.prefix(1)).uppercased())
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(hexColor(crew.colorHex))
                                        )

                                    Text("@\(member.name)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(palette.primaryText)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(palette.secondaryCardFill)
                                        .overlay(
                                            Capsule()
                                                .stroke(palette.cardStroke.opacity(0.7), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 2)
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
                    .focused($isComposerFocused)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(palette.secondaryCardFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(palette.cardStroke, lineWidth: 1)
                            )
                    )
                    .foregroundStyle(palette.primaryText)
                    .onChange(of: draftMessage) { _, newValue in
                        updateMentionState(for: newValue)
                    }

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
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(palette.cardStroke)
                        .frame(height: 0.8),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }
    func updateMentionState(for text: String) {
        guard let lastWord = text.split(separator: " ", omittingEmptySubsequences: false).last else {
            showMentionPicker = false
            mentionQuery = ""
            return
        }

        if lastWord.hasPrefix("@") {
            mentionQuery = String(lastWord.dropFirst())
            showMentionPicker = true
        } else {
            mentionQuery = ""
            showMentionPicker = false
        }
    }
    func insertMention(_ name: String) {
        let words = draftMessage.split(separator: " ", omittingEmptySubsequences: false).map(String.init)

        guard !words.isEmpty else {
            draftMessage = "@\(name) "
            mentionQuery = ""
            showMentionPicker = false
            isComposerFocused = true
            return
        }

        var mutableWords = words

        if let last = mutableWords.last, last.hasPrefix("@") {
            mutableWords.removeLast()
        }

        let prefix = mutableWords.joined(separator: " ")

        if prefix.isEmpty {
            draftMessage = "@\(name) "
        } else {
            draftMessage = "\(prefix) @\(name) "
        }

        mentionQuery = ""
        showMentionPicker = false
        isComposerFocused = true
    }
    func mentionStyledText(
        _ text: String,
        baseColor: Color,
        mentionColor: Color
    ) -> Text {
        let words = text.split(separator: " ", omittingEmptySubsequences: false)
        guard !words.isEmpty else { return Text("").foregroundColor(baseColor) }

        var result = Text("")

        for index in words.indices {
            let word = String(words[index])
            let piece: Text

            if word.hasPrefix("@") && word.count > 1 {
                piece = Text(word)
                    .foregroundColor(mentionColor)
            } else {
                piece = Text(word)
                    .foregroundColor(baseColor)
            }

            result = result + piece

            if index != words.indices.last {
                result = result + Text(" ").foregroundColor(baseColor)
            }
        }

        return result
    }
}
