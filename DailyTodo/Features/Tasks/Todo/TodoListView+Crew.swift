//
//  TodoListView+Crew.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension TodoListView {
     var crewOverviewCard: some View {
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

     var crewListCard: some View {
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
    
    
    var leaderboardPodium: some View {
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
    
    func singleChampionCard(for crew: Crew) -> some View {
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
    
     func podiumItem(
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
    
     func rankColor(for crew: Crew) -> Color {
        let sorted = crews.sorted { $0.totalFocusMinutes > $1.totalFocusMinutes }
        let rank = (sorted.firstIndex(where: { $0.id == crew.id }) ?? 999) + 1

        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .clear
        }
    }

     var crewActivityCard: some View {
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

     var socialQuickActionsCard: some View {
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
}
