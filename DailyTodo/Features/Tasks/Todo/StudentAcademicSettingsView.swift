//
//  StudentAcademicSettingsView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 25.04.2026.
//

import SwiftUI
import UIKit

struct StudentAcademicSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var studentStore: StudentStore

    @State private var gradeLevel = "1"
    @State private var institutionName = ""
    @State private var institutionCountry = "kktc"
    @State private var majorName = ""

    @State private var courseCode = ""
    @State private var courseName = ""

    @State private var showUniversityPicker = false
    @State private var showMajorPicker = false

    @State private var selectedUniversityID: UUID?
    @State private var selectedMajorID: UUID?

    @State private var majors: [CatalogMajor] = []
    @State private var suggestedCourses: [CatalogCurriculumCourse] = []

    @State private var isResolvingCatalog = false
    @State private var isLoadingMajors = false
    @State private var isLoadingSuggestions = false
    @State private var isSavingCourse = false
    @State private var isSavingProfile = false

    @State private var catalogError: String?
    @State private var majorLoadError: String?
    @State private var suggestionsError: String?

    @State private var universityRequestID = UUID()
    @State private var majorRequestID = UUID()
    @State private var suggestionRequestID = UUID()

    @FocusState private var focusedField: Field?

    private let years = ["prep", "1", "2", "3", "4", "5", "6"]

    private enum Field {
        case customMajor
        case courseCode
        case courseName
    }

    private var accent: Color { Color(academicSettingsHex: AcademicSettingsPalette.cyan) }
    private var secondaryAccent: Color { Color(academicSettingsHex: AcademicSettingsPalette.purple) }
    private var gold: Color { Color(academicSettingsHex: AcademicSettingsPalette.gold) }
    private var green: Color { Color(academicSettingsHex: AcademicSettingsPalette.green) }
    private var coral: Color { Color(academicSettingsHex: AcademicSettingsPalette.coral) }
    private var blue: Color { Color(academicSettingsHex: AcademicSettingsPalette.blue) }

    private var canSaveProfile: Bool {
        !institutionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !majorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSavingProfile
    }

    private var canAddManualCourse: Bool {
        !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSavingCourse
    }

    private var selectedMajor: CatalogMajor? {
        if let selectedMajorID {
            return majors.first { $0.id == selectedMajorID }
        }

        return majors.first {
            normalizedSearchKey($0.name) == normalizedSearchKey(majorName)
        }
    }

    var body: some View {
        ZStack {
            AcademicSettingsBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    schoolSection
                    majorSection
                    suggestionsSection
                    myCoursesSection
                    manualCourseSection

                    Color.clear.frame(height: 34)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
        .task {
            loadCurrentValues()
            await resolveUniversityAndMajor()
        }
        .onChange(of: selectedUniversityID) { _, newValue in
            handleUniversityIDChanged(newValue)
        }
        .sheet(isPresented: $showUniversityPicker) {
            UniversityPickerSheet(
                selectedUniversityID: $selectedUniversityID,
                selectedUniversityName: $institutionName,
                selectedCountryCode: $institutionCountry
            )
        }
        .sheet(isPresented: $showMajorPicker) {
            AcademicMajorPickerSheet(
                majors: majors,
                selectedMajorID: selectedMajorID,
                selectedMajorName: majorName,
                isLoading: isLoadingMajors || isResolvingCatalog,
                errorText: majorLoadError,
                onRetry: {
                    Task {
                        await loadMajorsForSelectedUniversity()
                    }
                },
                onSelect: { major in
                    selectMajor(major)
                    showMajorPicker = false
                },
                onManualMajor: { text in
                    handleManualMajorTextChanged(text)
                    showMajorPicker = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
    }
}

// MARK: - Header

private extension StudentAcademicSettingsView {
    var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accent, secondaryAccent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 22, height: 2)

                        Text("ACADEMIC SETUP")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(2.1)
                            .foregroundStyle(accent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Student")
                            .font(.system(size: 42, weight: .heavy))
                            .tracking(-1.0)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Text("Academic profile.")
                            .font(.system(size: 19, weight: .semibold))
                            .tracking(-0.2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [accent, secondaryAccent, coral],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.070))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.105), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            Text("Update your university, major, year and courses. Updo uses this setup across Home, Focus, Week and Insights.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.50))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                saveProfile()
            } label: {
                primaryActionButton(
                    title: isSavingProfile ? "SAVING..." : "SAVE ACADEMIC PROFILE",
                    icon: isSavingProfile ? "clock" : "checkmark.circle.fill",
                    tint: canSaveProfile ? accent : Color.white.opacity(0.16),
                    foreground: canSaveProfile ? .black : .white.opacity(0.46)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSaveProfile)
        }
        .padding(.top, 4)
    }
}

