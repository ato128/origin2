//
//  CrewChatView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 15.03.2026.
//
import SwiftUI
import SwiftData
import Combine

struct CrewChatView: View {
    let crew: Crew

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    @Query(sort: \CrewMessage.createdAt, order: .forward)
    private var allMessages: [CrewMessage]

    @Query private var members: [CrewMember]
    
    @Query private var focusSessions: [CrewFocusSession]

    @State private var mentionQuery: String = ""
    @State private var showMentionPicker = false

    @State private var draftMessage: String = ""
    @State private var animateMessages = false
    @State private var showCrewInfo = false
    @State private var replyingTo: CrewMessage?
    @State private var reactionTarget: CrewMessage?
    @State private var reactionAnchor: CGRect = .zero
    @State private var pressedMessageID: UUID?
    @State private var showFocusDurationSheet = false
    @State private var customFocusMinutes: Int = 25

    @FocusState private var isComposerFocused: Bool

    private let palette = ThemePalette()
    private let replyMarker = "[[reply]]"
    private let bodyMarker = "[[body]]"

    private var messages: [CrewMessage] {
        allMessages.filter { $0.crewID == crew.id }
    }

    private var crewMembers: [CrewMember] {
        members.filter { $0.crewID == crew.id }
    }

    private var filteredMentionMembers: [CrewMember] {
        guard showMentionPicker else { return [] }

        if mentionQuery.isEmpty {
            return crewMembers
        }

        return crewMembers.filter {
            $0.name.localizedCaseInsensitiveContains(mentionQuery)
        }
    }
    
    private var activeFocusSession: CrewFocusSession? {
        focusSessions.first {
            $0.crewID == crew.id && $0.isActive
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()

            if reactionTarget != nil {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        reactionTarget = nil
                        pressedMessageID = nil
                    }
            }

            VStack(spacing: 0) {
                header

                if let activeFocusSession {
                    NavigationLink {
                        CrewFocusRoomView(session: activeFocusSession)
                    } label: {
                        ActiveFocusBanner(
                            session: activeFocusSession,
                            palette: palette
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .transition(.scale.combined(with: .opacity))
                    }
                    .buttonStyle(.plain)
                }

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
        .sheet(isPresented: $showFocusDurationSheet) {
            focusDurationSheet
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
    
    var focusDurationSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Button {
                    startFocusSession(minutes: 25)
                } label: {
                    focusOptionRow(title: "25 min", subtitle: "Quick focus sprint")
                }
                .buttonStyle(.plain)

                Button {
                    startFocusSession(minutes: 45)
                } label: {
                    focusOptionRow(title: "45 min", subtitle: "Deep work block")
                }
                .buttonStyle(.plain)

                Button {
                    startFocusSession(minutes: 60)
                } label: {
                    focusOptionRow(title: "60 min", subtitle: "Long session")
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Custom")
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)

                    HStack {
                        Stepper(value: $customFocusMinutes, in: 5...180, step: 5) {
                            Text("\(customFocusMinutes) min")
                                .foregroundStyle(palette.primaryText)
                        }
                    }

                    Button {
                        startFocusSession(minutes: customFocusMinutes)
                    } label: {
                        Text("Start Custom Session")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.accentColor)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(palette.cardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(palette.cardStroke, lineWidth: 1)
                        )
                )

                Spacer()
            }
            .padding(16)
            .background(AppBackground())
            .navigationTitle("Focus Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        showFocusDurationSheet = false
                    }
                }
            }
        }
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
    
    func focusOptionRow(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer()

            Image(systemName: "timer")
                .foregroundStyle(.green)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
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

    func startFocusSession(minutes: Int) {
        if let activeFocusSession, activeFocusSession.isActive {
            showFocusDurationSheet = false
            return
        }

        let session = CrewFocusSession(
            crewID: crew.id,
            title: "\(crew.name) Focus",
            durationMinutes: minutes,
            startedAt: Date(),
            isActive: true,
            hostName: "Atakan",
            participantNames: ["Atakan"]
        )

        modelContext.insert(session)

        let message = CrewMessage(
            crewID: crew.id,
            senderName: "Atakan",
            text: "started a \(minutes) min shared focus session",
            isFromMe: false,
            isRead: false
        )

        modelContext.insert(message)
        try? modelContext.save()

        showFocusDurationSheet = false

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
        showMentionPicker = false
        mentionQuery = ""

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
    struct ActiveFocusBanner: View {
        let session: CrewFocusSession
        let palette: ThemePalette

        @State private var now = Date()
        @State private var glowPulse = false

        private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

        private var remainingSeconds: Int {
            max(0, Int(session.endDate.timeIntervalSince(now)))
        }

        private var mmss: String {
            let minutes = remainingSeconds / 60
            let seconds = remainingSeconds % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }

        var body: some View {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.blue.opacity(glowPulse ? 1.0 : 0.72))
                    .frame(width: 10, height: 10)
                    .shadow(color: Color.blue.opacity(glowPulse ? 0.40 : 0.16), radius: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Focus devam ediyor")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.primaryText)

                    Text("\(session.hostName) • \(mmss)")
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryText)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.2), value: mmss)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.blue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    Capsule()
                        .fill(palette.cardFill)

                    Capsule()
                        .stroke(Color.blue.opacity(0.28), lineWidth: 1)

                    Capsule()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.blue.opacity(glowPulse ? 0.18 : 0.08),
                                    Color.clear
                                ],
                                center: .leading,
                                startRadius: 10,
                                endRadius: 180
                            )
                        )
                        .blur(radius: 18)
                }
            )
            .shadow(color: Color.blue.opacity(glowPulse ? 0.18 : 0.08), radius: 12, y: 4)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }
            .onReceive(timer) { value in
                now = value
            }
        }
    }
}
