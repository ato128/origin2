//
//  StudentOnboardingFlowView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 23.04.2026.
//

import SwiftUI
import UIKit

struct OnboardingCourseDraft: Identifiable, Hashable {
    let id = UUID()
    var code: String
    var name: String
    var isSuggested: Bool = false
}

private enum StudentOnboardingPalette {
    static let backgroundTop = "#05060D"
    static let backgroundMid = "#070713"
    static let backgroundBottom = "#07040C"

    static let appBlue = "#1593FF"
    static let appBlueSoft = "#1E6BFF"
    static let appCyan = "#2DD4FF"
    static let appPurple = "#7C3AED"
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

    static var actionGradient: LinearGradient {
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedField: FocusField?

    @State private var currentStep: Int = 0
    @State private var isSubmitting: Bool = false
    @State private var submitError: String?

    @State private var educationLevel: String = "university"
    @State private var gradeLevel: String = "1"
    @State private var highSchoolTrack: String = "sayisal"

    @State private var institutionName: String = ""
    @State private var institutionCountry: String = "tr"
    @State private var showUniversityPicker: Bool = false

    @State private var majorName: String = ""
    @State private var majorSearchText: String = ""

    @State private var dailyStudyGoalMinutes: Double = 120

    @State private var draftCourseCode: String = ""
    @State private var draftCourseName: String = ""
    @State private var localCourses: [OnboardingCourseDraft] = []

    @State private var allMajorCourses: [CatalogCurriculumCourse] = []
    @State private var filteredCourseSuggestions: [CatalogCurriculumCourse] = []

    @State private var remoteMajors: [CatalogMajor] = []
    @State private var remoteSuggestedCourses: [CatalogCurriculumCourse] = []

    @State private var selectedUniversityID: UUID?
    @State private var selectedMajorID: UUID?

    @State private var isLoadingMajors: Bool = false
    @State private var isLoadingCurriculum: Bool = false
    @State private var isLoadingAllMajorCourses: Bool = false

    @State private var majorLoadRequestID = UUID()
    @State private var curriculumLoadRequestID = UUID()
    @State private var allCoursesLoadRequestID = UUID()

    @State private var isSelectingMajorFromList: Bool = false

    @State private var majorLoadError: String?
    @State private var curriculumLoadError: String?
    
    private let highSchoolGrades = ["9", "10", "11", "12"]
    private let universityGrades = ["prep", "1", "2", "3", "4", "5", "6"]
    private let highSchoolTracks = ["sayisal", "sozel", "esit_agirlik", "dil"]

    enum FocusField {
        case majorSearch
        case customMajor
        case courseCode
        case courseName
    }

    private var totalSteps: Int { 5 }

    private var progressText: String {
        "\(currentStep + 1) / \(totalSteps)"
    }

    private var progressValue: Double {
        Double(currentStep + 1) / Double(totalSteps)
    }

    private var title: String {
        switch currentStep {
        case 0: return "Level"
        case 1: return educationLevel == "high_school" ? "School" : "University"
        case 2: return educationLevel == "high_school" ? "Track" : "Major"
        case 3: return "Courses"
        default: return "Goal"
        }
    }

    private var subtitle: String {
        switch currentStep {
        case 0:
            return "Choose how Updo should shape your setup."
        case 1:
            return educationLevel == "high_school"
            ? "Pick your grade."
            : "Choose your university and year."
        case 2:
            return educationLevel == "high_school"
            ? "Pick your study track."
            : "Find your department."
        case 3:
            return "Select at least one course."
        default:
            return "Set your daily focus target."
        }
    }

    private var gradeOptions: [String] {
        educationLevel == "high_school" ? highSchoolGrades : universityGrades
    }

    private var filteredMajors: [CatalogMajor] {
        let query = normalizedSearchKey(majorSearchText)
        guard !query.isEmpty else { return remoteMajors }

        return remoteMajors.filter { major in
            normalizedSearchKey(major.name).contains(query) ||
            normalizedSearchKey(major.normalized_name ?? "").contains(query)
        }
    }

    private var canContinueCurrentStep: Bool {
        guard !isSubmitting else { return false }

        switch currentStep {
        case 0:
            return true
        case 1:
            if educationLevel == "high_school" {
                return !gradeLevel.isEmpty
            }
            return !institutionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !gradeLevel.isEmpty
        case 2:
            if educationLevel == "high_school" {
                return !highSchoolTrack.isEmpty
            }
            return !majorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 3:
            return !localCourses.isEmpty
        default:
            return true
        }
    }

    var body: some View {
        ZStack {
            StudentOnboardingBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                GeometryReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            hero
                            content
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 8)
                        .padding(.bottom, focusedField == nil ? 104 : 28)
                        .frame(minHeight: proxy.size.height, alignment: .top)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if focusedField == nil {
                    bottomBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
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
            hydrateInitialDrafts()
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
        .onChange(of: selectedUniversityID) { _, newValue in
            resetUniversityCatalogState(clearManualCourses: true)

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

    private var topBar: some View {
        HStack {
            Button {
                goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(currentStep > 0 ? .white.opacity(0.86) : .clear)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(currentStep > 0 ? Color.white.opacity(0.060) : Color.clear)
                            .overlay(
                                Circle()
                                    .stroke(currentStep > 0 ? Color.white.opacity(0.090) : Color.clear, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(currentStep == 0)

            Spacer()

            HStack(spacing: 8) {
                Capsule()
                    .fill(StudentOnboardingPalette.actionGradient)
                    .frame(width: 18, height: 2)

                Text(progressText)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingPalette.appCyan))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.055))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.090), lineWidth: 1)
                    )
            )

            Spacer()

            Color.clear
                .frame(width: 38, height: 38)
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProgressView(value: progressValue)
                .tint(Color(studentOnboardingHex: StudentOnboardingPalette.appCyan))
                .background(Color.white.opacity(0.08), in: Capsule())
                .clipShape(Capsule())
                .frame(height: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 39, weight: .black))
                    .tracking(-1.0)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(subtitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .id("hero-\(currentStep)-\(educationLevel)")
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing)))
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.88), value: currentStep)
    }

    @ViewBuilder
    private var content: some View {
        switch currentStep {
        case 0:
            levelStep
        case 1:
            schoolStep
        case 2:
            detailStep
        case 3:
            coursesStep
        default:
            goalStep
        }
    }

    private var levelStep: some View {
        VStack(spacing: 12) {
            twoColumnSelection(
                left: SelectionOption(
                    title: "University",
                    subtitle: "Degree or prep year",
                    icon: "building.columns.fill",
                    isSelected: educationLevel == "university"
                ),
                right: SelectionOption(
                    title: "High School",
                    subtitle: "Grades 9–12",
                    icon: "building.2.fill",
                    isSelected: educationLevel == "high_school"
                ),
                leftAction: {
                    StudentSetupHaptics.softTap()
                    educationLevel = "university"
                },
                rightAction: {
                    StudentSetupHaptics.softTap()
                    educationLevel = "high_school"
                }
            )

            MinimalInfoCard(
                icon: "sparkles",
                title: "Personal setup",
                subtitle: "Courses and goals shape Home, Focus and Insights."
            )
        }
    }

    @ViewBuilder
    private var schoolStep: some View {
        if educationLevel == "high_school" {
            VStack(spacing: 12) {
                gradePicker
            }
        } else {
            VStack(spacing: 12) {
                Button {
                    StudentSetupHaptics.softTap()
                    showUniversityPicker = true
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 19, weight: .black))
                            .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingPalette.appCyan))
                            .frame(width: 50, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .fill(Color(studentOnboardingHex: StudentOnboardingPalette.appBlue).opacity(0.13))
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("University")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(.white.opacity(0.50))

                            Text(institutionName.isEmpty ? "Choose university" : institutionName)
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(institutionName.isEmpty ? .white.opacity(0.42) : .white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            if !institutionName.isEmpty {
                                Text(institutionCountry.uppercased())
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .tracking(1.1)
                                    .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingPalette.appCyan))
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.white.opacity(0.30))
                    }
                    .padding(13)
                    .background(cardSurface(radius: 23))
                }
                .buttonStyle(.plain)

                gradePicker
            }
        }
    }

    private var gradePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(educationLevel == "high_school" ? "Grade" : "Year")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            if educationLevel == "university" {
                SelectionRow(
                    title: "Prep",
                    subtitle: "Language preparation",
                    isSelected: gradeLevel == "prep"
                ) {
                    StudentSetupHaptics.softTap()
                    gradeLevel = "prep"
                }
            }

            let numericGrades = gradeOptions.filter { $0 != "prep" }
            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(numericGrades, id: \.self) { grade in
                    Button {
                        StudentSetupHaptics.softTap()
                        gradeLevel = grade
                    } label: {
                        Text(educationLevel == "high_school" ? "\(grade). Grade" : "\(grade). Year")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(gradeLevel == grade ? .black.opacity(0.78) : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(
                                RoundedRectangle(cornerRadius: 19, style: .continuous)
                                    .fill(
                                        gradeLevel == grade
                                        ? AnyShapeStyle(StudentOnboardingPalette.appGradient)
                                        : AnyShapeStyle(Color.white.opacity(0.060))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                                            .stroke(Color.white.opacity(gradeLevel == grade ? 0.13 : 0.075), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(cardSurface(radius: 22))
    }

    @ViewBuilder
    private var detailStep: some View {
        if educationLevel == "high_school" {
            trackStep
        } else {
            majorStep
        }
    }

    private var trackStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Track")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(highSchoolTracks, id: \.self) { track in
                    Button {
                        StudentSetupHaptics.softTap()
                        highSchoolTrack = track
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: iconForTrack(track))
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(highSchoolTrack == track ? .black.opacity(0.75) : Color(studentOnboardingHex: StudentOnboardingPalette.appCyan))

                            Text(labelForTrack(track))
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(highSchoolTrack == track ? .black.opacity(0.78) : .white)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 84)
                        .background(
                            RoundedRectangle(cornerRadius: 21, style: .continuous)
                                .fill(
                                    highSchoolTrack == track
                                    ? AnyShapeStyle(StudentOnboardingPalette.appGradient)
                                    : AnyShapeStyle(Color.white.opacity(0.060))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                                        .stroke(Color.white.opacity(highSchoolTrack == track ? 0.13 : 0.075), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(cardSurface(radius: 22))
    }

    private var majorStep: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Search")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))

                searchField(
                    text: $majorSearchText,
                    placeholder: "Search major"
                )
                .focused($focusedField, equals: .majorSearch)
            }
            .padding(14)
            .background(cardSurface(radius: 22))

            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Text("Majors")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    if isLoadingMajors {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.82)
                    }
                }

                if institutionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    EmptyStateRow(
                        icon: "building.columns",
                        text: "Choose a university first."
                    )
                } else if isLoadingMajors && remoteMajors.isEmpty {
                    LoadingRow(text: "Loading majors...")
                } else if let majorLoadError {
                    VStack(spacing: 10) {
                        EmptyStateRow(
                            icon: "exclamationmark.triangle.fill",
                            text: majorLoadError
                        )

                        Button {
                            Task {
                                await loadMajorsForSelectedUniversity()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .black))

                                Text("Retry")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .tracking(0.8)
                            }
                            .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingPalette.appCyan))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(studentOnboardingHex: StudentOnboardingPalette.appCyan).opacity(0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color(studentOnboardingHex: StudentOnboardingPalette.appCyan).opacity(0.18), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } else if remoteMajors.isEmpty {
                    EmptyStateRow(
                        icon: "graduationcap",
                        text: "No catalog majors yet. You can type your major manually."
                    )
                } else if filteredMajors.isEmpty {
                    EmptyStateRow(
                        icon: "magnifyingglass",
                        text: "No result for this search."
                    )
                } else {
                    VStack(spacing: 8) {
                        ForEach(filteredMajors.prefix(6)) { major in
                            Button {
                                selectMajor(major)
                            } label: {
                                HStack(spacing: 11) {
                                    Image(systemName: majorName == major.name ? "checkmark.circle.fill" : "graduationcap.fill")
                                        .font(.system(size: 18, weight: .black))
                                        .foregroundStyle(Color(studentOnboardingHex: majorName == major.name ? StudentOnboardingPalette.green : StudentOnboardingPalette.appCyan))
                                        .frame(width: 32, height: 32)
                                        .background(
                                            Circle()
                                                .fill(Color.white.opacity(0.055))
                                        )

                                    Text(major.name)
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)

                                    Spacer()
                                }
                                .padding(11)
                                .background(
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .fill(Color.white.opacity(0.050))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                                .stroke(
                                                    majorName == major.name
                                                    ? Color(studentOnboardingHex: StudentOnboardingPalette.appCyan).opacity(0.22)
                                                    : Color.white.opacity(0.060),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(14)
            .background(cardSurface(radius: 22))

            VStack(alignment: .leading, spacing: 9) {
                Text("Custom")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))

                textField(
                    text: $majorName,
                    placeholder: "Type your department",
                    icon: "pencil"
                )
                .focused($focusedField, equals: .customMajor)
                .onChange(of: majorName) { _, newValue in
                    guard !isSelectingMajorFromList else { return }
                    handleCustomMajorChange(newValue)
                }
            }
            .padding(14)
            .background(cardSurface(radius: 22))
        }
    }

    private var coursesStep: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Selected")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    Text("\(localCourses.count)")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingPalette.appCyan))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(studentOnboardingHex: StudentOnboardingPalette.appBlue).opacity(0.13))
                        )
                }

                if localCourses.isEmpty {
                    EmptyStateRow(
                        icon: "book.closed",
                        text: "Add at least one course."
                    )
                } else {
                    VStack(spacing: 8) {
                        ForEach(localCourses) { course in
                            CourseRow(course: course) {
                                removeCourse(course)
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(cardSurface(radius: 22))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Add course")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    if isLoadingCurriculum || isLoadingAllMajorCourses {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.82)
                    }
                }

                HStack(spacing: 10) {
                    TextField(
                        "",
                        text: $draftCourseCode,
                        prompt: Text("Code").foregroundStyle(.white.opacity(0.30))
                    )
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(width: 96, height: 50)
                    .background(fieldBackground)
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
                    .autocorrectionDisabled()
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 50)
                    .background(fieldBackground)
                    .focused($focusedField, equals: .courseName)
                    .onChange(of: draftCourseName) { _, _ in
                        updateCourseSuggestions()
                    }
                }

                Button {
                    addDraftCourse()
                    focusedField = nil
                } label: {
                    HStack(spacing: 8) {
                        Text("Add")
                            .font(.system(size: 15, weight: .black, design: .rounded))

                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .black))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        Capsule()
                            .fill(StudentOnboardingPalette.actionGradient)
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(cardSurface(radius: 22))

            if !filteredCourseSuggestions.isEmpty {
                suggestionsView
            }

            if let curriculumLoadError {
                ErrorCard(text: curriculumLoadError)
            }

            if let submitError {
                ErrorCard(text: submitError)
            }
        }
    }

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Suggestions")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                ForEach(filteredCourseSuggestions.prefix(5)) { course in
                    Button {
                        applyCourseSuggestion(course)
                        focusedField = nil
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 19, weight: .black))
                                .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingPalette.gold))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(course.course_code.isEmpty ? course.course_name : "\(course.course_code) • \(course.course_name)")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                Text("Year \(course.year_number) • Term \(course.term_number ?? 0)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.42))
                            }

                            Spacer()
                        }
                        .padding(11)
                        .background(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(Color.white.opacity(0.050))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .stroke(Color(studentOnboardingHex: StudentOnboardingPalette.gold).opacity(0.14), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(cardSurface(radius: 22))
    }

    private var goalStep: some View {
        VStack(spacing: 12) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.075), lineWidth: 8)
                        .frame(width: 138, height: 138)

                    Circle()
                        .trim(from: 0, to: min(dailyStudyGoalMinutes / 240, 1.0))
                        .stroke(
                            StudentOnboardingPalette.actionGradient,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 138, height: 138)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: dailyStudyGoalMinutes)

                    VStack(spacing: 1) {
                        Text("\(Int(dailyStudyGoalMinutes))")
                            .font(.system(size: 36, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())

                        Text("minutes")
                            .font(.system(size: 13, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingPalette.appCyan))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 154)

                Slider(value: $dailyStudyGoalMinutes, in: 30...480, step: 15)
                    .tint(Color(studentOnboardingHex: StudentOnboardingPalette.appCyan))
            }
            .padding(16)
            .background(cardSurface(radius: 26))

            VStack(spacing: 8) {
                SummaryRow(
                    icon: "graduationcap.fill",
                    title: "Profile",
                    value: profileSummary
                )

                SummaryRow(
                    icon: "book.closed.fill",
                    title: "Courses",
                    value: "\(localCourses.count) selected"
                )

                SummaryRow(
                    icon: "target",
                    title: "Daily goal",
                    value: "\(Int(dailyStudyGoalMinutes)) min"
                )
            }
            .padding(14)
            .background(cardSurface(radius: 22))

            if let submitError {
                ErrorCard(text: submitError)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    goBack()
                } label: {
                    Text("Back")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: 92, height: 52)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.060))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.095), lineWidth: 1)
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
                            .scaleEffect(0.86)
                    }

                    Text(currentStep == totalSteps - 1 ? "Finish" : "Continue")
                        .font(.system(size: 16, weight: .black, design: .rounded))

                    Image(systemName: currentStep == totalSteps - 1 ? "checkmark" : "arrow.right")
                        .font(.system(size: 15, weight: .black))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    Capsule()
                        .fill(
                            canContinueCurrentStep
                            ? AnyShapeStyle(StudentOnboardingPalette.actionGradient)
                            : AnyShapeStyle(Color.white.opacity(0.10))
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(canContinueCurrentStep ? 0.15 : 0.060), lineWidth: 1)
                )
                .shadow(
                    color: canContinueCurrentStep
                    ? Color(studentOnboardingHex: StudentOnboardingPalette.appPurple).opacity(0.26)
                    : .clear,
                    radius: 16,
                    y: 8
                )
            }
            .buttonStyle(.plain)
            .disabled(!canContinueCurrentStep)
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 16)
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
            Color.black.opacity(0.50)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.05)

                Text("Saving setup")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Preparing your student space.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .background(cardSurface(radius: 26))
            .padding(.horizontal, 34)
        }
    }

    private var profileSummary: String {
        if educationLevel == "high_school" {
            return "\(gradeLevel). Grade • \(labelForTrack(highSchoolTrack))"
        }

        let year = gradeLevel == "prep" ? "Prep" : "\(gradeLevel). Year"
        let major = majorName.trimmingCharacters(in: .whitespacesAndNewlines)
        return major.isEmpty ? year : "\(year) • \(major)"
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.060))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.070), lineWidth: 1)
            )
    }

    private func cardSurface(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(StudentOnboardingPalette.cardGradient)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 12, y: 7)
    }
}