// MARK: - School

private extension StudentAcademicSettingsView {
    var schoolSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: "SCHOOL",
                title: "University",
                icon: "building.columns.fill",
                tint: accent
            )

            Button {
                focusedField = nil
                showUniversityPicker = true
            } label: {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accent.opacity(0.13))
                        .frame(width: 46, height: 46)
                        .overlay(
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(accent)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("UNIVERSITY")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.1)
                            .foregroundStyle(.white.opacity(0.38))

                        Text(institutionName.isEmpty ? "Choose university" : institutionName)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(institutionName.isEmpty ? .white.opacity(0.42) : .white)
                            .lineLimit(2)

                        if !institutionCountry.isEmpty {
                            Text(displayCountry(institutionCountry))
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(accent.opacity(0.82))
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white.opacity(0.30))
                }
                .padding(13)
                .background(rowSurface(tint: accent))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 11) {
                Text("YEAR")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.38))

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 2),
                    spacing: 9
                ) {
                    ForEach(years, id: \.self) { year in
                        yearButton(year)
                    }
                }
            }
            .padding(13)
            .background(rowSurface(tint: blue))
        }
        .padding(16)
        .background(cardSurface(tint: accent, radius: 28))
    }

    func yearButton(_ year: String) -> some View {
        let isSelected = gradeLevel == year

        return Button {
            guard gradeLevel != year else { return }

            gradeLevel = year
            resetSuggestionsState(clearError: true)

            Task {
                await loadSuggestions()
            }

            AcademicSettingsHaptics.softTap()
        } label: {
            Text(yearTitle(year))
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(isSelected ? .black.opacity(0.80) : .white.opacity(0.82))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [accent, secondaryAccent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(Color.white.opacity(0.060))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.070),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Major

private extension StudentAcademicSettingsView {
    var majorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: "MAJOR",
                title: "Department",
                icon: "graduationcap.fill",
                tint: secondaryAccent
            )

            if institutionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                infoNotice(
                    icon: "building.columns",
                    title: "Choose university first",
                    subtitle: "Major catalog will load after university selection.",
                    tint: secondaryAccent
                )
            } else if isLoadingMajors || isResolvingCatalog {
                loadingRow(
                    title: "Loading majors",
                    subtitle: "Finding departments for your university.",
                    tint: secondaryAccent
                )
            } else if let majorLoadError {
                errorNotice(
                    title: "Major catalog unavailable",
                    message: majorLoadError,
                    tint: coral
                ) {
                    Task {
                        await loadMajorsForSelectedUniversity()
                    }
                }
            } else {
                compactMajorCard

                if majors.isEmpty {
                    customMajorField
                        .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .background(cardSurface(tint: secondaryAccent, radius: 28))
    }

    var compactMajorCard: some View {
        Button {
            focusedField = nil

            if majors.isEmpty {
                Task {
                    await loadMajorsForSelectedUniversity()
                    showMajorPicker = true
                }
            } else {
                showMajorPicker = true
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(secondaryAccent.opacity(0.13))
                        .frame(width: 46, height: 46)

                    Image(systemName: selectedMajorID == nil ? "graduationcap" : "graduationcap.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(secondaryAccent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("DEPARTMENT")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.38))

                    Text(majorName.isEmpty ? "Choose major" : majorName)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(majorName.isEmpty ? .white.opacity(0.42) : .white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let selectedMajor {
                        HStack(spacing: 7) {
                            if let faculty = selectedMajor.faculty_name, !faculty.isEmpty {
                                Text(faculty)
                            }

                            if let language = selectedMajor.language, !language.isEmpty {
                                Text(language)
                            }
                        }
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(secondaryAccent.opacity(0.82))
                        .lineLimit(1)
                    } else if majors.isEmpty {
                        Text("Manual entry available")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(0.6)
                            .foregroundStyle(.white.opacity(0.34))
                    } else {
                        Text("\(majors.count) majors ready")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(0.6)
                            .foregroundStyle(secondaryAccent.opacity(0.82))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.white.opacity(0.30))
            }
            .padding(13)
            .background(rowSurface(tint: secondaryAccent))
        }
        .buttonStyle(.plain)
    }

    var customMajorField: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("CUSTOM MAJOR")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.38))

            HStack(spacing: 10) {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(secondaryAccent)

                TextField(
                    "",
                    text: Binding(
                        get: { majorName },
                        set: { newValue in
                            handleManualMajorTextChanged(newValue)
                        }
                    ),
                    prompt: Text("Type your department").foregroundStyle(.white.opacity(0.30))
                )
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .customMajor)
            }
            .padding(.horizontal, 13)
            .frame(height: 52)
            .background(inputSurface(tint: secondaryAccent))
        }
        .padding(13)
        .background(rowSurface(tint: secondaryAccent))
    }
}

