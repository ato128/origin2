//
//  BackendCrewTaskDetailView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//
import SwiftUI

struct BackendCrewTaskDetailView: View {
    let task: CrewTaskDTO
    let crew: CrewDTO

    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var showEditSheet = false

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private var palette: ThemePalette { ThemePalette() }

    var currentTask: CrewTaskDTO {
        crewStore.crewTasks.first(where: { $0.id == task.id }) ?? task
    }

    var body: some View {
        ZStack {
            ambientBackground

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    customHeader
                    headerCard
                    quickActionsCard
                    assignmentCard
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            BackendEditCrewTaskView(crew: crew, task: currentTask)
                .environmentObject(crewStore)
                .environmentObject(session)
        }
        .task {
            await crewStore.loadTasks(for: crew.id)
            await crewStore.loadMemberProfiles(for: crewStore.crewMembers)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private extension BackendCrewTaskDetailView {

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
                        hexColor(crew.color_hex).opacity(0.10),
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

            Text("Task Detail")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Spacer()

            Color.clear.frame(width: 56, height: 56)
        }
    }

    var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(currentTask.title)
                        .font(.title3.bold())
                        .foregroundStyle(palette.primaryText)

                    HStack(spacing: 8) {
                        badge(
                            text: priorityLabel(currentTask.priority),
                            tint: priorityColor(currentTask.priority)
                        )

                        badge(
                            text: statusTitle(currentTask.status),
                            tint: statusColor(currentTask.status)
                        )
                    }
                }

                Spacer()

                Image(systemName: currentTask.is_done ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(currentTask.is_done ? .green : .orange)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .contextMenu {
            Button(role: .destructive) {
                Task {
                    do {
                        try await crewStore.deleteTask(
                            taskID: currentTask.id,
                            crewID: crew.id,
                            title: currentTask.title
                        )
                        dismiss()
                    } catch {
                        print("DELETE TASK ERROR:", error.localizedDescription)
                    }
                }
            } label: {
                Label("Delete Task", systemImage: "trash")
            }
        }
    }

    func priorityColor(_ value: String) -> Color {
        switch value {
        case "low": return .gray
        case "medium": return .blue
        case "high": return .orange
        case "urgent": return .red
        default: return .secondary
        }
    }

    func statusColor(_ value: String) -> Color {
        switch value {
        case "todo": return .gray
        case "inProgress": return .blue
        case "review": return .orange
        case "done": return .green
        default: return .secondary
        }
    }

    func priorityLabel(_ raw: String) -> String {
        switch raw {
        case "low": return "Low"
        case "medium": return "Medium"
        case "high": return "High"
        case "urgent": return "Urgent"
        default: return raw.capitalized
        }
    }

    func statusTitle(_ raw: String) -> String {
        switch raw {
        case "todo": return "Todo"
        case "inProgress": return "In Progress"
        case "review": return "Review"
        case "done": return "Done"
        default: return raw.capitalized
        }
    }

    var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            Button {
                Task {
                    await crewStore.toggleTask(currentTask)
                }
            } label: {
                HStack {
                    Image(systemName: currentTask.is_done ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                    Text(currentTask.is_done ? "Reopen Task" : "Mark Done")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(currentTask.is_done ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                .foregroundStyle(currentTask.is_done ? .orange : .green)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                showEditSheet = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text("Edit Task")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.15))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var assignmentCard: some View {
        let assignedProfile = crewStore.memberProfiles.first(where: { $0.id == currentTask.assigned_to })
        let creatorProfile = crewStore.memberProfiles.first(where: { $0.id == currentTask.created_by })

        return VStack(alignment: .leading, spacing: 12) {
            Text("Assignment")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            infoRow(
                icon: "person.fill",
                title: "Assigned To",
                value: assignedProfile.map(displayName(for:)) ?? "Unassigned",
                tint: hexColor(crew.color_hex)
            )

            infoRow(
                icon: "plus.circle.fill",
                title: "Created By",
                value: creatorProfile.map(displayName(for:)) ?? "Unknown",
                tint: palette.secondaryText
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    func infoRow(icon: String, title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(tint)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
            }

            Text(value)
                .font(.subheadline)
                .foregroundStyle(palette.primaryText)
                .textSelection(.enabled)
        }
    }

    func badge(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
            .foregroundStyle(tint)
    }

    func displayName(for profile: ProfileDTO) -> String {
        if let fullName = profile.full_name, !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fullName
        }

        if let username = profile.username, !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return username
        }

        return profile.email ?? "Unknown user"
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
