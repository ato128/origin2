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

    private let palette = ThemePalette()

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
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            seedMessagesIfNeeded()
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
            .onAppear {
                animateMessages = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        animateMessages = true
                    }
                }
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    func messageBubble(_ message: CrewMessage) -> some View {
        let isFocusSystemMessage =
            message.text.contains("started a 25 min shared focus session")

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

                    Text(message.text)
                        .font(.subheadline)
                        .foregroundStyle(message.isFromMe ? .white : palette.primaryText)
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

                if !message.isFromMe { Spacer(minLength: 42) }
            }
        }
    }
    var composerBar: some View {
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
            isFromMe: false
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

        let message = CrewMessage(
            crewID: crew.id,
            senderName: "Me",
            text: clean,
            isFromMe: true
        )

        modelContext.insert(message)
        try? modelContext.save()

        draftMessage = ""
        animateMessages = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                animateMessages = true
            }
        }
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
