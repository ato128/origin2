//
//  AIOnboardingStore.swift
//  DailyTodo
//
//  Drives the mascot-led onboarding conversation. The dialogue is SCRIPTED
//  (0 tokens) and USER-PACED — the mascot says one line at a time and waits
//  for the user to tap "Devam" before the next line. Course data comes from
//  the existing backend catalog; saving reuses StudentStore untouched.
//

import SwiftUI
import Combine

/// A course the user picks (or that is suggested) during onboarding, before it
/// is persisted as a real course. Shared by `StudentStore`, `CurriculumCatalog`
/// and the onboarding stores. (Previously lived in the now-removed
/// `StudentOnboardingFlowView`.)
struct OnboardingCourseDraft: Identifiable, Hashable {
    let id = UUID()
    var code: String
    var name: String
    var isSuggested: Bool = false
}

@MainActor
final class AIOnboardingStore: ObservableObject {

    enum Phase: Equatable {
        case greeting, education, university, grade, track, major, courses, goal, saving, finished
    }

    // MARK: - Conversation (user-paced)

    /// The single line the mascot is currently saying.
    @Published private(set) var currentLine: String = ""
    /// Lines still queued before this step's input is revealed.
    @Published private(set) var pendingLines: [String] = []
    /// When true, the phase's input controls are shown (instead of a "Devam" button).
    @Published private(set) var inputVisible = false
    /// Brief flag so the mascot animates its mouth when a new line appears.
    @Published private(set) var isSpeaking = false
    /// Network work in progress (majors/courses/saving) — show a spinner.
    @Published private(set) var isWorking = false

    @Published private(set) var phase: Phase = .greeting
    @Published var errorText: String?

    var hasMoreLines: Bool { !pendingLines.isEmpty }

    // MARK: - Collected answers (canonical values)

    @Published var educationLevel: String = "university"
    @Published var gradeLevel: String = "1"
    @Published var highSchoolTrack: String = "sayisal"

    @Published var selectedUniversityID: UUID?
    @Published var institutionName: String = ""
    @Published var institutionCountry: String = "tr"

    @Published var remoteMajors: [CatalogMajor] = []
    @Published var majorSearchText: String = ""
    @Published var selectedMajorID: UUID?
    @Published var majorName: String = ""

    @Published var suggestedCourses: [CatalogCurriculumCourse] = []
    @Published var selectedCourseIDs: Set<UUID> = []

    @Published var dailyStudyGoalMinutes: Double = 120

    private weak var studentStore: StudentStore?
    private var didStart = false

    func configure(studentStore: StudentStore) { self.studentStore = studentStore }

    var isUniversity: Bool { educationLevel == "university" }

