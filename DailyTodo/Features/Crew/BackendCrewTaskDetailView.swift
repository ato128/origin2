//
//  BackendCrewTaskDetailView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//
import SwiftUI

private enum BackendCrewTaskArenaPalette {
    static let backgroundTop = Color(taskHex: "#05060D")
    static let backgroundMid = Color(taskHex: "#070713")
    static let backgroundBottom = Color(taskHex: "#07040C")

    static let blue = Color(taskHex: "#1593FF")
    static let cyan = Color(taskHex: "#2DD4FF")
    static let purple = Color(taskHex: "#7C3AED")
    static let coral = Color(taskHex: "#FF5A44")
    static let gold = Color(taskHex: "#FBBF24")
    static let green = Color(taskHex: "#A3E635")

    static let surface = Color(taskHex: "#101118")
    static let surface2 = Color(taskHex: "#171821")

    static var appGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(taskHex: "#1E6BFF"),
                Color(taskHex: "#7C3AED")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct BackendCrewTaskDetailView: View {
    let task: CrewTaskDTO
    let crew: CrewDTO

    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var showEditSheet = false
    @State private var isDeleting = false
    @State private var showDeleteConfirm = false

    var currentTask: CrewTaskDTO {
        crewStore.crewTasks.first(where: { $0.id == task.id }) ?? task
    }

    private var assignedProfile: ProfileDTO? {
        crewStore.memberProfiles.first(where: { $0.id == currentTask.assigned_to })
    }

    private var creatorProfile: ProfileDTO? {
        crewStore.memberProfiles.first(where: { $0.id == currentTask.created_by })
    }

    private var taskStateTint: Color {
        currentTask.is_done ? BackendCrewTaskArenaPalette.green : BackendCrewTaskArenaPalette.coral
    }

    var body: some View {
        ZStack {
            taskAmbientBackground

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Color.clear.frame(height: 6)

                    taskHeader

                    taskHeroCard

                    quickActionsCard

                    assignmentCard

                    detailInfoCard

                    Color.clear.frame(height: 96)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 18)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            BackendEditCrewTaskView(crew: crew, task: currentTask)
                .environmentObject(crewStore)
                .environmentObject(session)
        }
        .confirmationDialog(
            tr("edit_delete_task"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive) {
                Task {
                    await deleteCurrentTask()
                }
            }

            Button(tr("common_cancel"), role: .cancel) { }
        } message: {
            Text(tr("bctd_remove_confirm"))
        }
        .task {
            await crewStore.loadTasks(for: crew.id)
            await crewStore.loadMemberProfiles(for: crewStore.crewMembers)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Layout

private extension BackendCrewTaskDetailView {
    var taskAmbientBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    BackendCrewTaskArenaPalette.backgroundTop,
                    BackendCrewTaskArenaPalette.backgroundMid,
                    BackendCrewTaskArenaPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(BackendCrewTaskArenaPalette.blue.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 96)
                .offset(x: 165, y: -245)

            Circle()
                .fill(BackendCrewTaskArenaPalette.purple.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: -175, y: 500)

            Circle()
                .fill(taskStateTint.opacity(0.08))
                .frame(width: 270, height: 270)
                .blur(radius: 100)
                .offset(x: 170, y: 280)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.16),
                    Color.clear,
                    Color.black.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    var taskHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(Color.white.opacity(0.075))
                            .overlay(
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 3) {
                Text("TASK DETAIL")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(BackendCrewTaskArenaPalette.cyan)

                Text(crew.name)
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer()

            Menu {
                Button {
                    showEditSheet = true
                } label: {
                    Label(tr("common_edit"), systemImage: "pencil")
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Sil", systemImage: "trash")
                }
            } label: {
                ZStack {
                    if isDeleting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 19, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(Color.white.opacity(0.075))
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
            }
            .disabled(isDeleting)
        }
    }
}

// MARK: - Hero

private extension BackendCrewTaskDetailView {
    var taskHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                priorityColor(currentTask.priority).opacity(0.90),
                                BackendCrewTaskArenaPalette.purple.opacity(0.82),
                                taskStateTint.opacity(0.65)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 62, height: 62)
                    .overlay(
                        Image(systemName: currentTask.is_done ? "checkmark.circle.fill" : "circle.dashed")
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(taskStateTint)
                            .frame(width: 8, height: 8)

                        Text(currentTask.is_done ? "COMPLETED TASK" : "OPEN TASK")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(taskStateTint)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Crew")
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(.white)

                        Text("task")
                            .font(.system(size: 25, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(BackendCrewTaskArenaPalette.cyan)
                    }

                    Text(currentTask.title)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                        .minimumScaleFactor(0.70)
                }

                Spacer()
            }

            if let details = currentTask.details,
               !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(details)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                taskPill(
                    text: priorityLabel(currentTask.priority),
                    tint: priorityColor(currentTask.priority)
                )

                taskPill(
                    text: statusTitle(currentTask.status),
                    tint: statusColor(currentTask.status)
                )

                if currentTask.show_on_week,
                   let weekday = currentTask.scheduled_weekday,
                   let start = currentTask.scheduled_start_minute {
                    taskPill(
                        text: "\(weekdayShort(weekday)) \(hm(start))",
                        tint: BackendCrewTaskArenaPalette.cyan
                    )
                }
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Durum")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.42))

                    Text(currentTask.is_done ? tr("bctd_task_done") : tr("bctd_task_open"))
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                }

