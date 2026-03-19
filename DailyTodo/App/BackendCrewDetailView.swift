//
//  BackendCrewDetailView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import SwiftUI

struct BackendCrewDetailView: View {
    let crew: CrewDTO

    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var session: SessionStore
    
    @State private var showAddMember = false
    @State private var newTaskText = ""
    @State private var selectedAssignedUserID: UUID?

    private let palette = ThemePalette()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                membersCard
                tasksCard
            }
            .padding(16)
            .padding(.bottom, 32)
        }
        .background(
            ZStack(alignment: .topLeading) {
                AppBackground()

                RadialGradient(
                    colors: [
                        hexColor(crew.color_hex).opacity(0.16),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: 280
                )
                .ignoresSafeArea()
            }
        )
        .navigationTitle(crew.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await crewStore.loadMembers(for: crew.id)
            await crewStore.loadMemberProfiles(for: crewStore.crewMembers)
            await crewStore.loadTasks(for: crew.id)
        }
        .onAppear {
            crewStore.subscribeToTasks(crewID: crew.id)
        }

        .onDisappear {
            crewStore.unsubscribe()
        }
        .sheet(isPresented: $showAddMember) {
            AddCrewMemberView(crewID: crew.id)
                .environmentObject(crewStore)
        }
    }
    
   
    @State private var taskErrorMessage: String?

    var tasksCard: some View {
        VStack(alignment: .leading, spacing: 14) {

            // HEADER
            Text("Crew Tasks")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            // INPUT + ADD
            HStack(spacing: 10) {
                TextField("New task...", text: $newTaskText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(palette.secondaryCardFill)
                    )
                    .foregroundStyle(palette.primaryText)

                Button {
                    Task {
                        await createTask()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.bold())
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.accentColor.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)
            }

            // ASSIGN MENU
            if !crewStore.crewMembers.isEmpty {
                Menu {
                    Button("Unassigned") {
                        selectedAssignedUserID = nil
                    }

                    ForEach(crewStore.crewMembers) { member in
                        let profile = crewStore.memberProfiles.first(where: { $0.id == member.user_id })
                        let name = profile?.full_name ?? profile?.username ?? "User"

                        Button(name) {
                            selectedAssignedUserID = member.user_id
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.plus")

                        if let selectedAssignedUserID,
                           let profile = crewStore.memberProfiles.first(where: { $0.id == selectedAssignedUserID }) {
                            Text("Assigned: \(profile.full_name ?? profile.username ?? "User")")
                        } else {
                            Text("Assign Member")
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(palette.secondaryCardFill)
                    )
                    .foregroundStyle(palette.primaryText)
                }
                .buttonStyle(.plain)
            }

            // ERROR
            if let taskErrorMessage {
                Text(taskErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // TASK LIST
            if crewStore.crewTasks.isEmpty {
                Text("No tasks yet")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 12) {
                    ForEach(crewStore.crewTasks) { task in
                        Button {
                            Task {
                                await crewStore.toggleTask(task)
                            }
                        } label: {
                            backendTaskCardView(task)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }
    @MainActor
    private func createTask() async {
        let cleanText = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }
        guard let user = session.currentUser else { return }

        taskErrorMessage = nil

        do {
            try await crewStore.createTask(
                title: cleanText,
                crewID: crew.id,
                userID: user.id,
                assignedTo: selectedAssignedUserID
            )

            newTaskText = ""
            selectedAssignedUserID = nil
            await crewStore.loadTasks(for: crew.id)
        } catch {
            taskErrorMessage = error.localizedDescription
            print("CREATE TASK ERROR:", error.localizedDescription)
        }
    }

    var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(hexColor(crew.color_hex).opacity(0.18))
                        .frame(width: 62, height: 62)

                    Image(systemName: crew.icon)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(hexColor(crew.color_hex))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(crew.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(palette.primaryText)

                    Text("Crew workspace")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                detailPill(
                    icon: "person.2.fill",
                    text: "\(crewStore.crewMembers.count) members",
                    tint: hexColor(crew.color_hex)
                )

                detailPill(
                    icon: "externaldrive.connected.to.line.below.fill",
                    text: "Supabase",
                    tint: .green
                )
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var membersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Members")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            if crewStore.crewMembers.isEmpty {
                Text("No members yet")
                    .foregroundStyle(palette.secondaryText)
            } else {
                ForEach(crewStore.crewMembers) { member in
                    memberRow(member)
                }
            }
            Button {
                showAddMember = true
            } label: {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Add Member")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor.opacity(0.14))
                .foregroundStyle(Color.accentColor)
                .cornerRadius(12)
            }
        }
        .padding(18)
        .background(cardBackground)
    }
    
    func backendTaskCardView(_ task: CrewTaskDTO) -> some View {
        let assignedProfile = crewStore.memberProfiles.first(where: { $0.id == task.assigned_to })

        return HStack(alignment: .top, spacing: 12) {

            // LEFT ICON
            Circle()
                .fill(Color.blue.opacity(0.18))
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .fill(task.is_done ? Color.green : Color.blue)
                        .frame(width: 12, height: 12)
                )

            VStack(alignment: .leading, spacing: 6) {

                // TITLE
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .strikethrough(task.is_done)
                    .opacity(task.is_done ? 0.6 : 1)

                // ASSIGNED USER
                if let assignedProfile {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                        Text(assignedProfile.full_name ?? assignedProfile.username ?? "User")
                    }
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                }

                // STATUS PILL
                HStack(spacing: 8) {

                    Text(task.is_done ? "Done" : "Todo")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill((task.is_done ? Color.green : Color.orange).opacity(0.18))
                        )
                        .foregroundStyle(task.is_done ? .green : .orange)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.tertiaryText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.secondaryCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(palette.cardStroke.opacity(0.7), lineWidth: 1)
        )
    }

    func memberRow(_ member: CrewMemberDTO) -> some View {
        let profile = crewStore.memberProfiles.first(where: { $0.id == member.user_id })
        let fullName = profile?.full_name ?? "User"
        let username = profile?.username ?? "unknown"

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(hexColor(crew.color_hex).opacity(0.14))
                    .frame(width: 44, height: 44)

                Image(systemName: "person.fill")
                    .foregroundStyle(hexColor(crew.color_hex))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(fullName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                Text("@\(username)")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer()

            Text(member.role.capitalized)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(
                            member.role.lowercased() == "owner"
                            ? Color.accentColor.opacity(0.16)
                            : Color.white.opacity(0.08)
                        )
                )
                .foregroundStyle(
                    member.role.lowercased() == "owner"
                    ? Color.accentColor
                    : palette.secondaryText
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.secondaryCardFill)
        )
    }

    func detailPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
        )
        .foregroundStyle(tint)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }
}
