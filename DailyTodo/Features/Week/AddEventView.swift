//
//  AddEventView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData

struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var studentStore: StudentStore

    let defaultWeekday: Int
    let defaultDate: Date?

    @State private var title = ""
    @State private var courseCode = ""
    @State private var weekday = 0
    @State private var location = ""
    @State private var notes = ""
    @State private var selectedColorHex = "#3B82F6"

    @State private var selectedCourseID: UUID?
    @State private var expandedCourseID: UUID?
    @State private var addedCourseIDs: Set<UUID> = []

    @State private var showManualCourse = false
    @State private var manualCourseCode = ""
    @State private var manualCourseName = ""

    @State private var showCustomEvent = false

    @State private var startTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()

    @State private var showConflictAlert = false
    @State private var conflictSummary = ""
    @State private var pendingKeepOpen = false
    @State private var pendingAddedCourseID: UUID?

    private var accent: Color {
        colorFromHex(selectedColorHex)
    }

    private var secondaryAccent: Color {
        Color(arenaHex: AppArenaPalette.purple)
    }

    var body: some View {
        ZStack {
            ArenaBackground(
                primaryGlow: accent,
                secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
                warmGlow: Color(arenaHex: AppArenaPalette.cyan),
                intensity: 0.94
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    livePreviewCard
                    coursesSection
                    manualCourseSection
                    customEventSection

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            applyDefaultDateIfNeeded()
            studentStore.reload()
        }
        .onChange(of: courseCode) { _, newValue in
            autoFillFromCode(newValue)
        }
        .alert(tr("ae_conflict"), isPresented: $showConflictAlert) {
            Button(tr("common_cancel"), role: .cancel) { }

            Button(tr("ae_add_anyway")) {
                saveIgnoringConflicts()
            }
        } message: {
            Text(conflictSummary)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(accent)
                        .frame(width: 20, height: 1)

                    Text("WEEK EVENT")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(2.3)
                        .foregroundStyle(accent)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("Yeni")
                        .font(.system(size: 38, weight: .black))
                        .foregroundStyle(.white)

                    Text("ders")
                        .font(.system(size: 35, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    accent,
                                    secondaryAccent
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .lineLimit(1)
                .minimumScaleFactor(0.72)

                Text(tr("ae_header_sub"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(2)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.095),
                                        Color.white.opacity(0.045)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.11), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.24), radius: 12, y: 6)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var livePreviewCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(accent.opacity(0.13))
                    .frame(width: 56, height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(accent.opacity(0.18), lineWidth: 1)
                    )

                Image(systemName: previewIcon)
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(accent)
                        .frame(width: 16, height: 1)

                    Text("PREVIEW")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(accent)
                }

                Text(title.isEmpty ? tr("ae_pick_class") : title)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if !courseCode.isEmpty {
                        miniPill(courseCode, tint: accent)
                    }

                    miniPill(localizedDayTitle(weekday), tint: Color(arenaHex: AppArenaPalette.cyan))
                    miniPill("\(hm(minutesFrom(startTime)))–\(hm(minutesFrom(endTime)))", tint: Color(arenaHex: AppArenaPalette.gold))
                }
            }

            Spacer()

            Text(durationText.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(accent)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(
                    Capsule()
                        .fill(accent.opacity(0.12))
                        .overlay(
                            Capsule()
                                .stroke(accent.opacity(0.16), lineWidth: 1)
                        )
                )
        }
        .padding(18)
        .background(cardBackground(tint: accent, radius: 28, strength: 0.76))
    }

    private var coursesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Derslerim",
                eyebrow: "COURSES",
                icon: "graduationcap.fill",
                tint: Color(arenaHex: AppArenaPalette.cyan)
            )

            if studentStore.courses.isEmpty {
                emptyCourseRow
            } else {
                VStack(spacing: 10) {
                    ForEach(uniqueCourses) { course in
                        courseRow(course)
                    }
                }
            }
        }
    }

    private var manualCourseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                    showManualCourse.toggle()
                }
            } label: {
                disclosureHeader(
                    title: "Ekstra ders",
                    subtitle: tr("ae_add_missing_class"),
                    icon: "plus.circle",
                    tint: Color(arenaHex: AppArenaPalette.green),
                    isOpen: showManualCourse
                )
            }
            .buttonStyle(.plain)

            if showManualCourse {
                VStack(spacing: 12) {
                    arenaTextField("Kod", text: $manualCourseCode, capitalization: .characters)
                    arenaTextField(tr("ae_class_name"), text: $manualCourseName)

                    Button {
                        addManualCourse()
                    } label: {
                        primaryActionButton(
                            title: tr("ae_add_class_caps"),
                            icon: "plus.circle.fill",
                            tint: Color(arenaHex: AppArenaPalette.green)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(manualCourseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(manualCourseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                }
                .padding(15)
                .background(cardBackground(tint: Color(arenaHex: AppArenaPalette.green), radius: 22, strength: 0.48))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var customEventSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                    showCustomEvent.toggle()
                    if showCustomEvent {
                        selectedCourseID = nil
                        expandedCourseID = nil
                    }
                }
            } label: {
                disclosureHeader(
                    title: tr("ae_custom_event"),
                    subtitle: tr("ae_custom_event_sub"),
                    icon: "calendar.badge.plus",
                    tint: Color(arenaHex: AppArenaPalette.gold),
                    isOpen: showCustomEvent
                )
            }
            .buttonStyle(.plain)

            if showCustomEvent {
                VStack(spacing: 12) {
                    arenaTextField("Kod", text: $courseCode, capitalization: .characters)
                    arenaTextField(tr("at_title"), text: $title)
                    arenaTextField("Konum (opsiyonel)", text: $location)

                    pickerBlock

                    TextField("Not (opsiyonel)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .tint(accent)
                        .padding(14)
                        .background(inputBackground)

                    Button {
                        trySaveWithConflictCheck()
                    } label: {
                        primaryActionButton(
                            title: tr("common_save_caps"),
                            icon: "checkmark.circle.fill",
                            tint: accent
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.45)
                }
                .padding(15)
                .background(cardBackground(tint: Color(arenaHex: AppArenaPalette.gold), radius: 22, strength: 0.48))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var pickerBlock: some View {
        VStack(spacing: 12) {
            Picker(tr("ae_day"), selection: $weekday) {
                ForEach(0..<7, id: \.self) { i in
                    Text(localizedDayTitle(i)).tag(i)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                DatePicker("", selection: $startTime, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .tint(accent)

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white.opacity(0.36))

                DatePicker("", selection: $endTime, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .tint(accent)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(13)
        .background(inputBackground)
    }

    private var previewIcon: String {
        if selectedCourseID != nil { return "book.closed.fill" }
        if showCustomEvent { return "calendar" }
        return "sparkles"
    }

    private var uniqueCourses: [Course] {
        var seen = Set<String>()

        return studentStore.courses.filter { course in
            let key = "\(course.code.uppercased())-\(course.name.uppercased())"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private var emptyCourseRow: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(arenaHex: AppArenaPalette.cyan).opacity(0.13))
                    .frame(width: 46, height: 46)

                Image(systemName: "graduationcap")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color(arenaHex: AppArenaPalette.cyan))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Ders yok")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)

                Text(tr("ae_add_class_hint"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(15)
        .background(cardBackground(tint: Color(arenaHex: AppArenaPalette.cyan), radius: 22, strength: 0.44))
    }

    private func courseRow(_ course: Course) -> some View {
        let isExpanded = expandedCourseID == course.id
        let isAdded = addedCourseIDs.contains(course.id)
        let tint = colorFromHex(course.colorHex)

        return VStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    selectedCourseID = course.id
                    expandedCourseID = isExpanded ? nil : course.id
                    showCustomEvent = false
                    applyCourse(course)
                }
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(isAdded ? Color(arenaHex: AppArenaPalette.green) : tint)
                        .frame(width: 11, height: 11)
                        .shadow(color: (isAdded ? Color(arenaHex: AppArenaPalette.green) : tint).opacity(0.28), radius: 7)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.name)
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        if !course.code.isEmpty {
                            Text(course.code.uppercased())
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .tracking(0.7)
                                .foregroundStyle(.white.opacity(0.44))
                        }
                    }

                    Spacer()

                    Image(systemName: isAdded ? "checkmark.circle.fill" : (isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle"))
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(isAdded ? Color(arenaHex: AppArenaPalette.green) : .white.opacity(0.38))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 12) {
                    pickerBlock

                    HStack {
                        Label(durationText, systemImage: "clock.fill")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(tint)

                        Spacer()

                        Label("Her hafta", systemImage: "repeat")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.44))
                    }

                    courseColorPicker()

                    Button {
                        title = course.name
                        courseCode = course.code

                        trySaveWithConflictCheck(
                            keepSheetOpen: true,
                            addedCourseID: course.id
                        )
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                            Text(isAdded ? tr("ae_added_caps") : tr("ae_add_to_week_caps"))
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(isAdded ? Color(arenaHex: AppArenaPalette.green) : .black)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(isAdded ? Color(arenaHex: AppArenaPalette.green).opacity(0.14) : tint)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(isAdded ? Color(arenaHex: AppArenaPalette.green).opacity(0.16) : Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isAdded || durationMinute < 15)
                    .opacity(isAdded || durationMinute < 15 ? 0.55 : 1)
                }
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(15)
        .background(cardBackground(tint: tint, radius: 22, strength: isExpanded ? 0.60 : 0.42))
    }

    private func courseColorPicker() -> some View {
        let colors = [
            "#3B82F6",
            "#22C55E",
            "#F59E0B",
            "#EF4444",
            "#A855F7",
            "#06B6D4",
            "#EC4899"
        ]

        return VStack(alignment: .leading, spacing: 10) {
            Text(tr("common_color_caps"))
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.42))

            HStack(spacing: 12) {
                ForEach(colors, id: \.self) { hex in
                    let color = colorFromHex(hex)
                    let selected = selectedColorHex == hex

                    Button {
                        selectedColorHex = hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)
                                .shadow(color: color.opacity(selected ? 0.28 : 0.08), radius: selected ? 8 : 3)

                            if selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(selected ? 0.85 : 0.0), lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 2)
    }

    private func sectionHeader(title: String, eyebrow: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(tint)
                        .frame(width: 18, height: 1)

                    Text(eyebrow)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(tint)
                }

                Text(title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
            }

            Spacer()

            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(0.12))
                )
        }
    }

    private func disclosureHeader(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        isOpen: Bool
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.13))
                    .frame(width: 46, height: 46)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(tint.opacity(0.16), lineWidth: 1)
                    )

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()

            Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(tint)
        }
        .padding(15)
        .background(cardBackground(tint: tint, radius: 22, strength: 0.42))
    }

    private func arenaTextField(
        _ placeholder: String,
        text: Binding<String>,
        capitalization: TextInputAutocapitalization = .sentences
    ) -> some View {
        TextField(placeholder, text: text)
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled()
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .tint(accent)
            .padding(14)
            .background(inputBackground)
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.060))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
    }

    private func primaryActionButton(title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(title)
            Spacer()
            Image(systemName: "arrow.right")
        }
        .font(.system(size: 11, weight: .black, design: .monospaced))
        .tracking(0.8)
        .foregroundStyle(.black)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint)
                .shadow(color: tint.opacity(0.18), radius: 10, y: 5)
        )
    }

    private func miniPill(_ text: String, tint: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.16), lineWidth: 1)
                    )
            )
    }

    private func cardBackground(tint: Color, radius: CGFloat, strength: Double) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.070 + strength * 0.035),
                        Color(arenaHex: AppArenaPalette.purple).opacity(0.038),
                        Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                tint.opacity(0.10 + strength * 0.08),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 6,
                            endRadius: 180
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(tint.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 13, y: 7)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && durationMinute >= 15
    }

    private var durationMinute: Int {
        max(0, minutesFrom(endTime) - minutesFrom(startTime))
    }

    private var durationText: String {
        let d = durationMinute
        if d <= 0 { return "—" }

        let h = d / 60
        let m = d % 60

        if h == 0 { return "\(m) dk" }
        if m == 0 { return "\(h) sa" }
        return "\(h) sa \(m) dk"
    }

    private func applyCourse(_ course: Course) {
        title = course.name
        courseCode = course.code
        selectedColorHex = course.colorHex
    }

    private func autoFillFromCode(_ code: String) {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return }

        if let match = studentStore.courses.first(where: {
            $0.code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == normalized
        }) {
            applyCourse(match)
            selectedCourseID = match.id
            expandedCourseID = match.id
        }
    }

    private func addManualCourse() {
        let name = manualCourseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = manualCourseCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !name.isEmpty else { return }

        studentStore.addCourse(
            name: name,
            code: code,
            colorHex: selectedColorHex,
            sourceType: "manual"
        )

        title = name
        courseCode = code
        manualCourseName = ""
        manualCourseCode = ""
        showManualCourse = false
        studentStore.reload()
        Haptics.notify(.success)
    }

    private func trySaveWithConflictCheck(
        keepSheetOpen: Bool = false,
        addedCourseID: UUID? = nil
    ) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let start = minutesFrom(startTime)
        let end = start + durationMinute

        pendingKeepOpen = keepSheetOpen
        pendingAddedCourseID = addedCourseID

        let descriptor = FetchDescriptor<EventItem>(
            predicate: #Predicate { $0.weekday == weekday },
            sortBy: [SortDescriptor(\EventItem.startMinute, order: .forward)]
        )

        let sameDayAll = (try? context.fetch(descriptor)) ?? []
        let sameDay = sameDayAll.filter {
            $0.ownerUserID == session.currentUser?.id.uuidString
        }

        let conflicts = sameDay.filter { ev in
            max(start, ev.startMinute) < min(end, ev.startMinute + ev.durationMinute)
        }

        if conflicts.isEmpty {
            insertEvent(title: t, start: start, dur: durationMinute)
            completeSaveFlow()
        } else {
            conflictSummary = conflicts
                .prefix(4)
                .map { "\($0.title) (\(hm($0.startMinute))–\(hm($0.startMinute + $0.durationMinute)))" }
                .joined(separator: "\n")

            showConflictAlert = true
        }
    }

    private func saveIgnoringConflicts() {
        insertEvent(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            start: minutesFrom(startTime),
            dur: durationMinute
        )
        completeSaveFlow()
    }

    private func completeSaveFlow() {
        if let id = pendingAddedCourseID {
            addedCourseIDs.insert(id)
        }

        Haptics.notify(.success)

        if !pendingKeepOpen {
            dismiss()
        }

        pendingKeepOpen = false
        pendingAddedCourseID = nil
    }

    private func insertEvent(title: String, start: Int, dur: Int) {
        let ev = EventItem(
            ownerUserID: session.currentUser?.id.uuidString,
            title: title,
            weekday: weekday,
            startMinute: start,
            durationMinute: dur,
            scheduledDate: nil,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            colorHex: selectedColorHex
        )

        context.insert(ev)

        do {
            try context.save()
            WidgetAppSync.refreshFromSwiftData(context: context)

            Task {
                await NotificationManager.shared.schedule(for: ev, minutesBefore: 10)
                await NotificationManager.shared.schedule(for: ev, minutesBefore: 0)
            }

            Task {
                guard let currentUserID = session.currentUser?.id else { return }
                await friendStore.resyncSharedWeekIfNeeded(
                    for: currentUserID,
                    events: currentUserEventsFromContext()
                )
            }
        } catch {
            Log.debug("Save error:", error)
        }
    }

    private func applyDefaultDateIfNeeded() {
        weekday = max(0, min(6, defaultWeekday))
    }

    private func currentUserEventsFromContext() -> [EventItem] {
        guard let currentUserID = session.currentUser?.id.uuidString else { return [] }

        let descriptor = FetchDescriptor<EventItem>(
            sortBy: [SortDescriptor(\EventItem.startMinute, order: .forward)]
        )

        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0.ownerUserID == currentUserID }
    }

    private func localizedDayTitle(_ day: Int) -> String {
        switch max(0, min(6, day)) {
        case 0: return "Pzt"
        case 1: return "Sal"
        case 2: return "Çar"
        case 3: return "Per"
        case 4: return "Cum"
        case 5: return "Cmt"
        default: return "Paz"
        }
    }

    private func minutesFrom(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return max(0, min(1439, (c.hour ?? 0) * 60 + (c.minute ?? 0)))
    }

    private func hm(_ minute: Int) -> String {
        let m = max(0, minute)
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    private func colorFromHex(_ hex: String) -> Color {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        clean = clean.replacingOccurrences(of: "#", with: "")

        guard clean.count == 6 else { return .accentColor }

        var rgb: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&rgb)

        return Color(
            red: Double((rgb & 0xFF0000) >> 16) / 255,
            green: Double((rgb & 0x00FF00) >> 8) / 255,
            blue: Double(rgb & 0x0000FF) / 255
        )
    }
}
