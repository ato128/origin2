//
//  HomeDashboardSections.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI
import SwiftData
import Combine

extension HomeDashboardView {

    var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(greetingText) 👋")
                .font(.title2.bold())

            Text(todayDateText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Stay productive today 🚀")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var homeMiniWeekCalendar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("This Week")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    onOpenWeek()
                } label: {
                    Image(systemName: "calendar")
                        .font(.caption.bold())
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                ForEach(0..<7, id: \.self) { day in
                    let isSelected = day == selectedDay
                    let isToday = day == weekdayIndexToday()
                    let date = targetDateFor(day: day)
                    let hasItems = hasEvents(on: day)

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            selectedDay = day
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(dayTitles[day])
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isSelected ? .primary : .secondary)

                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)
                                .monospacedDigit()

                            ZStack {
                                if isToday && !hasItems {
                                    Circle()
                                        .stroke(Color.accentColor.opacity(0.7), lineWidth: 1.5)
                                        .frame(width: 7, height: 7)
                                } else {
                                    Circle()
                                        .fill(hasItems ? Color.accentColor : Color.white.opacity(0.16))
                                        .frame(width: hasItems ? 6 : 4, height: hasItems ? 6 : 4)
                                }
                            }
                            .frame(height: 8)
                            .padding(.top, 1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    isSelected
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.white.opacity(0.035)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    isSelected
                                    ? Color.accentColor.opacity(0.18)
                                    : Color.white.opacity(0.045),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: isSelected ? Color.accentColor.opacity(0.08) : .clear,
                            radius: isSelected ? 10 : 0
                        )
                        .scaleEffect(isSelected ? 1.015 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(cardBackground)
        }
    }

    var todayProgressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today Progress")
                    .font(.headline)

                Spacer()

                Text("\(completedTodayCount)/\(totalTodayTaskCount)")
                    .font(.title2.bold())
                    .monospacedDigit()
            }

            ProgressView(value: todayProgressValue)
                .tint(.accentColor)
                .scaleEffect(y: 1.8)

            HStack(spacing: 10) {
                miniBadge(
                    icon: "flame.fill",
                    text: "\(streakCount) gün seri",
                    tint: .orange
                )

                miniBadge(
                    icon: "checkmark.circle.fill",
                    text: "\(completedTodayCount) bugün tamamlandı",
                    tint: .green
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var focusCard: some View {
        Group {
            if let task = focusTask {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Focus Now")
                            .font(.headline)

                        Spacer()

                        Image(systemName: "scope")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }

                    Text(task.title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if let due = task.dueDate {
                            Label {
                                Text(due, style: .time)
                            } icon: {
                                Image(systemName: "calendar")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(focusTaskStatusText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(store.isOverdue(task) ? .red : .secondary)
                    }

                    Button {
                        showingFocusSession = true
                    } label: {
                        Text("Start Focus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
            }
        }
    }

    var activeFocusCard: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            let liveRemaining = liveFocusRemaining(at: now)
            let urgencyColor = activeFocusUrgencyColor(for: liveRemaining)
            let warmState = liveRemaining > 0 && liveRemaining <= 30

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(urgencyColor)
                            .frame(width: 8, height: 8)
                            .scaleEffect(liveDotPulse ? 1.4 : 0.8)
                            .opacity(liveDotPulse ? 0.6 : 1)
                            .animation(
                                .easeInOut(duration: 1).repeatForever(autoreverses: true),
                                value: liveDotPulse
                            )

                        Text("Focus Running")
                            .font(.headline)
                    }

                    Spacer()

                    Text(liveFocusTimeText(at: now))
                        .font(.title3.bold())
                        .monospacedDigit()
                }

                Text(activeFocusTaskTitle.isEmpty ? "Deep Work Session" : activeFocusTaskTitle)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)

                smoothActiveFocusProgressBar(at: now)

                HStack(spacing: 10) {
                    miniBadge(
                        icon: "timer",
                        text: liveRemaining <= 30 ? "Son 30 saniye" : "Odak aktif",
                        tint: urgencyColor
                    )

                    miniBadge(
                        icon: "scope",
                        text: "Devam ediyor",
                        tint: warmState ? urgencyColor : .green
                    )
                }

                HStack(spacing: 12) {
                    Button {
                        showingFocusSession = true
                    } label: {
                        Text("Open Focus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        stopActiveFocus()
                    } label: {
                        Text("Stop")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.red.opacity(0.14))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(urgencyColor.opacity(warmState ? 0.08 : 0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                urgencyColor.opacity(pulseActiveFocus ? 0.38 : 0.18),
                                lineWidth: 1.2
                            )
                    )
            )
            .shadow(
                color: urgencyColor.opacity(pulseActiveFocus ? 0.28 : 0.12),
                radius: pulseActiveFocus ? 18 : 8,
                x: 0,
                y: 6
            )
            .scaleEffect(pulseActiveFocus ? 1.01 : 1.0)
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: pulseActiveFocus
            )
        }
        .onAppear {
            liveDotPulse = true
        }
    }

    var nextClassCard: some View {
        let classColor = nextEvent.map { hexColor($0.colorHex) } ?? .secondary
        let animatedClassColor = classColor

        let startsSoon: Bool = {
            guard let nextEvent else { return false }
            let now = currentMinuteOfDay()
            let diff = nextEvent.startMinute - now
            return diff > 0 && diff <= 30
        }()

        let startsVerySoon: Bool = {
            guard let nextEvent else { return false }
            let now = currentMinuteOfDay()
            let diff = nextEvent.startMinute - now
            return diff > 0 && diff <= 5
        }()

        let isLiveNow: Bool = {
            guard let nextEvent else { return false }
            let now = currentMinuteOfDay()
            let start = nextEvent.startMinute
            let end = nextEvent.startMinute + nextEvent.durationMinute
            return now >= start && now < end
        }()

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Next Class")
                    .font(.headline)
                    .foregroundStyle(nextEvent == nil ? .primary : animatedClassColor)

                Spacer()

                Button {
                    onOpenWeek()
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.caption.bold())
                        .padding(8)
                        .background(
                            Circle()
                                .fill(animatedClassColor.opacity(0.16))
                        )
                }
                .buttonStyle(.plain)
            }

            if let nextEvent {
                HStack(spacing: 12) {
                    Circle()
                        .fill(animatedClassColor)
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(nextEvent.title)
                            .font(.title3.bold())
                            .foregroundStyle(animatedClassColor)
                            .lineLimit(1)

                        Text(nextEventTimeText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            if nextEventStatusText.contains("aktif") {
                                Text("LIVE")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(Color.green.opacity(0.18))
                                    )
                                    .foregroundStyle(.green)
                            }

                            Text(nextEventStatusText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .id("\(nextEvent.title)-\(nextEvent.startMinute)-\(nextEvent.weekday)-\(nextEvent.colorHex)")
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.98)),
                        removal: .move(edge: .leading)
                            .combined(with: .opacity)
                    )
                )
            } else {
                Text("Bugün başka ders yok")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .id("no-next-class")
                    .transition(.opacity)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(animatedClassColor.opacity(nextEvent == nil ? 0.0 : 0.05))

                        if startsSoon {
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    animatedClassColor.opacity(0.03),
                                    animatedClassColor.opacity(0.10)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .clipShape(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                            )
                        }

                        if isLiveNow {
                            RadialGradient(
                                colors: [
                                    animatedClassColor.opacity(0.10),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 180
                            )
                            .clipShape(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                            )
                        }

                        if nextClassSweep {
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.22),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(width: 90)
                            .rotationEffect(.degrees(18))
                            .offset(x: nextClassSweep ? 220 : -220)
                            .blendMode(.plusLighter)
                            .animation(.easeInOut(duration: 0.9), value: nextClassSweep)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                            )
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            animatedClassColor.opacity(
                                nextEvent == nil
                                ? 0.08
                                : (isLiveNow ? 0.24 : (startsSoon ? 0.20 : 0.18))
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: animatedClassColor.opacity(
                nextEvent == nil
                ? 0.0
                : (isLiveNow ? 0.16 : (startsSoon ? 0.10 : 0.10))
            ),
            radius: isLiveNow ? 14 : 10,
            x: 0,
            y: 4
        )
        .animation(.interactiveSpring(response: 0.55, dampingFraction: 0.82, blendDuration: 0.25), value: nextEvent?.title)
        .animation(.interactiveSpring(response: 0.55, dampingFraction: 0.82, blendDuration: 0.25), value: nextEvent?.startMinute)
        .animation(.interactiveSpring(response: 0.55, dampingFraction: 0.82, blendDuration: 0.25), value: nextEventStatusText)
        .animation(.easeInOut(duration: 0.7), value: nextEvent?.colorHex)
        .scaleEffect(startsVerySoon ? (nextClassPulse ? 1.012 : 1.0) : 1.0)
        .shadow(
            color: animatedClassColor.opacity(
                startsVerySoon
                ? (nextClassPulse ? 0.22 : 0.12)
                : 0.0
            ),
            radius: startsVerySoon ? (nextClassPulse ? 18 : 10) : 0,
            x: 0,
            y: 0
        )
        .animation(
            startsVerySoon
            ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
            : .easeInOut(duration: 0.2),
            value: nextClassPulse
        )
        .onAppear {
            if startsVerySoon {
                nextClassPulse = true
            }
        }
        .onChange(of: startsVerySoon) { _, newValue in
            nextClassPulse = newValue
        }
        .onChange(of: isLiveNow) { _, newValue in
            guard newValue else { return }

            nextClassSweep = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                nextClassSweep = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                nextClassSweep = false
            }
        }
    }

    var todayTasksCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today Tasks")
                    .font(.headline)

                Spacer()

                Text("\(todayTasks.prefix(3).count) gösteriliyor")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if todayTasks.isEmpty {
                Text("Bugün için aktif task yok.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(todayTasks.prefix(3))) { task in
                    HStack(spacing: 10) {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)

                            if let due = task.dueDate {
                                Text(due, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                quickActionButton(
                    title: "Add Task",
                    systemImage: "plus.circle.fill",
                    action: onAddTask
                )

                quickActionButton(
                    title: "Week",
                    systemImage: "calendar",
                    action: onOpenWeek
                )

                quickActionButton(
                    title: "Insights",
                    systemImage: "chart.bar.fill",
                    action: onOpenInsights
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    func quickActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)

                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }

    func miniBadge(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(tint.opacity(0.15)))
        .foregroundStyle(tint)
    }

    func hasEvents(on day: Int) -> Bool {
        let calendar = Calendar.current
        let targetDate = targetDateFor(day: day)

        return allEvents.contains { ev in
            if let scheduledDate = ev.scheduledDate {
                return calendar.isDate(scheduledDate, inSameDayAs: targetDate)
            } else {
                return ev.weekday == day
            }
        }
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