    var filteredMajors: [CatalogMajor] {
        let q = majorSearchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return remoteMajors }
        return remoteMajors.filter { $0.name.lowercased().contains(q) }
    }

    var selectedCourseDrafts: [OnboardingCourseDraft] {
        suggestedCourses
            .filter { selectedCourseIDs.contains($0.id) }
            .map { OnboardingCourseDraft(code: $0.course_code, name: $0.course_name, isSuggested: true) }
    }

    var gradeOptions: [String] {
        isUniversity ? ["prep", "1", "2", "3", "4", "5", "6"] : ["9", "10", "11", "12"]
    }
    let trackOptions = ["sayisal", "sozel", "esit_agirlik", "dil"]

    // MARK: - Start

    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        present([tr("aio_greet_1"), tr("aio_greet_2"), tr("aio_q_education")], phase: .education)
    }

    // MARK: - Dialogue engine (user-paced)

    /// Show `lines` one at a time; reveal the phase's input once the last line is reached.
    private func present(_ lines: [String], phase newPhase: Phase) {
        var l = lines
        let first = l.isEmpty ? "" : l.removeFirst()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            phase = newPhase
            currentLine = first
            pendingLines = l
            inputVisible = l.isEmpty
            isWorking = false
        }
        speak()
    }

    /// Called by the "Devam" button.
    func tapContinue() {
        guard !pendingLines.isEmpty else { return }
        HapticManager.shared.selection()
        let next = pendingLines.removeFirst()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            currentLine = next
            if pendingLines.isEmpty { inputVisible = true }
        }
        speak()
    }

    private func speak() {
        isSpeaking = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            isSpeaking = false
        }
    }

    // MARK: - User answers

    func chooseEducation(_ level: String) {
        educationLevel = level
        gradeLevel = level == "university" ? "1" : "9"
        if level == "university" {
            present([tr("aio_q_university")], phase: .university)
        } else {
            // High school: no university catalog — skip institution and go to class.
            present([tr("aio_q_class")], phase: .grade)
        }
    }

    func universitySelected() {
        guard !institutionName.isEmpty else { return }
        HapticManager.shared.success()
        present([trArg("aio_uni_confirm", institutionName),
                 isUniversity ? tr("aio_q_year") : tr("aio_q_class")], phase: .grade)
    }

    func chooseGrade(_ value: String) {
        gradeLevel = value
        if isUniversity {
            beginMajorPhase()
        } else {
            present([tr("aio_q_track")], phase: .track)
        }
    }

    func chooseTrack(_ value: String) {
        highSchoolTrack = value
        present([tr("aio_q_goal")], phase: .goal)
    }

    func selectMajor(_ major: CatalogMajor) {
        selectedMajorID = major.id
        majorName = major.name
        HapticManager.shared.selection()
        beginCoursesPhase(majorID: major.id)
    }

    func toggleCourse(_ id: UUID) {
        if selectedCourseIDs.contains(id) { selectedCourseIDs.remove(id) } else { selectedCourseIDs.insert(id) }
        HapticManager.shared.selection()
    }

    func confirmCourses() {
        present([tr("aio_q_goal")], phase: .goal)
    }

    func confirmGoal() {
        Task { await finish() }
    }

    // MARK: - Catalog phases

    private func beginMajorPhase() {
        guard let uniID = selectedUniversityID else {
            present([tr("aio_q_major")], phase: .major); return
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            phase = .major
            currentLine = tr("aio_loading_majors")
            pendingLines = []
            inputVisible = false
            isWorking = true
        }
        speak()
        Task {
            do {
                let majors = try await StudentCatalogService.fetchMajors(universityID: uniID)
                remoteMajors = majors
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    isWorking = false
                    currentLine = majors.isEmpty ? tr("aio_no_majors") : tr("aio_q_major")
                    inputVisible = true
                }
                speak()
            } catch {
                withAnimation { isWorking = false; currentLine = tr("aio_majors_error"); inputVisible = false }
                speak()
            }
        }
    }

    private func beginCoursesPhase(majorID: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            phase = .courses
            currentLine = tr("aio_loading_courses")
            pendingLines = []
            inputVisible = false
            isWorking = true
        }
        speak()
        Task {
            do {
                let courses = try await StudentCatalogService.fetchCurriculumCourses(majorID: majorID, gradeLevel: gradeLevel)
                suggestedCourses = courses
                selectedCourseIDs = Set(courses.map { $0.id })
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    isWorking = false
                    currentLine = courses.isEmpty ? tr("aio_no_courses") : trArg("aio_courses_found", courses.count)
                    inputVisible = true
                }
                speak()
            } catch {
                withAnimation { isWorking = false; currentLine = tr("aio_courses_error"); inputVisible = true }
                speak()
            }
        }
    }

    // MARK: - Save

    private func finish() async {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            phase = .saving
            currentLine = tr("aio_saving")
            pendingLines = []
            inputVisible = false
            isWorking = true
        }
        speak()

        guard let studentStore else { isWorking = false; errorText = tr("aio_save_error"); return }
        do {
            try await studentStore.completeOnboardingAndSync(
                educationLevel: educationLevel,
                gradeLevel: gradeLevel,
                highSchoolTrack: isUniversity ? nil : highSchoolTrack,
                institutionName: institutionName.isEmpty ? nil : institutionName,
                institutionCountry: institutionCountry,
                majorName: majorName.isEmpty ? nil : majorName,
                dailyStudyGoalMinutes: Int(dailyStudyGoalMinutes),
                weeklyStudyGoalMinutes: Int(dailyStudyGoalMinutes) * 7,
                courseDrafts: selectedCourseDrafts
            )
            if !selectedCourseDrafts.isEmpty {
                studentStore.forceRestoreCoursesFromOnboardingDrafts(selectedCourseDrafts)
            }
            withAnimation { isWorking = false; phase = .finished; currentLine = tr("aio_done") }
            speak()
            HapticManager.shared.success()
        } catch {
            withAnimation { isWorking = false }
            errorText = tr("aio_save_error")
            HapticManager.shared.error()
        }
    }

    func retrySave() {
        errorText = nil
        Task { await finish() }
    }

    // MARK: - Display helpers (canonical → localized)

    func gradeDisplay(_ value: String) -> String {
        switch value {
        case "prep": return tr("grade_prep")
        case "1": return tr("grade_uni_1"); case "2": return tr("grade_uni_2")
        case "3": return tr("grade_uni_3"); case "4": return tr("grade_uni_4")
        case "5": return tr("grade_uni_5"); case "6": return tr("grade_uni_6")
        case "9": return tr("grade_hs_9"); case "10": return tr("grade_hs_10")
        case "11": return tr("grade_hs_11"); case "12": return tr("grade_hs_12")
        default: return value
        }
    }

    func trackDisplay(_ value: String) -> String {
        switch value {
        case "sayisal": return tr("track_sayisal"); case "sozel": return tr("track_sozel")
        case "esit_agirlik": return tr("track_esit_agirlik"); case "dil": return tr("track_dil")
        default: return value
        }
    }
}

private func trArg(_ key: String, _ arg: CVarArg) -> String { tr(key, arg) }