// MARK: - Suggestions

private extension StudentAcademicSettingsView {
    var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: "CATALOG",
                title: "Recommended courses",
                icon: "books.vertical.fill",
                tint: gold
            )

            if isLoadingSuggestions {
                loadingRow(
                    title: "Loading courses",
                    subtitle: "Preparing suggestions for \(yearTitle(gradeLevel)).",
                    tint: gold
                )
            } else if let suggestionsError {
                errorNotice(
                    title: "Course catalog unavailable",
                    message: suggestionsError,
                    tint: coral
                ) {
                    Task {
                        await loadSuggestions()
                    }
                }
            } else if suggestedCourses.isEmpty {
                infoNotice(
                    icon: "book.closed",
                    title: "No catalog courses",
                    subtitle: majorName.isEmpty ? "Choose a major first." : "You can add courses manually.",
                    tint: gold
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(suggestedCourses) { course in
                        suggestedCourseRow(course)
                    }
                }
            }
        }
        .padding(16)
        .background(cardSurface(tint: gold, radius: 28))
    }

    func suggestedCourseRow(_ course: CatalogCurriculumCourse) -> some View {
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

                studentStore.reload()
                isSavingCourse = false
                AcademicSettingsHaptics.success()
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill((alreadyAdded ? green : gold).opacity(alreadyAdded ? 0.18 : 0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(alreadyAdded ? green : gold)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(course.course_name)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(alreadyAdded ? .white.opacity(0.58) : .white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 7) {
                        if !course.course_code.isEmpty {
                            miniLabel(course.course_code, tint: gold)
                        }

                        miniLabel("Y\(course.year_number) T\(course.term_number ?? 0)", tint: .white.opacity(0.46))

                        if course.is_elective == true {
                            miniLabel("ELECTIVE", tint: secondaryAccent)
                        }
                    }
                }

                Spacer()
            }
            .padding(13)
            .background(rowSurface(tint: alreadyAdded ? green : gold))
        }
        .buttonStyle(.plain)
        .disabled(alreadyAdded || isSavingCourse)
    }
}

// MARK: - My Courses

private extension StudentAcademicSettingsView {
    var myCoursesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: "ACTIVE",
                title: "My courses",
                icon: "checkmark.seal.fill",
                tint: blue
            )

            if uniqueStudentCourses.isEmpty {
                infoNotice(
                    icon: "tray",
                    title: "No active courses",
                    subtitle: "Add catalog or manual courses.",
                    tint: blue
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(uniqueStudentCourses) { course in
                        myCourseRow(course)
                    }
                }
            }
        }
        .padding(16)
        .background(cardSurface(tint: blue, radius: 28))
    }

    func myCourseRow(_ course: Course) -> some View {
        let tint = colorFromHex(course.colorHex, fallback: blue)

        return HStack(spacing: 12) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)
                .shadow(color: tint.opacity(0.22), radius: 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if !course.code.isEmpty {
                    Text(course.code.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(.white.opacity(0.42))
                }
            }

            Spacer()

            Button(role: .destructive) {
                Task {
                    await studentStore.deleteCourseAndSync(course)
                    studentStore.reload()
                    AcademicSettingsHaptics.softTap()
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(coral)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(coral.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(13)
        .background(rowSurface(tint: tint))
    }
}

// MARK: - Manual Course

private extension StudentAcademicSettingsView {
    var manualCourseSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: "CUSTOM COURSE",
                title: "Add manually",
                icon: "plus.circle.fill",
                tint: green
            )

            HStack(spacing: 10) {
                courseTextField(
                    placeholder: "Code",
                    text: $courseCode,
                    icon: "number",
                    tint: green,
                    capitalization: .characters
                )
                .frame(width: 112)
                .focused($focusedField, equals: .courseCode)

                courseTextField(
                    placeholder: "Course name",
                    text: $courseName,
                    icon: "pencil",
                    tint: green,
                    capitalization: .words
                )
                .focused($focusedField, equals: .courseName)
            }

            Button {
                addManualCourse()
            } label: {
                primaryActionButton(
                    title: isSavingCourse ? "ADDING..." : "ADD COURSE",
                    icon: isSavingCourse ? "clock" : "plus.circle.fill",
                    tint: canAddManualCourse ? green : Color.white.opacity(0.16),
                    foreground: canAddManualCourse ? .black : .white.opacity(0.46)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canAddManualCourse)
        }
        .padding(16)
        .background(cardSurface(tint: green, radius: 28))
    }
}

