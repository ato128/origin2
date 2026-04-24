//
//  StudentOnboardingFlowView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 23.04.2026.
//

import SwiftUI

struct OnboardingCourseDraft: Identifiable, Hashable {
    let id = UUID()
    var code: String
    var name: String
    var isSuggested: Bool = false
}

struct StudentOnboardingFlowView: View {
    @EnvironmentObject var studentStore: StudentStore
    @FocusState private var focusedField: FocusField?

    @State private var currentStep: Int = 0
    @State private var isSubmitting: Bool = false

    @State private var educationLevel: String = "high_school"
    @State private var gradeLevel: String = "9"
    @State private var highSchoolTrack: String = "sayisal"

    @State private var institutionName: String = ""
    @State private var institutionCountry: String = "tr"
    @State private var showUniversityPicker: Bool = false

    @State private var majorName: String = ""
    @State private var majorSearchText: String = ""

    @State private var dailyStudyGoalMinutes: Double = 120
    @State private var weeklyStudyGoalMinutes: Double = 840

    @State private var draftCourseCode: String = ""
    @State private var draftCourseName: String = ""
    @State private var localCourses: [OnboardingCourseDraft] = []
    
    @State private var allMajorCourses: [CatalogCurriculumCourse] = []
    @State private var filteredCourseSuggestions: [CatalogCurriculumCourse] = []
    @State private var isLoadingAllMajorCourses: Bool = false
    
    @State private var remoteUniversities: [CatalogUniversity] = []
        @State private var remoteMajors: [CatalogMajor] = []
        @State private var remoteSuggestedCourses: [CatalogCurriculumCourse] = []

        @State private var selectedUniversityID: UUID?
        @State private var selectedMajorID: UUID?

        @State private var isLoadingMajors: Bool = false
        @State private var isLoadingCurriculum: Bool = false

    private let highSchoolGrades = ["9", "10", "11", "12"]
    private let universityGrades = ["prep", "1", "2", "3", "4", "5", "6"]
    private let highSchoolTracks = ["sayisal", "sozel", "esit_agirlik", "dil"]

    

