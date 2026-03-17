//
//  FocusSessionView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 7.03.2026.
//

import SwiftUI
import Combine
import SwiftData
import UIKit

struct FocusSessionView: View {
    let taskID: PersistentIdentifier?
    let taskTitle: String?
    let onStartFocus: (_ title: String, _ totalSeconds: Int) -> Void
    let onTick: (_ remainingSeconds: Int) -> Void
    let onFinishFocus: (_ title: String, _ startedAt: Date, _ endedAt: Date, _ totalSeconds: Int, _ completedSeconds: Int, _ isCompleted: Bool) -> Void
    let workoutExercises: [WorkoutExerciseItem]?
    
    

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

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
    @State private var sessionStartedAt: Date? = nil

    @State private var currentExerciseIndex: Int = 0
    @State private var currentSet: Int = 1

    @State private var isRestPhase: Bool = false
    @State private var restOverlayVisible: Bool = false
    @State private var restOverlaySeconds: Int = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let presets = [15, 25, 45, 60]

    private enum Keys {
        static let endDate = "focus_end_date"
        static let totalSeconds = "focus_total_seconds"
        static let selectedMinutes = "focus_selected_minutes"
        static let taskTitle = "focus_task_title"

        static let focusMode = "focus_mode"
        static let focusFriendName = "focus_friend_name"
        static let focusFriendID = "focus_friend_id"
        static let workoutMode = "focus_workout_mode"
        static let workoutExerciseName = "focus_workout_exercise_name"
        static let workoutCurrentSet = "focus_workout_current_set"
        static let workoutTotalSets = "focus_workout_total_sets"
        static let workoutIsResting = "focus_workout_is_resting"
    }

    private var isWorkoutMode: Bool {
        guard let workoutExercises else { return false }
        return !workoutExercises.isEmpty
    }

    private var currentExercise: WorkoutExerciseItem? {
        guard let workoutExercises,
              currentExerciseIndex >= 0,
              currentExerciseIndex < workoutExercises.count else { return nil }
        return workoutExercises[currentExerciseIndex]
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

    private var resolvedTaskTitle: String {
        if let taskTitle,
           !taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return taskTitle
        }
        return "Deep Work Session"
    }

    private var mainTitleText: String {
        if isWorkoutMode { return "Workout Focus" }
        return "Focus Mode"
    }

    private var subtitleView: some View {
        Group {
            if let exercise = currentExercise {
                VStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        Text("Set \(currentSet) / \(exercise.sets)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if isRestPhase {
                            Text("Rest")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.orange.opacity(0.16))
                                )
                                .foregroundStyle(.orange)
                        }
                    }
                }
            } else {
                Text(resolvedTaskTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var primaryButtonTitle: String {
        if isWorkoutMode {
            return isRestPhase ? "Resting..." : "Next Set"
        } else {
            return isRunning ? "Pause" : "Start"
        }
    }

    private var primaryButtonDisabled: Bool {
        isWorkoutMode && isRestPhase
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Text(mainTitleText)
                            .font(.title.bold())

                        subtitleView

                        statusPill
                    }

                    if !isWorkoutMode {
                        presetBar
                    }

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
                                        : isRestPhase
                                            ? [.orange, .yellow, .orange]
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
                                    : (isRestPhase
                                        ? Color.orange.opacity(0.24)
                                        : (isEndingSoon
                                            ? Color.orange.opacity(0.28)
                                            : Color.blue.opacity(0.25))),
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

                                    Text(isWorkoutMode ? "Workout completed" : "Session completed")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(liveTime)
                                        .font(.system(size: 42, weight: .bold, design: .rounded))
                                        .monospacedDigit()

                                    Text(statusCenterText)
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
                            if isWorkoutMode {
                                nextSet()
                            } else {
                                handleStartPause()
                            }
                        } label: {
                            Text(primaryButtonTitle)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(primaryButtonDisabled ? Color.gray.opacity(0.35) : Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .disabled(primaryButtonDisabled)

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

                    // 🔥 workout ise home card için state pushla
                    if isWorkoutMode {
                        saveWorkoutLiveState()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    guard !isWorkoutMode else { return }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        syncTimerFromSavedState()
                    }
                }
                .onReceive(timer) { _ in
                    handleTimerTick()
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

                if restOverlayVisible {
                    restOverlay
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                        .zIndex(10)
                }
            }
        }
    }
}

private extension FocusSessionView {
    var statusCenterText: String {
        if isRestPhase {
            return "Dinleniyorsun"
        }
        if isWorkoutMode {
            return "Set ilerliyor"
        }
        return isRunning ? "Odaklanıyorsun" : "Hazır"
    }

    var restOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.cooldown")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.orange)

            Text("REST")
                .font(.title2.weight(.bold))
                .foregroundStyle(.orange)

