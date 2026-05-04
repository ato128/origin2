//
//  BackendCreateCrewTaskSheet.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 22.03.2026.
//

import SwiftUI

private enum BackendCreateTaskArenaPalette {
    static let backgroundTop = Color(createTaskHex: "#05060D")
    static let backgroundMid = Color(createTaskHex: "#070713")
    static let backgroundBottom = Color(createTaskHex: "#07040C")

    static let blue = Color(createTaskHex: "#1593FF")
    static let cyan = Color(createTaskHex: "#2DD4FF")
    static let purple = Color(createTaskHex: "#7C3AED")
    static let coral = Color(createTaskHex: "#FF5A44")
    static let gold = Color(createTaskHex: "#FBBF24")
    static let green = Color(createTaskHex: "#A3E635")
    static let surface = Color(createTaskHex: "#101118")

    static var appGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(createTaskHex: "#1E6BFF"),
                Color(createTaskHex: "#7C3AED")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct BackendCreateCrewTaskSheet: View {
    let crew: CrewDTO
    let members: [CrewMemberDTO]
    let memberProfiles: [ProfileDTO]

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var session: SessionStore

    @State private var title = ""
    @State private var details = ""
    @State private var selectedAssigneeID: UUID?
    @State private var priority = "medium"
    @State private var status = "todo"
    @State private var showOnWeek = false
    @State private var plannedDate = Date()
    @State private var durationMinute = 60

    @State private var isSaving = false
    @State private var errorMessage: String?

    private let priorityOptions = ["low", "medium", "high", "urgent"]
    private let statusOptions = ["todo", "inProgress", "review", "done"]

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        ZStack {
            sheetBackground

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Color.clear.frame(height: 4)

                    header

                    heroCard

                    taskInfoCard

                    assignmentCard

                    priorityStatusCard

                    weekPlanningCard

                    if let errorMessage {
                        errorCard(errorMessage)
                    }

                    saveButton

                    Color.clear.frame(height: 36)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Layout

private extension BackendCreateCrewTaskSheet {
    var sheetBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    BackendCreateTaskArenaPalette.backgroundTop,
                    BackendCreateTaskArenaPalette.backgroundMid,
                    BackendCreateTaskArenaPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(BackendCreateTaskArenaPalette.blue.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 96)
                .offset(x: 165, y: -245)

            Circle()
                .fill(BackendCreateTaskArenaPalette.purple.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: -175, y: 500)

            Circle()
                .fill(BackendCreateTaskArenaPalette.coral.opacity(0.08))
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

    var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .black))
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
                Text("NEW CREW TASK")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(BackendCreateTaskArenaPalette.cyan)

                Text(crew.name)
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer()

            Button {
                Task {
                    await saveTask()
                }
            } label: {
                ZStack {
                    if isSaving {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.black)
                    }
                }
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(canSave ? BackendCreateTaskArenaPalette.green : Color.white.opacity(0.12))
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.55)
        }
    }

    var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(BackendCreateTaskArenaPalette.appGradient)
                    .frame(width: 62, height: 62)
                    .overlay(
                        Image(systemName: "checklist")
                            .font(.system(size: 27, weight: .black))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("CREW FLOW")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(BackendCreateTaskArenaPalette.cyan)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Yeni")
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(.white)

                        Text("görev")
                            .font(.system(size: 25, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(BackendCreateTaskArenaPalette.cyan)
                    }

                    Text("Crew için ortak görev oluştur, kişiye ata ve haftaya planla.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(2)
                }

                Spacer()
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BackendCreateTaskArenaPalette.blue.opacity(0.12),
                            BackendCreateTaskArenaPalette.purple.opacity(0.12),
                            BackendCreateTaskArenaPalette.surface.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(BackendCreateTaskArenaPalette.blue.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.24), radius: 20, y: 12)
        )
    }
}

// MARK: - Cards

private extension BackendCreateCrewTaskSheet {
    var taskInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(eyebrow: "TASK INFO", title: "Görev", italic: "bilgisi")

