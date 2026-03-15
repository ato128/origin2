//
//  CrewChatView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 15.03.2026.
//
import SwiftUI
import SwiftData

struct CrewChatView: View {
    let crew: Crew

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    @Query(sort: \CrewMessage.createdAt, order: .forward)
    private var allMessages: [CrewMessage]

    @State private var draftMessage: String = ""
    @State private var animateMessages = false
    @State private var showCrewInfo = false
    @State private var replyingTo: CrewMessage?

    @FocusState private var isComposerFocused: Bool

    private let palette = ThemePalette()
    private let replyMarker = "[[reply]]"
    private let bodyMarker = "[[body]]"

    private var messages: [CrewMessage] {
        allMessages.filter { $0.crewID == crew.id }
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()

            VStack(spacing: 0) {
                header

                if messages.isEmpty {
                    emptyState
                } else {
                    messagesList
                }

                composerBar
            }
        }
        .contentShape(Rectangle())
        .hideKeyboardOnTap()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            seedMessagesIfNeeded()
            markMessagesAsRead()
        }
        .sheet(isPresented: $showCrewInfo) {
            NavigationStack {
                CrewChatInfoView(crew: crew)
            }
        }
    }
}

private extension CrewChatView {
    var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle()
                            .fill(palette.cardFill)
                            .overlay(
                                Circle()
                                    .stroke(palette.cardStroke, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            Button {
                showCrewInfo = true
            } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(hexColor(crew.colorHex).opacity(0.16))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: crew.icon)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(hexColor(crew.colorHex))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(crew.name)
                            .font(.headline)
                            .foregroundStyle(palette.primaryText)

                        Text("Crew chat")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.35))
                .ignoresSafeArea(edges: .top)
        )
    }

    var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(hexColor(crew.colorHex).opacity(0.14))
                    .frame(width: 82, height: 82)

                Image(systemName: "person.3.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(hexColor(crew.colorHex))
            }

            Text("No messages yet")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.primaryText)

            Text("Start chatting with your crew.")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

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
            messageBody.contains("started a 25 min shared focus session")

        return HStack(alignment: .bottom) {
            if isFocusSystemMessage {
                Spacer()

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                            .font(.caption.bold())
                            .foregroundStyle(.green)

                        Text("\(message.senderName) started a 25 min shared focus session")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.primaryText)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                    } label: {
                        Text("Join Focus")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.16))
                            )
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)

                    Text(message.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(palette.secondaryCardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
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

                    VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 6) {
                        if let replyPreview {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Reply")
                                    .font(.caption2)
                                    .foregroundStyle(
                                        message.isFromMe
                                        ? .white.opacity(0.80)
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
                                    .opacity(0.85)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        message.isFromMe
                                        ? Color.white.opacity(0.10)
                                        : Color.white.opacity(appTheme == AppTheme.light.rawValue ? 0.35 : 0.05)
                                    )
                            )
                        }

                        Text(messageBody)
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
                                : palette.cardStroke,
                                lineWidth: 1
                            )
                    )

                    Text(message.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryText)
                        .padding(.horizontal, 4)
                }
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

                if !message.isFromMe { Spacer(minLength: 42) }
            }
        }
    }

    var composerBar: some View {
        VStack(spacing: 6) {
            if let replyingTo {
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2)
                        .clipShape(Capsule())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Replying to \(replyingTo.isFromMe ? "yourself" : replyingTo.senderName)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)

                        Text(visibleMessageText(from: replyingTo.text))
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(1)
                            .opacity(0.85)
                    }

                    Spacer()

                    Button {
                        self.replyingTo = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.secondaryText)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(palette.secondaryCardFill)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(palette.secondaryCardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(palette.cardStroke.opacity(0.7), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
            }

            HStack(alignment: .bottom, spacing: 10) {
                Button {
                    sendFocusInvite()
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

    func sendFocusInvite() {
        let message = CrewMessage(
            crewID: crew.id,
            senderName: "Atakan",
            text: "started a 25 min shared focus session",
            isFromMe: false,
            isRead: false
        )

        modelContext.insert(message)
        try? modelContext.save()

        animateMessages = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                animateMessages = true
            }
        }
    }

    func sendMessage() {
        let clean = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let storedText = encodedMessageText(from: clean)

        let message = CrewMessage(
            crewID: crew.id,
            senderName: "Me",
            text: storedText,
            isFromMe: true,
            isRead: true
        )

        modelContext.insert(message)
        try? modelContext.save()

        draftMessage = ""
        replyingTo = nil
        isComposerFocused = false

        animateMessages = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                animateMessages = true
            }
        }
    }

    func encodedMessageText(from clean: String) -> String {
        guard let replyingTo else { return clean }

        let preview = visibleMessageText(from: replyingTo.text)
            .replacingOccurrences(of: "\n", with: " ")

        return "\(replyMarker)\(preview)\(bodyMarker)\(clean)"
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

    func visibleMessageText(from fullText: String) -> String {
        guard
            fullText.hasPrefix(replyMarker),
            let bodyRange = fullText.range(of: bodyMarker)
        else {
            return fullText
        }

        let bodyStart = bodyRange.upperBound
        return String(fullText[bodyStart...])
    }

    func markMessagesAsRead() {
        let unreadMessages = allMessages.filter { message in
            message.crewID == crew.id && !message.isFromMe && !message.isRead
        }

        guard !unreadMessages.isEmpty else { return }

        for message in unreadMessages {
            message.isRead = true
        }

        try? modelContext.save()
    }

    func seedMessagesIfNeeded() {
        guard messages.isEmpty else { return }

        let seed = [
            CrewMessage(
                crewID: crew.id,
                senderName: "Atakan",
                text: "Bugünkü görevleri sıraya koyalım mı?",
                isFromMe: false
            ),
            CrewMessage(
                crewID: crew.id,
                senderName: "Selin",
                text: "Ben focus başlatacağım 20 dk içinde.",
                isFromMe: false
            ),
            CrewMessage(
                crewID: crew.id,
                senderName: "Me",
                text: "Olur, önce zor olanı bitirelim.",
                isFromMe: true
            )
        ]

        for item in seed {
            modelContext.insert(item)
        }

        try? modelContext.save()
    }

    func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastID = messages.last?.id else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}
