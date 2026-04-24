//
//  CourseSetupSheet.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 24.04.2026.
//

import SwiftUI

struct CourseSetupSheet: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var studentStore: StudentStore

    @State private var catalogCourses: [CatalogCurriculumCourse] = []
    @State private var selectedIDs: Set<UUID> = []

    @State private var manualCode = ""
    @State private var manualName = ""

    @State private var loading = false

    var body: some View {
        NavigationStack {
            List {
                profileSection
                catalogSection
                manualSection
                currentCoursesSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("Derslerini Seç")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadCatalog()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kaydet") {
                        saveSelected()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    var profileSection: some View {
        Section("Profil") {
            VStack(alignment: .leading, spacing: 8) {
                Text(studentStore.profile?.institutionName ?? "-")
                Text(studentStore.profile?.majorName ?? "-")
                    .foregroundStyle(.secondary)
            }
        }
    }

    var catalogSection: some View {
        Section("Önerilen Dersler") {
            if loading {
                ProgressView()
            } else {
                ForEach(catalogCourses) { item in
                    Button {
                        toggle(item.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.course_name)
                                Text(item.course_code)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedIDs.contains(item.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    var manualSection: some View {
        Section("Manuel Ekle") {
            TextField("Kod", text: $manualCode)
            TextField("Ders Adı", text: $manualName)

            Button("Ekle") {
                studentStore.addCourse(
                    name: manualName,
                    code: manualCode,
                    sourceType: "manual"
                )

                manualCode = ""
                manualName = ""
            }
        }
    }

    var currentCoursesSection: some View {
        Section("Mevcut Dersler") {
            ForEach(studentStore.courses) { course in
                Text("\(course.code) \(course.name)")
            }
        }
    }

    func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func saveSelected() {
        for item in catalogCourses where selectedIDs.contains(item.id) {
            studentStore.addCourse(
                name: item.course_name,
                code: item.course_code,
                sourceType: "catalog",
                yearNumber: item.year_number,
                termNumber: item.term_number
            )
        }
    }

    func loadCatalog() async {
        guard let major = studentStore.profile?.majorName else { return }
        _ = major

        loading = true
        defer { loading = false }

        guard let profile = studentStore.profile else { return }

        do {
            let universities = try await StudentCatalogService.fetchUniversities(
                countryCode: profile.institutionCountry ?? "CY"
            )

            guard let uni = universities.first(where: {
                $0.name == profile.institutionName
            }) else { return }

            let majors = try await StudentCatalogService.fetchMajors(
                universityID: uni.id
            )

            guard let major = majors.first(where: {
                $0.name == profile.majorName
            }) else { return }

            catalogCourses =
                try await StudentCatalogService.fetchCurriculumCourses(
                    majorID: major.id,
                    gradeLevel: profile.gradeLevel
                )

        } catch {
            print(error)
        }
    }
}