            VStack(spacing: 10) {
                fieldBox(
                    title: "Başlık",
                    icon: "text.cursor",
                    tint: BackendCreateTaskArenaPalette.blue
                ) {
                    TextField("Görev başlığı", text: $title)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)
                        .submitLabel(.done)
                }

                fieldBox(
                    title: "Detay",
                    icon: "text.alignleft",
                    tint: BackendCreateTaskArenaPalette.purple
                ) {
                    TextField("Kısa açıklama ekle", text: $details, axis: .vertical)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(3...6)
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var assignmentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(eyebrow: "ASSIGNMENT", title: "Atama", italic: "seçimi")

            Picker(selection: $selectedAssigneeID) {
                Text("Atanmamış").tag(UUID?.none)

                ForEach(members) { member in
                    Text(displayName(for: member))
                        .tag(Optional(member.user_id))
                }
            } label: {
                pickerLabel(
                    icon: "person.fill",
                    title: "Sorumlu kişi",
                    value: selectedAssigneeID.flatMap { id in
                        members.first(where: { $0.user_id == id }).map(displayName(for:))
                    } ?? "Atanmamış",
                    tint: BackendCreateTaskArenaPalette.cyan
                )
            }
            .pickerStyle(.menu)
            .tint(BackendCreateTaskArenaPalette.cyan)
        }
        .padding(18)
        .background(cardBackground)
    }

    var priorityStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(eyebrow: "TASK STATE", title: "Öncelik", italic: "durum")

            VStack(spacing: 14) {
                optionGrid(
                    title: "Öncelik",
                    options: priorityOptions,
                    selection: $priority,
                    colorProvider: priorityColor,
                    labelProvider: priorityLabel
                )

                optionGrid(
                    title: "Durum",
                    options: statusOptions,
                    selection: $status,
                    colorProvider: statusColor,
                    labelProvider: statusLabel
                )
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var weekPlanningCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle(eyebrow: "WEEK PLAN", title: "Haftaya", italic: "ekle")

                Spacer()

                Toggle("", isOn: $showOnWeek)
                    .labelsHidden()
                    .tint(BackendCreateTaskArenaPalette.green)
            }

            if showOnWeek {
                VStack(spacing: 10) {
                    DatePicker(
                        "Tarih / Saat",
                        selection: $plannedDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .tint(BackendCreateTaskArenaPalette.green)

                    Stepper(
                        "Süre: \(durationMinute) dk",
                        value: $durationMinute,
                        in: 15...240,
                        step: 15
                    )
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                }
                .padding(14)
                .background(detailSurface(cornerRadius: 22, tint: BackendCreateTaskArenaPalette.green))
            } else {
                Text("Bu görev sadece crew içinde kalır. İstersen Week ekranına da ekleyebilirsin.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(detailSurface(cornerRadius: 22, tint: BackendCreateTaskArenaPalette.green))
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var saveButton: some View {
        Button {
            Task {
                await saveTask()
            }
        } label: {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .black))
                }

                Text("Görevi Kaydet")
                    .font(.system(size: 16, weight: .black))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Capsule()
                    .fill(canSave ? BackendCreateTaskArenaPalette.green : Color.white.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.55)
    }
}

// MARK: - Components

private extension BackendCreateCrewTaskSheet {
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