                Spacer()

                Image(systemName: currentTask.is_done ? "checkmark.seal.fill" : "hourglass.circle.fill")
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(taskStateTint)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            priorityColor(currentTask.priority).opacity(0.14),
                            BackendCrewTaskArenaPalette.purple.opacity(0.12),
                            BackendCrewTaskArenaPalette.surface.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(priorityColor(currentTask.priority).opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.24), radius: 20, y: 12)
        )
    }
}

// MARK: - Cards

private extension BackendCrewTaskDetailView {
    var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                eyebrow: "QUICK ACTIONS",
                title: tr("bctd_quick_w"),
                italic: tr("bctd_actions_w")
            )

            HStack(spacing: 10) {
                Button {
                    Task {
                        await crewStore.toggleTask(currentTask)
                    }
                } label: {
                    actionButtonContent(
                        icon: currentTask.is_done ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill",
                        title: currentTask.is_done
                        ? String(localized: "backend_crew_reopen_task")
                        : String(localized: "backend_crew_mark_done"),
                        tint: currentTask.is_done ? BackendCrewTaskArenaPalette.coral : BackendCrewTaskArenaPalette.green,
                        filled: false
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showEditSheet = true
                } label: {
                    actionButtonContent(
                        icon: "pencil",
                        title: String(localized: "backend_crew_edit_task"),
                        tint: BackendCrewTaskArenaPalette.blue,
                        filled: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var assignmentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                eyebrow: "ASSIGNMENT",
                title: "Atama",
                italic: "bilgisi"
            )

            VStack(spacing: 10) {
                infoRow(
                    icon: "person.fill",
                    title: String(localized: "backend_crew_assigned_to"),
                    value: assignedProfile.map(displayName(for:)) ?? String(localized: "backend_crew_unassigned"),
                    tint: BackendCrewTaskArenaPalette.cyan
                )

                infoRow(
                    icon: "plus.circle.fill",
                    title: String(localized: "backend_crew_created_by"),
                    value: creatorProfile.map(displayName(for:)) ?? String(localized: "backend_crew_unknown"),
                    tint: BackendCrewTaskArenaPalette.gold
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var detailInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                eyebrow: "TASK META",
                title: tr("at_kind_task"),
                italic: tr("bctd_detail_w")
            )

            HStack(spacing: 10) {
                miniStat(
                    icon: "flag.fill",
                    value: priorityLabel(currentTask.priority),
                    title: tr("priority_label"),
                    tint: priorityColor(currentTask.priority)
                )

                miniStat(
                    icon: "slider.horizontal.3",
                    value: statusTitle(currentTask.status),
                    title: "Durum",
                    tint: statusColor(currentTask.status)
                )

                miniStat(
                    icon: "person.3.fill",
                    value: crew.name,
                    title: "Crew",
                    tint: BackendCrewTaskArenaPalette.purple
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
}

// MARK: - Components

private extension BackendCrewTaskDetailView {
    func actionButtonContent(icon: String, title: String, tint: Color, filled: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))

            Text(title)
                .font(.system(size: 13, weight: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .foregroundStyle(filled ? .black : tint)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(
            Capsule()
                .fill(filled ? tint : tint.opacity(0.13))
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(filled ? 0 : 0.22), lineWidth: 1)
                )
        )
    }

    func infoRow(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(tint.opacity(0.13))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.36))

                Text(value)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .padding(14)
        .background(detailSurface(cornerRadius: 22, tint: tint))
    }

    func miniStat(icon: String, value: String, title: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.42))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 92)
        .padding(.horizontal, 12)
        .background(detailSurface(cornerRadius: 20, tint: tint))
    }

    func taskPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.20), lineWidth: 1)
                    )
            )
    }

    func sectionTitle(eyebrow: String, title: String, italic: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("— \(eyebrow) —")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.34))
                .lineLimit(1)
                .minimumScaleFactor(0.60)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)

                Text(italic)
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.white)
            }
        }
    }

    func detailSurface(cornerRadius: CGFloat, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.055),
                        BackendCrewTaskArenaPalette.purple.opacity(0.040),
                        Color.white.opacity(0.038)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.13), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 14, y: 8)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        BackendCrewTaskArenaPalette.blue.opacity(0.035),
                        BackendCrewTaskArenaPalette.purple.opacity(0.045),
                        Color.white.opacity(0.040)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
    }
}

