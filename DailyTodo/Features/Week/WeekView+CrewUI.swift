//
//  WeekView+CrewUI.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 11.03.2026.
//

import SwiftUI
import SwiftData

extension WeekView {
    
    
    var allCrewTasksForSelectedDay: [CrewTask] {
        allCrewTasks
            .filter { $0.showOnWeek && $0.scheduledWeekday == selectedDay }
            .sorted {
                ($0.scheduledStartMinute ?? 0) < ($1.scheduledStartMinute ?? 0)
            }
    }

  
    @ViewBuilder
    func personalWeekList(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: WeekScrollOffsetKey.self,
                        value: max(0, -geo.frame(in: .named("personalScroll")).minY)
                    )
            }
            .frame(height: 0)

            VStack(spacing: 0) {
                modeTitleSwitcher

                LazyVStack(spacing: 0, pinnedViews: []) {
                    pickerSection
                    summarySection

                    if eventsForDay.isEmpty {
                        emptySection
                    } else {
                        eventsSection
                    }

                    Spacer(minLength: 90)
                }
            }
        }
        .coordinateSpace(name: "personalScroll")
        .onPreferenceChange(WeekScrollOffsetKey.self) { value in
            personalScrollOffset = value
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .offset(y: showPersonalEntrance ? 0 : 28)
        .opacity(showPersonalEntrance ? 1 : 0)
        .scaleEffect(showPersonalEntrance ? 1.0 : 0.985)
        .animation(.spring(response: 0.44, dampingFraction: 0.86), value: showPersonalEntrance)
    }
    var crewWeekList: some View {
        ScrollView {
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: WeekScrollOffsetKey.self,
                        value: max(0, -geo.frame(in: .named("crewScroll")).minY)
                    )
            }
            .frame(height: 0)

            VStack(spacing: 0) {
                modeTitleSwitcher

                VStack(spacing: 16) {
                    crewPickerSection

                    HStack(alignment: .center, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Today in Crew")
                                .font(.system(size: 22, weight: .bold, design: .default))

                            Text(fullDateTextForSelectedDay())
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.blue)

                                Text("Team flow for today")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.accentColor.opacity(0.22),
                                                Color.accentColor.opacity(0.08)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 54, height: 54)

                                Image(systemName: "person.3.fill")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Color.accentColor)
                            }

                            Text("\(allCrewTasksForSelectedDay.filter { !$0.isDone }.count) Görev")
                                .font(.caption2.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
                .background(Color(.systemGroupedBackground))

                VStack(spacing: 0) {
                    crewWeekSection
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    if !allCrewTasksForSelectedDay.isEmpty {
                        Divider()
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)

                        HStack {
                            Text("Recent Activity")
                                .font(.system(size: 18, weight: .bold, design: .rounded))

                            Spacer()

                            Image(systemName: "bolt.fill")
                                .foregroundStyle(.orange)
                        }
                        .padding(.horizontal, 20)

                        activityListContent
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }
                }

                Spacer(minLength: 90)
            }
        }
        .coordinateSpace(name: "crewScroll")
        .onPreferenceChange(WeekScrollOffsetKey.self) { value in
            crewScrollOffset = value
        }
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .offset(y: showCrewEntrance ? 0 : 30)
        .opacity(showCrewEntrance ? 1 : 0)
        .scaleEffect(showCrewEntrance ? 1 : 0.98)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showCrewEntrance)
        .onAppear {
            if !didAnimateCrewCards {
                didAnimateCrewCards = true
            }
        }
    }
    var crewPickerSection: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { day in
                Button {
                    withAnimation(.spring(duration: 0.28)) {
                        selectedDay = day
                    }
                } label: {
                    Text(dayTitles[day])
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(day == selectedDay ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    day == selectedDay
                                    ? LinearGradient(
                                        colors: [
                                            dayIndicatorColor(for: day),
                                            dayIndicatorColor(for: day).opacity(0.82)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.05),
                                            Color.white.opacity(0.025)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(
                                    day == selectedDay
                                    ? Color.white.opacity(0.12)
                                    : Color.white.opacity(0.05),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: day == selectedDay
                            ? dayIndicatorColor(for: day).opacity(0.30)
                            : .clear,
                            radius: day == selectedDay ? 12 : 0
                        )
                        .scaleEffect(day == selectedDay ? 1.02 : 1.0)
                        .animation(.spring(duration: 0.22), value: selectedDay)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    var activityListContent: some View {
        let recent = Array(allCrewActivities.prefix(5))

        return VStack(alignment: .leading, spacing: 14) {
            if recent.isEmpty {
                Text("No crew activity yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(Color.orange.opacity(0.95))
                                .frame(width: 10, height: 10)

                            if index != recent.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                                    .padding(.top, 5)
                            }
                        }
                        .frame(width: 14)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.memberName)
                                    .font(.caption.weight(.bold))

                                Spacer()

                                Text(item.createdAt, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }

                            Text(item.actionText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    var crewWeekSection: some View {
        Section {
            let tasks = allCrewTasksForSelectedDay

            VStack(alignment: .leading, spacing: 14) {
                if tasks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)

                        Text("Bugün için görev yok")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text("Seçili gün için crew görevi eklendiğinde burada görünecek.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                    .padding(.bottom, 20)

                } else {
                    let nowTasks = activeCrewTasksToday()
                    let nextTasks = upcomingCrewTasksToday()
                    let lateTasks = lateCrewTasksToday()
                    let laterTasks = laterCrewTasksToday()
                    let doneTasks = completedCrewTasksToday()

                    VStack(alignment: .leading, spacing: 14) {
                        if !nowTasks.isEmpty {
                            crewTimelineSectionHeader("Now", systemImage: "dot.radiowaves.left.and.right")

                            LazyVStack(spacing: 12) {
                                ForEach(Array(nowTasks.enumerated()), id: \.element.id) { index, task in
                                    crewTaskButton(task: task, index: index, totalCount: nowTasks.count)
                                }
                            }
                        }

                        if !nextTasks.isEmpty {
                            crewTimelineSectionHeader("Up Next", systemImage: "clock.badge")

                            LazyVStack(spacing: 12) {
                                ForEach(Array(nextTasks.enumerated()), id: \.element.id) { index, task in
                                    crewTaskButton(task: task, index: index, totalCount: nextTasks.count)
                                }
                            }
                        }

                        if !lateTasks.isEmpty {
                            crewTimelineSectionHeader("Late", systemImage: "exclamationmark.circle")

                            LazyVStack(spacing: 12) {
                                ForEach(Array(lateTasks.enumerated()), id: \.element.id) { index, task in
                                    crewTaskButton(task: task, index: index, totalCount: lateTasks.count)
                                }
                            }
                        }

                        if !laterTasks.isEmpty {
                            crewTimelineSectionHeader("Later Today", systemImage: "calendar")

                            LazyVStack(spacing: 12) {
                                ForEach(Array(laterTasks.enumerated()), id: \.element.id) { index, task in
                                    crewTaskButton(task: task, index: index, totalCount: laterTasks.count)
                                }
                            }
                        }

                        if !doneTasks.isEmpty {
                            VStack(spacing: 10) {
                                crewCollapsibleSectionHeader(
                                    "Completed",
                                    systemImage: "checkmark.circle",
                                    isExpanded: showCompletedCrewTasks,
                                    count: doneTasks.count
                                ) {
                                    withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                                        showCompletedCrewTasks.toggle()
                                    }
                                }

                                if showCompletedCrewTasks {
                                    LazyVStack(spacing: 12) {
                                        ForEach(Array(doneTasks.enumerated()), id: \.element.id) { index, task in
                                            crewTaskButton(task: task, index: index, totalCount: doneTasks.count)
                                                .transition(
                                                    .asymmetric(
                                                        insertion: .move(edge: .top).combined(with: .opacity),
                                                        removal: .opacity.combined(with: .scale(scale: 0.98))
                                                    )
                                                )
                                        }
                                    }
                                } else {
                                    completedTasksCollapsedSummary(doneTasks)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                                                showCompletedCrewTasks.toggle()
                                            }
                                        }
                                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                }
                            }
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("Crew Tasks")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .onAppear {
                if !didAnimateCrewCards {
                    didAnimateCrewCards = true
                }
            }
            .textCase(nil)
            .offset(y: showCrewTaskHeader ? 0 : 14)
            .opacity(showCrewTaskHeader ? 1 : 0)
        }
    }

    func enhancedPremiumTimelineCard(
        _ task: CrewTask,
        isLast: Bool,
        parallaxOffset: CGFloat,
        timelineParallaxOffset: CGFloat
    ) -> some View {

        let tint = premiumPriorityColor(task.priority)
        let active = isTaskActive(task)
        let done = task.isDone
        let soon = isTaskStartingSoon(task)
        let isLate = lateCrewTasksToday().contains(where: { $0.id == task.id })
        let lateText = lateDurationText(for: task)

        return CrewTaskCard(
            title: task.title,
            crewName: crewName(for: task),
            timeText: taskTimeText(task),
            priorityTitle: priorityTitle(task.priority),
            statusTitle: statusTitle(task.status),
            tint: tint,
            active: active,
            done: done,
            soon: soon,
            isLate: isLate,
            lateText: lateText,
            crewPulse: crewPulse,
            commentPulse: commentPulse,
            commentCount: commentsForTask(task).count,
            commentPreview: commentPreviewItems(for: task),
            minutesLeft: taskMinutesLeft(task),
            progress: taskProgress(task),

            parallaxOffset: parallaxOffset,
            timelineParallaxOffset: timelineParallaxOffset
        )
    }
    
    func crewTimelineSectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
    func crewTaskButton(task: CrewTask, index: Int, totalCount: Int) -> some View {
        Button {
            if let crew = crewMap[task.crewID] {
                selectedCrewTask = task
                selectedCrewForDetail = crew
                Haptics.impact(.light)
            }
        } label: {
            GeometryReader { geo in
                let minY = geo.frame(in: .global).minY
                let screenMid = UIScreen.main.bounds.height * 0.5
                let distance = minY - screenMid

                let parallax = max(-3, min(3, -distance * 0.025))
                let timelineParallax = max(-8, min(8, -distance * 0.02))

                enhancedPremiumTimelineCard(
                    task,
                    isLast: index == totalCount - 1,
                    parallaxOffset: parallax,
                    timelineParallaxOffset: timelineParallax
                )
            }
            .frame(height: 210)
        }
        .buttonStyle(.plain)
        .offset(y: didAnimateCrewCards ? 0 : CGFloat(14 + (index * 6)))
        .opacity(didAnimateCrewCards ? 1 : 0)
        .scaleEffect(didAnimateCrewCards ? 1 : 0.985)
        .animation(
            .spring(response: 0.42, dampingFraction: 0.86)
                .delay(Double(index) * 0.04),
            value: didAnimateCrewCards
        )
        .contextMenu {
            Button {
                toggleCrewTaskDone(task)
            } label: {
                Label(
                    task.isDone ? "Mark as Undone" : "Mark as Done",
                    systemImage: task.isDone
                    ? "arrow.uturn.backward.circle.fill"
                    : "checkmark.circle.fill"
                )
            }

            if !commentsForTask(task).isEmpty {
                Button {
                    if let crew = crewMap[task.crewID] {
                        selectedCrewTask = task
                        selectedCrewForDetail = crew
                    }
                } label: {
                    Label("Open Task & Comments", systemImage: "text.bubble.fill")
                }
            }

            Button(role: .destructive) {
                deleteCrewTask(task)
            } label: {
                Label("Delete Task", systemImage: "trash.fill")
            }
        }
    }
    func crewCollapsibleSectionHeader(
        _ title: String,
        systemImage: String,
        isExpanded: Bool,
        count: Int,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("\(count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isExpanded)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
    func completedTasksCollapsedSummary(_ tasks: [CrewTask]) -> some View {
        let count = tasks.count
        let firstTitle = tasks.first?.title ?? "Completed tasks"

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.018))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
                .offset(y: 10)
                .padding(.horizontal, 10)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.028))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
                .offset(y: 5)
                .padding(.horizontal, 5)

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.14))
                        .frame(width: 34, height: 34)

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 16, weight: .bold))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(count) completed")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(firstTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text("Show completed")
                    .font(.caption2)
                    .foregroundStyle(.tertiary.opacity(0.8))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .frame(height: 68)
    }
   
}


