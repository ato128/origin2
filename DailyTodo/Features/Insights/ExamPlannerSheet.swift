//
//  ExamPlannerSheet.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 27.04.2026.
//

import SwiftUI
import SwiftData

struct ExamPlannerSheet: View {
    let courses: [Course]
    let ownerUserID: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ExamStudyPlanItem.examDate, order: .forward)
    private var allItems: [ExamStudyPlanItem]

    @State private var selectedCourseID: UUID?
    @State private var selectedType: ExamPlannerType = .final
    @State private var examDate: Date = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now

    @State private var showNewExamForm = false
    @State private var showManualBuilder = false
    @State private var expandedCourseID: UUID?

    @State private var manualDate: Date = .now
    @State private var manualMinutes: Int = 45
    @State private var manualTopic: String = tr("tv_solve_q")

    // AI plan generation
    @State private var examTopics: String = ""
    @State private var dailyStudyHours: Int = 3
    @State private var isGeneratingAIPlan = false
    @State private var aiPlanError: String? = nil

    private var accent: Color {
        Color(arenaHex: AppArenaPalette.gold)
    }

    private var secondaryAccent: Color {
        Color(arenaHex: AppArenaPalette.coral)
    }

    private var scopedItems: [ExamStudyPlanItem] {
        allItems.filter { $0.ownerUserID == ownerUserID }
    }

    private var selectedCourse: Course? {
        courses.first { $0.id == selectedCourseID } ?? courses.first
    }

    private var plannedCourses: [Course] {
        courses.filter { course in
            scopedItems.contains { $0.courseID == course.id }
        }
    }

    private var examGroups: [(key: String, value: [ExamStudyPlanItem])] {
        Dictionary(grouping: scopedItems) {
            "\($0.examGroupID?.uuidString ?? $0.courseName)-\($0.examTypeRaw)-\($0.examDate.timeIntervalSince1970)"
        }
        .map { ($0.key, $0.value.sorted { $0.studyDate < $1.studyDate }) }
        .sorted {
            ($0.value.first?.examDate ?? .distantFuture) < ($1.value.first?.examDate ?? .distantFuture)
        }
    }

    private var nextExamGroup: [ExamStudyPlanItem]? {
        examGroups.first?.value
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        topHero
                        newExamCollapsedCard

                        if showNewExamForm {
                            createExamCard
                        }

                        examTimeline
                        coursePlans

                        Spacer(minLength: 34)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 34)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                headerBar
            }
            .onAppear {
                if selectedCourseID == nil {
                    selectedCourseID = courses.first?.id
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var background: some View {
        ArenaBackground(
            primaryGlow: accent,
            secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
            warmGlow: secondaryAccent,
            intensity: 0.94
        )
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("eps_planner_caps"))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(accent)

                Text(tr("ep_exam_plan"))
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark").accessibilityLabel(tr("event_close"))
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
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
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            ArenaHeaderScrim(height: 78, materialHeight: 58)
                .ignoresSafeArea()
        )
    }

    private var topHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(accent)
                            .frame(width: 20, height: 1)

                        Text(tr("eps_flow_caps"))
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.8)
                            .foregroundStyle(accent)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(tr("at_kind_exam"))
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(.white)

                        Text(tr("ep_plan_w"))
                            .font(.system(size: 31, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [accent, secondaryAccent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                    Text(heroTitle)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(accent.opacity(0.13))
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(accent.opacity(0.18), lineWidth: 1)
                        )

                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 21, weight: .black))
                        .foregroundStyle(accent)
                }
            }

            HStack(spacing: 8) {
                compactMetric(icon: "calendar", title: tr("at_kind_exam"), value: nextExamDateText)
                compactMetric(icon: "flame.fill", title: "Risk", value: riskText)
                compactMetric(icon: "timer", title: tr("common_today"), value: todayFocusText)
            }
        }
        .padding(18)
        .background(arenaCardBackground(tint: accent, radius: 30, strength: 0.86))
    }

    private var newExamCollapsedCard: some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                showNewExamForm.toggle()
                if !showNewExamForm {
                    showManualBuilder = false
                }
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accent.opacity(0.13))
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(accent.opacity(0.16), lineWidth: 1)
                        )

                    Image(systemName: showNewExamForm ? "xmark" : "plus")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(showNewExamForm ? "Formu kapat" : tr("ha_add_new_exam"))
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(.white)

                    Text(showNewExamForm ? tr("ep_back_calendar") : tr("ep_pick_sub"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.48))
                }

                Spacer()

                Image(systemName: showNewExamForm ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(accent.opacity(0.9))
            }
            .padding(16)
            .background(arenaCardBackground(tint: accent, radius: 24, strength: 0.50))
        }
        .buttonStyle(.plain)
    }

    private var createExamCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: tr("ep_new_exam"), eyebrow: "CREATE PLAN", icon: "sparkles", tint: accent)

            Picker("Ders", selection: $selectedCourseID) {
                ForEach(courses) { course in
                    Text(course.code.isEmpty ? course.name : "\(course.code) • \(course.name)")
                        .tag(Optional(course.id))
                }
            }
            .pickerStyle(.menu)
            .tint(accent)

            Picker(tr("at_kind_exam"), selection: $selectedType) {
                ForEach(ExamPlannerType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Label(tr("eps_date"), systemImage: "calendar")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white.opacity(0.82))

                Spacer()

                DatePicker("", selection: $examDate, in: Date.now..., displayedComponents: .date)
                    .labelsHidden()
                    .tint(accent)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(accent)
                    Text(tr("eps_topics_caps"))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(accent)
                }

                TextField(tr("ep_topics_ph"), text: $examTopics)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .tint(accent)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.065))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
            }

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(accent)
                    Text(tr("ep_daily_hours"))
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white.opacity(0.82))
                }
                Spacer()
                Stepper("\(dailyStudyHours) saat", value: $dailyStudyHours, in: 1...12)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
            }

            if let err = aiPlanError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(err)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.orange.opacity(0.12))
                )
            }

            Button {
                Task { await createAIPlan() }
            } label: {
                HStack {
                    if isGeneratingAIPlan {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.black)
                            .scaleEffect(0.8)
                        Text(tr("ep_ai_preparing"))
                    } else {
                        Image(systemName: "sparkles")
                        Text(tr("ep_create_ai_caps"))
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                }
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent, secondaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: accent.opacity(0.20), radius: 14, y: 7)
                        .opacity(isGeneratingAIPlan ? 0.7 : 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isGeneratingAIPlan || selectedCourse == nil)

            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    showManualBuilder.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text(tr("ep_create_self_caps"))
                    Spacer()
                    Image(systemName: showManualBuilder ? "chevron.up" : "chevron.down")
                }
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.86))
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.060))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.085), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            if showManualBuilder {
                manualBuilderCard
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .background(arenaCardBackground(tint: accent, radius: 28, strength: 0.62))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var manualBuilderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Konu", text: $manualTopic)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)
                .tint(accent)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.065))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )

            DatePicker(tr("cs_day"), selection: $manualDate, displayedComponents: .date)
                .tint(accent)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)

            Stepper("\(tr("duration_label")): \(manualMinutes) \(tr("common_min_short"))", value: $manualMinutes, in: 15...180, step: 15)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)

            Button {
                createManualDay()
            } label: {
                HStack {
                    Image(systemName: "plus").accessibilityLabel(tr("common_add"))
                    Text(tr("ep_add_day_caps"))
                    Spacer()
                }
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(accent)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.070), lineWidth: 1)
                )
        )
    }

    private var examTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: tr("ep_exam_calendar"), eyebrow: "TIMELINE", icon: "calendar.badge.clock", tint: accent)

            if examGroups.isEmpty {
                emptyMiniCard(tr("ep_no_exams"), icon: "calendar")
            } else {
                VStack(spacing: 10) {
                    ForEach(examGroups, id: \.key) { group in
                        examTableRow(group.value)
                    }
                }
            }
        }
    }

    private var coursePlans: some View {
        Group {
            if !plannedCourses.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(title: tr("ep_course_plans"), eyebrow: "COURSE PLANS", icon: "book.closed.fill", tint: Color(arenaHex: AppArenaPalette.blue))

                    ForEach(plannedCourses) { course in
                        let items = scopedItems
                            .filter { $0.courseID == course.id }
                            .sorted { $0.studyDate < $1.studyDate }

                        VStack(spacing: 8) {
                            Button {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                    expandedCourseID = expandedCourseID == course.id ? nil : course.id
                                }
                            } label: {
                                courseHeader(course: course, items: items)
                            }
                            .buttonStyle(.plain)

                            if expandedCourseID == course.id {
                                VStack(spacing: 9) {
                                    ForEach(items) { item in
                                        planDayRow(item)
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                }
            }
        }
    }

    private func examTableRow(_ items: [ExamStudyPlanItem]) -> some View {
        guard let first = items.first else {
            return AnyView(EmptyView())
        }

        let completed = items.filter(\.isCompleted).count
        let total = items.count
        let progress = total == 0 ? 0 : Double(completed) / Double(total)

        return AnyView(
            HStack(spacing: 12) {
                progressCircle(progress)

                VStack(alignment: .leading, spacing: 4) {
                    Text(first.courseName)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("\(first.examType.title) • \(dateText(first.examDate))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.52))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(completed)/\(total)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(accent)

                    Text(daysLeftText(first.examDate))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.44))
                }
            }
            .padding(15)
            .background(rowBackground(tint: accent, isCompleted: completed == total && total > 0))
            .contextMenu {
                Button(role: .destructive) {
                    deleteExamPlan(items)
                } label: {
                    Label(tr("ep_delete_plan"), systemImage: "trash")
                }
            }
        )
    }

    private func courseHeader(course: Course, items: [ExamStudyPlanItem]) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color(arenaHex: AppArenaPalette.blue).opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color(arenaHex: AppArenaPalette.blue))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(tr("ep_day_plan", items.count))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
            }

            Spacer()

            Image(systemName: expandedCourseID == course.id ? "chevron.up" : "chevron.down")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(15)
        .background(rowBackground(tint: Color(arenaHex: AppArenaPalette.blue), isCompleted: false))
    }

    private func planDayRow(_ item: ExamStudyPlanItem) -> some View {
        HStack(spacing: 12) {
            Button {
                toggle(item)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : phaseIcon(item))
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(item.isCompleted ? Color(arenaHex: AppArenaPalette.green) : accent)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.topic)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    miniInfo(icon: "calendar", text: dateText(item.studyDate))
                    miniInfo(icon: "timer", text: "\(item.minutes) dk")

                    if Calendar.current.isDateInToday(item.studyDate) {
                        miniInfo(icon: "scope", text: "Focus")
                    }
                }
            }

            Spacer()

            if Calendar.current.isDateInToday(item.studyDate) {
                Button {
                    startFocusForPlan(item)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 31, height: 31)
                        .background(accent)
                        .clipShape(Circle())
                        .shadow(color: accent.opacity(0.18), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(rowBackground(tint: item.isCompleted ? Color(arenaHex: AppArenaPalette.green) : accent, isCompleted: item.isCompleted))
        .contextMenu {
            Button(role: .destructive) {
                deleteStudyDay(item)
            } label: {
                Label(tr("ep_delete_day"), systemImage: "trash")
            }
        }
    }

    @MainActor
    private func createAIPlan() async {
        guard let course = selectedCourse else { return }
        isGeneratingAIPlan = true
        aiPlanError = nil

        do {
            let system = PromptBuilder.examPlannerSystem()
            let user = PromptBuilder.examPlannerUser(
                courseName: course.name,
                examType: selectedType.title,
                examDate: examDate,
                topics: examTopics,
                dailyHours: dailyStudyHours,
                languageCode: Locale.current.identifier
            )

            let raw = try await AIService.shared.complete(system: system, user: user, feature: "exam-planner")

            // Strip possible markdown code fences
            var json = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if json.hasPrefix("```") {
                json = json.components(separatedBy: "\n").dropFirst().dropLast().joined(separator: "\n")
            }

            guard let data = json.data(using: .utf8),
                  let planDays = try? JSONDecoder().decode([AIStudyPlanDay].self, from: data) else {
                aiPlanError = tr("ep_parse_failed")
                isGeneratingAIPlan = false
                return
            }

            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withFullDate]
            let examGroupID = UUID()

            for day in planDays {
                guard let studyDate = fmt.date(from: day.date) else { continue }
                let isRevision = ["weakTopics", "mockExam", "finalReview"].contains(day.phase)
                let isWeakBoost = day.phase == "weakTopics"

                let item = ExamStudyPlanItem(
                    ownerUserID: ownerUserID,
                    courseID: course.id,
                    courseName: course.name,
                    courseCode: course.code,
                    examType: selectedType,
                    examDate: examDate,
                    studyDate: studyDate,
                    minutes: day.minutes,
                    topic: day.topic,
                    isRevisionDay: isRevision,
                    isWeakTopicBoost: isWeakBoost,
                    examGroupID: examGroupID
                )
                modelContext.insert(item)

                let task = DTTaskItem(
                    ownerUserID: ownerUserID,
                    title: "\(course.name) • \(day.topic)",
                    dueDate: studyDate,
                    notes: day.notes,
                    taskType: "exam_study",
                    colorName: "orange",
                    courseName: course.name,
                    workoutDurationMinutes: day.minutes,
                    scheduledWeekDate: studyDate,
                    scheduledWeekDurationMinutes: day.minutes,
                    linkedExamID: examGroupID,
                    studyTopic: day.topic
                )
                modelContext.insert(task)
            }

            try? modelContext.save()

            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                expandedCourseID = course.id
                showNewExamForm = false
                showManualBuilder = false
                isGeneratingAIPlan = false
            }
        } catch {
            aiPlanError = error.localizedDescription
            isGeneratingAIPlan = false
        }
    }

    private func createPlan() {
        guard let course = selectedCourse else { return }

        let generated = ExamPlannerEngine.generate(
            course: course,
            examType: selectedType,
            examDate: examDate,
            ownerUserID: ownerUserID
        )

        let examGroupID = UUID()

        for item in generated {
            item.examGroupID = examGroupID
            modelContext.insert(item)

            let task = DTTaskItem(
                ownerUserID: ownerUserID,
                title: "\(course.name) • \(item.topic)",
                isDone: false,
                dueDate: item.studyDate,
                notes: tr("ep_prep_for", selectedType.title),
                taskType: "exam_study",
                colorName: "orange",
                courseName: course.name,
                workoutDurationMinutes: item.minutes,
                scheduledWeekDate: item.studyDate,
                scheduledWeekDurationMinutes: item.minutes,
                linkedExamID: examGroupID,
                studyTopic: item.topic
            )

            modelContext.insert(task)
        }

        try? modelContext.save()

        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            expandedCourseID = course.id
            showNewExamForm = false
            showManualBuilder = false
        }
    }

    private func createManualDay() {
        guard let course = selectedCourse else { return }

        let groupID = UUID()

        let item = ExamStudyPlanItem(
            ownerUserID: ownerUserID,
            courseID: course.id,
            courseName: course.name,
            courseCode: course.code,
            examType: selectedType,
            examDate: examDate,
            studyDate: manualDate,
            minutes: manualMinutes,
            topic: manualTopic,
            isRevisionDay: manualTopic.lowercased().contains("tekrar"),
            isWeakTopicBoost: manualTopic.lowercased().contains(tr("ep_weak"))
        )

        item.examGroupID = groupID
        modelContext.insert(item)

        let task = DTTaskItem(
            ownerUserID: ownerUserID,
            title: "\(course.name) • \(manualTopic)",
            dueDate: manualDate,
            notes: tr("ep_prep_for", selectedType.title),
            taskType: "exam_study",
            colorName: "orange",
            courseName: course.name,
            workoutDurationMinutes: manualMinutes,
            scheduledWeekDate: manualDate,
            scheduledWeekDurationMinutes: manualMinutes,
            linkedExamID: groupID,
            studyTopic: manualTopic
        )

        modelContext.insert(task)
        try? modelContext.save()

        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            expandedCourseID = course.id
            showNewExamForm = false
            showManualBuilder = false
        }
    }

    private func toggle(_ item: ExamStudyPlanItem) {
        item.isCompleted.toggle()
        item.completedAt = item.isCompleted ? .now : nil
        try? modelContext.save()
    }

    private func deleteStudyDay(_ item: ExamStudyPlanItem) {
        let groupID = item.examGroupID
        let date = Calendar.current.startOfDay(for: item.studyDate)
        let topic = item.topic

        modelContext.delete(item)

        if let groupID {
            let tasks = (try? modelContext.fetch(FetchDescriptor<DTTaskItem>())) ?? []
            let matches = tasks.filter { task in
                guard task.linkedExamID == groupID else { return false }
                guard let taskDate = task.scheduledWeekDate ?? task.dueDate else { return false }

                return Calendar.current.isDate(taskDate, inSameDayAs: date)
                    && task.studyTopic == topic
            }

            for task in matches {
                modelContext.delete(task)
            }
        }

        try? modelContext.save()
    }

    private func deleteExamPlan(_ items: [ExamStudyPlanItem]) {
        guard let first = items.first else { return }
        let groupID = first.examGroupID

        for item in items {
            modelContext.delete(item)
        }

        if let groupID {
            let tasksToDelete = try? modelContext.fetch(FetchDescriptor<DTTaskItem>())
                .filter { $0.linkedExamID == groupID }

            tasksToDelete?.forEach { modelContext.delete($0) }
        }

        try? modelContext.save()
    }

    private func startFocusForPlan(_ item: ExamStudyPlanItem) {
        NotificationCenter.default.post(name: .openExamFocusFromPlanner, object: item.id.uuidString)
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

    private func compactMetric(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(accent)

            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.40))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(accent.opacity(0.075))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accent.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func miniInfo(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 10, weight: .black, design: .monospaced))
        .foregroundStyle(.white.opacity(0.46))
    }

    private func progressCircle(_ progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 5)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 38, height: 38)
    }

    private func emptyMiniCard(_ text: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(accent)

            Text(text)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(.white.opacity(0.62))

            Spacer()
        }
        .padding(15)
        .background(rowBackground(tint: accent, isCompleted: false))
    }

    private func rowBackground(tint: Color, isCompleted: Bool) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(isCompleted ? 0.060 : 0.075),
                        Color.white.opacity(0.035)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(tint.opacity(isCompleted ? 0.12 : 0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 10, y: 5)
    }

    private func arenaCardBackground(tint: Color, radius: CGFloat, strength: Double) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.075 + strength * 0.035),
                        Color(arenaHex: AppArenaPalette.purple).opacity(0.040),
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
                                tint.opacity(0.11 + strength * 0.08),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 8,
                            endRadius: 190
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(arenaHex: AppArenaPalette.blue).opacity(0.070),
                                Color.clear
                            ],
                            center: .bottomLeading,
                            startRadius: 8,
                            endRadius: 190
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(tint.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
    }

    private func phaseIcon(_ item: ExamStudyPlanItem) -> String {
        if item.isRevisionDay { return "arrow.triangle.2.circlepath" }
        if item.isWeakTopicBoost { return "exclamationmark.magnifyingglass" }
        return "circle"
    }

    private var heroTitle: String {
        guard let first = nextExamGroup?.first else {
            return tr("ep_build_plan")
        }

        return first.courseName
    }

    private var nextExamDateText: String {
        guard let first = nextExamGroup?.first else { return "-" }
        return dateText(first.examDate)
    }

    private var todayFocusText: String {
        let todayItems = scopedItems.filter {
            Calendar.current.isDateInToday($0.studyDate) && !$0.isCompleted
        }

        let minutes = todayItems.reduce(0) { $0 + $1.minutes }
        return minutes == 0 ? "Yok" : "\(minutes) dk"
    }

    private var riskText: String {
        guard let first = nextExamGroup?.first else { return "-" }

        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: first.examDate)
        ).day ?? 0

        let total = nextExamGroup?.count ?? 1
        let completed = nextExamGroup?.filter(\.isCompleted).count ?? 0
        let progress = Double(completed) / Double(max(total, 1))

        if days <= 3 && progress < 0.5 { return tr("prio_high") }
        if progress > 0.6 { return tr("ep_good") }
        return "Orta"
    }

    private func daysLeftText(_ date: Date) -> String {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: date)
        ).day ?? 0

        if days <= 0 { return tr("common_today") }
        if days == 1 { return tr("common_tomorrow") }
        return tr("ch_streak_days_n", days)
    }

    private func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }
}

// MARK: - AI Response Model

private struct AIStudyPlanDay: Decodable {
    let date: String
    let topic: String
    let minutes: Int
    let phase: String
    let notes: String
}

extension Notification.Name {
    static let openExamFocusFromPlanner = Notification.Name("openExamFocusFromPlanner")
}