// MARK: - Helpers

private extension BackendCrewTaskDetailView {
    func deleteCurrentTask() async {
        isDeleting = true

        do {
            try await crewStore.deleteTask(
                taskID: currentTask.id,
                crewID: crew.id,
                title: currentTask.title
            )
            dismiss()
        } catch {
            Log.debug("DELETE TASK ERROR:", error.localizedDescription)
        }

        isDeleting = false
    }

    func displayName(for profile: ProfileDTO) -> String {
        if let fullName = profile.full_name,
           !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fullName
        }

        if let username = profile.username,
           !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return username
        }

        return profile.email ?? String(localized: "backend_crew_unknown_user")
    }

    func priorityColor(_ value: String) -> Color {
        switch value {
        case "low": return .gray
        case "medium": return BackendCrewTaskArenaPalette.blue
        case "high": return .orange
        case "urgent": return BackendCrewTaskArenaPalette.coral
        default: return .secondary
        }
    }

    func statusColor(_ value: String) -> Color {
        switch value {
        case "todo": return .gray
        case "inProgress": return BackendCrewTaskArenaPalette.blue
        case "review": return .orange
        case "done": return BackendCrewTaskArenaPalette.green
        default: return .secondary
        }
    }

    func priorityLabel(_ raw: String) -> String {
        let isTurkish = !appLanguageIsEnglish()

        switch raw {
        case "low": return isTurkish ? tr("prio_low") : "Low"
        case "medium": return isTurkish ? "Orta" : "Medium"
        case "high": return isTurkish ? tr("prio_high") : "High"
        case "urgent": return isTurkish ? "Acil" : "Urgent"
        default: return raw.capitalized
        }
    }

    func statusTitle(_ raw: String) -> String {
        let isTurkish = !appLanguageIsEnglish()

        switch raw {
        case "todo": return isTurkish ? tr("status_todo") : "Todo"
        case "inProgress": return isTurkish ? "Devam Ediyor" : "In Progress"
        case "review": return isTurkish ? tr("status_review") : "Review"
        case "done": return isTurkish ? tr("common_completed") : "Done"
        default: return raw.capitalized
        }
    }

    func weekdayShort(_ weekday: Int) -> String {
        let isTurkish = !appLanguageIsEnglish()

        let titles = isTurkish
        ? ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
        : ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

        return titles[max(0, min(6, weekday))]
    }

    func hm(_ minute: Int) -> String {
        let h = max(0, min(23, minute / 60))
        let m = max(0, min(59, minute % 60))
        return String(format: "%02d:%02d", h, m)
    }
}

// MARK: - Color Hex

private extension Color {
    init(taskHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch cleaned.count {
        case 3:
            a = 255
            r = (int >> 8) * 17
            g = ((int >> 4) & 0xF) * 17
            b = (int & 0xF) * 17

        case 6:
            a = 255
            r = int >> 16
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        case 8:
            a = int >> 24
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        default:
            a = 255
            r = 255
            g = 255
            b = 255
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