// MARK: - Logic

private extension StudentAcademicSettingsView {
    var uniqueStudentCourses: [Course] {
        var seen = Set<String>()

        return studentStore.courses.filter { course in
            let key = "\(course.code.uppercased())-\(course.name.uppercased())"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    func loadCurrentValues() {
        studentStore.reload()

        if let profile = studentStore.profile {
            gradeLevel = profile.gradeLevel
            institutionName = profile.institutionName ?? ""
            institutionCountry = normalizedCountryCode(profile.institutionCountry)
            majorName = profile.majorName ?? ""
        } else {
            institutionCountry = "kktc"
        }
    }

    func handleUniversityIDChanged(_ newValue: UUID?) {
        resetMajorState(clearMajorName: true)
        resetSuggestionsState(clearError: true)

        guard newValue != nil else { return }

        Task {
            await loadMajorsForSelectedUniversity()
        }
    }

    @MainActor
    func resolveUniversityAndMajor() async {
        let trimmedUniversity = institutionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUniversity.isEmpty else { return }

        let requestID = UUID()
        universityRequestID = requestID
        isResolvingCatalog = true
        catalogError = nil

        defer {
            if universityRequestID == requestID {
                isResolvingCatalog = false
            }
        }

        do {
            let country = normalizedCountryCode(institutionCountry)

            let universities = try await StudentCatalogService.fetchUniversities(
                countryCode: country,
                query: trimmedUniversity
            )

            guard universityRequestID == requestID else { return }

            guard let matchedUniversity = bestUniversityMatch(
                universities: universities,
                profileInstitutionName: trimmedUniversity
            ) else {
                catalogError = "University catalog match not found."
                selectedUniversityID = nil
                return
            }

            selectedUniversityID = matchedUniversity.id
            institutionName = matchedUniversity.name
            institutionCountry = matchedUniversity.country_code

            await loadMajorsForSelectedUniversity(preferredMajorName: majorName)
        } catch {
            guard universityRequestID == requestID else { return }

            catalogError = error.localizedDescription
            selectedUniversityID = nil
            majors = []
            suggestedCourses = []

            print("❌ resolveUniversityAndMajor error:", error.localizedDescription)
        }
    }

    @MainActor
    func loadMajorsForSelectedUniversity(preferredMajorName: String? = nil) async {
        guard let selectedUniversityID else {
            majors = []
            return
        }

        let requestID = UUID()
        majorRequestID = requestID

        isLoadingMajors = true
        majorLoadError = nil

        resetSuggestionsState(clearError: true)

        defer {
            if majorRequestID == requestID {
                isLoadingMajors = false
            }
        }

        do {
            let loadedMajors = try await StudentCatalogService.fetchMajors(
                universityID: selectedUniversityID
            )

            guard majorRequestID == requestID else { return }

            majors = loadedMajors

            let targetMajorName = (preferredMajorName ?? majorName)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !targetMajorName.isEmpty,
               let matchedMajor = bestMajorMatch(
                majors: loadedMajors,
                profileMajorName: targetMajorName
               ) {
                selectedMajorID = matchedMajor.id
                majorName = matchedMajor.name
                await loadSuggestions()
            } else {
                selectedMajorID = nil
                majorName = ""
                suggestedCourses = []
            }
        } catch {
            guard majorRequestID == requestID else { return }

            majors = []
            selectedMajorID = nil
            majorName = ""
            suggestedCourses = []
            majorLoadError = error.localizedDescription

            print("❌ loadMajors error:", error.localizedDescription)
        }
    }

    func selectMajor(_ major: CatalogMajor) {
        selectedMajorID = major.id
        majorName = major.name

        resetSuggestionsState(clearError: true)

        Task {
            await loadSuggestions()
        }

        AcademicSettingsHaptics.softTap()
    }

    func handleManualMajorTextChanged(_ newValue: String) {
        majorName = newValue

        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if let matched = bestMajorMatch(majors: majors, profileMajorName: trimmed) {
            if selectedMajorID != matched.id {
                selectedMajorID = matched.id
                resetSuggestionsState(clearError: true)

                Task {
                    await loadSuggestions()
                }
            }
        } else {
            selectedMajorID = nil
            resetSuggestionsState(clearError: true)
        }
    }

    @MainActor
    func loadSuggestions() async {
        let requestID = UUID()
        suggestionRequestID = requestID

        guard let selectedMajorID else {
            suggestedCourses = []
            isLoadingSuggestions = false
            return
        }

        isLoadingSuggestions = true
        suggestionsError = nil

        defer {
            if suggestionRequestID == requestID {
                isLoadingSuggestions = false
            }
        }

        do {
            let courses = try await StudentCatalogService.fetchCurriculumCourses(
                majorID: selectedMajorID,
                gradeLevel: gradeLevel
            )

            guard suggestionRequestID == requestID else { return }

            guard self.selectedMajorID == selectedMajorID else {
                print("⚪️ settings suggestions ignored: major changed")
                return
            }

            suggestedCourses = courses
            suggestionsError = nil
        } catch {
            guard suggestionRequestID == requestID else { return }

            suggestedCourses = []
            suggestionsError = error.localizedDescription

            print("❌ loadSuggestions error:", error.localizedDescription)
        }
    }

    func resetMajorState(clearMajorName: Bool) {
        majorRequestID = UUID()

        majors = []
        selectedMajorID = nil
        majorLoadError = nil

        if clearMajorName {
            majorName = ""
        }
    }

    func resetSuggestionsState(clearError: Bool) {
        suggestionRequestID = UUID()

        suggestedCourses = []
        isLoadingSuggestions = false

        if clearError {
            suggestionsError = nil
        }
    }

    func saveProfile() {
        guard canSaveProfile else { return }

        isSavingProfile = true

        let current = studentStore.profile
        let cleanInstitutionName = institutionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMajorName = majorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCountry = normalizedCountryCode(institutionCountry)

        studentStore.saveStudentProfile(
            educationLevel: current?.educationLevel ?? "university",
            gradeLevel: gradeLevel,
            highSchoolTrack: current?.highSchoolTrack,
            institutionName: cleanInstitutionName,
            institutionCountry: cleanCountry,
            majorName: cleanMajorName,
            dailyStudyGoalMinutes: current?.dailyStudyGoalMinutes ?? 120,
            weeklyStudyGoalMinutes: current?.weeklyStudyGoalMinutes ?? 840
        )

        studentStore.reload()
        AcademicSettingsHaptics.success()

        isSavingProfile = false
        dismiss()
    }

    func addManualCourse() {
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

            studentStore.reload()

            isSavingCourse = false
            courseCode = ""
            courseName = ""
            focusedField = nil

            AcademicSettingsHaptics.success()
        }
    }

    func isCourseAlreadyAdded(code: String, name: String) -> Bool {
        uniqueStudentCourses.contains {
            normalizedSearchKey($0.code) == normalizedSearchKey(code) &&
            normalizedSearchKey($0.name) == normalizedSearchKey(name)
        }
    }
}

// MARK: - Matching / Formatting

private extension StudentAcademicSettingsView {
    func bestUniversityMatch(
        universities: [CatalogUniversity],
        profileInstitutionName: String
    ) -> CatalogUniversity? {
        let target = normalizedSearchKey(profileInstitutionName)

        if let exact = universities.first(where: {
            normalizedSearchKey($0.name) == target
        }) {
            return exact
        }

        if let sortExact = universities.first(where: {
            normalizedSearchKey($0.sort_name) == target
        }) {
            return sortExact
        }

        return universities.first(where: {
            normalizedSearchKey($0.name).contains(target) ||
            target.contains(normalizedSearchKey($0.name)) ||
            normalizedSearchKey($0.sort_name).contains(target) ||
            target.contains(normalizedSearchKey($0.sort_name))
        })
    }

