//
//  CrewDetailView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 10.03.2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CrewDetailView: View {
    let crew: Crew

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) var dbContext

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    var palette: ThemePalette { ThemePalette() }

    @State var showCreateTask = false
    @State var showAddMemberSheet = false
    @State var selectedTaskForEdit: CrewTask?
    @State var showShareSheet = false

    @State var showHeroCard = false
    @State var showStatsRow = false
    @State var showMembersSection = false
    @State var showTasksSection = false
    @State var showFocusSection = false
    @State var showActivitySection = false

    @State var editableTasks: [CrewTask] = []
    @State var isReorderMode = false
    @State var draggedTask: CrewTask?

    @Query var members: [CrewMember]
    @Query var tasks: [CrewTask]

    @Query(sort: \CrewActivity.createdAt, order: .reverse)
    var activities: [CrewActivity]

    @Query var comments: [CrewTaskComment]
    @Query var polls: [CrewTaskPoll]
    @Query var reactions: [CrewTaskReaction]
    @Query var focusRecords: [CrewFocusRecord]
    
    var body: some View {
        let crewMembers = members.filter { $0.crewID == crew.id }
        let crewTasks = tasks
            .filter { $0.crewID == crew.id }
            .sorted { lhs, rhs in
                if lhs.orderIndex != rhs.orderIndex {
                    return lhs.orderIndex < rhs.orderIndex
                }

                if lhs.isDone != rhs.isDone {
                    return !lhs.isDone && rhs.isDone
                }

                let priorityRank: [String: Int] = [
                    "urgent": 0,
                    "high": 1,
                    "medium": 2,
                    "low": 3
                ]

                let lhsPriority = priorityRank[lhs.priority, default: 99]
                let rhsPriority = priorityRank[rhs.priority, default: 99]

                if lhsPriority != rhsPriority {
                    return lhsPriority < rhsPriority
                }

                let lhsMinute = lhs.scheduledStartMinute ?? 9999
                let rhsMinute = rhs.scheduledStartMinute ?? 9999

                if lhsMinute != rhsMinute {
                    return lhsMinute < rhsMinute
                }

                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

        let crewActivities = activities.filter { $0.crewID == crew.id }
        let completedTasks = crewTasks.filter(\.isDone).count
        let pendingTasks = max(0, crewTasks.count - completedTasks)
        let progress = crewTasks.isEmpty ? 0 : Double(completedTasks) / Double(crewTasks.count)

        ZStack(alignment: .top) {
            ambientBackground

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Color.clear.frame(height: 76)

                    customHeader

                    heroCard(
                        memberCount: crewMembers.count,
                        totalTasks: crewTasks.count,
                        progress: progress
                    )
                    .offset(y: showHeroCard ? 0 : 18)
                    .opacity(showHeroCard ? 1 : 0)
                    .scaleEffect(showHeroCard ? 1 : 0.985)

                    quickStatsRow(
                        completed: completedTasks,
                        pending: pendingTasks,
                        memberCount: crewMembers.count
                    )
                    .offset(y: showStatsRow ? 0 : 18)
                    .opacity(showStatsRow ? 1 : 0)
                    .scaleEffect(showStatsRow ? 1 : 0.985)

                    leaderboardCard
                        .offset(y: showStatsRow ? 0 : 18)
                        .opacity(showStatsRow ? 1 : 0)
                        .scaleEffect(showStatsRow ? 1 : 0.985)
                    
                    CrewBadgeCard(
                        crew: crew,
                        palette: palette
                    )
                        .offset(y: showStatsRow ? 0 : 18)
                        .opacity(showStatsRow ? 1 : 0)
                        .scaleEffect(showStatsRow ? 1 : 0.985)
                    
                    membersSection(crewMembers)
                        .offset(y: showMembersSection ? 0 : 18)
                        .opacity(showMembersSection ? 1 : 0)
                        .scaleEffect(showMembersSection ? 1 : 0.985)

                    tasksSection(crewTasks)
                        .offset(y: showTasksSection ? 0 : 18)
                        .opacity(showTasksSection ? 1 : 0)
                        .scaleEffect(showTasksSection ? 1 : 0.985)

                    focusSection(memberCount: crewMembers.count)
                        .offset(y: showFocusSection ? 0 : 18)
                        .opacity(showFocusSection ? 1 : 0)
                        .scaleEffect(showFocusSection ? 1 : 0.985)

                    activitySection(crewActivities)
                        .offset(y: showActivitySection ? 0 : 18)
                        .opacity(showActivitySection ? 1 : 0)
                        .scaleEffect(showActivitySection ? 1 : 0.985)

                    Spacer(minLength: 90)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            editableTasks = crewTasks

            showHeroCard = false
            showStatsRow = false
            showMembersSection = false
            showTasksSection = false
            showFocusSection = false
            showActivitySection = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    showHeroCard = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                    showStatsRow = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                    showMembersSection = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                    showTasksSection = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                withAnimation(.spring(response: 0.50, dampingFraction: 0.86)) {
                    showFocusSection = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
                    showActivitySection = true
                }
            }
        }
        .onChange(of: tasks.count) { _, _ in
            editableTasks = crewTasks
        }
        .sheet(isPresented: $showCreateTask) {
            CreateCrewTaskView(
                crew: crew,
                members: crewMembers
            )
        }
        .sheet(isPresented: $showAddMemberSheet) {
            AddMemberView(crew: crew)
        }
        .sheet(item: $selectedTaskForEdit) { task in
            EditCrewTaskView(crew: crew, task: task)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(
                items: [
                    "Join my crew '\(crew.name)' on DailyTodo 🚀"
                ]
            )
        }
    }
}

 extension CrewDetailView {

    var ambientBackground: some View {
        ZStack(alignment: .topLeading) {
            AppBackground()

            if appTheme == AppTheme.gradient.rawValue {
                RadialGradient(
                    colors: [
                        Color.purple.opacity(0.12),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 30,
                    endRadius: 260
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        hexColor(crew.colorHex).opacity(0.10),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 60,
                    endRadius: 320
                )
                .ignoresSafeArea()
            }
        }
    }

    var customHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(palette.cardFill)
                            .overlay(
                                Circle()
                                    .stroke(palette.cardStroke, lineWidth: 1)
                            )
                    )
                    .shadow(color: palette.shadowColor, radius: 10, y: 4)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(crew.name)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Spacer()

            Color.clear.frame(width: 56, height: 56)
        }
    }

    func heroCard(memberCount: Int, totalTasks: Int, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(hexColor(crew.colorHex).opacity(0.18))
                        .frame(width: 64, height: 64)

                    Image(systemName: crew.icon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(hexColor(crew.colorHex))
                }

                Spacer()

                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(hexColor(crew.colorHex))
                        )
                        .shadow(color: hexColor(crew.colorHex).opacity(0.28), radius: 10, y: 5)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(crew.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Text("Manage members, shared tasks, and project activity in one place.")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }

            HStack(spacing: 10) {
                infoPill(text: "\(memberCount) members", tint: hexColor(crew.colorHex))
                infoPill(text: "\(totalTasks) tasks", tint: palette.secondaryText)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Crew Progress")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)

                    Spacer()

                    Text("\(Int(progress * 100))%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.secondaryText)
                }

                ProgressView(value: progress)
                    .tint(hexColor(crew.colorHex))
                    .scaleEffect(y: 1.8)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .shadow(color: hexColor(crew.colorHex).opacity(0.10), radius: 12, y: 6)
    }

    func quickStatsRow(completed: Int, pending: Int, memberCount: Int) -> some View {
        HStack(spacing: 10) {
            statCard(
                value: "\(completed)",
                title: "Done",
                icon: "checkmark.circle.fill",
                tint: .green
            )

            statCard(
                value: "\(pending)",
                title: "Pending",
                icon: "clock.fill",
                tint: .orange
            )

            statCard(
                value: "\(memberCount)",
                title: "Members",
                icon: "person.3.fill",
                tint: hexColor(crew.colorHex)
            )
        }
    }

    func statCard(value: String, title: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(palette.primaryText)
                .monospacedDigit()

            Text(title)
                .font(.caption2)
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.secondaryCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(palette.cardStroke.opacity(0.7), lineWidth: 1)
                )
        )
    }

    func focusSection(memberCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Focus Together")
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Image(systemName: "timer")
                    .foregroundStyle(hexColor(crew.colorHex))
            }

            Text("Start a shared focus session and keep your crew productive together.")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)

            HStack(spacing: 10) {
                infoPill(text: "\(memberCount) participants", tint: hexColor(crew.colorHex))
                infoPill(text: "25 min", tint: palette.secondaryText)
            }

            Button {
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Group Focus")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(hexColor(crew.colorHex))
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
     
     var todayLeaderboard: [(name: String, minutes: Int)] {
         let calendar = Calendar.current

         let todayRecords = focusRecords.filter {
             $0.crewID == crew.id && calendar.isDateInToday($0.createdAt)
         }

         let grouped = Dictionary(grouping: todayRecords, by: { $0.memberName })

         return grouped
             .map { name, records in
                 (name: name, minutes: records.reduce(0) { $0 + $1.minutes })
             }
             .sorted { lhs, rhs in
                 if lhs.minutes == rhs.minutes {
                     return lhs.name < rhs.name
                 }
                 return lhs.minutes > rhs.minutes
             }
     }

     var topThreeLeaderboard: [(name: String, minutes: Int)] {
         Array(todayLeaderboard.prefix(3))
     }

     func focusTimeText(_ minutes: Int) -> String {
         let hours = minutes / 60
         let mins = minutes % 60

         if hours > 0 {
             return "\(hours)h \(mins)m"
         } else {
             return "\(mins)m"
         }
     }
     
     var leaderboardCard: some View {
         VStack(alignment: .leading, spacing: 14) {
             HStack {
                 Text("Leaderboard")
                     .font(.headline)
                     .foregroundStyle(palette.primaryText)

                 Spacer()

                 Text("Today")
                     .font(.caption.weight(.semibold))
                     .foregroundStyle(palette.secondaryText)
             }

             if topThreeLeaderboard.isEmpty {
                 Text("No shared focus records today")
                     .font(.subheadline)
                     .foregroundStyle(palette.secondaryText)
             } else {
                 ForEach(Array(topThreeLeaderboard.enumerated()), id: \.offset) { index, entry in
                     CrewLeaderboardRow(
                         rank: index + 1,
                         name: entry.name,
                         minutes: entry.minutes,
                         palette: palette
                     )
                 }
             }
         }
         .padding(18)
         .background(cardBackground)
     }
     
     var focusBadgeMinutes: Int {
         crew.totalFocusMinutes
     }

     
     
     var badgeCard: some View {
         let minutes = focusBadgeMinutes
         let badgeTitle = CrewBadgeHelper.title(for: minutes)
         let badgeColor = CrewBadgeHelper.color(for: minutes)
         let nextTarget = CrewBadgeHelper.nextTarget(for: minutes)

         return VStack(alignment: .leading, spacing: 14) {
             HStack {
                 VStack(alignment: .leading, spacing: 4) {
                     Text("Crew Badge")
                         .font(.headline)
                         .foregroundStyle(palette.primaryText)

                     Text("Unlocked by total focus time")
                         .font(.caption)
                         .foregroundStyle(palette.secondaryText)
                 }

                 Spacer()

                 Image(systemName: "sparkles")
                     .font(.title3)
                     .foregroundStyle(badgeColor)
             }

             HStack(spacing: 12) {
                 ZStack {
                     Circle()
                         .fill(badgeColor.opacity(0.16))
                         .frame(width: 56, height: 56)

                     Image(systemName: "medal.fill")
                         .font(.title3)
                         .foregroundStyle(badgeColor)
                 }

                 VStack(alignment: .leading, spacing: 4) {
                     Text(badgeTitle)
                         .font(.headline)
                         .foregroundStyle(palette.primaryText)

                     Text(focusTimeText(minutes))
                         .font(.caption)
                         .foregroundStyle(palette.secondaryText)
                 }

                 Spacer()
             }

             if let nextTarget {
                 VStack(alignment: .leading, spacing: 8) {
                     HStack {
                         Text("Next badge")
                             .font(.caption.weight(.semibold))
                             .foregroundStyle(palette.secondaryText)

                         Spacer()

                         Text("\(focusTimeText(minutes)) / \(focusTimeText(nextTarget))")
                             .font(.caption2.weight(.bold))
                             .foregroundStyle(palette.secondaryText)
                     }

                     ProgressView(value: CrewBadgeHelper.progress(for: minutes))
                         .tint(badgeColor)
                         .scaleEffect(y: 1.5)
                 }
             }
         }
         .padding(18)
         .background(cardBackground)
     }
     
     
     func presenceColor(for member: CrewMember) -> Color {
         switch member.presence {
         case "focus":
             return .green
         case "online":
             return .orange
         default:
             return .gray
         }
     }

     func presenceText(for member: CrewMember) -> String {
         switch member.presence {
         case "focus":
             return "Focus"
         case "online":
             return "Online"
         default:
             return "Offline"
         }
     }
     
    func infoPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
            .foregroundStyle(tint)
    }

    func emptyMiniState(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(palette.secondaryText)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
        }
        .padding(.vertical, 4)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }

    struct ShareSheet: UIViewControllerRepresentable {
        var items: [Any]

        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(
                activityItems: items,
                applicationActivities: nil
            )
        }

        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    }
}
    