// MARK: - Logic

private extension StudentOnboardingFlowView {
    func resetUniversityCatalogState(clearManualCourses: Bool) {
        majorLoadRequestID = UUID()
        curriculumLoadRequestID = UUID()
        allCoursesLoadRequestID = UUID()

        remoteMajors = []
        remoteSuggestedCourses = []
        allMajorCourses = []
        filteredCourseSuggestions = []

        selectedMajorID = nil
        majorName = ""
        majorSearchText = ""

        draftCourseCode = ""
        draftCourseName = ""

        majorLoadError = nil
        curriculumLoadError = nil

        isLoadingMajors = false
        isLoadingCurriculum = false
        isLoadingAllMajorCourses = false

        if clearManualCourses {
            localCourses = []
        } else {
            localCourses.removeAll(where: { $0.isSuggested })
        }
    }

    func resetMajorCatalogState(keepManualCourses: Bool) {
        curriculumLoadRequestID = UUID()
        allCoursesLoadRequestID = UUID()

        remoteSuggestedCourses = []
        allMajorCourses = []
        filteredCourseSuggestions = []

        draftCourseCode = ""
        draftCourseName = ""

        curriculumLoadError = nil

        isLoadingCurriculum = false
        isLoadingAllMajorCourses = false

        if keepManualCourses {
            localCourses = localCourses.filter { !$0.isSuggested }
        } else {
            localCourses = []
        }
    }
    
