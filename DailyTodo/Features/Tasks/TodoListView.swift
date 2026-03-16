//
//  TodoListView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 5.03.2026.
//

import SwiftUI
import SwiftData
import UIKit
import Combine

struct TodoListView: View {
    @Binding var selectedTab: AppTab
    @EnvironmentObject private var store: TodoStore

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    @Query(sort: \EventItem.startMinute, order: .forward)
    private var allEvents: [EventItem]

    @Query(sort: \Crew.createdAt, order: .reverse)
    private var crews: [Crew]

    @Query private var members: [CrewMember]
    @Query private var crewTasks: [CrewTask]

    @Query(sort: \CrewActivity.createdAt, order: .reverse)
    private var activities: [CrewActivity]

    enum HomeSection: String, CaseIterable, Identifiable {
        case personal = "Personal"
        case crew = "Crew"
        var id: String { rawValue }
    }

    enum NextClassStatus {
        case live
        case next
    }
    @State private var showLeaderboardPodium = false
    @State private var previousTopCrewID: UUID?
    @State private var showingAdd: Bool = false
    @State private var homeSection: HomeSection = .personal
    @State private var showMessages = false
    @Query private var friendMessages: [FriendMessage]
    @Query private var crewMessages: [CrewMessage]

    private let chipTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var now = Date()
    
    private var unreadCount: Int {
        let friendUnread = friendMessages.filter { !$0.isRead }.count
        let crewUnread = crewMessages.filter { !$0.isRead }.count
        return friendUnread + crewUnread
    }

    private var items: [DTTaskItem] { store.items }

    private var nextClassInfo: (title: String, timeText: String, status: NextClassStatus)? {
        let today = weekdayIndexToday()
        let nowMinute = currentMinuteOfDay()

        let todayEvents = allEvents
            .filter { $0.weekday == today }
            .sorted { $0.startMinute < $1.startMinute }

        if let live = todayEvents.first(where: {
            nowMinute >= $0.startMinute &&
            nowMinute < ($0.startMinute + $0.durationMinute)
        }) {
            let endMinute = live.startMinute + live.durationMinute
            let remain = max(0, endMinute - nowMinute)
            return (live.title, "\(remain) dk", .live)
        }

        if let next = todayEvents.first(where: { $0.startMinute > nowMinute }) {
            let remain = max(0, next.startMinute - nowMinute)
            return (next.title, "\(remain) dk", .next)
        }

        return nil
    }

