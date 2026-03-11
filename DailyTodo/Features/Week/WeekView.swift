//
//  WeekView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData
import UIKit
import Combine

enum WeekMode {
    case personal
    case crew
}

struct WeekView: View {

    @Environment(\.modelContext) private var context

    @Query(sort: \EventItem.startMinute, order: .forward)
    private var allEvents: [EventItem]
    @Query private var allCrewTasks: [CrewTask]
    @Query private var allCrews: [Crew]
    @Query(sort: \CrewActivity.createdAt, order: .reverse)
    private var allCrewActivities: [CrewActivity]
    @Query(sort: \CrewTaskComment.createdAt, order: .reverse)
    private var allCrewComments: [CrewTaskComment]
    
    private var crewMap: [UUID: Crew] {
        Dictionary(uniqueKeysWithValues: allCrews.map { ($0.id, $0) })
    }
   

    @State private var selectedDay: Int = 0
    @State private var showingAdd: Bool = false
    @State private var editingEvent: EventItem? = nil
    
    @State private var weekMode: WeekMode = .personal
    

    @State private var showCopied: Bool = false
    @State private var crewPulse = false

    @State private var didInitialAutoScroll: Bool = false
    @State private var lastAutoScrollTargetID: UUID? = nil
    @State private var didSetInitialDay: Bool = false

    @State private var animateSummary = false
    @State private var pulseTodayDot = false
    @State private var commentPulse = false
    @State private var selectedCrewTask: CrewTask?
    @State private var selectedCrewForDetail: Crew?
    @State private var showCrewEntrance = false
    @State private var showCrewTaskHeader = false
    @State private var showCrewTaskCards = false


    private let liveTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private let dayTitles = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]

    private var allEventIDs: [UUID] { allEvents.map(\.id) }

    private var eventsForDay: [EventItem] {
        allEvents
            .filter { $0.weekday == selectedDay }
            .sorted { $0.startMinute < $1.startMinute }
    }

    private var eventsForDayIDs: [UUID] { eventsForDay.map(\.id) }

    private var totalMinutesForDay: Int {
        eventsForDay.reduce(0) { $0 + $1.durationMinute }
    }

    private var firstEventOfDay: EventItem? {
        eventsForDay.first
    }

    private var lastEventOfDay: EventItem? {
        eventsForDay.last
    }

    private var isTodaySelected: Bool {
        selectedDay == weekdayIndexToday()
    }

    private var liveEventForDay: EventItem? {
        guard isTodaySelected else { return nil }
        let now = currentMinuteOfDay()
        return eventsForDay.first(where: {
            now >= $0.startMinute && now < ($0.startMinute + $0.durationMinute)
        })
    }

    private var currentTimeIndicatorText: String? {
        guard isTodaySelected else { return nil }

        let now = currentMinuteOfDay()

        if let live = eventsForDay.first(where: { now >= $0.startMinute && now < ($0.startMinute + $0.durationMinute) }) {
            let left = max(0, (live.startMinute + live.durationMinute) - now)
            return "Şu an \(hm(now)) • \(live.title) devam ediyor • \(left) dk kaldı"
        }

        if let next = eventsForDay.first(where: { $0.startMinute > now }) {
            return "Şu an \(hm(now)) • Sıradaki ders \(hm(next.startMinute))"
        }

        if !eventsForDay.isEmpty {
            return "Şu an \(hm(now)) • Bugünkü dersler bitti"
        }

        return nil
    }

    var body: some View {
        ScrollViewReader { proxy in
            mainList(proxy: proxy)
                .navigationTitle("Week")
                .navigationBarTitleDisplayMode(.large)
                .toolbar { toolbarContent }
                .sheet(isPresented: $showingAdd) {
                    NavigationStack { AddEventView(defaultWeekday: selectedDay) }
                        .presentationDetents([.medium, .large])
                }
                .sheet(item: $editingEvent) { ev in
                    NavigationStack { EditEventView(event: ev) }
                        .presentationDetents([.medium, .large])
                }
                .sheet(item: $selectedCrewTask) { task in
                    if let crew = selectedCrewForDetail {
                        NavigationStack {
                            CrewTaskDetailView(task: task, crew: crew)
                                .presentationDetents([.medium, .large])
                                .presentationDragIndicator(.visible)
                                .presentationCornerRadius(28)
                        }
                    }
                }
                .overlay(toastView, alignment: .bottom)
                .onAppear {
                    onAppear(proxy: proxy)
                    crewPulse = true
                    commentPulse = true
                }
                .onChange(of: selectedDay) { _, _ in onDayChanged(proxy: proxy) }
                .onChange(of: eventsForDayIDs) { _, _ in
                    animateSummaryCard()
                    autoScrollIfNeeded(proxy: proxy)
                }
                .onChange(of: allEventIDs) { _, _ in
                    Task { await NotificationManager.shared.rescheduleAll(events: allEvents) }
                }
                .onReceive(liveTimer) { _ in
                    Task { await LiveActivityManager.shared.autoSyncIfNeeded(events: allEvents) }
                }
                .onChange(of: weekMode) { _, newValue in
                    if newValue == .crew {
                        showCrewEntrance = false
                        showCrewTaskHeader = false
                        showCrewTaskCards = false

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                showCrewEntrance = true
                            }
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                            withAnimation(.easeOut(duration: 0.28)) {
                                showCrewTaskHeader = true
                            }
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                                showCrewTaskCards = true
                            }
                        }

                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCrewEntrance = false
                            showCrewTaskHeader = false
                            showCrewTaskCards = false
                        }
                    }
                }
        }
    }
}


