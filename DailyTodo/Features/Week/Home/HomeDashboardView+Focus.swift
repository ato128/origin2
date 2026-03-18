//
//  HomeDashboardView+Focus.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI
import SwiftData

extension HomeDashboardView {
    var focusCard: some View {
        Group {
            if let task = focusTask {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(focusCardTitle)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(palette.primaryText)
                        
                        Spacer()
                        
                        Image(systemName: isSharedFocusActive ? "person.2.fill" : (task.taskType == "workout" ? "dumbbell.fill" : "scope"))
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                    }
                    
                    Text(focusCardMainText)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(2)
                    
                    if task.taskType == "workout" {
                        VStack(alignment: .leading, spacing: 8) {
                            if !focusWorkoutExerciseName.isEmpty {
                                Text(focusWorkoutExerciseName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(palette.secondaryText)
                                    .lineLimit(1)
                            }
                            
                            HStack(spacing: 8) {
                                if focusWorkoutCurrentSet > 0 && focusWorkoutTotalSets > 0 {
                                    miniBadge(
                                        icon: "figure.strengthtraining.traditional",
                                        text: "Set \(focusWorkoutCurrentSet)/\(focusWorkoutTotalSets)",
                                        tint: .green
                                    )
                                }
                                
                                if focusWorkoutIsResting {
                                    miniBadge(
                                        icon: "figure.cooldown",
                                        text: "Rest",
                                        tint: .orange
                                    )
                                }
                            }
                        }
                    }
                    
                    HStack(spacing: 8) {
                        if let due = task.dueDate {
                            Label {
                                Text(due, style: .time)
                            } icon: {
                                Image(systemName: "calendar")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                        }
                        
                        Spacer()
                        
                        Text(
                            task.taskType == "workout"
                            ? (focusWorkoutIsResting ? "Rest aktif" : "Workout hazır")
                            : focusCardStatusText
                        )
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(
                            task.taskType == "workout"
                            ? (focusWorkoutIsResting ? .orange : .green)
                            : (isSharedFocusActive
                               ? .green
                               : (store.isOverdue(task) ? .red : palette.secondaryText))
                        )
                    }
                    
                    Button {
                        startInlineFocus()
                        
                        if guide.currentStep == .homeFocusPrompt {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                guide.next()
                            }
                        }
                    } label: {
                        Text(task.taskType == "workout" ? "Start Workout" : "Start Focus")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                ZStack {
                                    Capsule()
                                        .fill(Color.accentColor)
                                    
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.14),
                                                    Color.clear
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                }
                            )
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .shadow(color: Color.accentColor.opacity(0.22), radius: 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(heroCardBackground)
                .overlay(
                    guideBorder(
                        active: guide.highlightsHomeFocus,
                        cornerRadius: 24
                    )
                )
            }
        }
    }
    
    var activeFocusCard: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            let liveRemaining = liveFocusRemaining(at: now)
            let urgencyColor = activeFocusUrgencyColor(for: liveRemaining)
            let warmState = liveRemaining > 0 && liveRemaining <= 30
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(focusWorkoutIsResting ? .orange : urgencyColor)
                            .frame(width: 8, height: 8)
                            .scaleEffect(liveDotPulse ? 1.35 : 0.85)
                            .opacity(liveDotPulse ? 0.65 : 1)
                            .animation(
                                .easeInOut(duration: 1).repeatForever(autoreverses: true),
                                value: liveDotPulse
                            )
                        
