//
//  CrewFocusRoomView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 15.03.2026.
//

import SwiftUI
import SwiftData
import Combine

struct CrewFocusRoomView: View {
    @Bindable var session: CrewFocusSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    @State private var now = Date()
    @State private var joinedName: String = "Atakan"
    @State private var glowPulse = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var remainingSeconds: Int {
        if session.isPaused {
            return max(0, session.pausedRemainingSeconds ?? 0)
        }

        return max(0, Int(session.endDate.timeIntervalSince(now)))
    }

    private var progress: Double {
        let total = Double(session.durationMinutes * 60)
        guard total > 0 else { return 0 }

        let elapsed = total - Double(remainingSeconds)
        return min(1, max(0, elapsed / total))
    }

    private var mmss: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var isEndingSoon: Bool {
        remainingSeconds <= 600
    }

    private var isCritical: Bool {
        remainingSeconds <= 180
    }

    private var focusAccentColor: Color {
        if !session.isActive { return .green }
        if isCritical { return .red }
        if isEndingSoon { return .orange }
        return .blue
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    timerCard
                    participantsCard
                    controlsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
        .onReceive(timer) { value in
            now = value

            guard session.isActive, !session.isPaused else { return }

            if remainingSeconds <= 0 {
                session.isActive = false
                session.isPaused = false
                session.pausedRemainingSeconds = nil

                let message = CrewMessage(
                    crewID: session.crewID,
                    senderName: session.hostName,
                    text: "ended the shared focus session",
                    isFromMe: false,
                    isRead: false
                )

                modelContext.insert(message)
                try? modelContext.save()
            }
        }
    }
}

private extension CrewFocusRoomView {
    var headerCard: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 44, height: 44)
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

            Spacer()

            Text("Focus Room")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
    }

    var timerCard: some View {
        VStack(spacing: 18) {
            Text(session.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Text(
                !session.isActive ? "Session completed" :
                session.isPaused ? "Paused" :
                "Stay locked in"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(
                !session.isActive ? .green :
                session.isPaused ? .orange :
                palette.secondaryText
            )
            ZStack {
                Circle()
                    .stroke(palette.secondaryCardFill, lineWidth: 16)
                    .frame(width: 220, height: 220)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        focusAccentColor,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 220, height: 220)
                    .shadow(color: focusAccentColor.opacity(glowPulse ? 0.45 : 0.22), radius: 12)
                    .animation(.linear(duration: 1), value: progress)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                focusAccentColor.opacity(glowPulse ? 0.22 : 0.10),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 105
                        )
                    )
                    .frame(width: 175, height: 175)
                    .blur(radius: 12)

                VStack(spacing: 8) {
                    Image(systemName: session.isActive ? "timer" : "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(focusAccentColor)

                    Text(mmss)
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.2), value: mmss)
                        .contentTransition(.numericText())

                    Text("\(session.durationMinutes) min")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.secondaryText)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .foregroundStyle(focusAccentColor)

                Text("Host: \(session.hostName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(palette.cardFill)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(focusAccentColor.opacity(0.28), lineWidth: 1)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                focusAccentColor.opacity(
                                    glowPulse
                                    ? (isCritical ? 0.28 : isEndingSoon ? 0.24 : 0.18)
                                    : (isCritical ? 0.16 : isEndingSoon ? 0.14 : 0.08)
                                ),
                                Color.clear
                            ],
                            center: .top,
                            startRadius: 20,
                            endRadius: 260
                        )
                    )
                    .blur(radius: 28)
            }
        )
        .shadow(
            color: focusAccentColor.opacity(
                glowPulse
                ? (isCritical ? 0.32 : isEndingSoon ? 0.26 : 0.18)
                : (isCritical ? 0.18 : isEndingSoon ? 0.14 : 0.08)
            ),
            radius: 18,
            y: 8
        )
    }

    var participantsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Participants")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            if session.participantNames.isEmpty {
                Text("No participants yet")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            } else {
                ForEach(session.participantNames, id: \.self) { name in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.16))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(String(name.prefix(1)).uppercased())
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.accentColor)
                            )

                        Text(name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.primaryText)

                        Spacer()

                        if name == session.hostName {
                            Text("Host")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.green.opacity(0.12))
                                )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardBackground)
    }

    var controlsCard: some View {
        VStack(spacing: 12) {
            Button {
                joinSession()
            } label: {
                Text(session.participantNames.contains(joinedName) ? "Joined" : "Join Session")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(session.participantNames.contains(joinedName) ? Color.green : Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
            .disabled(session.participantNames.contains(joinedName) || !session.isActive)

            Button {
                leaveSession()
            } label: {
                Text("Leave Session")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(palette.secondaryCardFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(palette.cardStroke, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            
            if session.isActive {
                Button {
                    togglePauseResume()
                } label: {
                    Text(session.isPaused ? "Resume Session" : "Pause Session")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(session.isPaused ? .green : .orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(palette.secondaryCardFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(
                                            (session.isPaused ? Color.green : Color.orange).opacity(0.22),
                                            lineWidth: 1
                                        )
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            if session.isActive {
                Button {
                    endSession()
                } label: {
                    Text("End Session")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(palette.secondaryCardFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.red.opacity(0.22), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(cardBackground)
    }
    
    func togglePauseResume() {
        guard session.isActive else { return }

        if session.isPaused {
            let remaining = session.pausedRemainingSeconds ?? 0
            session.startedAt = Date().addingTimeInterval(-Double(session.durationMinutes * 60 - remaining))
            session.isPaused = false
            session.pausedRemainingSeconds = nil

            let message = CrewMessage(
                crewID: session.crewID,
                senderName: session.hostName,
                text: "resumed the shared focus session",
                isFromMe: false,
                isRead: false
            )

            modelContext.insert(message)
        } else {
            session.pausedRemainingSeconds = remainingSeconds
            session.isPaused = true

            let message = CrewMessage(
                crewID: session.crewID,
                senderName: session.hostName,
                text: "paused the shared focus session",
                isFromMe: false,
                isRead: false
            )

            modelContext.insert(message)
        }

        try? modelContext.save()
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }

    func joinSession() {
        guard session.isActive else { return }
        guard !session.participantNames.contains(joinedName) else { return }

        session.participantNames.append(joinedName)

        let message = CrewMessage(
            crewID: session.crewID,
            senderName: joinedName,
            text: "joined the shared focus session",
            isFromMe: false,
            isRead: false
        )

        modelContext.insert(message)
        try? modelContext.save()
    }

    func leaveSession() {
        session.participantNames.removeAll { $0 == joinedName }
        try? modelContext.save()
        dismiss()
    }

    func endSession() {
        session.isActive = false

        let message = CrewMessage(
            crewID: session.crewID,
            senderName: session.hostName,
            text: "ended the shared focus session",
            isFromMe: false,
            isRead: false
        )

        modelContext.insert(message)
        try? modelContext.save()
        dismiss()
    }
}