    enum FocusField {
        case courseCode
        case courseName
        case majorSearch
        case majorCustom
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                topBar
                progressSection

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        stepHero
                        stepContent
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, focusedField == nil ? 132 : 28)
                }

                if focusedField == nil {
                    bottomBar
                }
            }
            .disabled(isSubmitting)

            if isSubmitting {
                savingOverlay
            }
        }
        .preferredColorScheme(.dark)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
        .onAppear {
            if localCourses.isEmpty {
                localCourses = defaultCoursesForCurrentSelection()
            }
        }
        .onChange(of: educationLevel) { _, newValue in
            adaptGradeIfNeeded()

            if newValue == "high_school" {
                institutionName = ""
                institutionCountry = "tr"
                majorName = ""
                majorSearchText = ""
                localCourses = defaultCoursesForCurrentSelection()
            } else {
                highSchoolTrack = "sayisal"
                localCourses = []
            }
        }
        .onChange(of: highSchoolTrack) { _, _ in
            if educationLevel == "high_school" {
                localCourses = defaultCoursesForCurrentSelection()
            }
        }
        .onChange(of: institutionName) { _, _ in
            remoteMajors = []
            remoteSuggestedCourses = []
            selectedMajorID = nil
            majorName = ""
            majorSearchText = ""
            localCourses.removeAll(where: { $0.isSuggested })

            Task {
                await loadMajorsForSelectedUniversity()
            }
        }
        .onChange(of: selectedUniversityID) { _, _ in
            remoteSuggestedCourses = []
            selectedMajorID = nil
            majorName = ""
            majorSearchText = ""
            localCourses.removeAll(where: { $0.isSuggested })

            Task {
                await loadMajorsForSelectedUniversity()
            }
        }
        .onChange(of: gradeLevel) { _, _ in
            Task {
                await applySuggestedUniversityCoursesIfAvailable(forceReplace: true)
            }
        }
        .sheet(isPresented: $showUniversityPicker) {
            UniversityPickerSheet(
                selectedUniversityID: $selectedUniversityID,
                selectedUniversityName: $institutionName,
                selectedCountryCode: $institutionCountry
            )
        }
    }

    private var suggestedCoursesOnly: [OnboardingCourseDraft] {
        localCourses.filter { $0.isSuggested }
    }

    private var manualCoursesOnly: [OnboardingCourseDraft] {
        localCourses.filter { !$0.isSuggested }
    }

    private var hasRemoteSuggestionsAvailable: Bool {
        !remoteSuggestedCourses.isEmpty
    }

    private var canRestoreSuggestedCourses: Bool {
        hasRemoteSuggestionsAvailable && suggestedCoursesOnly.isEmpty
    }
    
    private var totalSteps: Int { 7 }

    private var progressValue: Double {
        Double(currentStep + 1) / Double(totalSteps)
    }

    private var stepTitle: String {
        switch currentStep {
        case 0: return "Welcome"
        case 1: return "Education"
        case 2: return educationLevel == "high_school" ? "School" : "University"
        case 3: return "Grade"
        case 4: return educationLevel == "high_school" ? "Track" : "Major"
        case 5: return "Courses"
        default: return "Goals"
        }
    }

    private var progressLabel: String {
        switch currentStep {
        case 0: return "Start"
        case 1: return "Profile"
        case 2: return educationLevel == "high_school" ? "School" : "Institution"
        case 3: return "Level"
        case 4: return "Details"
        case 5: return "Courses"
        default: return "Finish"
        }
    }

    private var stepContextPill: (String, String) {
        switch currentStep {
        case 0: return ("sparkles", "Student setup")
        case 1: return ("person.text.rectangle", "Education profile")
        case 2: return (educationLevel == "high_school" ? "building.2" : "building.columns", educationLevel == "high_school" ? "School flow" : "University setup")
        case 3: return ("graduationcap", "Academic level")
        case 4: return (educationLevel == "high_school" ? "square.grid.2x2" : "magnifyingglass", educationLevel == "high_school" ? "Track setup" : "Department setup")
        case 5: return ("list.bullet.rectangle", "Course builder")
        default: return ("target", "Goal setup")
        }
    }

    private var heroTitle: String {
        switch currentStep {
        case 0:
            return "Build your student system"
        case 1:
            return "Choose your education"
        case 2:
            return educationLevel == "high_school" ? "School setup" : "Choose your university"
        case 3:
            return "Select your year"
        case 4:
            return educationLevel == "high_school" ? "Choose your track" : "Choose your major"
        case 5:
            return "Set your courses"
        default:
            return "Set your goals"
        }
    }

    private var heroSubtitle: String {
        switch currentStep {
        case 0:
            return "Set up your profile, courses, and goals so DailyTodo can work like a real student operating system."
        case 1:
            return "Pick the academic structure that fits you."
        case 2:
            return educationLevel == "high_school"
                ? "No university selection is needed for high school mode."
                : "Choose your university from a searchable list."
        case 3:
            return "This shapes your academic planning flow."
        case 4:
            return educationLevel == "high_school"
                ? "We’ll use this to prepare your default course set."
                : "Search from common departments or enter your own."
        case 5:
            return courseStepSubtitle
        default:
            return "These targets will power planning, focus, and recommendations."
        }
    }

    private var gradeOptions: [String] {
        educationLevel == "high_school" ? highSchoolGrades : universityGrades
    }

    private var filteredMajors: [CatalogMajor] {
            let trimmed = majorSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return remoteMajors }

            return remoteMajors.filter {
                $0.name.localizedCaseInsensitiveContains(trimmed)
            }
        }

    private var canContinueCurrentStep: Bool {
        if isSubmitting { return false }

        switch currentStep {
        case 0, 1:
            return true
        case 2:
            return educationLevel == "high_school" || !institutionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 3:
            return !gradeLevel.isEmpty
        case 4:
            return educationLevel == "high_school"
                ? !highSchoolTrack.isEmpty
                : !majorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 5:
            return !localCourses.isEmpty
        default:
            return true
        }
    }

    private var courseStepSubtitle: String {
            if educationLevel == "high_school" {
                return "Default courses are ready. Edit or add your own."
            }

            if isLoadingCurriculum {
                return "Loading suggested courses..."
            }

            return remoteSuggestedCourses.isEmpty
                ? "Add course code and course name manually."
                : "Suggested courses were loaded for your university, major, and year."
        }

    private var topBar: some View {
        HStack {
            if currentStep > 0 {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                        currentStep -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.08), in: Circle())
                }
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(stepTitle)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Step \(currentStep + 1) of \(totalSteps)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.66))

                Spacer()

                Text(progressLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.blue)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.07))
                        .frame(height: 7)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progressValue, height: 7)
                }
            }
            .frame(height: 7)
        }
        .padding(.horizontal, 24)
    }

    private var stepHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: stepContextPill.0)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))

                Text(stepContextPill.1)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.white.opacity(0.08))
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(heroTitle)
                    .font(.system(size: 33, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineSpacing(1)

                Text(heroSubtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineSpacing(2)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            welcomeContent
        case 1:
            educationContent
        case 2:
            institutionContent
        case 3:
            gradeContent
        case 4:
            detailContent
        case 5:
            coursesContent
        default:
            goalsContent
        }
    }

    private var welcomeContent: some View {
        VStack(spacing: 12) {
            compactFeatureCard(icon: "calendar", title: "Weekly planning")
            compactFeatureCard(icon: "graduationcap", title: "Course structure")
            compactFeatureCard(icon: "timer", title: "Focus flow")
            compactFeatureCard(icon: "sparkles", title: "Smart suggestions")
        }
    }

    private var educationContent: some View {
        HStack(spacing: 12) {
            selectionCard(
                title: "High School",
                subtitle: "Grades 9–12",
                badge: "School",
                isSelected: educationLevel == "high_school"
            ) {
                educationLevel = "high_school"
            }

            selectionCard(
                title: "University",
                subtitle: "Prep or degree",
                badge: "Campus",
                isSelected: educationLevel == "university"
            ) {
                educationLevel = "university"
            }
        }
    }

    @ViewBuilder
    private var institutionContent: some View {
        if educationLevel == "high_school" {
            compactInfoGroup(
                title: "Next",
                items: [
                    ("graduationcap", "Choose your grade"),
                    ("square.grid.2x2", "Choose your track"),
                    ("list.bullet.rectangle", "Set your course list")
                ]
            )
        } else {
            VStack(spacing: 14) {
                Button {
                    showUniversityPicker = true
                } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Selected university")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.55))

                            Text(institutionName.isEmpty ? "Tap to choose university" : institutionName)
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(institutionName.isEmpty ? .white.opacity(0.42) : .white)
                                .multilineTextAlignment(.leading)

                            if !institutionName.isEmpty {
                                Label(
                                    institutionCountry == "tr" ? "Türkiye" : "KKTC",
                                    systemImage: "flag.fill"
                                )
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.blue)
                            }
                        }

                        Spacer()

                        VStack(spacing: 8) {
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.blue)

                            Text("Choose")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.58))
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(.white.opacity(0.06), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                if !institutionName.isEmpty {
                    compactInfoGroup(
                        title: "Setup status",
                        items: [
                            ("checkmark.circle.fill", "University selected"),
                            ("graduationcap", "Next: choose your year"),
                            ("list.bullet.rectangle", "Then set major and courses")
                        ]
                    )
                }
            }
        }
    }

    private var gradeContent: some View {
        VStack(spacing: 12) {
            if educationLevel == "university", gradeOptions.contains("prep") {
                selectionRowCard(
                    title: "Hazırlık",
                    subtitle: "Prep year",
                    isSelected: gradeLevel == "prep"
                ) {
                    gradeLevel = "prep"
                }
            }

            let numericGrades = gradeOptions.filter { $0 != "prep" }
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(numericGrades, id: \.self) { grade in
                    selectionNumberCard(
                        title: educationLevel == "high_school" ? grade : "\(grade). Year",
                        isSelected: gradeLevel == grade
                    ) {
                        gradeLevel = grade
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if educationLevel == "high_school" {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(highSchoolTracks, id: \.self) { track in
                    selectionChip(
                        icon: iconForTrack(track),
                        title: labelForTrack(track),
                        isSelected: highSchoolTrack == track
                    ) {
                        highSchoolTrack = track
                    }
                }
            }
        } else {
            VStack(spacing: 14) {
                premiumTextField(
                    title: "Search majors",
                    text: $majorSearchText,
                    placeholder: "Search major"
                )
                .focused($focusedField, equals: .majorSearch)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Suggested majors")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.72))

                        Spacer()

                        if isLoadingMajors {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.85)
                        }
                    }

                    if isLoadingMajors && remoteMajors.isEmpty {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(.white)

                            Text("Loading majors...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)

                    } else if !institutionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && filteredMajors.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.white.opacity(0.45))

                            Text("No majors found for this university yet")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)

                    } else {
                        VStack(spacing: 10) {
                            ForEach(filteredMajors.prefix(8)) { major in
                                majorRow(
                                    title: major.name,
                                    isSelected: majorName == major.name
                                ) {
                                    majorName = major.name
                                    majorSearchText = major.name
                                    selectedMajorID = major.id
                                    focusedField = nil

                                    Task {
                                        await loadAllCoursesForSelectedMajor()
                                     await  applySuggestedUniversityCoursesIfAvailable(forceReplace: true)
                                    }
                                }
                            }
                        }
                    }
                }

                premiumTextField(
                    title: "Custom major",
                    text: $majorName,
                    placeholder: "Type your department"
                )
                .focused($focusedField, equals: .majorCustom)
                .onChange(of: majorName) { _, newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

                    if let matchedMajor = remoteMajors.first(where: {
                        $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
                    }) {
                        selectedMajorID = matchedMajor.id

                        Task {
                            await loadAllCoursesForSelectedMajor()
                           await applySuggestedUniversityCoursesIfAvailable(forceReplace: true)
                        }
                    } else {
                        selectedMajorID = nil
                        remoteSuggestedCourses = []
                        allMajorCourses = []
                        filteredCourseSuggestions = []
                        localCourses.removeAll(where: { $0.isSuggested })
                    }
                }
            }
        }
    }

    private var coursesContent: some View {
        VStack(spacing: 14) {
            selectedCoursesSection
            courseBuilderCard

            if !filteredCourseSuggestions.isEmpty {
                courseSuggestionsSection
            }
        }
    }
    
    private var courseSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggestions")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.72))

            VStack(spacing: 10) {
                ForEach(filteredCourseSuggestions) { course in
                    Button {
                        applyCourseSuggestion(course)
                        focusedField = nil
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(.blue.opacity(0.9))
                                .frame(width: 4, height: 44)

                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) {
                                    if !course.course_code.isEmpty {
                                        Text(course.course_code)
                                            .font(.system(size: 12, weight: .heavy))
                                            .foregroundStyle(.blue)
                                    }

                                    Text("Suggestion")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.72))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(.white.opacity(0.08))
                                        )
                                }

                                Text(course.course_name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)

                                Text("Year \(course.year_number) • Term \(course.term_number ?? 0)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.45))
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.white.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var selectedCoursesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Selected courses", systemImage: "list.bullet")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(localCourses.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.blue.opacity(0.14))
                    )
            }

            if localCourses.isEmpty {
                compactInfoGroup(
                    title: "No courses yet",
                    items: [
                        ("plus.circle", "Add at least one course"),
                        ("number", "Use code + name when possible"),
                        ("book", "Example: CMPE201 • Data Structures")
                    ]
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(localCourses) { course in
                        compactCourseRow(
                            course: course,
                            isSuggested: isSuggestedCourse(course)
                        ) {
                            removeCourse(course)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.06))
        )
    }
    
    private var courseBuilderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Course builder", systemImage: "square.and.pencil")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                if isLoadingCurriculum || isLoadingAllMajorCourses {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                }
            }

            HStack(spacing: 10) {
                TextField(
                    "",
                    text: $draftCourseCode,
                    prompt: Text("Code").foregroundStyle(.white.opacity(0.34))
                )
                .textInputAutocapitalization(.characters)
                .padding(.horizontal, 14)
                .frame(width: 104, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.08))
                )
                .foregroundStyle(.white)
                .focused($focusedField, equals: .courseCode)
                .onChange(of: draftCourseCode) { _, newValue in
                    let upper = newValue.uppercased()
                    if upper != newValue {
                        draftCourseCode = upper
                        return
                    }
                    updateCourseSuggestions()
                }

                TextField(
                    "",
                    text: $draftCourseName,
                    prompt: Text("Course name").foregroundStyle(.white.opacity(0.34))
                )
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.08))
                )
                .foregroundStyle(.white)
                .focused($focusedField, equals: .courseName)
                .onChange(of: draftCourseName) { _, _ in
                    updateCourseSuggestions()
                }
            }

            Button {
                addDraftCourse()
                focusedField = nil
            } label: {
                Text("Add Course")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.08))
        )
    }
    
    
    
    func sectionMiniHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))

            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
        }
    }

    private var goalsContent: some View {
        VStack(spacing: 14) {
            premiumGoalCard(
                title: "Daily Goal",
                value: "\(Int(dailyStudyGoalMinutes)) min",
                slider: $dailyStudyGoalMinutes,
                range: 30...480,
                step: 15,
                helper: "Your focused study target per day."
            )

            premiumGoalCard(
                title: "Weekly Goal",
                value: "\(Int(weeklyStudyGoalMinutes)) min",
                slider: $weeklyStudyGoalMinutes,
                range: 120...3000,
                step: 30,
                helper: "Your total academic target per week."
            )

            compactInfoGroup(
                title: "Summary",
                items: [
                    ("graduationcap", educationLevel == "high_school"
                        ? "High School • \(labelForGrade(gradeLevel))"
                        : "University • \(labelForGrade(gradeLevel))"),
                    ("square.grid.2x2", educationLevel == "high_school"
                        ? labelForTrack(highSchoolTrack)
                        : (majorName.isEmpty ? "Major not selected" : majorName)),
                    ("list.bullet.rectangle", "\(localCourses.count) course(s) selected")
                ]
            )
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 1)

            HStack(spacing: 14) {
                if currentStep > 0 {
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                            currentStep -= 1
                        }
                    } label: {
                        Text("Back")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 108, height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(.white.opacity(0.08))
                            )
                    }
                }

                Button {
                    handleContinue()
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.9)
                        }

                        Text(currentStep == totalSteps - 1 ? "Finish" : "Continue")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                canContinueCurrentStep
                                ? LinearGradient(colors: [.blue, .purple, .pink], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.35)], startPoint: .leading, endPoint: .trailing)
                            )
                    )
                }
                .disabled(!canContinueCurrentStep)
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 22)
            .background(.ultraThinMaterial.opacity(0.35))
        }
    }

    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.05)

                Text("Saving your setup...")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.10))
            )
        }
    }

    private func handleContinue() {
        if currentStep < totalSteps - 1 {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                currentStep += 1
            }
        } else {
            Task {
                await completeOnboarding()
            }
        }
    }

    private func completeOnboarding() async {
        guard !isSubmitting else { return }

        let cleanedMajor = majorName.trimmingCharacters(in: .whitespacesAndNewlines)

        let normalizedCourses = localCourses
            .map {
                OnboardingCourseDraft(
                    code: $0.code.trimmingCharacters(in: .whitespacesAndNewlines),
                    name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    isSuggested: $0.isSuggested
                )
            }
            .filter { !$0.name.isEmpty }

        guard !normalizedCourses.isEmpty else { return }

        focusedField = nil
        isSubmitting = true
        defer { isSubmitting = false }

        await studentStore.completeOnboardingAndSync(
            educationLevel: educationLevel,
            gradeLevel: gradeLevel,
            highSchoolTrack: educationLevel == "high_school" ? highSchoolTrack : nil,
            institutionName: educationLevel == "university" ? institutionName : nil,
            institutionCountry: educationLevel == "university" ? institutionCountry : nil,
            majorName: educationLevel == "university" ? cleanedMajor : nil,
            dailyStudyGoalMinutes: Int(dailyStudyGoalMinutes),
            weeklyStudyGoalMinutes: Int(weeklyStudyGoalMinutes),
            courseDrafts: normalizedCourses
        )
        studentStore.forceRestoreCoursesFromOnboardingDrafts(normalizedCourses)
    }
    
    private func loadMajorsForSelectedUniversity() async {
        guard educationLevel == "university" else { return }

        let trimmedUniversity = institutionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUniversity.isEmpty else {
            remoteMajors = []
            remoteSuggestedCourses = []
            allMajorCourses = []
            filteredCourseSuggestions = []
            selectedUniversityID = nil
            selectedMajorID = nil
            return
        }

        isLoadingMajors = true
        defer { isLoadingMajors = false }

        do {
            let universities = try await StudentCatalogService.fetchUniversities(
                countryCode: institutionCountry,
                query: trimmedUniversity
            )

            guard let matchedUniversity = universities.first(where: {
                $0.name.caseInsensitiveCompare(trimmedUniversity) == .orderedSame
            }) else {
                remoteMajors = []
                remoteSuggestedCourses = []
                allMajorCourses = []
                filteredCourseSuggestions = []
                selectedUniversityID = nil
                selectedMajorID = nil
                return
            }

            selectedUniversityID = matchedUniversity.id

            let majors = try await StudentCatalogService.fetchMajors(
                universityID: matchedUniversity.id
            )

            remoteMajors = majors
            remoteSuggestedCourses = []
            allMajorCourses = []
            filteredCourseSuggestions = []
            localCourses.removeAll(where: { $0.isSuggested })

            let trimmedMajor = majorName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedMajor.isEmpty,
               let matchedMajor = majors.first(where: {
                   $0.name.caseInsensitiveCompare(trimmedMajor) == .orderedSame
               }) {
                selectedMajorID = matchedMajor.id
                await loadAllCoursesForSelectedMajor()
                await applySuggestedUniversityCoursesIfAvailable(forceReplace: true)
            } else {
                selectedMajorID = nil
            }
        } catch {
            print("❌ loadMajorsForSelectedUniversity error:", error)
            remoteMajors = []
            remoteSuggestedCourses = []
            allMajorCourses = []
            filteredCourseSuggestions = []
            selectedUniversityID = nil
            selectedMajorID = nil
        }
    }

    private func applySuggestedUniversityCoursesIfAvailable(forceReplace: Bool = false) async {
        guard educationLevel == "university" else { return }
        guard let selectedMajorID else {
            remoteSuggestedCourses = []
            if forceReplace {
                localCourses = localCourses.filter { !$0.isSuggested }
            }
            return
        }

        isLoadingCurriculum = true
        defer { isLoadingCurriculum = false }

        do {
            let suggestions = try await StudentCatalogService.fetchCurriculumCourses(
                majorID: selectedMajorID,
                gradeLevel: gradeLevel
            )

            remoteSuggestedCourses = suggestions

            let markedSuggestions = suggestions.map {
                OnboardingCourseDraft(
                    code: $0.course_code,
                    name: $0.course_name,
                    isSuggested: true
                )
            }

            let manualCourses = localCourses.filter { !$0.isSuggested }
            localCourses = markedSuggestions + manualCourses
        } catch {
            print("❌ applySuggestedUniversityCoursesIfAvailable error:", error)
            remoteSuggestedCourses = []
            if forceReplace {
                localCourses = localCourses.filter { !$0.isSuggested }
            }
        }
    }
    private func isSuggestedCourse(_ course: OnboardingCourseDraft) -> Bool {
        course.isSuggested
    }

    private func adaptGradeIfNeeded() {
        let options = gradeOptions
        if !options.contains(gradeLevel) {
            gradeLevel = options.first ?? "9"
        }
    }

    private func addDraftCourse() {
        let trimmedCode = draftCourseCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = draftCourseName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else { return }

        let alreadyExists = localCourses.contains {
            $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame &&
            $0.code.caseInsensitiveCompare(trimmedCode) == .orderedSame
        }

        guard !alreadyExists else {
            draftCourseCode = ""
            draftCourseName = ""
            return
        }

        localCourses.append(
            OnboardingCourseDraft(
                code: trimmedCode,
                name: trimmedName,
                isSuggested: false
            )
        )

        draftCourseCode = ""
        draftCourseName = ""
    }

    private func removeCourse(_ course: OnboardingCourseDraft) {
        localCourses.removeAll { $0.id == course.id }

        if course.isSuggested {
            remoteSuggestedCourses.removeAll {
                $0.course_code.caseInsensitiveCompare(course.code) == .orderedSame &&
                $0.course_name.caseInsensitiveCompare(course.name) == .orderedSame
            }
        }

        updateCourseSuggestions()
    }

    private func defaultCoursesForCurrentSelection() -> [OnboardingCourseDraft] {
        if educationLevel == "university" {
            return []
        }

        switch highSchoolTrack {
        case "sayisal":
            return [
                OnboardingCourseDraft(code: "", name: "Mathematics", isSuggested: true),
                OnboardingCourseDraft(code: "", name: "Physics", isSuggested: true),
                OnboardingCourseDraft(code: "", name: "Chemistry", isSuggested: true),
                OnboardingCourseDraft(code: "", name: "Biology", isSuggested: true),
                OnboardingCourseDraft(code: "", name: "Turkish", isSuggested: true)
            ]
        case "sozel":
            return [
                OnboardingCourseDraft(code: "", name: "Turkish", isSuggested: true),
                OnboardingCourseDraft(code: "", name: "Literature", isSuggested: true),
                OnboardingCourseDraft(code: "", name: "History", isSuggested: true),
                OnboardingCourseDraft(code: "", name: "Geography", isSuggested: true),
                OnboardingCourseDraft(code: "", name: "Philosophy", isSuggested: true)
            ]
        case "esit_agirlik":
            return [
                OnboardingCourseDraft(code: "", name: "Mathematics", isSuggested: true),
                OnboardingCourseDraft(code: "", name: "Turkish", isSuggested: true),
                OnboardingCourseDraft(code: "", name: "Literature", isSuggested: true),
                OnboardingCourseDraft(code: "", name: "History", isSuggested: true),
                OnboardingCourseDraft(code: "", name: "Geography", isSuggested: true)
            ]
        case "dil":
            return [
                OnboardingCourseDraft(code: "", name: "English", isSuggested: true),
                OnboardingCourseDraft(code: "", name: "Turkish", isSuggested: true),
                OnboardingCourseDraft(code: "", name: "Literature", isSuggested: true)
            ]
        default:
            return [
                OnboardingCourseDraft(code: "", name: "Mathematics", isSuggested: true),
                OnboardingCourseDraft(code: "", name: "Turkish", isSuggested: true)
            ]
        }
    }

    private func labelForTrack(_ value: String) -> String {
        switch value {
        case "sayisal": return "Sayısal"
        case "sozel": return "Sözel"
        case "esit_agirlik": return "Eşit Ağırlık"
        case "dil": return "Dil"
        default: return value
        }
    }

    private func labelForGrade(_ value: String) -> String {
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
    
    private func normalizedUniversityYear(from gradeLevel: String) -> Int? {
        switch gradeLevel {
        case "1": return 1
        case "2": return 2
        case "3": return 3
        case "4": return 4
        case "5": return 5
        case "6": return 6
        default: return nil
        }
    }
    
   
    
    private func loadAllCoursesForSelectedMajor() async {
        guard let selectedMajorID else {
            allMajorCourses = []
            filteredCourseSuggestions = []
            return
        }

        isLoadingAllMajorCourses = true
        defer { isLoadingAllMajorCourses = false }

        do {
            let courses = try await StudentCatalogService.fetchAllCurriculumCourses(
                majorID: selectedMajorID
            )
            allMajorCourses = courses
            updateCourseSuggestions()
        } catch {
            print("❌ loadAllCoursesForSelectedMajor error:", error)
            allMajorCourses = []
            filteredCourseSuggestions = []
        }
    }

    private func updateCourseSuggestions() {
        let codeQuery = draftCourseCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameQuery = draftCourseName.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasCode = !codeQuery.isEmpty
        let hasName = !nameQuery.isEmpty

        let source = allMajorCourses

        let filtered: [CatalogCurriculumCourse]
        if !hasCode && !hasName {
            filtered = source.filter { course in
                !localCourses.contains {
                    $0.code.caseInsensitiveCompare(course.course_code) == .orderedSame &&
                    $0.name.caseInsensitiveCompare(course.course_name) == .orderedSame
                }
            }
        } else {
            filtered = source.filter { course in
                let matchesCode = !hasCode || course.course_code.localizedCaseInsensitiveContains(codeQuery)
                let matchesName = !hasName || course.course_name.localizedCaseInsensitiveContains(nameQuery)

                let notAlreadySelected = !localCourses.contains {
                    $0.code.caseInsensitiveCompare(course.course_code) == .orderedSame &&
                    $0.name.caseInsensitiveCompare(course.course_name) == .orderedSame
                }

                return matchesCode && matchesName && notAlreadySelected
            }
        }

        filteredCourseSuggestions = Array(filtered.prefix(8))
    }

    private func applyCourseSuggestion(_ course: CatalogCurriculumCourse) {
        let alreadyExists = localCourses.contains {
            $0.code.caseInsensitiveCompare(course.course_code) == .orderedSame &&
            $0.name.caseInsensitiveCompare(course.course_name) == .orderedSame
        }

        guard !alreadyExists else { return }

        localCourses.append(
            OnboardingCourseDraft(
                code: course.course_code,
                name: course.course_name,
                isSuggested: true
            )
        )

        draftCourseCode = ""
        draftCourseName = ""
        updateCourseSuggestions()
    }

    private func iconForTrack(_ value: String) -> String {
        switch value {
        case "sayisal": return "function"
        case "sozel": return "text.book.closed"
        case "esit_agirlik": return "scale.3d"
        case "dil": return "globe"
        default: return "square.grid.2x2"
        }
    }
}

