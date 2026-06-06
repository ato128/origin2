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

private enum StudentOnboardingArenaPalette {
    static let backgroundTop = "#05060D"
    static let backgroundMid = "#070713"
    static let backgroundBottom = "#07040C"

    static let appBlue = "#1593FF"
    static let appBlueSoft = "#1E6BFF"
    static let appCyan = "#2DD4FF"
    static let appPurple = "#7C3AED"
    static let appViolet = "#8B5CF6"
    static let coral = "#FF5A44"
    static let gold = "#FBBF24"
    static let green = "#A3E635"

    static let surface = "#101118"
    static let surface2 = "#171821"

    static var appGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(studentOnboardingHex: appBlueSoft),
                Color(studentOnboardingHex: appPurple)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var hotGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(studentOnboardingHex: appBlue),
                Color(studentOnboardingHex: appPurple),
                Color(studentOnboardingHex: coral)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(studentOnboardingHex: surface).opacity(0.96),
                Color(studentOnboardingHex: surface2).opacity(0.88),
                Color(studentOnboardingHex: appBlue).opacity(0.035),
                Color(studentOnboardingHex: appPurple).opacity(0.045)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
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
    @State private var majorLoadRequestID = UUID()
    @State private var isSelectingMajorFromList: Bool = false

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
            StudentOnboardingArenaBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                progressSection

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        stepHero
                        stepContent
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, focusedField == nil ? 132 : 28)
                }
                .scrollDismissesKeyboard(.interactively)

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
                selectedUniversityID = nil
                selectedMajorID = nil
                majorName = ""
                majorSearchText = ""
                remoteMajors = []
                remoteSuggestedCourses = []
                allMajorCourses = []
                filteredCourseSuggestions = []
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
            allMajorCourses = []
            filteredCourseSuggestions = []
            selectedMajorID = nil
            majorName = ""
            majorSearchText = ""
            localCourses.removeAll(where: { $0.isSuggested })

            // Burada load çağırmıyoruz.
            // Major yükleme tek kaynak olarak selectedUniversityID değişiminden yapılır.
        }
        .onChange(of: selectedUniversityID) { _, newValue in
            remoteSuggestedCourses = []
            allMajorCourses = []
            filteredCourseSuggestions = []
            selectedMajorID = nil
            majorName = ""
            majorSearchText = ""
            localCourses.removeAll(where: { $0.isSuggested })

            guard newValue != nil else {
                remoteMajors = []
                return
            }

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
            return "Set up your profile, courses, and goals so Updo can work like a real student operating system."
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
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.075))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
            }

            Spacer()

            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appBlue))
                    .frame(width: 18, height: 1)

                Text("STEP \(currentStep + 1) / \(totalSteps)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.075))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(progressLabel.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.42))

                Spacer()

                Text(stepTitle)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 7)

                    Capsule()
                        .fill(StudentOnboardingArenaPalette.hotGradient)
                        .frame(width: geo.size.width * progressValue, height: 7)
                        .shadow(
                            color: Color(studentOnboardingHex: StudentOnboardingArenaPalette.appPurple).opacity(0.24),
                            radius: 8,
                            y: 3
                        )
                }
            }
            .frame(height: 7)
        }
        .padding(.horizontal, 24)
    }

    private var stepHero: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appBlue))
                    .frame(width: 18, height: 1)

                Text(stepContextPill.1.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }

            let split = splitHeroTitle(heroTitle)

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(split.first)
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.70)

                if !split.accent.isEmpty {
                    Text(split.accent)
                        .font(.system(size: 32, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan),
                                    Color(studentOnboardingHex: StudentOnboardingArenaPalette.appPurple)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                }
            }

            Text(heroSubtitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.58))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 1)
        }
    }

    private func splitHeroTitle(_ value: String) -> (first: String, accent: String) {
        let parts = value.split(separator: " ").map(String.init)

        guard parts.count > 1 else {
            return (value, "")
        }

        let first = parts.dropLast().joined(separator: " ")
        let accent = parts.last ?? ""

        return (first, accent)
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
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(studentOnboardingHex: StudentOnboardingArenaPalette.appBlue).opacity(0.18),
                                            Color(studentOnboardingHex: StudentOnboardingArenaPalette.appPurple).opacity(0.12)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 54, height: 54)

                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Selected university")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(.white.opacity(0.52))

                            Text(institutionName.isEmpty ? "Tap to choose university" : institutionName)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(institutionName.isEmpty ? .white.opacity(0.42) : .white)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)

                            if !institutionName.isEmpty {
                                Label(
                                    institutionCountry == "tr" ? "Türkiye" : "KKTC",
                                    systemImage: "flag.fill"
                                )
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan))
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.white.opacity(0.28))
                    }
                    .padding(14)
                    .background(studentOnboardingSurface(radius: 24))
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
                            .font(.system(size: 14, weight: .black, design: .rounded))
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
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.66))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)

                    } else if !institutionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && filteredMajors.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.white.opacity(0.45))

                            Text("No majors found for this university yet")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.60))
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
                                    isSelectingMajorFromList = true

                                    majorName = major.name
                                    majorSearchText = major.name
                                    selectedMajorID = major.id
                                    focusedField = nil

                                    Task {
                                        await loadAllCoursesForSelectedMajor()
                                        await applySuggestedUniversityCoursesIfAvailable(forceReplace: true)

                                        await MainActor.run {
                                            isSelectingMajorFromList = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(14)
                .background(studentOnboardingSurface(radius: 24))

                premiumTextField(
                    title: "Custom major",
                    text: $majorName,
                    placeholder: "Type your department"
                )
                .focused($focusedField, equals: .majorCustom)
                .onChange(of: majorName) { _, newValue in
                    guard !isSelectingMajorFromList else { return }

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
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("Suggestions")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(filteredCourseSuggestions.count)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingArenaPalette.gold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(studentOnboardingHex: StudentOnboardingArenaPalette.gold).opacity(0.12))
                    )
            }

            VStack(spacing: 10) {
                ForEach(filteredCourseSuggestions) { course in
                    Button {
                        applyCourseSuggestion(course)
                        focusedField = nil
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color(studentOnboardingHex: StudentOnboardingArenaPalette.gold))
                                .frame(width: 4, height: 46)

                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) {
                                    if !course.course_code.isEmpty {
                                        Text(course.course_code)
                                            .font(.system(size: 11, weight: .black, design: .monospaced))
                                            .tracking(0.8)
                                            .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingArenaPalette.gold))
                                    }

                                    Text("ADD")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .tracking(0.9)
                                        .foregroundStyle(.black.opacity(0.78))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color(studentOnboardingHex: StudentOnboardingArenaPalette.gold))
                                        )
                                }

                                Text(course.course_name)
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)

                                Text("Year \(course.year_number) • Term \(course.term_number ?? 0)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.44))
                            }

                            Spacer()

                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingArenaPalette.gold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.060))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color(studentOnboardingHex: StudentOnboardingArenaPalette.gold).opacity(0.14), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(studentOnboardingSurface(radius: 24))
    }

    private var selectedCoursesSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                HStack(spacing: 9) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan))

                    Text("Selected courses")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text("\(localCourses.count)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appBlue).opacity(0.13))
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
        .padding(16)
        .background(studentOnboardingSurface(radius: 24))
    }

    private var courseBuilderCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                HStack(spacing: 9) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan))

                    Text("Course builder")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

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
                    prompt: Text("Code").foregroundStyle(.white.opacity(0.30))
                )
                .textInputAutocapitalization(.characters)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .padding(.horizontal, 14)
                .frame(width: 104, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(Color.white.opacity(0.060))
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(Color.white.opacity(0.070), lineWidth: 1)
                        )
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
                    prompt: Text("Course name").foregroundStyle(.white.opacity(0.30))
                )
                .textInputAutocapitalization(.words)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(Color.white.opacity(0.060))
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(Color.white.opacity(0.070), lineWidth: 1)
                        )
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
                HStack(spacing: 9) {
                    Text("Add Course")
                        .font(.system(size: 15, weight: .black, design: .rounded))

                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .black))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    Capsule()
                        .fill(StudentOnboardingArenaPalette.hotGradient)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .shadow(
                            color: Color(studentOnboardingHex: StudentOnboardingArenaPalette.appPurple).opacity(0.20),
                            radius: 14,
                            y: 7
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(studentOnboardingSurface(radius: 24))
    }

    func sectionMiniHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))

            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
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
            HStack(spacing: 14) {
                if currentStep > 0 {
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                            currentStep -= 1
                        }
                    } label: {
                        Text("Back")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                            .frame(width: 108, height: 56)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.075))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    handleContinue()
                } label: {
                    HStack(spacing: 9) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.9)
                        }

                        Text(currentStep == totalSteps - 1 ? "Finish" : "Continue")
                            .font(.system(size: 17, weight: .black, design: .rounded))

                        Image(systemName: currentStep == totalSteps - 1 ? "checkmark.circle.fill" : "arrow.right")
                            .font(.system(size: 16, weight: .black))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        Capsule()
                            .fill(
                                canContinueCurrentStep
                                ? AnyShapeStyle(StudentOnboardingArenaPalette.hotGradient)
                                : AnyShapeStyle(Color.white.opacity(0.10))
                            )
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(canContinueCurrentStep ? 0.16 : 0.06), lineWidth: 1)
                    )
                    .shadow(
                        color: canContinueCurrentStep
                        ? Color(studentOnboardingHex: StudentOnboardingArenaPalette.appPurple).opacity(0.24)
                        : .clear,
                        radius: 16,
                        y: 8
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canContinueCurrentStep)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 22)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.82),
                    Color.black.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.08)

                Text("Saving your setup...")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))

                Text("Courses, profile and goals are being prepared.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
            .background(studentOnboardingSurface(radius: 26))
            .padding(.horizontal, 32)
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
        guard educationLevel == "university" else {
            isLoadingMajors = false
            return
        }

        guard let selectedUniversityID else {
            print("⚪️ loadMajors skipped: selectedUniversityID nil")
            remoteMajors = []
            isLoadingMajors = false
            return
        }

        let requestID = UUID()
        majorLoadRequestID = requestID

        isLoadingMajors = true

        defer {
            if majorLoadRequestID == requestID {
                isLoadingMajors = false
            }
        }

        do {
            print("🟡 loadMajors start:", selectedUniversityID)

            let majors = try await StudentCatalogService.fetchMajors(
                universityID: selectedUniversityID
            )

            guard majorLoadRequestID == requestID else {
                print("⚪️ loadMajors ignored: stale request")
                return
            }

            print("✅ loadMajors completed:", majors.count)

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
            guard majorLoadRequestID == requestID else { return }

            print("❌ loadMajorsForSelectedUniversity error:", error.localizedDescription)

            remoteMajors = []
            remoteSuggestedCourses = []
            allMajorCourses = []
            filteredCourseSuggestions = []
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
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(studentOnboardingHex: StudentOnboardingArenaPalette.appBlue).opacity(0.18),
                            Color(studentOnboardingHex: StudentOnboardingArenaPalette.appPurple).opacity(0.13)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan))
                )

            Text(title)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white.opacity(0.24))
        }
        .padding(13)
        .background(studentOnboardingSurface(radius: 24))
    }

    func compactInfoGroup(title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(items, id: \.1) { item in
                    Label {
                        Text(item.1)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.76))
                    } icon: {
                        Image(systemName: item.0)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan))
                    }
                }
            }
        }
        .padding(16)
        .background(studentOnboardingSurface(radius: 24))
    }

    func compactCourseRow(
        course: OnboardingCourseDraft,
        isSuggested: Bool,
        onDelete: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan),
                            Color(studentOnboardingHex: StudentOnboardingArenaPalette.appPurple)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if !course.code.isEmpty {
                        Text(course.code)
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan))
                    }

                    if isSuggested {
                        Text("SUGGESTED")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(0.9)
                            .foregroundStyle(.white.opacity(0.62))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.075))
                            )
                    }
                }

                Text(course.name)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingArenaPalette.coral))
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(Color(studentOnboardingHex: StudentOnboardingArenaPalette.coral).opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.070), lineWidth: 1)
                )
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
                Text(badge.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(isSelected ? Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan) : .white.opacity(0.46))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color(studentOnboardingHex: StudentOnboardingArenaPalette.appBlue).opacity(0.13) : Color.white.opacity(0.07))
                    )

                Spacer()

                Text(title)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(
                        isSelected
                        ? LinearGradient(
                            colors: [
                                Color(studentOnboardingHex: StudentOnboardingArenaPalette.appBlue).opacity(0.15),
                                Color(studentOnboardingHex: StudentOnboardingArenaPalette.appPurple).opacity(0.11),
                                Color.white.opacity(0.040)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : StudentOnboardingArenaPalette.cardGradient
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .stroke(
                                isSelected
                                ? Color(studentOnboardingHex: StudentOnboardingArenaPalette.appBlue).opacity(0.30)
                                : Color.white.opacity(0.075),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: isSelected ? Color(studentOnboardingHex: StudentOnboardingArenaPalette.appPurple).opacity(0.13) : Color.black.opacity(0.16),
                        radius: 14,
                        y: 7
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
            HStack(spacing: 13) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.52))
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(isSelected ? Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan) : .white.opacity(0.28))
            }
            .padding(.horizontal, 18)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? Color(studentOnboardingHex: StudentOnboardingArenaPalette.appBlue).opacity(0.13) : Color.white.opacity(0.060))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(isSelected ? Color(studentOnboardingHex: StudentOnboardingArenaPalette.appBlue).opacity(0.32) : Color.white.opacity(0.075), lineWidth: 1)
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
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(isSelected ? .black : .white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: 92)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            isSelected
                            ? AnyShapeStyle(StudentOnboardingArenaPalette.appGradient)
                            : AnyShapeStyle(Color.white.opacity(0.065))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.075), lineWidth: 1)
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
            VStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(isSelected ? .black : Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan))

                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? .black : .white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 84)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        isSelected
                        ? AnyShapeStyle(StudentOnboardingArenaPalette.appGradient)
                        : AnyShapeStyle(Color.white.opacity(0.065))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.075), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    func studentOnboardingSurface(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(StudentOnboardingArenaPalette.cardGradient)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.090),
                                Color(studentOnboardingHex: StudentOnboardingArenaPalette.appBlue).opacity(0.055),
                                Color.white.opacity(0.030)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.18), radius: 12, y: 7)
    }

    func premiumTextField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))

            HStack(spacing: 11) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan))
                    .frame(width: 22)

                TextField("", text: text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.30)))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.060))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.070), lineWidth: 1)
                    )
            )
        }
    }

    func majorRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isSelected
                        ? StudentOnboardingArenaPalette.appGradient
                        : LinearGradient(
                            colors: [
                                Color(studentOnboardingHex: StudentOnboardingArenaPalette.appBlue).opacity(0.10),
                                Color(studentOnboardingHex: StudentOnboardingArenaPalette.appPurple).opacity(0.07)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: isSelected ? "checkmark" : "graduationcap.fill")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(isSelected ? .black.opacity(0.78) : Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan))
                    )

                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white.opacity(0.24))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        isSelected
                        ? LinearGradient(
                            colors: [
                                Color(studentOnboardingHex: StudentOnboardingArenaPalette.appBlue).opacity(0.13),
                                Color(studentOnboardingHex: StudentOnboardingArenaPalette.appPurple).opacity(0.10),
                                Color.white.opacity(0.040)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                Color.white.opacity(0.055),
                                Color.white.opacity(0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                isSelected
                                ? Color(studentOnboardingHex: StudentOnboardingArenaPalette.appBlue).opacity(0.26)
                                : Color.white.opacity(0.065),
                                lineWidth: 1
                            )
                    )
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(helper)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.46))
                }

                Spacer()

                Text(value)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appBlue).opacity(0.13))
                    )
            }

            Slider(value: slider, in: range, step: step)
                .tint(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appCyan))
        }
        .padding(16)
        .background(studentOnboardingSurface(radius: 24))
    }
}

