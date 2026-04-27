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
    @State private var manualTopic: String = "Soru çözümü"

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
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("Sınav Planı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                }
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
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [.orange.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 360
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [.purple.opacity(0.20), .clear],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }

    private var topHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Exam Planner")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)

                    Text(heroTitle)
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 52, height: 52)

                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }

            HStack(spacing: 8) {
                compactMetric(icon: "calendar", title: "Sınav", value: nextExamDateText)
                compactMetric(icon: "flame.fill", title: "Risk", value: riskText)
                compactMetric(icon: "timer", title: "Bugün", value: todayFocusText)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.18),
                            Color.purple.opacity(0.12),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(.white.opacity(0.09), lineWidth: 1)
                )
        )
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
                    Circle()
                        .fill(Color.orange.opacity(0.16))
                        .frame(width: 46, height: 46)

                    Image(systemName: showNewExamForm ? "xmark" : "plus")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(showNewExamForm ? "Formu kapat" : "Yeni sınav ekle")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(showNewExamForm ? "Takvime dön" : "Ders, tarih ve sınav tipini seç")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.48))
                }

                Spacer()

                Image(systemName: showNewExamForm ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.42))
            }
            .padding(16)
            .background(.white.opacity(0.065))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var createExamCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Ders", selection: $selectedCourseID) {
                ForEach(courses) { course in
                    Text(course.code.isEmpty ? course.name : "\(course.code) • \(course.name)")
                        .tag(Optional(course.id))
                }
            }
            .pickerStyle(.menu)
            .tint(.orange)

            Picker("Sınav", selection: $selectedType) {
                ForEach(ExamPlannerType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Label("Tarih", systemImage: "calendar")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))

                Spacer()

                DatePicker("", selection: $examDate, in: Date.now..., displayedComponents: .date)
                    .labelsHidden()
                    .tint(.orange)
            }

            Button {
                createPlan()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Akıllı Plan Oluştur")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 15)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }

            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    showManualBuilder.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("Kendin oluştur")
                    Spacer()
                    Image(systemName: showManualBuilder ? "chevron.up" : "chevron.down")
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(.white.opacity(0.065))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            if showManualBuilder {
                manualBuilderCard
            }
        }
        .padding(18)
        .background(.white.opacity(0.075))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var manualBuilderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Konu", text: $manualTopic)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(14)
                .background(.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            DatePicker("Gün", selection: $manualDate, displayedComponents: .date)
                .tint(.orange)

            Stepper("Süre: \(manualMinutes) dk", value: $manualMinutes, in: 15...180, step: 15)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Button {
                createManualDay()
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Günü Ekle")
                    Spacer()
                }
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .padding(14)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(15)
        .background(.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var examTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Sınav Takvimi", icon: "calendar.badge.clock")

            if examGroups.isEmpty {
                emptyMiniCard("Henüz sınav yok", icon: "calendar")
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
                    sectionTitle("Ders Planları", icon: "book.closed.fill")

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
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("\(first.examType.title) • \(dateText(first.examDate))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(completed)/\(total)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.orange)

                    Text(daysLeftText(first.examDate))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.48))
                }
            }
            .padding(15)
            .background(.white.opacity(0.065))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contextMenu {
                Button(role: .destructive) {
                    deleteExamPlan(items)
                } label: {
                    Label("Sınav planını sil", systemImage: "trash")
                }
            }
        )
    }

    private func courseHeader(course: Course, items: [ExamStudyPlanItem]) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.14))
                    .frame(width: 44, height: 44)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text("\(items.count) günlük plan")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
            }

            Spacer()

            Image(systemName: expandedCourseID == course.id ? "chevron.up" : "chevron.down")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(15)
        .background(.white.opacity(0.065))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func planDayRow(_ item: ExamStudyPlanItem) -> some View {
        HStack(spacing: 12) {
            Button {
                toggle(item)
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : phaseIcon(item))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(item.isCompleted ? .green : .orange)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.topic)
                    .font(.system(size: 15, weight: .black, design: .rounded))
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
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 30, height: 30)
                        .background(.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(.white.opacity(item.isCompleted ? 0.035 : 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contextMenu {
            Button(role: .destructive) {
                deleteStudyDay(item)
            } label: {
                Label("Bu günü sil", systemImage: "trash")
            }
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
                notes: "\(selectedType.title) hazırlığı",
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
            isWeakTopicBoost: manualTopic.lowercased().contains("zayıf")
        )

        item.examGroupID = groupID
        modelContext.insert(item)

        let task = DTTaskItem(
            ownerUserID: ownerUserID,
            title: "\(course.name) • \(manualTopic)",
            dueDate: manualDate,
            notes: "\(selectedType.title) hazırlığı",
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

    private func sectionTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.orange)

            Text(title)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Spacer()
        }
    }

    private func compactMetric(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.orange)

            Text(value)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(.white.opacity(0.065))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func miniInfo(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .foregroundStyle(.white.opacity(0.52))
    }

    private func progressCircle(_ progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 5)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(.orange, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 38, height: 38)
    }

    private func emptyMiniCard(_ text: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.orange)

            Text(text)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))

            Spacer()
        }
        .padding(15)
        .background(.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func phaseIcon(_ item: ExamStudyPlanItem) -> String {
        if item.isRevisionDay { return "arrow.triangle.2.circlepath" }
        if item.isWeakTopicBoost { return "exclamationmark.magnifyingglass" }
        return "circle"
    }

    private var heroTitle: String {
        guard let first = nextExamGroup?.first else {
            return "Sınav planını kur"
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

        if days <= 3 && progress < 0.5 { return "Yüksek" }
        if progress > 0.6 { return "İyi" }
        return "Orta"
    }

    private func daysLeftText(_ date: Date) -> String {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: date)
        ).day ?? 0

        if days <= 0 { return "Bugün" }
        if days == 1 { return "Yarın" }
        return "\(days) gün"
    }

    private func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }
}

extension Notification.Name {
    static let openExamFocusFromPlanner = Notification.Name("openExamFocusFromPlanner")
}
