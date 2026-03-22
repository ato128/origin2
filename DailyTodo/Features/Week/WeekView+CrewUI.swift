//
//  WeekView+CrewUI.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 11.03.2026.
//

import SwiftUI
import SwiftData

extension WeekView {
    
    var allCrewTasksForSelectedDay: [WeekCrewTaskItem] {
        crewTasks(for: selectedDay)
    }
    var hasVisibleEventsForSelectedDay: Bool {
        !eventsForDay.isEmpty || !completedEvents.isEmpty
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
                    .padding(.bottom, 6)

                LazyVStack(spacing: 14, pinnedViews: []) {
                    personalDayPickerSection
                    summarySection

                    if hasVisibleEventsForSelectedDay {
                        eventsSection
                    } else {
                        emptySection
                    }

                    Spacer(minLength: 104)
                }
            }
            .padding(.top, 4)
        }
        .coordinateSpace(name: "personalScroll")
        .onPreferenceChange(WeekScrollOffsetKey.self) { value in
            personalScrollOffset = value
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .offset(y: showPersonalEntrance ? 0 : 22)
        .opacity(showPersonalEntrance ? 1 : 0)
        .scaleEffect(showPersonalEntrance ? 1.0 : 0.992)
        .animation(.spring(response: 0.40, dampingFraction: 0.88), value: showPersonalEntrance)
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
                    crewProjectSelector

                    HStack(alignment: .center, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(crewSummaryTitle)
                                .font(.system(size: 22, weight: .bold, design: .default))

                            Text(fullDateTextForSelectedDay())
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(palette.secondaryText)

                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(crewSummaryTint)

                                Text("Team flow for today")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(palette.secondaryText)

                                if activeCrewTaskCount > 0 {
                                    Text("Live")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(crewSummaryTint.opacity(0.12))
                                        .foregroundStyle(crewSummaryTint)
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        Spacer()

                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                crewSummaryTint.opacity(0.22),
                                                crewSummaryTint.opacity(0.08)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 54, height: 54)

                                Image(systemName: crewSummaryIconName)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(crewSummaryTint)
                            }

                            Text(crewSummaryTaskCountText)
                                .font(.caption2.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(crewSummaryTint.opacity(0.12))
                                .foregroundStyle(crewSummaryTint)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
                .background(Color.clear)

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
                                .foregroundStyle(palette.primaryText)

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
        .background(Color.clear)
        .offset(y: showCrewEntrance ? 0 : 24)
        .opacity(showCrewEntrance ? 1 : 0)
        .scaleEffect(showCrewEntrance ? 1 : 0.99)
        .animation(.spring(response: 0.42, dampingFraction: 0.87), value: showCrewEntrance)
        .onAppear {
            if !didAnimateCrewCards {
                didAnimateCrewCards = true
            }
        }
    }

    var crewPickerSection: some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { day in
                Button {
                    withAnimation(.spring(duration: 0.28)) {
                        selectedDay = day
                    }
                } label: {
                    Text(dayTitles[day])
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(day == selectedDay ? .white : palette.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
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
                                            palette.secondaryCardFill,
                                            palette.secondaryCardFill.opacity(0.92)
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
                                    : palette.cardStroke,
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

    var crewProjectSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(allCrews, id: \.id) { crew in
                    let isSelected = selectedCrewID == crew.id
                    let tint = hexColor(crew.colorHex)

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            selectedCrewID = crew.id
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: crew.icon)
                            Text(crew.name)
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(
                                    isSelected
                                    ? tint.opacity(0.18)
                                    : palette.secondaryCardFill
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isSelected
                                    ? tint.opacity(0.35)
                                    : palette.cardStroke,
                                    lineWidth: 1
                                )
                        )
                        .foregroundStyle(isSelected ? tint : palette.primaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    var activityListContent: some View {
        let recent = Array(
            allCrewActivities
                .filter { selectedCrewID == nil || $0.crewID == selectedCrewID }
                .prefix(5)
        )

        return VStack(alignment: .leading, spacing: 14) {
            if recent.isEmpty {
                Text("No crew activity yet")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            } else {
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(Color.orange.opacity(0.95))
                                .frame(width: 10, height: 10)

                            if index != recent.count - 1 {
                                Rectangle()
                                    .fill(palette.cardStroke)
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
                                    .foregroundStyle(palette.primaryText)

                                Spacer()

                                Text(item.createdAt, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(palette.secondaryText)
                            }

                            Text(item.actionText)
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
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

                        Text("Seçili gün ve crew için görev eklendiğinde burada görünecek.")
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
                                
                                .animation(.spring(response: 0.38, dampingFraction: 0.86), value: allCrewTasksForSelectedDay.map { "\($0.id.uuidString)-\($0.isDone)" })

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
            HStack(spacing: 10) {
                Image(systemName: "checklist")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(palette.secondaryText)

                Text("Crew Tasks")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                if activeCrewTaskCount > 0 {
                    Text("\(activeCrewTaskCount)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(palette.secondaryCardFill)
                        .clipShape(Capsule())
                        .foregroundStyle(palette.secondaryText)
                }

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

    var crewSummaryIconName: String {
        selectedCrew?.icon ?? "person.3.fill"
    }

    var crewSummaryTint: Color {
        selectedCrew.map { hexColor($0.colorHex) } ?? .blue
    }

    var crewSummaryTitle: String {
        selectedCrew.map { "Today in \($0.name)" } ?? "Select a Crew"
    }

    var crewSummaryTaskCountText: String {
        let count = allCrewTasksForSelectedDay.filter { !$0.isDone }.count
        return "\(count) Tasks"
    }

    func enhancedPremiumTimelineCard(
        _ task: WeekCrewTaskItem,
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
                .foregroundStyle(palette.secondaryText)

            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.secondaryText)

            Spacer()
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    func crewTaskButton(task: WeekCrewTaskItem, index: Int, totalCount: Int) -> some View {
        Button {
            if let crew = crewMap[task.crewID] {
                selectedCrewTask = task
                selectedCrewForDetail = crew
                Haptics.impact(.light)
            }
        } label: {
            GeometryReader { geo in
                let minY = geo.frame(in: .global).minY
                let screenMid = geo.size.height * 0.5
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
            .frame(height: 178)
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
        .transition(
            .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity.combined(with: .scale(scale: 0.98))
            )
        )
        .contextMenu {
            Button {
                selectedTaskForEdit = task
            } label: {
                Label("Edit", systemImage: "pencil")
            }

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
                    .foregroundStyle(palette.secondaryText)

                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                Text("\(count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(palette.secondaryCardFill)
                    .clipShape(Capsule())
                    .foregroundStyle(palette.secondaryText)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.secondaryText)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isExpanded)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    func completedTasksCollapsedSummary(_ tasks: [WeekCrewTaskItem]) -> some View {
        let count = tasks.count
        let firstTitle = tasks.first?.title ?? "Completed tasks"

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.secondaryCardFill.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardStroke.opacity(0.7), lineWidth: 1)
                )
                .offset(y: 10)
                .padding(.horizontal, 10)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.secondaryCardFill.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardStroke.opacity(0.85), lineWidth: 1)
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
                        .foregroundStyle(palette.primaryText)

                    Text(firstTitle)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Text("Show completed")
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryText.opacity(0.85))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
        }
        .frame(height: 68)
    }
}