// MARK: - Main List
// MARK: - Main List
private extension WeekView {
    
    @ViewBuilder
    func mainList(proxy: ScrollViewProxy) -> some View {
        if weekMode == .personal {
            personalWeekList(proxy: proxy)
        } else {
            crewWeekList
                .offset(y: showCrewEntrance ? 0 : 26)
                .opacity(showCrewEntrance ? 1 : 0)
                .scaleEffect(showCrewEntrance ? 1.0 : 0.985)
                .animation(.spring(response: 0.45, dampingFraction: 0.86), value: showCrewEntrance)
        }
    }
    
    
    
    @ViewBuilder
    func personalWeekList(proxy: ScrollViewProxy) -> some View {
        List {
            pickerSection
            summarySection
            
            if eventsForDay.isEmpty {
                emptySection
            } else {
                eventsSection
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }
    
    @ViewBuilder
    var crewWeekList: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    crewPickerSection
                    
                    HStack(alignment: .center, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Crew Week")
                                .font(.system(size: 30, weight: .black, design: .rounded))
                            
                            Text(fullDateTextForSelectedDay())
                                .font(.subheadline.weight(.medium))
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
                        .padding(.top, 10)
                    
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
        .background(Color(.systemGroupedBackground))
        .scrollIndicators(.hidden)
        .offset(y: showCrewEntrance ? 0 : 30)
        .opacity(showCrewEntrance ? 1 : 0)
        .scaleEffect(showCrewEntrance ? 1 : 0.98)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showCrewEntrance)
    }
    
    var crewDateSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Crew Week")
                        .font(.system(size: 20, weight: .bold))
                    
                    Text(fullDateTextForSelectedDay())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 42, height: 42)
                    
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }
    var crewActivityPreviewSection: some View {
        let recent = Array(allCrewActivities.prefix(4))
        
        return Section("Recent Activity") {
            if recent.isEmpty {
                Text("No crew activity yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recent) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.memberName)
                                .font(.caption.weight(.semibold))
                            
                            Text(item.actionText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        Text(item.createdAt, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
    
    var pickerSection: some View {
        Section {
            VStack(spacing: 12) {
                
                Picker("Week Mode", selection: $weekMode) {
                    Text("Personal").tag(WeekMode.personal)
                    Text("Crew").tag(WeekMode.crew)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                
                Picker("Gün", selection: $selectedDay) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(dayTitles[i]).tag(i)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)
                
                HStack {
                    ForEach(0..<7, id: \.self) { i in
                        VStack(spacing: 4) {
                            Circle()
                                .fill(i == weekdayIndexToday() ? Color.accentColor : .clear)
                                .frame(width: 6, height: 6)
                                .scaleEffect(i == weekdayIndexToday() && pulseTodayDot ? 1.18 : 1.0)
                                .opacity(i == weekdayIndexToday() ? 1 : 0)
                            
                            Color.clear.frame(height: 1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulseTodayDot)
            }
            .padding(10)
            .background(sectionCardBackground)
        }
        .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
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
    
    var allCrewTasksForSelectedDay: [CrewTask] {
        allCrewTasks
            .filter { $0.showOnWeek && $0.scheduledWeekday == selectedDay }
            .sorted {
                ($0.scheduledStartMinute ?? 0) < ($1.scheduledStartMinute ?? 0)
            }
    }
    
    func enhancedPremiumTimelineCard(_ task: CrewTask, isLast: Bool) -> some View {
        let tint = premiumPriorityColor(task.priority)
        let active = isTaskActive(task)
        let done = task.isDone
        let soon = isTaskStartingSoon(task)

        return timelineCardContent(
            task: task,
            isLast: isLast,
            tint: tint,
            active: active,
            done: done,
            soon: soon
        )
    }
    
    func timelineCardContent(
        task: CrewTask,
        isLast: Bool,
        tint: Color,
        active: Bool,
        done: Bool,
        soon: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            timelineIndicator(isLast: isLast, tint: tint, active: active, done: done, soon: soon)

            VStack(alignment: .leading, spacing: 12) {
                taskHeader(task: task, tint: tint, active: active, done: done)

                if let crew = crewMap[task.crewID] {
                    taskProjectBadge(crew: crew)
                }

                taskMeta(task: task, tint: tint, active: active, soon: soon)

                if !previewCommentsForTask(task).isEmpty {
                    taskCommentPreview(task)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .shadow(
                        color: active ? tint.opacity(0.25) : .black.opacity(0.08),
                        radius: active ? 10 : 4,
                        y: active ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(active ? tint.opacity(0.28) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .opacity(done ? 0.82 : 1.0)
        .shadow(
            color: hasComments(task)
            ? tint.opacity(commentPulse ? 0.16 : 0.06)
            : .clear,
            radius: hasComments(task) ? (commentPulse ? 12 : 5) : 0
        )
        .scaleEffect(active && crewPulse ? 1.008 : 1.0)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: crewPulse)
        .animation(
            .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
            value: commentPulse
        )
        .animation(.easeInOut(duration: 0.2), value: done)
    }
    func liveDot(tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 16, height: 16)
                .scaleEffect(crewPulse ? 1.15 : 0.95)

            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
                .shadow(color: tint.opacity(0.35), radius: 6)
        }
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: crewPulse)
    }
    
    func taskProjectBadge(crew: Crew) -> some View {
        let tint = hexColor(crew.colorHex)

        return HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
                .shadow(color: tint.opacity(0.35), radius: 4)

            Text(crew.name)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12))
        .foregroundStyle(tint)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: tint.opacity(0.25), radius: 6)
    }
    
    func timelineIndicator(
        isLast: Bool,
        tint: Color,
        active: Bool,
        done: Bool,
        soon: Bool
    ) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(done ? Color.green : (active ? tint : tint.opacity(0.85)))
                    .frame(width: active ? 16 : 13, height: active ? 16 : 13)
                    .scaleEffect(active && crewPulse ? 1.12 : 1.0)
                    .shadow(
                        color: active ? tint.opacity(0.40) : (soon ? tint.opacity(0.18) : .clear),
                        radius: active ? 14 : (soon ? 8 : 0)
                    )

                if active {
                    Circle()
                        .stroke(tint.opacity(0.24), lineWidth: 6)
                        .frame(width: 16, height: 16)
                        .scaleEffect(crewPulse ? 1.55 : 1.15)
                        .opacity(crewPulse ? 0.35 : 0.12)
                }
            }
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: crewPulse)

            if !isLast {
                LinearGradient(
                    colors: [
                        active ? tint.opacity(0.85) : tint.opacity(0.35),
                        tint.opacity(0.15),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .padding(.top, 6)
            }
        }
        .frame(width: 20)
    }
    func taskHeader(
        task: CrewTask,
        tint: Color,
        active: Bool,
        done: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(task.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(done ? .secondary : .primary)
                .strikethrough(done, color: .secondary)
                .lineLimit(2)

            Spacer()

            if active {
                ZStack {
                    Circle()
                        .stroke(tint.opacity(0.18), lineWidth: 4)
                        .frame(width: 30, height: 30)

                    Circle()
                        .trim(from: 0, to: taskProgress(task))
                        .stroke(
                            tint,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 30, height: 30)
                        .animation(.easeInOut(duration: 0.35), value: taskProgress(task))

                    Text("\(taskMinutesLeft(task))")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(tint)
                }
            } else if let start = task.scheduledStartMinute {
                Text(hm(start))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
    func taskMeta(
        task: CrewTask,
        tint: Color,
        active: Bool,
        soon: Bool
    ) -> some View {
        let commentCount = commentsForTask(task).count
        let hasComments = commentCount > 0

        return VStack(alignment: .leading, spacing: 10) {
            if !task.assignedTo.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                    Text(task.assignedTo)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text(priorityTitle(task.priority))
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(tint.opacity(0.14))
                    .foregroundStyle(tint)
                    .clipShape(Capsule())

                Text(statusTitle(task.status))
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.06))
                    .foregroundStyle(.secondary)
                    .clipShape(Capsule())

                Spacer()

                if hasComments {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                                .scaleEffect(commentPulse ? 1.18 : 1.0)
                                .shadow(color: Color.blue.opacity(commentPulse ? 0.35 : 0.12), radius: commentPulse ? 8 : 3)
                        }

                        HStack(spacing: 5) {
                            Image(systemName: "text.bubble.fill")
                            Text("\(commentCount)")
                                .monospacedDigit()
                        }
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.14))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                    }
                    .animation(
                        .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                        value: commentPulse
                    )
                }

                if active {
                    HStack(spacing: 6) {
                        liveDot(tint: .green)

                        Text("LIVE")
                            .font(.caption2.weight(.black))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.green.opacity(0.16))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                } else if soon {
                    Text("SOON")
                        .font(.caption2.weight(.black))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(tint.opacity(0.14))
                        .foregroundStyle(tint)
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    func taskProgress(_ task: CrewTask) -> Double {
        guard isTaskActive(task),
              let start = task.scheduledStartMinute,
              let duration = task.scheduledDurationMinute,
              duration > 0
        else { return 0 }

        let now = currentMinuteOfDay()
        let elapsed = max(0, now - start)
        return min(1, Double(elapsed) / Double(duration))
    }

    func taskMinutesLeft(_ task: CrewTask) -> Int {
        guard let start = task.scheduledStartMinute,
              let duration = task.scheduledDurationMinute
        else { return 0 }

        let now = currentMinuteOfDay()
        let end = start + duration
        return max(0, end - now)
    }
    
    func hasComments(_ task: CrewTask) -> Bool {
        !commentsForTask(task).isEmpty
    }
    
    func taskCommentPreview(_ task: CrewTask) -> some View {
        let comments = Array(previewCommentsForTask(task))
        let totalCount = commentsForTask(task).count
        let remaining = max(0, totalCount - comments.count)

        return VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(comments.enumerated()), id: \.element.id) { _, comment in
                HStack(alignment: .top, spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 28, height: 28)

                        Text(initialLetter(comment.authorName))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.primary)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(comment.authorName)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.primary)

                        Text(comment.message)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "text.bubble")
                Text("\(totalCount) comments")
                    .font(.caption2.weight(.semibold))

                if remaining > 0 {
                    Text("• +\(remaining) more")
                        .font(.caption2.weight(.semibold))
                }

                Spacer()
            }
            .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    func crewTasks(for day: Int) -> [CrewTask] {
        allCrewTasks
            .filter { $0.showOnWeek && $0.scheduledWeekday == day }
            .sorted {
                ($0.scheduledStartMinute ?? 0) < ($1.scheduledStartMinute ?? 0)
            }
    }
    
    func commentsForTask(_ task: CrewTask) -> [CrewTaskComment] {
        allCrewComments
            .filter { $0.taskID == task.id }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    

    func previewCommentsForTask(_ task: CrewTask) -> [CrewTaskComment] {
        Array(commentsForTask(task).prefix(2))
    }

    func initialLetter(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(1)).uppercased()
    }
    
    func currentMinuteOfDay() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    
    func hasCrewTasks(on day: Int) -> Bool {
        !crewTasks(for: day).isEmpty
    }
    
    
    func hasActiveCrewTask(on day: Int) -> Bool {
        guard day == weekdayIndexToday() else { return false }
        
        let now = currentMinuteOfDay()
        
        return crewTasks(for: day).contains { task in
            guard let start = task.scheduledStartMinute,
                  let duration = task.scheduledDurationMinute else { return false }
            let end = start + duration
            return now >= start && now < end
        }
    }
    
    func hasUpcomingCrewTaskSoon(on day: Int) -> Bool {
        guard day == weekdayIndexToday() else { return false }
        
        let now = currentMinuteOfDay()
        
        return crewTasks(for: day).contains { task in
            guard let start = task.scheduledStartMinute else { return false }
            let diff = start - now
            return diff >= 0 && diff <= 30
        }
    }
    
    func shouldGlowDay(_ day: Int) -> Bool {
        hasActiveCrewTask(on: day) || hasUpcomingCrewTaskSoon(on: day)
    }
    
    func toggleCrewTaskDone(_ task: CrewTask) {
        task.isDone.toggle()

        if task.isDone {
            task.status = "done"
            Haptics.notify(.success)
        } else {
            if task.status == "done" {
                task.status = "todo"
            }
            Haptics.impact(.light)
        }

        try? context.save()
    }

    func deleteCrewTask(_ task: CrewTask) {
        context.delete(task)
        Haptics.impact(.heavy)
        try? context.save()
    }
    
    func dayIndicatorColor(for day: Int) -> Color {
        if hasActiveCrewTask(on: day) {
            return .green
        }
        
        if hasUpcomingCrewTaskSoon(on: day) {
            return .orange
        }
        
        if hasUrgentCrewTask(on: day) {
            return .red
        }
        
        if hasCrewTasks(on: day) {
            return .blue
        }
        
        return .secondary
    }
    
    func dayIndicatorSize(for day: Int) -> CGFloat {
        if hasActiveCrewTask(on: day) {
            return 12
        }
        
        if hasUpcomingCrewTaskSoon(on: day) {
            return 10
        }
        
        return hasCrewTasks(on: day) ? 8 : 6
    }
    
    func dayPulseScale(for day: Int) -> CGFloat {
        if hasActiveCrewTask(on: day) {
            return 1.18
        }
        
        if hasUpcomingCrewTaskSoon(on: day) {
            return 1.08
        }
        
        return 1.0
    }
    
    func fullDateTextForSelectedDay() -> String {
        let calendar = Calendar.current
        let today = Date()
        
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let targetDate = calendar.date(byAdding: .day, value: selectedDay, to: startOfWeek) else {
            return "Date unavailable"
        }
        
        return targetDate.formatted(date: .complete, time: .omitted)
    }
    func premiumPriorityColor(_ priority: String) -> Color {
        switch priority {
        case "urgent":
            return Color(red: 1.00, green: 0.24, blue: 0.36)
        case "high":
            return Color(red: 1.00, green: 0.58, blue: 0.18)
        case "medium":
            return Color(red: 0.18, green: 0.56, blue: 1.00)
        case "low":
            return Color(red: 0.42, green: 0.78, blue: 0.67)
        default:
            return .secondary
        }
    }
    
    func hasUrgentCrewTask(on day: Int) -> Bool {
        crewTasks(for: day).contains { $0.priority == "urgent" }
    }
    
    func premiumCardFill(_ priority: String, active: Bool, soon: Bool) -> LinearGradient {
        let tint = premiumPriorityColor(priority)
        
        return LinearGradient(
            colors: [
                tint.opacity(priority == "urgent" ? 0.16 : (active ? 0.12 : 0.08)),
                Color.white.opacity(active ? 0.07 : 0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    func premiumBorderColor(_ priority: String, active: Bool, soon: Bool) -> Color {
        let tint = premiumPriorityColor(priority)
        
        if priority == "urgent" {
            return tint.opacity(active ? 0.65 : 0.42)
        }
        
        if active {
            return tint.opacity(0.50)
        }
        
        if soon {
            return tint.opacity(0.30)
        }
        
        return tint.opacity(0.18)
    }
    
    func premiumGlowColor(_ priority: String, active: Bool, soon: Bool) -> Color {
        let tint = premiumPriorityColor(priority)
        
        if priority == "urgent" {
            return tint.opacity(active ? 0.35 : 0.22)
        }
        
        if active {
            return tint.opacity(0.20)
        }
        
        if soon {
            return tint.opacity(0.10)
        }
        
        return .clear
    }
    
    func premiumPriorityBadge(_ priority: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            if priority == "urgent" {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.bold))
            }
            
            Text(priorityTitle(priority))
                .font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(tint.opacity(0.16))
        )
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.28), lineWidth: 1)
        )
        .foregroundStyle(tint)
    }
    
    func premiumMetaPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
        )
        .foregroundStyle(tint)
    }
    
    func crewTimelineTaskCard(_ task: CrewTask, isLast: Bool) -> some View {
        let crew = allCrews.first { $0.id == task.crewID }
        let active = isTaskActive(task)
        let soon = isTaskStartingSoon(task)
        
        let tint = premiumPriorityColor(task.priority)
        let cardFill = premiumCardFill(task.priority, active: active, soon: soon)
        let border = premiumBorderColor(task.priority, active: active, soon: soon)
        let glow = premiumGlowColor(task.priority, active: active, soon: soon)
        
        return HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(tint)
                    .frame(
                        width: active ? 16 : (soon ? 13 : 11),
                        height: active ? 16 : (soon ? 13 : 11)
                    )
                    .shadow(color: glow, radius: active ? 14 : (soon ? 8 : 0))
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(active ? 0.30 : 0.10), lineWidth: 1)
                    )
                    .scaleEffect(active ? 1.15 : (soon ? 1.06 : 1.0))
                
                if !isLast {
                    LinearGradient(
                        colors: [
                            tint.opacity(active ? 0.55 : 0.22),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 6)
                }
            }
            .frame(width: 18)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    if let start = task.scheduledStartMinute {
                        HStack(spacing: 5) {
                            Image(systemName: "clock")
                            Text(hm(start))
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(active ? tint : .secondary)
                    }
                    
                    Spacer()
                    
                    premiumPriorityBadge(task.priority, tint: tint)
                }
                
                Text(task.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                if let crew {
                    HStack(spacing: 6) {
                        Image(systemName: "person.3.fill")
                        Text(crew.name)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 10) {
                    premiumMetaPill(
                        icon: "flag.fill",
                        text: statusTitle(task.status),
                        tint: .secondary
                    )
                    
                    if !task.assignedTo.isEmpty {
                        premiumMetaPill(
                            icon: "person.fill",
                            text: task.assignedTo,
                            tint: tint.opacity(0.95)
                        )
                    }
                }
                
                if active {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        
                        Text("Active now")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                } else if soon {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 6, height: 6)
                        
                        Text("Starting soon")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(border, lineWidth: active ? 1.2 : 1)
            )
            .shadow(color: glow, radius: active ? 18 : (soon ? 10 : 0))
            .scaleEffect(active ? 1.015 : 1.0)
        }
        .animation(.spring(duration: 0.28), value: active)
        .animation(.easeInOut(duration: 0.25), value: soon)
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
                    LazyVStack(spacing: 0) {
                        ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                            Button {
                                if let crew = crewMap[task.crewID] {
                                    selectedCrewTask = task
                                    selectedCrewForDetail = crew
                                    Haptics.impact(.light)
                                }
                            } label: {
                                enhancedPremiumTimelineCard(task, isLast: index == tasks.count - 1)
                            }
                            .buttonStyle(.plain)
                            .offset(y: showCrewTaskCards ? 0 : CGFloat(18 + (index * 8)))
                            .opacity(showCrewTaskCards ? 1 : 0)
                            .scaleEffect(showCrewTaskCards ? 1 : 0.985)
                            .animation(
                                .spring(response: 0.48, dampingFraction: 0.88)
                                    .delay(Double(index) * 0.06),
                                value: showCrewTaskCards
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
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    toggleCrewTaskDone(task)
                                } label: {
                                    Label(task.isDone ? "Undo" : "Done", systemImage: task.isDone ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                                }
                                .tint(task.isDone ? .orange : .green)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteCrewTask(task)
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }

                                Button {
                                    toggleCrewTaskDone(task)
                                } label: {
                                    Label(task.isDone ? "Undo" : "Done", systemImage: task.isDone ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                                }
                                .tint(task.isDone ? .orange : .green)
                            }
                            .contextMenu {
                                Button {
                                    toggleCrewTaskDone(task)
                                } label: {
                                    Label(task.isDone ? "Mark as Undone" : "Mark as Done", systemImage: task.isDone ? "arrow.uturn.backward.circle" : "checkmark.circle")
                                }

                                Button(role: .destructive) {
                                    deleteCrewTask(task)
                                } label: {
                                    Label("Delete Task", systemImage: "trash")
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
            .textCase(nil)
            .offset(y: showCrewTaskHeader ? 0 : 14)
            .opacity(showCrewTaskHeader ? 1 : 0)
        }
    }
    
    func shortDateTextForDay(_ day: Int) -> String {
        let calendar = Calendar.current
        let today = Date()
        
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let targetDate = calendar.date(byAdding: .day, value: day, to: startOfWeek) else {
            return ""
        }
        
        return targetDate.formatted(date: .abbreviated, time: .omitted)
    }
    
    func priorityColor(_ value: String) -> Color {
        switch value {
        case "urgent":
            return .red
        case "high":
            return .orange
        case "medium":
            return .blue
        case "low":
            return .gray
        default:
            return .secondary
        }
    }
    
    func isTaskActive(_ task: CrewTask) -> Bool {
        guard task.scheduledWeekday == weekdayIndexToday() else { return false }
        
        let now = currentMinuteOfDay()
        guard let start = task.scheduledStartMinute,
              let duration = task.scheduledDurationMinute else { return false }
        
        let end = start + duration
        return now >= start && now < end
    }
    
    func isTaskStartingSoon(_ task: CrewTask) -> Bool {
        guard task.scheduledWeekday == weekdayIndexToday() else { return false }
        
        let now = currentMinuteOfDay()
        guard let start = task.scheduledStartMinute else { return false }
        
        let diff = start - now
        return diff >= 0 && diff <= 30
    }
    
    
    
    func crewForTask(_ task: CrewTask) -> Crew? {
        allCrews.first { $0.id == task.crewID }
    }
    
    func crewWeekTaskRow(_ task: CrewTask) -> some View {
        let crew = crewForTask(task)
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(priorityColor(task.priority).opacity(0.18))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: task.isDone ? "checkmark.circle.fill" : "person.3.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(task.isDone ? .green : priorityColor(task.priority))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(task.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        
                        Text(priorityTitle(task.priority))
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(priorityColor(task.priority).opacity(0.12))
                            )
                            .foregroundStyle(priorityColor(task.priority))
                    }
                    
                    if let crew {
                        Text(crew.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 10) {
                        if let start = task.scheduledStartMinute {
                            Label(hm(start), systemImage: "clock")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        if !task.assignedTo.isEmpty {
                            Label(task.assignedTo, systemImage: "person.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        Label(statusTitle(task.status), systemImage: "flag.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
    
    var summarySection: some View {
        Section {
            daySummaryCard
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    var emptySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                
                Text("\(dayTitles[selectedDay]) günü boş")
                    .font(.headline)
                
                Spacer()
            }
            
            Text("Bu güne henüz ders eklenmemiş. Sağ üstteki + ile hızlıca yeni ders oluşturabilirsin.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button {
                Haptics.impact(.medium)
                showingAdd = true
            } label: {
                Label("Ders ekle", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.accentColor.opacity(0.16)))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sectionCardBackground)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 12, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    var eventsSection: some View {
        Section {
            let now = currentMinuteOfDay()
            
            ForEach(eventsForDay) { ev in
                AnyView(
                    EventRow(
                        event: ev,
                        timeText: timeText(for: ev),
                        hasConflict: hasConflict(ev),
                        nowMinute: now,
                        isTodaySelected: isTodaySelected,
                        onTap: { editingEvent = ev },
                        onEdit: { editingEvent = ev },
                        onDelete: { delete(ev) }
                    )
                    .id(ev.id)
                )
            }
        }
    }
    
    var daySummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(dayTitles[selectedDay])
                            .font(.headline)
                        
                        if isTodaySelected {
                            Text("Bugün")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.accentColor.opacity(0.18))
                                )
                                .foregroundStyle(Color.accentColor)
                        }
                        
                        if liveEventForDay != nil {
                            Text("LIVE")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.green.opacity(0.18)))
                                .foregroundStyle(.green)
                                .scaleEffect(animateSummary ? 1.03 : 1.0)
                                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: animateSummary)
                        }
                    }
                    
                    Text(summarySubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if totalMinutesForDay > 0 {
                    Text(durationText(totalMinutesForDay))
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }
            }
            
            HStack(spacing: 10) {
                summaryChip(
                    title: "Ders",
                    value: "\(eventsForDay.count)",
                    icon: "book.closed.fill"
                )
                
                summaryChip(
                    title: "İlk",
                    value: firstEventOfDay.map { hm($0.startMinute) } ?? "--:--",
                    icon: "sunrise.fill"
                )
                
                summaryChip(
                    title: "Son",
                    value: lastEventOfDay.map { hm($0.startMinute + $0.durationMinute) } ?? "--:--",
                    icon: "moon.stars.fill"
                )
            }
            
            if let live = liveEventForDay {
                HStack(spacing: 8) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundStyle(.green)
                    
                    Text("\(live.title) şu an devam ediyor")
                        .font(.caption.weight(.semibold))
                    
                    Spacer()
                    
                    Text(timeText(for: live))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.12))
                )
            }
            
            if let indicator = currentTimeIndicatorText {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animateSummary ? 1.15 : 0.9)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: animateSummary)
                    
                    Text(indicator)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.10))
                )
            }
        }
        .padding(18)
        .background(sectionCardBackground)
        .scaleEffect(animateSummary ? 1.01 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: animateSummary)
    }
    
    func summaryChip(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Button {
                    Haptics.impact(.light)
                    shareDay()
                } label: {
                    Label("Bu günü paylaş", systemImage: "square.and.arrow.up")
                }
                
                Button {
                    Haptics.impact(.light)
                    shareWeek()
                } label: {
                    Label("Tüm haftayı paylaş", systemImage: "calendar")
                }
                
                Button {
                    UIPasteboard.general.string = shareTextForSelectedDay()
                    Haptics.notify(.success)
                    showCopiedToast()
                } label: {
                    Label("Kopyala", systemImage: "doc.on.doc")
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            
            Button {
                Haptics.impact(.medium)
                showingAdd = true
            } label: {
                Image(systemName: "plus")
            }
        }
    }
    
    var toastView: some View {
        Group {
            if showCopied {
                Text("Kopyalandı")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 30)
            }
        }
    }
    
    var sectionCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
    
    var summarySubtitle: String {
        if eventsForDay.isEmpty {
            return "Bu gün için kayıtlı ders yok"
        }
        
        if liveEventForDay != nil {
            return "Ders şu an aktif"
        }
        
        return "\(eventsForDay.count) ders • \(durationText(totalMinutesForDay)) toplam"
    }
    
    func animateSummaryCard() {
        animateSummary = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            animateSummary = false
        }
    }
}
    
    
    
    // MARK: - Lifecycle
    private extension WeekView {
        
        func onAppear(proxy: ScrollViewProxy) {
            if !didSetInitialDay {
                didSetInitialDay = true
                selectedDay = weekdayIndexToday()
            }
            
            if !didInitialAutoScroll {
                didInitialAutoScroll = true
                autoScrollIfNeeded(proxy: proxy)
            }
            
            animateSummary = true
            pulseTodayDot = true
            showCrewTaskHeader = weekMode == .crew
            showCrewTaskCards = weekMode == .crew
            
            if weekMode == .crew {
                showCrewEntrance = true
            }
            
            Task {
                await NotificationManager.shared.rescheduleAll(events: allEvents)
            }
        }
        
        func onDayChanged(proxy: ScrollViewProxy) {
            lastAutoScrollTargetID = nil
            animateSummaryCard()
            autoScrollIfNeeded(proxy: proxy)
        }
    }
    
    
    // MARK: - Logic
    private extension WeekView {
        
        func delete(_ ev: EventItem) {
            context.delete(ev)
            try? context.save()
            WidgetAppSync.refreshFromSwiftData(context: context)
            
            Task {
                await NotificationManager.shared.rescheduleAll(events: allEvents.filter { $0.id != ev.id })
            }
        }
        
        func timeText(for ev: EventItem) -> String {
            let start = ev.startMinute
            let end = ev.startMinute + ev.durationMinute
            return "\(hm(start)) – \(hm(end))"
        }
        
        func hm(_ minute: Int) -> String {
            let m = max(0, min(1439, minute))
            let h = m / 60
            let mm = m % 60
            return String(format: "%02d:%02d", h, mm)
        }
        
        func durationText(_ minutes: Int) -> String {
            let h = minutes / 60
            let m = minutes % 60
            
            if h == 0 { return "\(m)dk" }
            if m == 0 { return "\(h)s" }
            return "\(h)s \(m)dk"
        }
        
        
        func weekdayIndexToday() -> Int {
            let w = Calendar.current.component(.weekday, from: Date())
            return (w + 5) % 7
        }
        
        func hasConflict(_ ev: EventItem) -> Bool {
            for other in eventsForDay {
                if other.id == ev.id { continue }
                if overlaps(ev, other) { return true }
            }
            return false
        }
        
        func overlaps(_ a: EventItem, _ b: EventItem) -> Bool {
            let aStart = a.startMinute
            let aEnd = a.startMinute + a.durationMinute
            let bStart = b.startMinute
            let bEnd = b.startMinute + b.durationMinute
            return max(aStart, bStart) < min(aEnd, bEnd)
        }
        
        func autoScrollTarget(now: Int) -> EventItem? {
            guard !eventsForDay.isEmpty else { return nil }
            
            if selectedDay == weekdayIndexToday() {
                if let live = eventsForDay.first(where: { ev in
                    let s = ev.startMinute
                    let e = ev.startMinute + ev.durationMinute
                    return now >= s && now < e
                }) {
                    return live
                }
                
                if let next = eventsForDay.first(where: { $0.startMinute > now }) {
                    return next
                }
            }
            
            return eventsForDay.first
        }
        
        func autoScrollIfNeeded(proxy: ScrollViewProxy) {
            let now = currentMinuteOfDay()
            guard let target = autoScrollTarget(now: now) else { return }
            
            if lastAutoScrollTargetID == target.id { return }
            lastAutoScrollTargetID = target.id
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(target.id, anchor: .center)
                }
            }
        }
    }

    
    // MARK: - Share
    private extension WeekView {
        
        
        
        
        func shareDay() { presentShare(text: shareTextForSelectedDay()) }
        
        func shareWeek() {
            let parts: [String] = (0..<7).map { day in shareTextForDay(day) }
            presentShare(text: parts.joined(separator: "\n\n"))
        }
        
        func presentShare(text: String) {
            let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                root.present(vc, animated: true)
            }
        }
        
        func shareTextForSelectedDay() -> String { shareTextForDay(selectedDay) }
        
        
        
        func priorityTitle(_ value: String) -> String {
            switch value {
            case "low": return "Low"
            case "medium": return "Medium"
            case "high": return "High"
            case "urgent": return "Urgent"
            default: return value.capitalized
            }
        }
        
        func statusTitle(_ value: String) -> String {
            switch value {
            case "todo": return "Todo"
            case "inProgress": return "In Progress"
            case "review": return "Review"
            case "done": return "Done"
            default: return value.capitalized
            }
        }
        
        
        func shareTextForDay(_ day: Int) -> String {
            let d = max(0, min(6, day))
            let dayName = dayTitles[d]
            
            let items = allEvents
                .filter { $0.weekday == d }
                .sorted { $0.startMinute < $1.startMinute }
            
            if items.isEmpty { return "📅 \(dayName) — Ders yok" }
            
            let lines = items.map { ev in
                let start = hm(ev.startMinute)
                let end = hm(ev.startMinute + ev.durationMinute)
                let loc = (ev.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let locText = loc.isEmpty ? "" : " • \(loc)"
                return "• \(start)–\(end)  \(ev.title)\(locText)"
            }
            
            return """
        📅 \(dayName) Programım
        
        \(lines.joined(separator: "\n"))
        
        (DailyTodo ile oluşturuldu)
        """
        }
        
        func showCopiedToast() {
            withAnimation { showCopied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation { showCopied = false }
            }
        }
    }

    
    // MARK: - Row
    private struct EventRow: View {
        
        @State private var pulse: Bool = false
        @State private var glowPhase: Bool = false
        
        let event: EventItem
        let timeText: String
        let hasConflict: Bool
        let nowMinute: Int
        let isTodaySelected: Bool
        
        let onTap: () -> Void
        let onEdit: () -> Void
        let onDelete: () -> Void
        
        private var start: Int { event.startMinute }
        private var end: Int { event.startMinute + event.durationMinute }
        private var duration: Int { max(1, event.durationMinute) }
        
        private var isLive: Bool {
            guard isTodaySelected else { return false }
            return nowMinute >= start && nowMinute < end
        }
        
        private var isUpNext: Bool {
            guard isTodaySelected else { return false }
            return nowMinute < start && (start - nowMinute) <= 15
        }
        
        private var isSoon: Bool {
            guard isTodaySelected else { return false }
            let diff = start - nowMinute
            return diff > 0 && diff <= 5
        }
        
        private var isDone: Bool {
            guard isTodaySelected else { return false }
            return nowMinute >= end
        }
        
        private var progress: Double {
            guard isLive else { return 0 }
            return min(1, max(0, Double(nowMinute - start) / Double(duration)))
        }
        
        private var minutesLeft: Int { max(0, end - nowMinute) }
        private var minutesUntilStart: Int { max(0, start - nowMinute) }
        
        private func hm(_ minute: Int) -> String {
            let m = max(0, min(1439, minute))
            let h = m / 60
            let mm = m % 60
            return String(format: "%02d:%02d", h, mm)
        }
        
        var body: some View {
            
            let baseColor = hexColor(event.colorHex)
            
            let accent: Color = {
                if isDone { return Color.secondary.opacity(0.55) }
                if isSoon { return .orange }
                return baseColor
            }()
            
            let bg: Color = {
                if isDone { return Color.secondary.opacity(0.06) }
                return accent.opacity(isLive ? 0.16 : (isUpNext ? 0.13 : 0.10))
            }()
            
            let strokeColor: Color = {
                if hasConflict { return .red.opacity(0.40) }
                if isDone { return .secondary.opacity(0.14) }
                if isLive { return accent.opacity(glowPhase ? 0.75 : 0.45) }
                if isSoon { return .orange.opacity(0.70) }
                if isUpNext { return accent.opacity(0.35) }
                return .secondary.opacity(0.10)
            }()
            
            let strokeWidth: CGFloat =
            hasConflict ? 1.6 :
            (isLive ? 2.2 :
                (isSoon ? 2.0 :
                    (isUpNext ? 1.4 : 1.0)))
            
            let mainTextOpacity: Double = isDone ? 0.55 : 1.0
            let secondaryTextOpacity: Double = isDone ? 0.55 : 1.0
            
            HStack(spacing: 12) {
                
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(1.0), accent.opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: isLive ? 10 : 8)
                    .shadow(color: isLive ? accent.opacity(0.55) : .clear, radius: isLive ? 14 : 6)
                    .padding(.vertical, 10)
                    .opacity(isDone ? 0.75 : 1.0)
                
                VStack(alignment: .leading, spacing: 10) {
                    
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(event.title)
                            .font(.headline)
                            .lineLimit(1)
                            .opacity(mainTextOpacity)
                        
                        if isLive {
                            Text("Şu an")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(accent.opacity(0.25)))
                                .overlay(Capsule().stroke(accent.opacity(0.45), lineWidth: 1))
                        } else if isSoon {
                            Text("5 dk kaldı")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.orange.opacity(0.22)))
                                .overlay(Capsule().stroke(Color.orange.opacity(0.55), lineWidth: 1))
                        } else if isDone {
                            Text("Bitti")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.secondary.opacity(0.12)))
                                .overlay(Capsule().stroke(Color.secondary.opacity(0.18), lineWidth: 1))
                                .opacity(0.9)
                        }
                        
                        Spacer()
                        
                        if hasConflict {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                                .accessibilityLabel("Çakışma var")
                        }
                        
                        Text(timeText)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(isDone ? Color.secondary.opacity(0.10) : accent.opacity(isLive ? 0.25 : 0.18)))
                            .overlay(Capsule().stroke(isDone ? Color.secondary.opacity(0.16) : accent.opacity(isLive ? 0.40 : 0.25), lineWidth: 1))
                            .opacity(secondaryTextOpacity)
                    }
                    
                    HStack(spacing: 8) {
                        if let loc = event.location,
                           !loc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Label(loc, systemImage: "mappin.and.ellipse")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.secondary.opacity(0.10)))
                                .opacity(secondaryTextOpacity)
                        }
                        
                        Spacer()
                        
                        Text("\(max(15, event.durationMinute)) dk")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .opacity(secondaryTextOpacity)
                    }
                    
                    if isLive {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: progress)
                                .tint(baseColor)
                                .animation(.smooth, value: progress)
                            
                            HStack(spacing: 8) {
                                Image(systemName: "hourglass")
                                    .font(.caption2)
                                    .foregroundStyle(baseColor)
                                
                                Text("%\(Int(progress * 100)) tamamlandı")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Text("\(minutesLeft) dk kaldı")
                                    .font(.caption2.weight(.semibold))
                                
                                Text("• bitiyor: \(hm(end))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    if isUpNext {
                        HStack(spacing: 8) {
                            Text("\(minutesUntilStart) dk")
                                .font(.caption2.weight(.bold))
                                .monospacedDigit()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill((isDone ? Color.secondary.opacity(0.10) : accent.opacity(0.18))))
                                .overlay(Capsule().stroke((isDone ? Color.secondary.opacity(0.16) : accent.opacity(0.28)), lineWidth: 1))
                                .opacity(secondaryTextOpacity)
                            
                            Text("sonra (\(hm(start))) başlıyor")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .opacity(secondaryTextOpacity)
                            
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(bg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isLive ? 0.16 : 0.10),
                                        Color.white.opacity(0.00)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
            .shadow(color: isLive ? baseColor.opacity(glowPhase ? 0.42 : 0.22) : .clear, radius: isLive ? 18 : 0)
            .shadow(color: isSoon ? Color.orange.opacity(0.30) : .clear, radius: isSoon ? 10 : 0)
            .shadow(radius: isLive ? 8 : 0)
            .scaleEffect(isLive && pulse ? 1.012 : 1.0)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: glowPhase)
            .onAppear {
                pulse = isLive
                glowPhase = isLive
            }
            .onChange(of: isLive) { _, newValue in
                pulse = newValue
                glowPhase = newValue
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.impact(.light)
                onTap()
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    Haptics.impact(.light)
                    onEdit()
                } label: {
                    Label("Düzenle", systemImage: "pencil")
                }
                .tint(.blue)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    Haptics.impact(.heavy)
                    onDelete()
                } label: {
                    Label("Sil", systemImage: "trash")
                }
            }
        }
    }