    func bestMajorMatch(
        majors: [CatalogMajor],
        profileMajorName: String
    ) -> CatalogMajor? {
        let target = normalizedSearchKey(profileMajorName)

        guard !target.isEmpty else { return nil }

        if let exact = majors.first(where: {
            normalizedSearchKey($0.name) == target
        }) {
            return exact
        }

        if let normalizedExact = majors.first(where: {
            normalizedSearchKey($0.normalized_name ?? "") == target
        }) {
            return normalizedExact
        }

        return majors.first(where: {
            normalizedSearchKey($0.name).contains(target) ||
            target.contains(normalizedSearchKey($0.name)) ||
            normalizedSearchKey($0.normalized_name ?? "").contains(target)
        })
    }

    func normalizedCountryCode(_ raw: String?) -> String {
        let value = (raw ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch value {
        case "tr", "turkey", "türkiye", "turkiye":
            return "tr"

        case "kktc", "kk tc", "trnc", "cy", "cyprus", "north cyprus", "northern cyprus":
            return "kktc"

        default:
            return value.isEmpty ? "kktc" : value
        }
    }

    func displayCountry(_ raw: String) -> String {
        switch normalizedCountryCode(raw) {
        case "tr":
            return "Türkiye"
        case "kktc":
            return "KKTC"
        default:
            return raw.uppercased()
        }
    }

    func normalizedSearchKey(_ text: String) -> String {
        academicNormalizedSearchKey(text)
    }

    func yearTitle(_ value: String) -> String {
        switch value {
        case "prep": return "Prep"
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

// MARK: - Major Picker Sheet

private struct AcademicMajorPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let majors: [CatalogMajor]
    let selectedMajorID: UUID?
    let selectedMajorName: String
    let isLoading: Bool
    let errorText: String?
    let onRetry: () -> Void
    let onSelect: (CatalogMajor) -> Void
    let onManualMajor: (String) -> Void

    @State private var searchText = ""
    @State private var manualMajorText = ""

    private var accent: Color { Color(academicSettingsHex: AcademicSettingsPalette.cyan) }
    private var purple: Color { Color(academicSettingsHex: AcademicSettingsPalette.purple) }
    private var green: Color { Color(academicSettingsHex: AcademicSettingsPalette.green) }
    private var coral: Color { Color(academicSettingsHex: AcademicSettingsPalette.coral) }

    private var filteredMajors: [CatalogMajor] {
        let query = academicNormalizedSearchKey(searchText)

        guard !query.isEmpty else {
            return majors
        }

        return majors.filter { major in
            academicNormalizedSearchKey(major.name).contains(query) ||
            academicNormalizedSearchKey(major.normalized_name ?? "").contains(query) ||
            academicNormalizedSearchKey(major.faculty_name ?? "").contains(query)
        }
    }

    var body: some View {
        ZStack {
            AcademicSettingsBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                sheetHeader

                VStack(spacing: 12) {
                    searchBar

                    if isLoading {
                        pickerLoading
                    } else if let errorText {
                        pickerError(errorText)
                    } else if filteredMajors.isEmpty {
                        pickerEmpty
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredMajors) { major in
                                    majorRow(major)
                                }

                                manualEntryCard
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 30)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            manualMajorText = selectedMajorName
        }
    }

    private var sheetHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accent, purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 22, height: 2)

                    Text("DEPARTMENT")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(2.0)
                        .foregroundStyle(accent)
                }

                Text("Choose major")
                    .font(.system(size: 34, weight: .heavy))
                    .tracking(-0.8)
                    .foregroundStyle(.white)

                Text("Search your department or type it manually.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.070))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.105), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(accent)

            TextField(
                "",
                text: $searchText,
                prompt: Text("Search major").foregroundStyle(.white.opacity(0.30))
            )
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .tint(accent)

            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white.opacity(0.34))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(Color.white.opacity(0.065))
                .overlay(
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .stroke(accent.opacity(0.13), lineWidth: 1)
                )
        )
    }