    func hydrateInitialDrafts() {
        if localCourses.isEmpty {
            localCourses = defaultCoursesForCurrentSelection()
        }
    }

    func goBack() {
        guard currentStep > 0 else { return }

        StudentSetupHaptics.softTap()

        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            currentStep -= 1
        }
    }

    func handleContinue() {
        submitError = nil
        focusedField = nil

        guard canContinueCurrentStep else {
            StudentSetupHaptics.warning()
            return
        }

        if currentStep < totalSteps - 1 {
            StudentSetupHaptics.softTap()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                currentStep += 1
            }
        } else {
            Task {
                await completeOnboarding()
            }
        }
    }

    func completeOnboarding() async {
        guard !isSubmitting else { return }

        let cleanedMajor = majorName.trimmingCharacters(in: .whitespacesAndNewlines)

        let normalizedCourses = localCourses
            .map {
                OnboardingCourseDraft(
                    code: $0.code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                    name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    isSuggested: $0.isSuggested
                )
            }
            .filter { !$0.name.isEmpty }

        guard !normalizedCourses.isEmpty else {
            submitError = "Add at least one course."
            StudentSetupHaptics.warning()
            return
        }

        focusedField = nil
        submitError = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let computedWeeklyGoal = Int(dailyStudyGoalMinutes) * 7

            try await studentStore.completeOnboardingAndSync(
                educationLevel: educationLevel,
                gradeLevel: gradeLevel,
                highSchoolTrack: educationLevel == "high_school" ? highSchoolTrack : nil,
                institutionName: educationLevel == "university" ? institutionName : nil,
                institutionCountry: educationLevel == "university" ? institutionCountry : nil,
                majorName: educationLevel == "university" ? cleanedMajor : nil,
                dailyStudyGoalMinutes: Int(dailyStudyGoalMinutes),
                weeklyStudyGoalMinutes: computedWeeklyGoal,
                courseDrafts: normalizedCourses
            )

            studentStore.forceRestoreCoursesFromOnboardingDrafts(normalizedCourses)
            StudentSetupHaptics.success()
        } catch {
            submitError = "Setup could not be saved. Check your connection and try again."
            StudentSetupHaptics.warning()
            print("❌ STUDENT ONBOARDING COMPLETE ERROR:", error.localizedDescription)
        }
    }

    func selectMajor(_ major: CatalogMajor) {
        StudentSetupHaptics.softTap()
        isSelectingMajorFromList = true

        let isDifferentMajor = selectedMajorID != major.id

        if isDifferentMajor {
            resetMajorCatalogState(keepManualCourses: true)
        }

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

    func handleCustomMajorChange(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let matchedMajor = remoteMajors.first(where: {
            normalizedSearchKey($0.name) == normalizedSearchKey(trimmed) ||
            normalizedSearchKey($0.normalized_name ?? "") == normalizedSearchKey(trimmed)
        }) {
            let isDifferentMajor = selectedMajorID != matchedMajor.id

            if isDifferentMajor {
                resetMajorCatalogState(keepManualCourses: true)
            }

            selectedMajorID = matchedMajor.id

            Task {
                await loadAllCoursesForSelectedMajor()
                await applySuggestedUniversityCoursesIfAvailable(forceReplace: true)
            }
        } else {
            selectedMajorID = nil
            resetMajorCatalogState(keepManualCourses: true)
        }
    }

    @MainActor
    func loadMajorsForSelectedUniversity() async {
        guard educationLevel == "university" else {
            isLoadingMajors = false
            return
        }

        guard let selectedUniversityID else {
            remoteMajors = []
            majorLoadError = nil
            isLoadingMajors = false
            return
        }

        let requestID = UUID()
        majorLoadRequestID = requestID
        isLoadingMajors = true
        majorLoadError = nil

        defer {
            if majorLoadRequestID == requestID {
                isLoadingMajors = false
            }
        }

        do {
            print("🟡 loadMajors start")
            print("🟡 universityID:", selectedUniversityID.uuidString)
            print("🟡 institutionName:", institutionName)
            print("🟡 institutionCountry:", institutionCountry)

            let majors = try await StudentCatalogService.fetchMajors(
                universityID: selectedUniversityID
            )

            guard majorLoadRequestID == requestID else {
                print("⚪️ loadMajors ignored: stale request")
                return
            }

            print("✅ loadMajors completed:", majors.count)
            print("✅ loadMajors names:", majors.prefix(10).map(\.name).joined(separator: ", "))

            remoteMajors = majors
            majorLoadError = nil
            remoteSuggestedCourses = []
            allMajorCourses = []
            filteredCourseSuggestions = []
            localCourses = localCourses.filter { !$0.isSuggested }
            
            let trimmedMajor = majorName.trimmingCharacters(in: .whitespacesAndNewlines)

            if !trimmedMajor.isEmpty,
               let matchedMajor = majors.first(where: {
                   normalizedSearchKey($0.name) == normalizedSearchKey(trimmedMajor) ||
                   normalizedSearchKey($0.normalized_name ?? "") == normalizedSearchKey(trimmedMajor)
               }) {
                selectedMajorID = matchedMajor.id
                await loadAllCoursesForSelectedMajor()
                await applySuggestedUniversityCoursesIfAvailable(forceReplace: true)
            } else {
                selectedMajorID = nil
            }
        } catch {
            guard majorLoadRequestID == requestID else { return }

            let message = error.localizedDescription

            print("❌ loadMajorsForSelectedUniversity error:", message)

            remoteMajors = []
            remoteSuggestedCourses = []
            allMajorCourses = []
            filteredCourseSuggestions = []
            selectedMajorID = nil
            majorLoadError = "Could not load majors. \(message)"
        }
    }

    @MainActor
    func applySuggestedUniversityCoursesIfAvailable(forceReplace: Bool = false) async {
        guard educationLevel == "university" else { return }

        guard let selectedMajorID else {
            remoteSuggestedCourses = []

            if forceReplace {
                localCourses = localCourses.filter { !$0.isSuggested }
            }

            return
        }

        let requestID = UUID()
        curriculumLoadRequestID = requestID

        isLoadingCurriculum = true
        curriculumLoadError = nil

        defer {
            if curriculumLoadRequestID == requestID {
                isLoadingCurriculum = false
            }
        }

        do {
            let suggestions = try await StudentCatalogService.fetchCurriculumCourses(
                majorID: selectedMajorID,
                gradeLevel: gradeLevel
            )

            guard curriculumLoadRequestID == requestID else {
                print("⚪️ curriculum ignored: stale request")
                return
            }

            guard self.selectedMajorID == selectedMajorID else {
                print("⚪️ curriculum ignored: major changed")
                return
            }

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

            updateCourseSuggestions()
        } catch {
            guard curriculumLoadRequestID == requestID else { return }

            print("❌ applySuggestedUniversityCoursesIfAvailable error:", error.localizedDescription)

            remoteSuggestedCourses = []
            curriculumLoadError = "Could not load suggested courses. \(error.localizedDescription)"

            if forceReplace {
                localCourses = localCourses.filter { !$0.isSuggested }
            }

            updateCourseSuggestions()
        }
    }

    @MainActor
    func loadAllCoursesForSelectedMajor() async {
        guard let selectedMajorID else {
            allMajorCourses = []
            filteredCourseSuggestions = []
            return
        }

        let requestID = UUID()
        allCoursesLoadRequestID = requestID

        isLoadingAllMajorCourses = true

        defer {
            if allCoursesLoadRequestID == requestID {
                isLoadingAllMajorCourses = false
            }
        }

        do {
            let courses = try await StudentCatalogService.fetchAllCurriculumCourses(
                majorID: selectedMajorID
            )

            guard allCoursesLoadRequestID == requestID else {
                print("⚪️ all courses ignored: stale request")
                return
            }

            guard self.selectedMajorID == selectedMajorID else {
                print("⚪️ all courses ignored: major changed")
                return
            }

            allMajorCourses = courses
            updateCourseSuggestions()
        } catch {
            guard allCoursesLoadRequestID == requestID else { return }

            print("❌ loadAllCoursesForSelectedMajor error:", error.localizedDescription)

            allMajorCourses = []
            filteredCourseSuggestions = []
            updateCourseSuggestions()
        }
    }

    func updateCourseSuggestions() {
        let codeQuery = draftCourseCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameQuery = draftCourseName.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasCode = !codeQuery.isEmpty
        let hasName = !nameQuery.isEmpty

        let filtered: [CatalogCurriculumCourse]

        if !hasCode && !hasName {
            filtered = allMajorCourses.filter { course in
                !localCourses.contains {
                    $0.code.caseInsensitiveCompare(course.course_code) == .orderedSame &&
                    $0.name.caseInsensitiveCompare(course.course_name) == .orderedSame
                }
            }
        } else {
            filtered = allMajorCourses.filter { course in
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

    func applyCourseSuggestion(_ course: CatalogCurriculumCourse) {
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

    func addDraftCourse() {
        let trimmedCode = draftCourseCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let trimmedName = draftCourseName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            StudentSetupHaptics.warning()
            return
        }

        let alreadyExists = localCourses.contains {
            $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame &&
            $0.code.caseInsensitiveCompare(trimmedCode) == .orderedSame
        }

        guard !alreadyExists else {
            draftCourseCode = ""
            draftCourseName = ""
            updateCourseSuggestions()
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
        updateCourseSuggestions()
        StudentSetupHaptics.softTap()
    }

    func removeCourse(_ course: OnboardingCourseDraft) {
        localCourses.removeAll { $0.id == course.id }

        if course.isSuggested {
            remoteSuggestedCourses.removeAll {
                $0.course_code.caseInsensitiveCompare(course.code) == .orderedSame &&
                $0.course_name.caseInsensitiveCompare(course.name) == .orderedSame
            }
        }

        updateCourseSuggestions()
        StudentSetupHaptics.softTap()
    }

    func adaptGradeIfNeeded() {
        let options = gradeOptions
        if !options.contains(gradeLevel) {
            gradeLevel = options.first ?? "1"
        }
    }

    func defaultCoursesForCurrentSelection() -> [OnboardingCourseDraft] {
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

    func labelForTrack(_ value: String) -> String {
        switch value {
        case "sayisal": return "Sayısal"
        case "sozel": return "Sözel"
        case "esit_agirlik": return "Eşit Ağırlık"
        case "dil": return "Dil"
        default: return value
        }
    }

    func iconForTrack(_ value: String) -> String {
        switch value {
        case "sayisal": return "function"
        case "sozel": return "text.book.closed"
        case "esit_agirlik": return "scale.3d"
        case "dil": return "globe"
        default: return "square.grid.2x2"
        }
    }
    func normalizedSearchKey(_ text: String) -> String {
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
}

// MARK: - Small Components

private struct SelectionOption {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
}

private extension StudentOnboardingFlowView {
    func twoColumnSelection(
        left: SelectionOption,
        right: SelectionOption,
        leftAction: @escaping () -> Void,
        rightAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            selectionCard(option: left, action: leftAction)
            selectionCard(option: right, action: rightAction)
        }
    }

    func selectionCard(option: SelectionOption, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: option.icon)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(option.isSelected ? .black.opacity(0.76) : Color(studentOnboardingHex: StudentOnboardingPalette.appCyan))
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(option.isSelected ? Color.white.opacity(0.20) : Color.white.opacity(0.055))
                    )

                Spacer(minLength: 6)

                Text(option.title)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(option.isSelected ? .black.opacity(0.82) : .white)

                Text(option.subtitle)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(option.isSelected ? .black.opacity(0.52) : .white.opacity(0.52))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        option.isSelected
                        ? AnyShapeStyle(StudentOnboardingPalette.appGradient)
                        : AnyShapeStyle(StudentOnboardingPalette.cardGradient)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(option.isSelected ? 0.14 : 0.075), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    func searchField(text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingPalette.appCyan))

            TextField("", text: text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.30)))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 13)
        .frame(height: 52)
        .background(fieldBackground)
    }

    func textField(
        text: Binding<String>,
        placeholder: String,
        icon: String
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingPalette.appCyan))

            TextField("", text: text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.30)))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 13)
        .frame(height: 52)
        .background(fieldBackground)
    }
}