    var body: some View {
        ZStack {
            tasksAmbientBackground

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Color.clear.frame(height: 76)

                    tasksHeader
                    topSegment

                    if homeSection == .personal {
                        HomeDashboardView(
                            onAddTask: {
                                showingAdd = true
                                haptic(.medium)
                            },
                            onOpenWeek: {
                                selectedTab = .week
                            },
                            onOpenInsights: {
                                selectedTab = .insights
                            }
                        )
                        .environmentObject(store)

                    } else {
                        crewOverviewCard
                        crewListCard
                        crewActivityCard
                        socialQuickActionsCard
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingAdd) {
            AddTaskView()
                .environmentObject(store)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showMessages) {
            MessagesView()
        }
        .onReceive(chipTimer) { value in
            now = value
        }
        .onAppear {
            previousTopCrewID = crews
                .sorted { $0.totalFocusMinutes > $1.totalFocusMinutes }
                .first?.id

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    showLeaderboardPodium = true
                }
            }
        }
        .onChange(of: crews.map { "\($0.id.uuidString)-\($0.totalFocusMinutes)" }) { _, _ in
            let newTopCrewID = crews
                .sorted { $0.totalFocusMinutes > $1.totalFocusMinutes }
                .first?.id

            if let previousTopCrewID, let newTopCrewID, previousTopCrewID != newTopCrewID {
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.prepare()
                gen.impactOccurred()
            }

            self.previousTopCrewID = newTopCrewID
        }
    }

    private var todayTasks: [DTTaskItem] {
        let calendar = Calendar.current

        return items
            .filter { !$0.isDone }
            .filter { item in
                guard let dueDate = item.dueDate else { return false }
                return calendar.isDate(dueDate, inSameDayAs: Date())
            }
            .sorted {
                ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
    }

    private var tasksAmbientBackground: some View {
        AppBackground()
    }

    private var topSegment: some View {
        HStack(spacing: 8) {
            ForEach(HomeSection.allCases) { section in
                let isSelected = homeSection == section

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        homeSection = section
                    }
                } label: {
                    Text(section.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? palette.primaryText : palette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    isSelected
                                    ? Color.accentColor.opacity(appTheme == AppTheme.light.rawValue ? 0.14 : 0.18)
                                    : palette.secondaryCardFill
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    isSelected
                                    ? Color.accentColor.opacity(appTheme == AppTheme.light.rawValue ? 0.22 : 0.30)
                                    : palette.cardStroke.opacity(0.8),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    private var tasksHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Home")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Spacer()

            Button {
                showMessages = true
                haptic(.light)
            } label: {

                ZStack(alignment: .topTrailing) {

                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(palette.primaryText)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(palette.cardFill)
                                .overlay(
                                    Circle()
                                        .stroke(palette.cardStroke, lineWidth: 1)
                                )
                        )

                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .buttonStyle(.plain)

            if homeSection == .personal, let next = nextClassInfo {
                Button {
                    withAnimation(.easeInOut) {
                        selectedTab = .week
                    }
                    haptic(.light)
                } label: {
                    LiveBadgeView(
                        next: next,
                        palette: palette,
                        appTheme: appTheme
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private var crewOverviewCard: some View {
        let totalCrews = crews.count
        let totalMembers = members.count
        let totalTasks = crewTasks.count
        let completedTasks = crewTasks.filter(\.isDone).count

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Overview")
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)

                    Text("Your team productivity at a glance")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()

                Image(systemName: "person.3.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }

            HStack(spacing: 10) {
                previewStatCard(value: "\(totalCrews)", title: "Crews")
                previewStatCard(value: "\(totalMembers)", title: "Members")
                previewStatCard(value: "\(completedTasks)/\(totalTasks)", title: "Tasks")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var crewListCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Top Crews")
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)
                
                Text("Ranked by focus time")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                
                Spacer()
                
                Button {
                    selectedTab = .crew
                    haptic(.light)
                } label: {
                    Text("Open")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.14))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            if !crews.isEmpty {
                leaderboardPodium
            }
            
            if crews.isEmpty {
                Text("No crew yet")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            } else {
                let sortedCrews = crews.sorted { $0.totalFocusMinutes > $1.totalFocusMinutes }
                let remainingCrews = Array(sortedCrews.dropFirst(min(3, sortedCrews.count)))
                
                if !remainingCrews.isEmpty {
                    ForEach(remainingCrews) { crew in
                        let crewMembers = members.filter { $0.crewID == crew.id }
                        let tasksForCrew = crewTasks.filter { $0.crewID == crew.id }
                        let completed = tasksForCrew.filter(\.isDone).count
                        let progress = tasksForCrew.isEmpty ? 0 : Double(completed) / Double(tasksForCrew.count)
                        
                        HStack(spacing: 12) {
                            rankBadge(for: crew)
                            
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(hexColor(crew.colorHex).opacity(0.18))
                                    .frame(width: 52, height: 52)
                                
                                Image(systemName: crew.icon)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(hexColor(crew.colorHex))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(crew.name)
                                    .font(.headline)
                                    .foregroundStyle(palette.primaryText)
                                
                                Text("\(crewMembers.count) members • \(tasksForCrew.count) tasks")
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryText)
                                
                                Text("\(crew.totalFocusMinutes / 60)h \(crew.totalFocusMinutes % 60)m focus")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(rankColor(for: crew) == .clear ? palette.secondaryText : rankColor(for: crew))
                                
                                ProgressView(value: progress)
                                    .tint(hexColor(crew.colorHex))
                                    .scaleEffect(y: 1.4)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 6) {
                                Text("\(Int(progress * 100))%")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(palette.secondaryText)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "flame.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                    
                                    Text("\(crew.currentStreak)")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(palette.primaryText)
                                }
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(palette.secondaryCardFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(
                                            rankColor(for: crew) == .clear
                                            ? palette.cardStroke.opacity(0.7)
                                            : rankColor(for: crew).opacity(0.24),
                                            lineWidth: 1
                                        )
                                )
                        )
                        .shadow(
                            color: rankColor(for: crew).opacity(0.14),
                            radius: 10,
                            y: 4
                        )
                    }
                }
            }
        }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
        }
    
    
    private var leaderboardPodium: some View {
        let ranked = crews.sorted { $0.totalFocusMinutes > $1.totalFocusMinutes }

        if ranked.count == 1, let first = ranked.first {
            return AnyView(singleChampionCard(for: first))
        }

        let first = ranked.indices.contains(0) ? ranked[0] : nil
        let second = ranked.indices.contains(1) ? ranked[1] : nil
        let third = ranked.indices.contains(2) ? ranked[2] : nil

        return AnyView(
            HStack(alignment: .bottom, spacing: 10) {
                if let second {
                    podiumItem(
                        crew: second,
                        rank: 2,
                        height: 92,
                        color: .gray
                    )
                    .offset(y: showLeaderboardPodium ? 0 : 18)
                    .opacity(showLeaderboardPodium ? 1 : 0)
                    .scaleEffect(showLeaderboardPodium ? 1 : 0.96)
                } else {
                    Spacer()
                }

                if let first {
                    podiumItem(
                        crew: first,
                        rank: 1,
                        height: 122,
                        color: .yellow
                    )
                    .offset(y: showLeaderboardPodium ? 0 : 22)
                    .opacity(showLeaderboardPodium ? 1 : 0)
                    .scaleEffect(showLeaderboardPodium ? 1 : 0.94)
                } else {
                    Spacer()
                }

                if let third {
                    podiumItem(
                        crew: third,
                        rank: 3,
                        height: 78,
                        color: .orange
                    )
                    .offset(y: showLeaderboardPodium ? 0 : 18)
                    .opacity(showLeaderboardPodium ? 1 : 0)
                    .scaleEffect(showLeaderboardPodium ? 1 : 0.96)
                } else {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
        )
    }
    
    private func singleChampionCard(for crew: Crew) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.16))
                    .frame(width: 72, height: 72)
                    .shadow(color: Color.yellow.opacity(0.22), radius: 14)

                Image(systemName: crew.icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.yellow)

                Image(systemName: "crown.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.yellow)
                    .offset(y: -42)
                    .shadow(color: Color.yellow.opacity(0.35), radius: 8)
            }

            Text(crew.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.primaryText)

            Text("\(crew.totalFocusMinutes / 60)h \(crew.totalFocusMinutes % 60)m focus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)

            HStack(spacing: 8) {
                Label("Champion", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.yellow.opacity(0.14))
                    )

                if crew.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)

                        Text("\(crew.currentStreak)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.primaryText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.12))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(palette.secondaryCardFill)

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.yellow.opacity(0.24), lineWidth: 1)

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.yellow.opacity(0.16),
                                Color.clear
                            ],
                            center: .top,
                            startRadius: 10,
                            endRadius: 180
                        )
                    )
                    .blur(radius: 18)
            }
        )
        .shadow(color: Color.yellow.opacity(0.14), radius: 12, y: 6)
        .offset(y: showLeaderboardPodium ? 0 : 18)
        .opacity(showLeaderboardPodium ? 1 : 0)
        .scaleEffect(showLeaderboardPodium ? 1 : 0.96)
    }
    
    private func podiumItem(
        crew: Crew,
        rank: Int,
        height: CGFloat,
        color: Color
    ) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.16))
                    .frame(width: rank == 1 ? 56 : 48, height: rank == 1 ? 56 : 48)
                    .shadow(color: color.opacity(rank == 1 ? 0.22 : 0.12), radius: 10)

                Image(systemName: crew.icon)
                    .font(.system(size: rank == 1 ? 20 : 17, weight: .bold))
                    .foregroundStyle(color)

                if rank == 1 {
                    Image(systemName: "crown.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.yellow)
                        .offset(y: -34)
                        .shadow(color: Color.yellow.opacity(0.35), radius: 8)
                }
            }

            Text(crew.name)
                .font(rank == 1 ? .subheadline.weight(.bold) : .caption.weight(.bold))
                .foregroundStyle(palette.primaryText)
                .lineLimit(1)

            Text("\(crew.totalFocusMinutes / 60)h")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.secondaryText)

            VStack(spacing: 0) {
                if rank == 1 {
                    Text("TOP")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.yellow.opacity(0.14))
                        )
                        .padding(.top, 8)
                }
                Text("#\(rank)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                    .padding(.top, 10)

                Spacer()

                if crew.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)

                        Text("\(crew.currentStreak)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(palette.primaryText)
                    }
                    .padding(.bottom, 10)
                }
            }
            .frame(width: 94, height: height)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(palette.secondaryCardFill)

                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(color.opacity(0.24), lineWidth: 1)

                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    color.opacity(rank == 1 ? 0.18 : 0.10),
                                    Color.clear
                                ],
                                center: .top,
                                startRadius: 10,
                                endRadius: 120
                            )
                        )
                        .blur(radius: 14)
                }
            )
            .shadow(color: color.opacity(rank == 1 ? 0.22 : 0.08), radius: rank == 1 ? 16 : 12, y: 6)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func rankColor(for crew: Crew) -> Color {
        let sorted = crews.sorted { $0.totalFocusMinutes > $1.totalFocusMinutes }
        let rank = (sorted.firstIndex(where: { $0.id == crew.id }) ?? 999) + 1

        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .clear
        }
    }

    private var crewActivityCard: some View {
        let topActivities = Array(activities.prefix(3))

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Activity")
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Text("Recent updates")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }

            if topActivities.isEmpty {
                Text("No activity yet")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            } else {
                ForEach(topActivities) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.16))
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: "bolt.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.accentColor)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.memberName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryText)

                            Text(item.actionText)
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                                .lineLimit(2)

                            Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryText.opacity(0.8))
                        }

                        Spacer()
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var socialQuickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            Button {
                selectedTab = .crew
                haptic(.medium)
            } label: {
                socialActionRow(title: "Open Crew", icon: "person.3.fill")
            }
            .buttonStyle(.plain)

            Button {
                selectedTab = .week
                haptic(.light)
            } label: {
                socialActionRow(title: "Go to Week", icon: "calendar")
            }
            .buttonStyle(.plain)

            Button {
                selectedTab = .insights
                haptic(.light)
            } label: {
                socialActionRow(title: "Open Insights", icon: "chart.bar.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private func previewStatCard(value: String, title: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(palette.primaryText)

            Text(title)
                .font(.caption)
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.secondaryCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardStroke.opacity(0.7), lineWidth: 1)
                )
        )
    }
    
    private func rankBadge(for crew: Crew) -> some View {
        let sorted = crews.sorted { $0.totalFocusMinutes > $1.totalFocusMinutes }
        let rank = (sorted.firstIndex(where: { $0.id == crew.id }) ?? 999) + 1

        let color: Color = {
            switch rank {
            case 1: return .yellow
            case 2: return .gray
            case 3: return .orange
            default: return .secondary
            }
        }()

        return ZStack {
            Circle()
                .fill(color.opacity(0.16))
                .frame(width: 34, height: 34)

            Text("\(rank)")
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
        }
    }

    private func socialActionRow(title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 26)
                .foregroundStyle(palette.primaryText)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.primaryText)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.secondaryCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardStroke.opacity(0.7), lineWidth: 1)
                )
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            EmptyView()
        }

        ToolbarItem(placement: .topBarTrailing) {
            EmptyView()
        }
    }

    private func currentMinuteOfDay() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private func weekdayIndexToday() -> Int {
        let w = Calendar.current.component(.weekday, from: now)
        return (w + 5) % 7
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
    }

    private struct LiveBadgeView: View {
        let next: (title: String, timeText: String, status: TodoListView.NextClassStatus)
        let palette: ThemePalette
        let appTheme: String

        var body: some View {
            let isLive = next.status == .live

            return HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isLive ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                        .shadow(
                            color: isLive ? Color.green.opacity(0.45) : Color.orange.opacity(0.35),
                            radius: isLive ? 6 : 4
                        )

                    Text(isLive ? "LIVE" : "NEXT")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isLive ? Color.green : Color.orange)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isLive ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isLive ? Color.green.opacity(0.22) : Color.orange.opacity(0.22),
                            lineWidth: 0.8
                        )
                )

                VStack(alignment: .leading, spacing: 0) {
                    Text(next.title.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(1)

                    Text(next.timeText)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryText)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(height: 34)
            .background(
                Capsule()
                    .fill(palette.cardFill)
                    .overlay(
                        Capsule()
                            .stroke(palette.cardStroke, lineWidth: 1)
                    )
            )
        }
    }
}