    func fieldBox<Content: View>(
        title: String,
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(tint.opacity(0.13))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.36))

                content()
                    .textInputAutocapitalization(.sentences)
            }
        }
        .padding(14)
        .background(detailSurface(cornerRadius: 22, tint: tint))
    }

    func pickerLabel(icon: String, title: String, value: String, tint: Color) -> some View {
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
            }

            Spacer()

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white.opacity(0.38))
        }
        .padding(14)
        .background(detailSurface(cornerRadius: 22, tint: tint))
    }

    func optionGrid(
        title: String,
        options: [String],
        selection: Binding<String>,
        colorProvider: @escaping (String) -> Color,
        labelProvider: @escaping (String) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.36))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let selected = selection.wrappedValue == option
                    let tint = colorProvider(option)

                    Button {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                            selection.wrappedValue = option
                        }
                    } label: {
                        Text(labelProvider(option))
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(selected ? .black : tint)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(selected ? tint : tint.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(tint.opacity(selected ? 0 : 0.20), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    func errorCard(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(BackendCreateTaskArenaPalette.coral)

            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(3)

            Spacer()
        }
        .padding(16)
        .background(detailSurface(cornerRadius: 22, tint: BackendCreateTaskArenaPalette.coral))
    }

    func detailSurface(cornerRadius: CGFloat, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.055),
                        BackendCreateTaskArenaPalette.purple.opacity(0.040),
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
                        BackendCreateTaskArenaPalette.blue.opacity(0.035),
                        BackendCreateTaskArenaPalette.purple.opacity(0.045),
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

// MARK: - Logic

private extension BackendCreateCrewTaskSheet {
    @MainActor
    func saveTask() async {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        guard let user = session.currentUser else {
            errorMessage = String(localized: "backend_create_task_user_session_not_found")
            return
        }

        isSaving = true
        errorMessage = nil

        let schedule = makeSchedule()

        do {
            try await crewStore.createTask(
                title: cleanTitle,
                crewID: crew.id,
                userID: user.id,
                assignedTo: selectedAssigneeID,
                details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                priority: priority,
                status: status,
                showOnWeek: showOnWeek,
                scheduledWeekday: schedule.weekday,
                scheduledStartMinute: schedule.startMinute,
                scheduledDurationMinute: showOnWeek ? durationMinute : nil
            )

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    func makeSchedule() -> (weekday: Int?, startMinute: Int?) {
        guard showOnWeek else { return (nil, nil) }

        let cal = Calendar.current
        let comps = cal.dateComponents([.weekday, .hour, .minute], from: plannedDate)

        let systemWeekday = comps.weekday ?? 2
        let convertedWeekday = (systemWeekday + 5) % 7
        let startMinute = ((comps.hour ?? 0) * 60) + (comps.minute ?? 0)

        return (convertedWeekday, startMinute)
    }

    func displayName(for member: CrewMemberDTO) -> String {
        guard let profile = memberProfiles.first(where: { $0.id == member.user_id }) else {
            return String(localized: "backend_crew_unknown_user")
        }

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
        case "medium": return BackendCreateTaskArenaPalette.blue
        case "high": return .orange
        case "urgent": return BackendCreateTaskArenaPalette.coral
        default: return .secondary
        }
    }

    func statusColor(_ value: String) -> Color {
        switch value {
        case "todo": return .gray
        case "inProgress": return BackendCreateTaskArenaPalette.blue
        case "review": return .orange
        case "done": return BackendCreateTaskArenaPalette.green
        default: return .secondary
        }
    }

    func priorityLabel(_ raw: String) -> String {
        let isTurkish = Locale.current.language.languageCode?.identifier == "tr"

        switch raw {
        case "low": return isTurkish ? "Düşük" : "Low"
        case "medium": return isTurkish ? "Orta" : "Medium"
        case "high": return isTurkish ? "Yüksek" : "High"
        case "urgent": return isTurkish ? "Acil" : "Urgent"
        default: return raw.capitalized
        }
    }

    func statusLabel(_ raw: String) -> String {
        let isTurkish = Locale.current.language.languageCode?.identifier == "tr"

        switch raw {
        case "todo": return isTurkish ? "Yapılacak" : "Todo"
        case "inProgress": return isTurkish ? "Devam Ediyor" : "In Progress"
        case "review": return isTurkish ? "İncelemede" : "Review"
        case "done": return isTurkish ? "Tamamlandı" : "Done"
        default: return raw.capitalized
        }
    }
}

// MARK: - Color Hex

private extension Color {
    init(createTaskHex hex: String) {
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
