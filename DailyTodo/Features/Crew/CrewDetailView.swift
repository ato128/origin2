//
//  CrewDetailView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 10.03.2026.
//

import SwiftUI
import SwiftData

struct CrewDetailView: View {
    let crew: Crew

    @Query private var members: [CrewMember]
    @Query private var tasks: [CrewTask]
    @Query(sort: \CrewActivity.createdAt, order: .reverse)
    private var activities: [CrewActivity]

    var body: some View {
        let crewMembers = members.filter { $0.crewID == crew.id }
        let crewTasks = tasks.filter { $0.crewID == crew.id }
        let crewActivities = activities.filter { $0.crewID == crew.id }

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard(memberCount: crewMembers.count, taskCount: crewTasks.count)
                membersSection(crewMembers)
                tasksSection(crewTasks)
                focusSection
                activitySection(crewActivities)
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(crew.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func headerCard(memberCount: Int, taskCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(hexColor(crew.colorHex).opacity(0.18))
                        .frame(width: 52, height: 52)

                    Image(systemName: crew.icon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(hexColor(crew.colorHex))
                }

                Spacer()
            }

            Text(crew.name)
                .font(.title2.bold())

            HStack(spacing: 10) {
                infoPill(text: "\(memberCount) members", tint: hexColor(crew.colorHex))
                infoPill(text: "\(taskCount) tasks", tint: .secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private func membersSection(_ crewMembers: [CrewMember]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Members")
                .font(.headline)

            ForEach(crewMembers) { member in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.12))
                            .frame(width: 36, height: 36)

                        Image(systemName: member.avatarSymbol)
                            .foregroundStyle(.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.name)
                            .font(.subheadline.weight(.semibold))

                        Text(member.role)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Circle()
                        .fill(member.isOnline ? Color.green : Color.gray.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private func tasksSection(_ crewTasks: [CrewTask]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shared Tasks")
                .font(.headline)

            ForEach(crewTasks) { task in
                HStack(spacing: 10) {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(task.isDone ? Color.green : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(.subheadline.weight(.semibold))

                        if !task.assignedTo.isEmpty {
                            Text("Assigned to \(task.assignedTo)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Together")
                .font(.headline)

            Text("Start a group focus session with your crew.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
            } label: {
                Text("Start Group Focus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
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

    private func activitySection(_ crewActivities: [CrewActivity]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.headline)

            if crewActivities.isEmpty {
                Text("No activity yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(crewActivities.prefix(5)) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(hexColor(crew.colorHex).opacity(0.18))
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(item.memberName) \(item.actionText)")
                                .font(.subheadline)

                            Text(item.createdAt, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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

    private func infoPill(text: String, tint: Color) -> some View {
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

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

