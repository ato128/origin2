//
//  StudyCoachSheet.swift
//  DailyTodo
//

import SwiftUI

struct StudyCoachSheet: View {
    let courses: [Course]
    let ownerUserID: String?
    let languageCode: String

    @StateObject private var store = StudyCoachStore()
    @Environment(\.dismiss) private var dismiss

    @State private var inputText = ""
    @State private var goalsText = ""
    @State private var showGoalsSetup = false
    @FocusState private var inputFocused: Bool

    private let accent = Color(arenaHex: AppArenaPalette.cyan)
    private let gold = Color(arenaHex: AppArenaPalette.gold)

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 0) {
                    if store.messages.isEmpty && !showGoalsSetup {
                        welcomeView
                    } else if store.messages.isEmpty && showGoalsSetup {
                        goalsSetupView
                    } else {
                        chatView
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) { headerBar }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Background

    private var background: some View {
        ArenaBackground(
            primaryGlow: accent,
            secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
            warmGlow: gold,
            intensity: 0.90
        )
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("STUDY COACH")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(accent)

                Text(tr("hdb_ai_coach"))
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
            }

            Spacer()

            if !store.messages.isEmpty {
                Button {
                    store.clearHistory()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark").accessibilityLabel(tr("event_close"))
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            ArenaHeaderScrim(height: 72, materialHeight: 56).ignoresSafeArea()
        )
    }

    // MARK: - Welcome screen

    private var welcomeView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 80, height: 80)
                    .overlay(Circle().stroke(accent.opacity(0.20), lineWidth: 1))

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(accent)
            }

            VStack(spacing: 10) {
                Text(tr("scs_your_coach"))
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(.white)

                Text(tr("scs_share_goals"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }

            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    showGoalsSetup = true
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                    Text(tr("hd_start"))
                }
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: [accent, accent.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: accent.opacity(0.25), radius: 12, y: 6)
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Goals setup

    private var goalsSetupView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    eyebrow("COURSES")
                    Text("Ders listeni zaten biliyorum:")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))

                    FlowTagsView(tags: courses.prefix(6).map { $0.name }, accent: accent)
                }

                VStack(alignment: .leading, spacing: 8) {
                    eyebrow("GOALS")
                    Text("Hedeflerin neler?")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.white)

                    TextEditor(text: $goalsText)
                        .scrollContentBackground(.hidden)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .tint(accent)
                        .frame(minHeight: 80, maxHeight: 140)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.07))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                }

                Button {
                    Task {
                        await store.startCoaching(
                            courses: courses.map(\.name),
                            goals: goalsText,
                            languageCode: languageCode
                        )
                    }
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(tr("scs_create_routine"))
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(LinearGradient(colors: [accent, gold], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: accent.opacity(0.22), radius: 12, y: 6)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
    }

    // MARK: - Chat view

    private var chatView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(store.messages) { msg in
                            MessageBubble(message: msg, accent: accent)
                                .id(msg.id)
                        }

                        if store.isThinking && store.streamingText.isEmpty {
                            thinkingIndicator
                        } else if !store.streamingText.isEmpty {
                            StreamingBubble(text: store.streamingText, accent: accent)
                        }

                        if let routine = store.currentRoutine {
                            RoutineCard(routine: routine, accent: accent)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, 8)
                }
                .onChange(of: store.messages.count) { _, _ in
                    withAnimation { proxy.scrollTo(store.messages.last?.id) }
                }
                .onChange(of: store.streamingText) { _, _ in
                    withAnimation { proxy.scrollTo(store.messages.last?.id) }
                }
            }

            inputBar
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField(tr("scs_type_message"), text: $inputText, axis: .vertical)
                .focused($inputFocused)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .tint(accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )

            Button {
                let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, !store.isThinking else { return }
                inputText = ""
                inputFocused = false
                Task { await store.sendMessage(text) }
            } label: {
                Image(systemName: store.isThinking ? "ellipsis" : "arrow.up")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(store.isThinking ? Color.white.opacity(0.3) : accent)
                            .shadow(color: accent.opacity(0.22), radius: 8, y: 4)
                    )
            }
            .buttonStyle(.plain)
            .disabled(store.isThinking || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ArenaHeaderScrim(height: 72, materialHeight: 56)
                .rotationEffect(.degrees(180))
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var thinkingIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(accent.opacity(0.7))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func eyebrow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(accent).frame(width: 16, height: 1)
            Text(text)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(accent)
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: CoachMessage
    let accent: Color

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            Text(cleanedText)
                .font(.system(size: 15, weight: isUser ? .semibold : .regular))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isUser ? accent.opacity(0.25) : Color.white.opacity(0.09))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(isUser ? accent.opacity(0.35) : Color.white.opacity(0.12), lineWidth: 1)
                        )
                )

            if !isUser { Spacer(minLength: 40) }
        }
    }

    private var cleanedText: String {
        var t = message.text
        if let start = t.range(of: "<routine>"),
           let end = t.range(of: "</routine>") {
            t.removeSubrange(start.lowerBound...end.upperBound)
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Streaming Bubble

private struct StreamingBubble: View {
    let text: String
    let accent: Color

    var body: some View {
        HStack {
            Text(cleanedText + "▋")
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.09))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
            Spacer(minLength: 40)
        }
    }

    private var cleanedText: String {
        var t = text
        if let start = t.range(of: "<routine>") {
            t = String(t[..<start.lowerBound])
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Routine Card

private struct RoutineCard: View {
    let routine: CoachRoutine
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(accent)

                Text(routine.title)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)

                Spacer()

                Text(tr("scs_daily_routine_caps"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(accent.opacity(0.8))
            }

            VStack(spacing: 8) {
                ForEach(routine.items) { item in
                    HStack(spacing: 12) {
                        Text(item.time)
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(accent)
                            .frame(width: 46, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.activity)
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(.white)
                            if !item.course.isEmpty {
                                Text(item.course)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.50))
                            }
                        }

                        Spacer()

                        Text("\(item.duration)dk")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.vertical, 4)

                    if item.id != routine.items.last?.id {
                        Divider()
                            .background(Color.white.opacity(0.08))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.10), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(accent.opacity(0.20), lineWidth: 1)
                )
        )
    }
}

// MARK: - Flow Tags

private struct FlowTagsView: View {
    let tags: [String]
    let accent: Color

    var body: some View {
        LazyVGrid(columns: [.init(.adaptive(minimum: 80))], spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(accent.opacity(0.12))
                            .overlay(Capsule().stroke(accent.opacity(0.20), lineWidth: 1))
                    )
                    .lineLimit(1)
            }
        }
    }
}
