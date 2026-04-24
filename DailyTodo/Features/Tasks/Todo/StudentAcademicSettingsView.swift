//
//  StudentAcademicSettingsView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 25.04.2026.
//

import SwiftUI

struct StudentAcademicSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var studentStore: StudentStore

    @State private var gradeLevel = "1"
    @State private var institutionName = ""
    @State private var institutionCountry = "cy"
    @State private var majorName = ""

    @State private var courseCode = ""
    @State private var courseName = ""

    @State private var showUniversityPicker = false
    @State private var selectedUniversityID: UUID?
    @State private var selectedMajorID: UUID?
    @State private var majors: [CatalogMajor] = []
    @State private var suggestedCourses: [CatalogCurriculumCourse] = []
    @State private var isLoading = false
    @State private var isSavingCourse = false

    private let years = ["prep", "1", "2", "3", "4", "5", "6"]

    var body: some View {
        NavigationStack {
            Form {
                schoolSection
                majorSection
                suggestionsSection
                myCoursesSection
                manualCourseSection
            }
            .navigationTitle("Öğrenci Bilgileri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kaydet") { saveProfile() }
                        .fontWeight(.bold)
                }
            }
            .onAppear { loadCurrentValues() }
            .onChange(of: institutionName) { _, _ in
                Task { await loadMajors() }
            }
            .onChange(of: majorName) { _, _ in
                Task { await loadSuggestions() }
            }
            .onChange(of: gradeLevel) { _, _ in
                Task { await loadSuggestions() }
            }
            .sheet(isPresented: $showUniversityPicker) {
                UniversityPickerSheet(
                    selectedUniversityID: $selectedUniversityID,
                    selectedUniversityName: $institutionName,
                    selectedCountryCode: $institutionCountry
                )
            }
        }
    }

    private var schoolSection: some View {
        Section("Okul") {
            Button {
                showUniversityPicker = true
            } label: {
                HStack {
                    Label(
                        institutionName.isEmpty ? "Üniversite seç" : institutionName,
                        systemImage: "building.columns.fill"
                    )

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }

            Picker("Yıl", selection: $gradeLevel) {
                ForEach(years, id: \.self) { year in
                    Text(yearTitle(year)).tag(year)
                }
            }
        }
    }

    private var majorSection: some View {
        Section("Bölüm") {
            if majors.isEmpty {
                TextField("Bölüm adı", text: $majorName)
            } else {
                Picker("Bölüm", selection: $majorName) {
                    ForEach(majors) { major in
                        Text(major.name).tag(major.name)
                    }
                }
            }
        }
    }

    private var suggestionsSection: some View {
        Section("Önerilen Dersler") {
            if isLoading {
                ProgressView()
            } else if suggestedCourses.isEmpty {
                Text("Bu seçim için katalog dersi bulunamadı.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(suggestedCourses) { course in
                    suggestedCourseRow(course)
                }
            }
        }
    }

    private func suggestedCourseRow(_ course: CatalogCurriculumCourse) -> some View {
        let alreadyAdded = isCourseAlreadyAdded(
            code: course.course_code,
            name: course.course_name
        )

        return Button {
            guard !alreadyAdded else { return }

            Task {
                isSavingCourse = true

                await studentStore.addCourseAndSync(
                    name: course.course_name,
                    code: course.course_code,
                    sourceType: "catalog",
                    yearNumber: course.year_number,
                    termNumber: course.term_number
                )

                isSavingCourse = false
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(course.course_name)
                        .foregroundStyle(alreadyAdded ? Color.secondary : Color.blue)

                    Text(course.course_code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .foregroundStyle(alreadyAdded ? .green : .blue)
            }
        }
        .disabled(alreadyAdded || isSavingCourse)
    }

    private var myCoursesSection: some View {
        Section("Derslerim") {
            if uniqueStudentCourses.isEmpty {
                Text("Henüz ders yok.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(uniqueStudentCourses) { course in
                    myCourseRow(course)
                }
            }
        }
    }

    private func myCourseRow(_ course: Course) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(course.name)

                if !course.code.isEmpty {
                    Text(course.code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(role: .destructive) {
                Task {
                    await studentStore.deleteCourseAndSync(course)
                }
            } label: {
                Image(systemName: "trash")
            }
        }
    }

    private var manualCourseSection: some View {
        Section("Manuel Ders Ekle") {
            TextField("Kod", text: $courseCode)
                .textInputAutocapitalization(.characters)

            TextField("Ders adı", text: $courseName)

            Button {
                addManualCourse()
            } label: {
                Label("Dersi Ekle", systemImage: "plus.circle.fill")
            }
            .disabled(courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSavingCourse)
        }
    }

    private var uniqueStudentCourses: [Course] {
        var seen = Set<String>()

        return studentStore.courses.filter { course in
            let key = "\(course.code.uppercased())-\(course.name.uppercased())"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private func isCourseAlreadyAdded(code: String, name: String) -> Bool {
        uniqueStudentCourses.contains {
            $0.code.caseInsensitiveCompare(code) == .orderedSame &&
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    private func addManualCourse() {
        let name = courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = courseCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard !name.isEmpty else { return }

        Task {
            isSavingCourse = true

            await studentStore.addCourseAndSync(
                name: name,
                code: code,
                sourceType: "manual"
            )

            isSavingCourse = false
            courseCode = ""
            courseName = ""
        }
    }

    private func loadCurrentValues() {
        studentStore.reload()

        if let profile = studentStore.profile {
            gradeLevel = profile.gradeLevel
            institutionName = profile.institutionName ?? ""
            institutionCountry = profile.institutionCountry ?? "cy"
            majorName = profile.majorName ?? ""
        }

        Task {
            await resolveUniversityAndMajor()
            await loadSuggestions()
        }
    }

    private func resolveUniversityAndMajor() async {
        let trimmedUniversity = institutionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUniversity.isEmpty else { return }

        do {
            let universities = try await StudentCatalogService.fetchUniversities(
                countryCode: institutionCountry,
                query: trimmedUniversity
            )

            guard let matchedUniversity = universities.first(where: {
                $0.name.caseInsensitiveCompare(trimmedUniversity) == .orderedSame
            }) ?? universities.first else {
                return
            }

            selectedUniversityID = matchedUniversity.id

            let loadedMajors = try await StudentCatalogService.fetchMajors(
                universityID: matchedUniversity.id
            )

            majors = loadedMajors

            let trimmedMajor = majorName.trimmingCharacters(in: .whitespacesAndNewlines)

            if let matchedMajor = loadedMajors.first(where: {
                $0.name.caseInsensitiveCompare(trimmedMajor) == .orderedSame
            }) {
                selectedMajorID = matchedMajor.id
                majorName = matchedMajor.name
            }
        } catch {
            print("❌ resolveUniversityAndMajor error:", error)
        }
    }

    private func saveProfile() {
        let current = studentStore.profile

        studentStore.saveStudentProfile(
            educationLevel: current?.educationLevel ?? "university",
            gradeLevel: gradeLevel,
            highSchoolTrack: current?.highSchoolTrack,
            institutionName: institutionName,
            institutionCountry: institutionCountry,
            majorName: majorName,
            dailyStudyGoalMinutes: current?.dailyStudyGoalMinutes ?? 120,
            weeklyStudyGoalMinutes: current?.weeklyStudyGoalMinutes ?? 840
        )

        studentStore.reload()
        dismiss()
    }

    private func loadMajors() async {
        if selectedUniversityID == nil {
            await resolveUniversityAndMajor()
            return
        }

        guard let selectedUniversityID else { return }

        do {
            majors = try await StudentCatalogService.fetchMajors(universityID: selectedUniversityID)

            if let matched = majors.first(where: {
                $0.name.caseInsensitiveCompare(majorName) == .orderedSame
            }) {
                selectedMajorID = matched.id
                majorName = matched.name
            } else if majorName.isEmpty, let first = majors.first {
                majorName = first.name
                selectedMajorID = first.id
            }

            await loadSuggestions()
        } catch {
            print("❌ loadMajors error:", error)
        }
    }

    private func loadSuggestions() async {
        guard !majorName.isEmpty else { return }

        if selectedMajorID == nil {
            selectedMajorID = majors.first(where: { $0.name == majorName })?.id
        }

        guard let selectedMajorID else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            suggestedCourses = try await StudentCatalogService.fetchCurriculumCourses(
                majorID: selectedMajorID,
                gradeLevel: gradeLevel
            )
        } catch {
            print("❌ loadSuggestions error:", error)
            suggestedCourses = []
        }
    }

    private func yearTitle(_ value: String) -> String {
        switch value {
        case "prep": return "Hazırlık"
        case "1": return "1. Year"
        case "2": return "2. Year"
        case "3": return "3. Year"
        case "4": return "4. Year"
        case "5": return "5. Year"
        case "6": return "6. Year"
        default: return value
        }
    }
}