private extension StudentOnboardingFlowView {
    func compactFeatureCard(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.blue)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.08))
        )
    }

    func compactInfoGroup(title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(items, id: \.1) { item in
                    Label {
                        Text(item.1)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.84))
                    } icon: {
                        Image(systemName: item.0)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.08))
        )
    }

    func compactCourseRow(
        course: OnboardingCourseDraft,
        isSuggested: Bool,
        onDelete: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(.blue.opacity(0.9))
                .frame(width: 4, height: 42)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if !course.code.isEmpty {
                        Text(course.code)
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.blue)
                    }

                    if isSuggested {
                        Text("Suggested")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.72))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(.white.opacity(0.08))
                            )
                    }
                }

                Text(course.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.red)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.05))
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.08))
        )
    }

    func selectionCard(
        title: String,
        subtitle: String,
        badge: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Text(badge)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.08))
                    )

                Spacer()

                Text(title)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isSelected ? .white.opacity(0.14) : .white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(isSelected ? .blue.opacity(0.72) : .white.opacity(0.08), lineWidth: 1.15)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    func selectionRowCard(
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 84)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? .blue.opacity(0.18) : .white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(isSelected ? .blue.opacity(0.72) : .white.opacity(0.07), lineWidth: 1.1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    func selectionNumberCard(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: 108)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(isSelected ? .blue.opacity(0.18) : .white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(isSelected ? .blue.opacity(0.72) : .white.opacity(0.08), lineWidth: 1.15)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    func selectionChip(
        icon: String,
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.blue)

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 92)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? .blue.opacity(0.22) : .white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(isSelected ? .blue.opacity(0.75) : .white.opacity(0.08), lineWidth: 1.15)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    func premiumTextField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.76))

            TextField("", text: text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.34)))
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.08))
                )
                .foregroundStyle(.white)
        }
    }

    func majorRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? .blue.opacity(0.18) : .white.opacity(0.07))
            )
        }
        .buttonStyle(.plain)
    }

    func premiumGoalCard(
        title: String,
        value: String,
        slider: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        helper: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Text(value)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.blue)
            }

            Slider(value: slider, in: range, step: step)
                .tint(.blue)

            Text(helper)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.54))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.08))
        )
    }
}