private struct SelectionRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.50))
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(isSelected ? Color(studentOnboardingHex: StudentOnboardingPalette.green) : .white.opacity(0.26))
            }
            .padding(.horizontal, 14)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(Color.white.opacity(0.055))
                    .overlay(
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .stroke(isSelected ? Color(studentOnboardingHex: StudentOnboardingPalette.green).opacity(0.20) : Color.white.opacity(0.065), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MinimalInfoCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingPalette.appCyan))
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(Color(studentOnboardingHex: StudentOnboardingPalette.appBlue).opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(CardSurface(radius: 20))
    }
}

private struct CourseRow: View {
    let course: OnboardingCourseDraft
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(studentOnboardingHex: StudentOnboardingPalette.appCyan),
                            Color(studentOnboardingHex: StudentOnboardingPalette.appPurple)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                if !course.code.isEmpty {
                    Text(course.code)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingPalette.appCyan))
                }

                Text(course.name)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            if course.isSuggested {
                Text("AUTO")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.52))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.075))
                    )
            }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingPalette.coral))
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Color(studentOnboardingHex: StudentOnboardingPalette.coral).opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white.opacity(0.050))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(Color.white.opacity(0.060), lineWidth: 1)
                )
        )
    }
}

private struct SummaryRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingPalette.appCyan))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color(studentOnboardingHex: StudentOnboardingPalette.appBlue).opacity(0.12))
                )

            Text(title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.60))

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .padding(.horizontal, 11)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(Color.white.opacity(0.060), lineWidth: 1)
                )
        )
    }
}