    private var pickerLoading: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(accent)

            VStack(alignment: .leading, spacing: 3) {
                Text("Loading majors")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)

                Text("Preparing department catalog.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()
        }
        .padding(14)
        .background(sheetRowSurface(tint: accent))
    }

    private func pickerError(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(coral.opacity(0.13))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(coral)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Could not load majors")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)

                    Text(text)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(3)
                }

                Spacer()
            }

            Button {
                onRetry()
            } label: {
                Text("RETRY")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(coral)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(coral.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(coral.opacity(0.18), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(sheetRowSurface(tint: coral))
    }

    private var pickerEmpty: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(purple.opacity(0.13))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(purple)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("No matching major")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)

                    Text("Try another search or type your department manually.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(2)
                }

                Spacer()
            }

            manualEntryCard
        }
        .padding(14)
        .background(sheetRowSurface(tint: purple))
    }

    private func majorRow(_ major: CatalogMajor) -> some View {
        let isSelected =
        selectedMajorID == major.id ||
        academicNormalizedSearchKey(selectedMajorName) == academicNormalizedSearchKey(major.name)

        return Button {
            onSelect(major)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill((isSelected ? green : purple).opacity(isSelected ? 0.18 : 0.12))
                        .frame(width: 42, height: 42)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "graduationcap.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(isSelected ? green : purple)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(major.name)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 7) {
                        if let faculty = major.faculty_name, !faculty.isEmpty {
                            miniLabel(faculty, tint: .white.opacity(0.45))
                        }

                        if let language = major.language, !language.isEmpty {
                            miniLabel(language, tint: purple)
                        }
                    }
                }

                Spacer()
            }
            .padding(13)
            .background(sheetRowSurface(tint: isSelected ? green : purple))
        }
        .buttonStyle(.plain)
    }

    private var manualEntryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TYPE MANUALLY")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.38))

            HStack(spacing: 10) {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(accent)

                TextField(
                    "",
                    text: $manualMajorText,
                    prompt: Text("Type your department").foregroundStyle(.white.opacity(0.30))
                )
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .tint(accent)
            }
            .padding(.horizontal, 13)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.white.opacity(0.060))
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(accent.opacity(0.13), lineWidth: 1)
                    )
            )

            Button {
                let cleaned = manualMajorText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else { return }
                onManualMajor(cleaned)
            } label: {
                Text("USE MANUAL MAJOR")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(accent)
                    )
            }
            .buttonStyle(.plain)
            .disabled(manualMajorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(manualMajorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.48 : 1)
        }
        .padding(14)
        .background(sheetRowSurface(tint: accent))
    }

    private func miniLabel(_ text: String, tint: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .frame(height: 23)
            .background(
                Capsule()
                    .fill(tint.opacity(0.115))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.16), lineWidth: 1)
                    )
            )
    }

    private func sheetRowSurface(tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 21, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.080),
                        Color.white.opacity(0.040),
                        Color.black.opacity(0.020)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .stroke(tint.opacity(0.13), lineWidth: 1)
            )
    }
}

