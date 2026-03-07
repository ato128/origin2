//
//  FocusSessionView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 7.03.2026.
//

import SwiftUI
import Combine

struct FocusSessionView: View {
    let taskTitle: String?
    let onStartFocus: (_ title: String, _ totalSeconds: Int) -> Void
    let onTick: (_ remainingSeconds: Int) -> Void
    let onFinishFocus: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedMinutes: Int = 25
    @State private var totalSeconds: Int = 25 * 60
    @State private var remainingSeconds: Int = 25 * 60
    @State private var isRunning: Bool = false
    @State private var hasStartedSession: Bool = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let presets = [15, 25, 45, 60]

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    private var timeText: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var resolvedTaskTitle: String {
        if let taskTitle, !taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return taskTitle
        }
        return "Deep Work Session"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Focus Mode")
                        .font(.title.bold())

                    Text(resolvedTaskTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                presetBar

                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 14)
                        .frame(width: 220, height: 220)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            AngularGradient(
                                colors: [.blue, .cyan, .blue],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 220, height: 220)
                        .animation(.easeInOut(duration: 0.25), value: progress)

                    VStack(spacing: 8) {
                        Text(timeText)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .monospacedDigit()

                        Text(isRunning ? "Odaklanıyorsun" : "Hazır")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        handleStartPause()
                    } label: {
                        Text(isRunning ? "Pause" : "Start")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Button {
                        resetTimer()
                    } label: {
                        Text("Reset")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.secondary.opacity(0.12))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                Button {
                    finishAndDismiss()
                } label: {
                    Text("Finish")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(timer) { _ in
                guard isRunning else { return }

                guard remainingSeconds > 0 else {
                    isRunning = false
                    onFinishFocus()
                    return
                }

                remainingSeconds -= 1
                onTick(remainingSeconds)

                if remainingSeconds == 0 {
                    isRunning = false
                    onFinishFocus()
                }
            }
        }
    }

    private var presetBar: some View {
        HStack(spacing: 10) {
            ForEach(presets, id: \.self) { minutes in
                Button {
                    applyPreset(minutes)
                } label: {
                    Text("\(minutes) dk")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(
                                    minutes == selectedMinutes
                                    ? Color.accentColor
                                    : Color.secondary.opacity(0.12)
                                )
                        )
                        .foregroundStyle(minutes == selectedMinutes ? .white : .primary)
                }
                .buttonStyle(.plain)
                .disabled(isRunning)
            }
        }
    }

    private func handleStartPause() {
        if !hasStartedSession {
            hasStartedSession = true
            onStartFocus(resolvedTaskTitle, totalSeconds)
            onTick(remainingSeconds)
        }

        isRunning.toggle()
    }

    private func applyPreset(_ minutes: Int) {
        selectedMinutes = minutes
        totalSeconds = minutes * 60
        remainingSeconds = minutes * 60
        isRunning = false
        hasStartedSession = false
    }

    private func resetTimer() {
        isRunning = false
        remainingSeconds = totalSeconds
        onTick(remainingSeconds)
    }

    private func finishAndDismiss() {
        isRunning = false
        onFinishFocus()
        dismiss()
    }
}