private struct EmptyStateRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.white.opacity(0.44))

            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white.opacity(0.040))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(Color.white.opacity(0.055), lineWidth: 1)
                )
        )
    }
}

private struct LoadingRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 11) {
            ProgressView()
                .tint(.white)
                .scaleEffect(0.85)

            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white.opacity(0.040))
        )
    }
}

private struct ErrorCard: View {
    let text: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Color(studentOnboardingHex: StudentOnboardingPalette.gold))

            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(Color(studentOnboardingHex: StudentOnboardingPalette.gold).opacity(0.13))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(Color(studentOnboardingHex: StudentOnboardingPalette.gold).opacity(0.22), lineWidth: 1)
        )
    }
}

private struct CardSurface: View {
    var radius: CGFloat = 26

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(StudentOnboardingPalette.cardGradient)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 12, y: 7)
    }
}

// MARK: - Background

private struct StudentOnboardingBackground: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(studentOnboardingHex: StudentOnboardingPalette.backgroundTop),
                    Color(studentOnboardingHex: StudentOnboardingPalette.backgroundMid),
                    Color(studentOnboardingHex: StudentOnboardingPalette.backgroundBottom)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(studentOnboardingHex: StudentOnboardingPalette.appBlue).opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 100)
                .offset(x: 172, y: -250)

            Circle()
                .fill(Color(studentOnboardingHex: StudentOnboardingPalette.appPurple).opacity(0.12))
                .frame(width: 310, height: 310)
                .blur(radius: 118)
                .offset(x: -190, y: 490)

            Circle()
                .fill(Color(studentOnboardingHex: StudentOnboardingPalette.coral).opacity(0.050))
                .frame(width: 250, height: 250)
                .blur(radius: 106)
                .offset(x: 160, y: 300)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.46)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Haptics

private enum StudentSetupHaptics {
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

    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
}

// MARK: - Color

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