// MARK: - Reusable UI

private extension StudentAcademicSettingsView {
    func sectionHeader(
        eyebrow: String,
        title: String,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Capsule()
                        .fill(tint)
                        .frame(width: 18, height: 2)

                    Text(eyebrow)
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(tint)
                }

                Text(title)
                    .font(.system(size: 22, weight: .heavy))
                    .tracking(-0.25)
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

    func infoNotice(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(tint.opacity(0.12))
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(tint)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
        .background(rowSurface(tint: tint))
    }

    func loadingRow(
        title: String,
        subtitle: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(tint)
                .scaleEffect(0.92)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()
        }
        .padding(14)
        .background(rowSurface(tint: tint))
    }

    func errorNotice(
        title: String,
        message: String,
        tint: Color,
        retry: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(tint.opacity(0.13))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(tint)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)

                    Text(message)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(3)
                }

                Spacer()
            }

            Button(action: retry) {
                HStack(spacing: 9) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .black))

                    Text("RETRY")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(0.8)

                    Spacer()
                }
                .foregroundStyle(tint)
                .padding(.horizontal, 13)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(tint.opacity(0.18), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(rowSurface(tint: tint))
    }

    func courseTextField(
        placeholder: String,
        text: Binding<String>,
        icon: String,
        tint: Color,
        capitalization: TextInputAutocapitalization
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(tint)

            TextField(
                "",
                text: text,
                prompt: Text(placeholder).foregroundStyle(.white.opacity(0.30))
            )
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled()
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .tint(tint)
        }
        .padding(.horizontal, 13)
        .frame(height: 52)
        .background(inputSurface(tint: tint))
    }

    func primaryActionButton(
        title: String,
        icon: String,
        tint: Color,
        foreground: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))

            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(0.8)

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .black))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint)
                .shadow(color: tint.opacity(0.18), radius: 10, y: 5)
        )
    }

    func miniLabel(_ text: String, tint: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .frame(height: 23)
            .background(
                Capsule()
                    .fill(tint.opacity(0.115))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.16), lineWidth: 1)
                    )
            )
    }

    func inputSurface(tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.060))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tint.opacity(0.13), lineWidth: 1)
            )
    }

    func rowSurface(tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.080),
                        Color.white.opacity(0.040),
                        Color.black.opacity(0.020)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(tint.opacity(0.13), lineWidth: 1)
            )
    }

    func cardSurface(tint: Color, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.060),
                        tint.opacity(0.060),
                        secondaryAccent.opacity(0.035),
                        Color.black.opacity(0.040)
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
                                tint.opacity(0.13),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 6,
                            endRadius: 190
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(tint.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 14, y: 8)
    }
}