private struct StudentOnboardingArenaBackground: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(studentOnboardingHex: StudentOnboardingArenaPalette.backgroundTop),
                    Color(studentOnboardingHex: StudentOnboardingArenaPalette.backgroundMid),
                    Color(studentOnboardingHex: StudentOnboardingArenaPalette.backgroundBottom)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appBlue).opacity(0.10))
                .frame(width: 270, height: 270)
                .blur(radius: 100)
                .offset(x: 170, y: -250)

            Circle()
                .fill(Color(studentOnboardingHex: StudentOnboardingArenaPalette.appPurple).opacity(0.13))
                .frame(width: 320, height: 320)
                .blur(radius: 115)
                .offset(x: -180, y: 500)

            Circle()
                .fill(Color(studentOnboardingHex: StudentOnboardingArenaPalette.coral).opacity(0.060))
                .frame(width: 260, height: 260)
                .blur(radius: 105)
                .offset(x: 170, y: 300)

            Circle()
                .fill(Color(studentOnboardingHex: StudentOnboardingArenaPalette.gold).opacity(0.040))
                .frame(width: 220, height: 220)
                .blur(radius: 95)
                .offset(x: -170, y: -180)

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

private extension Color {
    init(studentOnboardingHex hex: String) {
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
            r = 21
            g = 147
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
