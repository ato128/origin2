//
//  CrewChatView+Focus.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI
import SwiftData
import Combine

extension CrewChatView {
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
}

extension CrewChatView {
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

    