// MARK: - Color Helpers

private extension StudentAcademicSettingsView {
    func colorFromHex(_ hex: String, fallback: Color) -> Color {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        clean = clean.replacingOccurrences(of: "#", with: "")

        guard clean.count == 6 else {
            return fallback
        }

        var rgb: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&rgb)

        return Color(
            red: Double((rgb & 0xFF0000) >> 16) / 255,
            green: Double((rgb & 0x00FF00) >> 8) / 255,
            blue: Double(rgb & 0x0000FF) / 255
        )
    }
}

// MARK: - Shared Helpers / Palette / Background / Haptics

private func academicNormalizedSearchKey(_ text: String) -> String {
    text
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
        .lowercased()
        .replacingOccurrences(of: "ı", with: "i")
        .replacingOccurrences(of: "ğ", with: "g")
        .replacingOccurrences(of: "ü", with: "u")
        .replacingOccurrences(of: "ş", with: "s")
        .replacingOccurrences(of: "ö", with: "o")
        .replacingOccurrences(of: "ç", with: "c")
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private enum AcademicSettingsPalette {
    static let backgroundTop = "#05060D"
    static let backgroundMid = "#070713"
    static let backgroundBottom = "#07040C"

    static let blue = "#1593FF"
    static let cyan = "#2DD4FF"
    static let purple = "#7C3AED"
    static let coral = "#FF5A44"
    static let gold = "#FBBF24"
    static let green = "#A3E635"
}

private struct AcademicSettingsBackground: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(academicSettingsHex: AcademicSettingsPalette.backgroundTop),
                    Color(academicSettingsHex: AcademicSettingsPalette.backgroundMid),
                    Color(academicSettingsHex: AcademicSettingsPalette.backgroundBottom)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(academicSettingsHex: AcademicSettingsPalette.blue).opacity(0.11))
                .frame(width: 270, height: 270)
                .blur(radius: 100)
                .offset(x: 170, y: -220)

            Circle()
                .fill(Color(academicSettingsHex: AcademicSettingsPalette.purple).opacity(0.14))
                .frame(width: 330, height: 330)
                .blur(radius: 118)
                .offset(x: -190, y: 500)

            Circle()
                .fill(Color(academicSettingsHex: AcademicSettingsPalette.coral).opacity(0.060))
                .frame(width: 280, height: 280)
                .blur(radius: 110)
                .offset(x: 165, y: 285)

            Circle()
                .fill(Color(academicSettingsHex: AcademicSettingsPalette.gold).opacity(0.045))
                .frame(width: 210, height: 210)
                .blur(radius: 95)
                .offset(x: -145, y: -155)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.44)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

private enum AcademicSettingsHaptics {
    static func softTap() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.72)
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}

private extension Color {
    init(academicSettingsHex hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "#", with: "")

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
            r = 45
            g = 212
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