            Text("\(restOverlaySeconds) sec")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.orange.opacity(0.24), lineWidth: 1)
                )
        )
        .shadow(color: Color.orange.opacity(0.18), radius: 16, y: 8)
    }

    var statusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(
                    showDoneState
                    ? Color.green
                    : (isRestPhase
                        ? Color.orange
                        : (isRunning ? Color.green : Color.secondary))
                )
                .frame(width: 8, height: 8)

            Text(
                showDoneState
                ? "Completed"
                : (isRestPhase
                    ? "Rest Active"
                    : (isRunning ? "Session Active" : "Ready to Focus"))
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
                    : (isRestPhase
                        ? Color.orange.opacity(0.14)
                        : (isRunning
                            ? Color.green.opacity(0.14)
                            : Color.secondary.opacity(0.12)))
                )
        )
        .foregroundStyle(
            showDoneState
            ? .green
            : (isRestPhase ? .orange : (isRunning ? .green : .secondary))
        )
    }

    var presetBar: some View {
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

    func liveProgress(at date: Date) -> Double {
        if showDoneState { return 1.0 }
        guard totalSeconds > 0 else { return 0 }

        guard let endDate, isRunning else {
            return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
        }

        let remaining = max(0, endDate.timeIntervalSince(date))
        let elapsed = Double(totalSeconds) - remaining

        return min(1, max(0, elapsed / Double(totalSeconds)))
    }

    func liveTimeText(at date: Date) -> String {
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

    func innerGlowColor() -> Color {
        if showDoneState { return .green }
        if isRestPhase { return .orange }
        if isEndingSoon { return .orange }
        return .blue
    }
    
    private func saveWorkoutLiveState() {
        let defaults = UserDefaults.standard

        defaults.set(isWorkoutMode, forKey: Keys.workoutMode)
        defaults.set(isRestPhase, forKey: Keys.workoutIsResting)

        if let exercise = currentExercise {
            defaults.set(exercise.name, forKey: Keys.workoutExerciseName)
            defaults.set(currentSet, forKey: Keys.workoutCurrentSet)
            defaults.set(exercise.sets, forKey: Keys.workoutTotalSets)
        } else {
            defaults.removeObject(forKey: Keys.workoutExerciseName)
            defaults.removeObject(forKey: Keys.workoutCurrentSet)
            defaults.removeObject(forKey: Keys.workoutTotalSets)
        }
    }

    private func clearWorkoutLiveState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.workoutMode)
        defaults.removeObject(forKey: Keys.workoutExerciseName)
        defaults.removeObject(forKey: Keys.workoutCurrentSet)
        defaults.removeObject(forKey: Keys.workoutTotalSets)
        defaults.removeObject(forKey: Keys.workoutIsResting)
    }

    func handleTimerTick() {
        guard isRunning else { return }
        guard let endDate else { return }

        let remaining = Int(endDate.timeIntervalSinceNow.rounded(.down))

        if remaining <= 0 {
            remainingSeconds = 0
            isRunning = false

            if isWorkoutMode && isRestPhase {
                isRestPhase = false
                restOverlayVisible = false
                restOverlaySeconds = 0
                saveWorkoutLiveState()

                let gen = UINotificationFeedbackGenerator()
                gen.prepare()
                gen.notificationOccurred(.success)

                return
            }

            showDoneState = true

            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                showCompletionBounce = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                showCompletionBounce = false
            }

            onTick(0)

            let endedAt = Date()
            let completedSeconds = totalSeconds

            saveFocusRecord(
                endedAt: endedAt,
                completedSeconds: completedSeconds,
                isCompleted: true
            )

            onFinishFocus(
                resolvedTaskTitle,
                sessionStartedAt ?? endedAt,
                endedAt,
                totalSeconds,
                completedSeconds,
                true
            )

            clearSharedFocusState()
            clearSavedTimer()
            return
        }

        remainingSeconds = remaining
        restOverlaySeconds = remaining
        onTick(remainingSeconds)
    }

    func handleStartPause() {
        if !hasStartedSession {
            hasStartedSession = true
            sessionStartedAt = Date()
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

    func nextSet() {
        guard let workoutExercises,
              currentExerciseIndex < workoutExercises.count else { return }

        if !hasStartedSession {
            hasStartedSession = true
            sessionStartedAt = Date()
            onStartFocus(resolvedTaskTitle, totalSeconds)
        }

        let exercise = workoutExercises[currentExerciseIndex]

        let tapGen = UIImpactFeedbackGenerator(style: .medium)
        tapGen.prepare()
        tapGen.impactOccurred()

        if currentSet < exercise.sets {
            currentSet += 1
            saveWorkoutLiveState()

            if exercise.restSeconds > 0 {
                startRestTimer(seconds: exercise.restSeconds)
            }
        } else {
            if currentExerciseIndex < workoutExercises.count - 1 {
                currentExerciseIndex += 1
                currentSet = 1
                saveWorkoutLiveState()

                if exercise.restSeconds > 0 {
                    startRestTimer(seconds: exercise.restSeconds)
                }
            } else {
                finishWorkout()
            }
        }
    }

    func startRestTimer(seconds: Int) {
        guard seconds > 0 else { return }

        isRestPhase = true
        restOverlayVisible = true
        restOverlaySeconds = seconds
        totalSeconds = seconds
        remainingSeconds = seconds
        endDate = Date().addingTimeInterval(TimeInterval(seconds))
        isRunning = true

        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.prepare()
        gen.impactOccurred()

        saveWorkoutLiveState()
    }

    func finishWorkout() {
        showDoneState = true
        isRunning = false
        isRestPhase = false
        restOverlayVisible = false
        restOverlaySeconds = 0

        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            showCompletionBounce = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            showCompletionBounce = false
        }

        let successGen = UINotificationFeedbackGenerator()
        successGen.prepare()
        successGen.notificationOccurred(.success)

        let endedAt = Date()
        let startedAt = sessionStartedAt ?? endedAt
        let completedSeconds = totalSeconds

        saveFocusRecord(
            endedAt: endedAt,
            completedSeconds: completedSeconds,
            isCompleted: true
        )

        onFinishFocus(
            resolvedTaskTitle,
            startedAt,
            endedAt,
            totalSeconds,
            completedSeconds,
            true
        )

        NotificationCenter.default.post(
            name: .workoutCompleted,
            object: taskID
        )
        clearWorkoutLiveState()
    }

    func applyPreset(_ minutes: Int) {
        selectedMinutes = minutes
        totalSeconds = minutes * 60
        remainingSeconds = minutes * 60
        isRunning = false
        hasStartedSession = false
        endDate = nil
        showDoneState = false
        showCompletionBounce = false
        isRestPhase = false
        restOverlayVisible = false
        restOverlaySeconds = 0
        saveDurationState()
        clearSavedTimer()
        onTick(remainingSeconds)
    }

    func resetTimer() {
        isRunning = false
        remainingSeconds = totalSeconds
        endDate = nil
        showDoneState = false
        showCompletionBounce = false
        isRestPhase = false
        restOverlayVisible = false
        restOverlaySeconds = 0
        clearSavedTimer()
        clearSavedDurationState()
        clearSharedFocusState()
        clearWorkoutLiveState()
        onTick(remainingSeconds)
    }

    func finishAndDismiss() {
        isRunning = false

        let endedAt = Date()
        let startedAt = sessionStartedAt ?? endedAt
        let completedSeconds = max(0, totalSeconds - remainingSeconds)
        let isCompleted = remainingSeconds == 0 || showDoneState

        saveFocusRecord(
            endedAt: endedAt,
            completedSeconds: completedSeconds,
            isCompleted: isCompleted
        )

        endDate = nil
        showDoneState = false
        showCompletionBounce = false
        isRestPhase = false
        restOverlayVisible = false
        restOverlaySeconds = 0
        clearSavedTimer()
        clearSavedDurationState()
        clearSharedFocusState()

        onFinishFocus(
            resolvedTaskTitle,
            startedAt,
            endedAt,
            totalSeconds,
            completedSeconds,
            isCompleted
            
        )
        clearWorkoutLiveState()

        dismiss()
    }

    func saveTimer() {
        guard let endDate else { return }
        guard !isWorkoutMode else { return }

        UserDefaults.standard.set(endDate.timeIntervalSince1970, forKey: Keys.endDate)
        saveDurationState()
    }

    func saveDurationState() {
        guard !isWorkoutMode else { return }

        UserDefaults.standard.set(totalSeconds, forKey: Keys.totalSeconds)
        UserDefaults.standard.set(selectedMinutes, forKey: Keys.selectedMinutes)
        UserDefaults.standard.set(resolvedTaskTitle, forKey: Keys.taskTitle)
    }

    func clearSavedTimer() {
        UserDefaults.standard.removeObject(forKey: Keys.endDate)
    }

    func clearSavedDurationState() {
        UserDefaults.standard.removeObject(forKey: Keys.totalSeconds)
        UserDefaults.standard.removeObject(forKey: Keys.selectedMinutes)
        UserDefaults.standard.removeObject(forKey: Keys.taskTitle)
    }

    func clearSharedFocusState() {
        UserDefaults.standard.removeObject(forKey: Keys.focusMode)
        UserDefaults.standard.removeObject(forKey: Keys.focusFriendName)
        UserDefaults.standard.removeObject(forKey: Keys.focusFriendID)
    }

    func syncTimerFromSavedState() {
        guard !isWorkoutMode else { return }

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
                sessionStartedAt = Date()
                onStartFocus(resolvedTaskTitle, totalSeconds)
            }

            onTick(remainingSeconds)
        } else {
            clearSavedTimer()
        }
    }

    func saveFocusRecord(
        endedAt: Date,
        completedSeconds: Int,
        isCompleted: Bool
    ) {
        let startedAt = sessionStartedAt ?? endedAt

        let record = FocusSessionRecord(
            title: resolvedTaskTitle,
            startedAt: startedAt,
            endedAt: endedAt,
            totalSeconds: totalSeconds,
            completedSeconds: completedSeconds,
            isCompleted: isCompleted
        )

        modelContext.insert(record)

        do {
            try modelContext.save()
            print("✅ Focus saved directly from FocusSessionView:", record.completedSeconds)
        } catch {
            print("❌ Focus save error:", error)
        }

        NotificationCenter.default.post(
            name: .focusSessionCompleted,
            object: nil
        )
    }
}