                        Text(
                            isSharedFocusActive
                            ? "Shared Focus Running"
                            : (focusWorkoutMode
                               ? (focusWorkoutIsResting ? "Workout Rest Running" : "Workout Running")
                               : "Focus Running")
                        )
                        .font(.system(size: 14, weight: .semibold))
                    }
                    
                    Spacer()
                    
                    Text(liveFocusTimeText(at: now))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                
                Text(
                    isSharedFocusActive
                    ? ((activeSharedFriendName != nil) ? "\(activeSharedFriendName!) ile focus" : "Shared Focus")
                    : (activeFocusTaskTitle.isEmpty ? "Deep Work Session" : activeFocusTaskTitle)
                )
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                
                if focusWorkoutMode {
                    VStack(alignment: .leading, spacing: 8) {
                        if !focusWorkoutExerciseName.isEmpty {
                            Text(focusWorkoutExerciseName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(palette.primaryText)
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 8) {
                            if focusWorkoutCurrentSet > 0 && focusWorkoutTotalSets > 0 {
                                miniBadge(
                                    icon: "figure.strengthtraining.traditional",
                                    text: "Set \(focusWorkoutCurrentSet)/\(focusWorkoutTotalSets)",
                                    tint: .green
                                )
                            }
                            
                            if focusWorkoutIsResting {
                                miniBadge(
                                    icon: "figure.cooldown",
                                    text: "Rest",
                                    tint: .orange
                                )
                            }
                        }
                    }
                }
                
                smoothActiveFocusProgressBar(at: now)
                    .frame(height: 10)
                
                HStack(spacing: 8) {
                    miniBadge(
                        icon: focusWorkoutIsResting ? "figure.cooldown" : "timer",
                        text: focusWorkoutIsResting
                        ? "Rest aktif"
                        : (liveRemaining <= 30 ? "Son 30 sn" : (focusWorkoutMode ? "Workout aktif" : "Odak aktif")),
                        tint: focusWorkoutIsResting ? .orange : urgencyColor
                    )
                    
                    miniBadge(
                        icon: focusWorkoutMode ? "dumbbell.fill" : "scope",
                        text: focusWorkoutMode
                        ? (focusWorkoutIsResting ? "Dinlenme" : "Set devam")
                        : "Devam",
                        tint: focusWorkoutIsResting ? .orange : (warmState ? urgencyColor : .green)
                    )
                }
                
                HStack(spacing: 8) {
                    Button {
                        if focusWorkoutMode {
                            advanceInlineWorkout()
                        }
                    } label: {
                        Text(
                            focusWorkoutMode
                            ? (focusWorkoutIsResting ? "Continue After Rest" : "Next Set")
                            : "Focus Active"
                        )
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(focusWorkoutMode ? Color.accentColor : Color.accentColor.opacity(0.16))
                        )
                        .foregroundStyle(focusWorkoutMode ? .white : Color.accentColor)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!focusWorkoutMode)
                    
                    Button {
                        stopActiveFocus()
                    } label: {
                        Text("Stop")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.14))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill((focusWorkoutIsResting ? Color.orange : urgencyColor).opacity(warmState ? 0.08 : 0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                (focusWorkoutIsResting ? Color.orange : urgencyColor).opacity(pulseActiveFocus ? 0.34 : 0.16),
                                lineWidth: 1.1
                            )
                    )
            )
            .overlay(
                guideBorder(
                    active: guide.currentStep == .homeFocusStarted,
                    cornerRadius: 22
                )
            )
            .shadow(
                color: (focusWorkoutIsResting ? Color.orange : urgencyColor).opacity(pulseActiveFocus ? 0.22 : 0.10),
                radius: pulseActiveFocus ? 14 : 7,
                x: 0,
                y: 5
            )
            .scaleEffect(pulseActiveFocus ? 1.008 : 1.0)
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: pulseActiveFocus
            )
        }
        .onAppear {
            liveDotPulse = true
        }
    }
    
    func focusChip(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(color.opacity(0.14))
        )
    }
    
    func crewFocusAccentColor(for session: CrewFocusSession) -> Color {
        if !session.isActive {
            return .green
        }
        
        let remaining = session.isPaused
        ? max(0, session.pausedRemainingSeconds ?? 0)
        : max(0, Int(session.endDate.timeIntervalSince(crewFocusNow)))
        
        if session.isPaused {
            return .orange
        }
        
        if remaining <= 180 {
            return .red
        }
        
        if remaining <= 600 {
            return .orange
        }
        
        return .blue
    }
    
    func toggleSharedFocusPause(session: CrewFocusSession) {
        guard session.isActive else { return }
        
        if session.isPaused {
            let remaining = session.pausedRemainingSeconds ?? 0
            session.startedAt = Date().addingTimeInterval(
                -Double(session.durationMinutes * 60 - remaining)
            )
            session.isPaused = false
            session.pausedRemainingSeconds = nil
        } else {
            let remaining = max(0, Int(ceil(session.endDate.timeIntervalSince(crewFocusNow))))
            session.pausedRemainingSeconds = remaining
            session.isPaused = true
        }
        
        try? modelContext.save()
    }
    
    func crewSharedFocusCard(session: CrewFocusSession) -> some View {
        let remaining = session.isPaused
        ? max(0, session.pausedRemainingSeconds ?? 0)
        : max(0, Int(session.endDate.timeIntervalSince(crewFocusNow)))
        
        let minutes = remaining / 60
        let seconds = remaining % 60
        let liveTimeText = String(format: "%02d:%02d", minutes, seconds)
        
        let total = Double(session.durationMinutes * 60)
        let progress = total > 0
        ? min(1, max(0, 1 - Double(remaining) / total))
        : 0
        
        let accent = crewFocusAccentColor(for: session)
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(accent.opacity(crewFocusGlowPulse ? 1 : 0.75))
                        .frame(width: 10, height: 10)
                        .shadow(
                            color: accent.opacity(crewFocusGlowPulse ? 0.45 : 0.20),
                            radius: 8
                        )
                    
                    Text(
                        !session.isActive
                        ? "Focus Completed"
                        : session.isPaused
                        ? "Focus Paused"
                        : "Focus Running"
                    )
                    .font(.headline.weight(.bold))
                    .foregroundStyle(palette.primaryText)
                }
                
                Spacer()
                
                Text(!session.isActive ? "DONE" : liveTimeText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(!session.isActive ? .green : palette.primaryText)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: liveTimeText)
            }
            
            Text(session.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.secondaryCardFill)
                    .frame(height: 10)
                
                GeometryReader { geo in
                    Capsule()
                        .fill(accent)
                        .frame(
                            width: max(10, geo.size.width * (!session.isActive ? 1 : progress)),
                            height: 10
                        )
                        .shadow(
                            color: accent.opacity(crewFocusGlowPulse ? 0.45 : 0.20),
                            radius: crewFocusGlowPulse ? 10 : 5
                        )
                        .animation(.linear(duration: 1), value: progress)
                }
            }
            .frame(height: 10)
            
            HStack(spacing: 10) {
                if !session.isActive {
                    focusChip(
                        title: "Done",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    
                    focusChip(
                        title: "Completed",
                        icon: "sparkles",
                        color: .green
                    )
                } else {
                    focusChip(
                        title: session.isPaused ? "Duraklatıldı" : "Odak aktif",
                        icon: session.isPaused ? "pause.fill" : "timer",
                        color: accent
                    )
                    
                    focusChip(
                        title: session.isPaused ? "Bekliyor" : "Devam",
                        icon: session.isPaused ? "pause.circle.fill" : "scope",
                        color: session.isPaused ? .orange : .green
                    )
                }
            }
            
            if session.isActive {
                HStack(spacing: 12) {
                    NavigationLink {
                        CrewFocusRoomView(session: session)
                    } label: {
                        Text("Open Focus")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.accentColor)
                            )
                    }
                    
                    Button {
                        toggleSharedFocusPause(session: session)
                    } label: {
                        Text(session.isPaused ? "Resume" : "Pause")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(session.isPaused ? .green : .orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(
                                        (session.isPaused ? Color.green : Color.orange)
                                            .opacity(0.12)
                                    )
                            )
                    }
                }
            } else {
                HStack {
                    Label("Session Completed", systemImage: "checkmark.circle.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.green)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.green.opacity(0.12))
                )
            }
        }
        .padding(18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(palette.cardFill)
                
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(accent.opacity(0.30), lineWidth: 1)
                
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(crewFocusGlowPulse ? 0.20 : 0.10),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 20,
                            endRadius: 260
                        )
                    )
                    .blur(radius: 24)
            }
        )
        .shadow(
            color: accent.opacity(crewFocusGlowPulse ? 0.18 : 0.08),
            radius: 18,
            y: 8
        )
    }
    
}
