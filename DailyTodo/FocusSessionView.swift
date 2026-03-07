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
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedMinutes: Int = 25
    @State private var totalSeconds: Int = 25 * 60
    @State private var remainingSeconds: Int = 25 * 60

    @State private var isRunning: Bool = false
    @State private var hasStartedSession: Bool = false

    @State private var showCustomInput: Bool = false
    @State private var customMinutes: String = ""

    @State private var endDate: Date? = nil

    @State private var showCompletionBounce: Bool = false
    @State private var showDoneState: Bool = false
    @State private var breathing = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let presets = [15, 25, 45, 60]

    private enum Keys {
        static let endDate = "focus_end_date"
        static let totalSeconds = "focus_total_seconds"
        static let selectedMinutes = "focus_selected_minutes"
        static let taskTitle = "focus_task_title"
    }

    private var progress: Double {
        liveProgress(at: Date())
    }

    private var timeText: String {
        liveTimeText(at: Date())
    }

    private var isEndingSoon: Bool {
        if let endDate, isRunning {
            return endDate.timeIntervalSinceNow <= 30
        }
        return false
    }

    private func liveProgress(at date: Date) -> Double {
        if showDoneState { return 1.0 }
        guard totalSeconds > 0 else { return 0 }

        guard let endDate, isRunning else {
            return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
        }

        let remaining = max(0, endDate.timeIntervalSince(date))
        let elapsed = Double(totalSeconds) - remaining

        return min(1, max(0, elapsed / Double(totalSeconds)))
    }

    private func liveTimeText(at date: Date) -> String {
        let liveRemaining: Int

        if let endDate, isRunning {
            liveRemaining = max(0, Int(endDate.timeIntervalSince(date).rounded(.down)))
        } else {
            liveRemaining = remainingSeconds
        }

        let m = liveRemaining / 60
        let s = liveRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func innerGlowColor() -> Color {
        if showDoneState { return .green }
        if isEndingSoon { return .orange }
        return .blue
    }

    private var resolvedTaskTitle: String {
        if let taskTitle,
           !taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return taskTitle
        }
        return "Deep Work Session"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Text("Focus Mode")
                        .font(.title.bold())

                    Text(resolvedTaskTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    statusPill
                }

                presetBar

                TimelineView(.animation) { timeline in
                    let now = timeline.date
                    let liveProgressValue = liveProgress(at: now)
                    let liveTime = liveTimeText(at: now)

                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 12)
                            .frame(width: 220, height: 220)

                        Circle()
                            .trim(from: 0, to: liveProgressValue)
                            .stroke(
                                AngularGradient(
                                    colors: showDoneState
                                        ? [.green, .green.opacity(0.85), .green]
                                        : isEndingSoon
                                            ? [.red, .orange, .red]
                                            : [.blue, .cyan, .blue],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 220, height: 220)
                            .shadow(
                                color: showDoneState
                                    ? Color.green.opacity(0.22)
                                    : (isEndingSoon
                                        ? Color.orange.opacity(0.28)
                                        : Color.blue.opacity(0.25)),
                                radius: 6
                            )

                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        innerGlowColor().opacity(showDoneState ? 0.24 : 0.18),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: breathing ? 92 : 74
                                )
                            )
                            .frame(width: 170, height: 170)
                            .blur(radius: 8)
                            .animation(
                                .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                                value: breathing
                            )

                        VStack(spacing: 8) {
                            if showDoneState {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 52))
                                    .foregroundStyle(.green)

                                Text("Done")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.green)

                                Text("Session completed")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(liveTime)
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
                                    .monospacedDigit()

                                Text(isRunning ? "Odaklanıyorsun" : "Hazır")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .scaleEffect(showCompletionBounce ? 1.08 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.55), value: showCompletionBounce)

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
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    Button {
                        resetTimer()
                    } label: {
                        Text("Reset")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.secondary.opacity(0.12))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
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
            .onAppear {
                syncTimerFromSavedState()
                breathing = true
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    syncTimerFromSavedState()
                }
            }
            .onReceive(timer) { _ in
                guard isRunning else { return }
                guard let endDate else { return }

                let remaining = Int(endDate.timeIntervalSinceNow.rounded(.down))

                if remaining <= 0 {
                    remainingSeconds = 0
                    isRunning = false
                    showDoneState = true

                    withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                        showCompletionBounce = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        showCompletionBounce = false
                    }

                    onTick(0)
                    onFinishFocus()
                    clearSavedTimer()
                    return
                }

                remainingSeconds = remaining
                onTick(remainingSeconds)
            }
            .alert("Custom Duration", isPresented: $showCustomInput) {
                TextField("Minutes", text: $customMinutes)
                    .keyboardType(.numberPad)

                Button("OK") {
                    if let m = Int(customMinutes), m > 0 {
                        applyPreset(m)
                    }
                    customMinutes = ""
                }

                Button("Cancel", role: .cancel) {
                    customMinutes = ""
                }
            } message: {
                Text("Enter custom focus duration in minutes.")
            }
        }
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(
                    showDoneState
                    ? Color.green
                    : (isRunning ? Color.green : Color.secondary)
                )
                .frame(width: 8, height: 8)

            Text(
                showDoneState
                ? "Completed"
                : (isRunning ? "Session Active" : "Ready to Focus")
            )
            .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(
                    showDoneState
                    ? Color.green.opacity(0.14)
                    : (isRunning
                        ? Color.green.opacity(0.14)
                        : Color.secondary.opacity(0.12))
                )
        )
        .foregroundStyle(
            showDoneState
            ? .green
            : (isRunning ? .green : .secondary)
        )
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
                        .scaleEffect(minutes == selectedMinutes ? 1.03 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: selectedMinutes)
                }
                .buttonStyle(.plain)
                .disabled(isRunning)
            }

            Button {
                showCustomInput = true
            } label: {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .padding(10)
                    .background(
                        Circle()
                            .fill(Color.secondary.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .disabled(isRunning)
        }
    }

    private func handleStartPause() {
        if !hasStartedSession {
            hasStartedSession = true
            onStartFocus(resolvedTaskTitle, totalSeconds)
        }

        if isRunning {
            isRunning = false

            if let endDate {
                let remaining = max(0, Int(endDate.timeIntervalSinceNow.rounded(.down)))
                remainingSeconds = remaining
            }

            clearSavedTimer()
            onTick(remainingSeconds)
        } else {
            showDoneState = false
            endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
            saveTimer()
            isRunning = true
            onTick(remainingSeconds)
        }
    }

    private func applyPreset(_ minutes: Int) {
        selectedMinutes = minutes
        totalSeconds = minutes * 60
        remainingSeconds = minutes * 60
        isRunning = false
        hasStartedSession = false
        endDate = nil
        showDoneState = false
        showCompletionBounce = false
        saveDurationState()
        clearSavedTimer()
        onTick(remainingSeconds)
    }

    private func resetTimer() {
        isRunning = false
        remainingSeconds = totalSeconds
        endDate = nil
        showDoneState = false
        showCompletionBounce = false
        clearSavedTimer()
        onTick(remainingSeconds)
    }

    private func finishAndDismiss() {
        isRunning = false
        endDate = nil
        showDoneState = false
        showCompletionBounce = false
        clearSavedTimer()
        clearSavedDurationState()
        onFinishFocus()
        dismiss()
    }

    private func saveTimer() {
        guard let endDate else { return }
        UserDefaults.standard.set(endDate.timeIntervalSince1970, forKey: Keys.endDate)
        saveDurationState()
    }

    private func saveDurationState() {
        UserDefaults.standard.set(totalSeconds, forKey: Keys.totalSeconds)
        UserDefaults.standard.set(selectedMinutes, forKey: Keys.selectedMinutes)
        UserDefaults.standard.set(resolvedTaskTitle, forKey: Keys.taskTitle)
    }

    private func clearSavedTimer() {
        UserDefaults.standard.removeObject(forKey: Keys.endDate)
    }

    private func clearSavedDurationState() {
        UserDefaults.standard.removeObject(forKey: Keys.totalSeconds)
        UserDefaults.standard.removeObject(forKey: Keys.selectedMinutes)
        UserDefaults.standard.removeObject(forKey: Keys.taskTitle)
    }

    private func syncTimerFromSavedState() {
        let defaults = UserDefaults.standard

        if let savedTotal = defaults.object(forKey: Keys.totalSeconds) as? Int, savedTotal > 0 {
            totalSeconds = savedTotal
        }

        if let savedSelected = defaults.object(forKey: Keys.selectedMinutes) as? Int, savedSelected > 0 {
            selectedMinutes = savedSelected
        }

        guard let timestamp = defaults.object(forKey: Keys.endDate) as? Double else {
            return
        }

        let savedEnd = Date(timeIntervalSince1970: timestamp)
        let remaining = Int(savedEnd.timeIntervalSinceNow.rounded(.down))

        if remaining > 0 {
            endDate = savedEnd

            if remainingSeconds != remaining {
                remainingSeconds = remaining
            }

            if !isRunning {
                isRunning = true
            }

            if !hasStartedSession {
                hasStartedSession = true
                onStartFocus(resolvedTaskTitle, totalSeconds)
            }

            onTick(remainingSeconds)
        } else {
            clearSavedTimer()
        }
    }
}
