//
//  AIOnboardingStore.swift
//  DailyTodo
//
//  Drives the mascot-led onboarding conversation. The dialogue is SCRIPTED
//  (0 tokens) and USER-PACED — the mascot says one line at a time and waits
//  for the user to tap "Devam" before the next line.
//
//  Flow: education → university (single global search, no country split) →
//  grade → (track for HS / free-text major for uni) → courses (type or paste,
//  parsed by OnboardingCourseParser) → schedule fill for courses missing a
//  day/time → daily goal → save (profile + courses + weekly EventItems).
//

import SwiftUI
import Combine

/// A course the user picks (or that is suggested) during onboarding, before it
/// is persisted as a real course. Shared by `StudentStore` and the onboarding
/// stores.
struct OnboardingCourseDraft: Identifiable, Hashable {
    let id = UUID()
    var code: String
    var name: String
    var isSuggested: Bool = false
}

@MainActor
final class AIOnboardingStore: ObservableObject {

    enum Phase: Equatable {
        case greeting, education, university, grade, track, major, courses, schedule, goal, saving, finished
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
    /// Network work in progress (saving) — show a spinner.
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

    @Published var majorName: String = ""

    @Published var dailyStudyGoalMinutes: Double = 120

    // MARK: - University search (single global list)

    @Published var universityQuery: String = ""
    @Published private(set) var universityMatches: [CatalogUniversity] = []
    @Published private(set) var isSearchingUniversities = false

    private var universitySearchTask: Task<Void, Never>?

    // MARK: - Courses (typed or pasted)

    @Published var courseInputText: String = ""
    @Published private(set) var parsedCourses: [ParsedCourse] = []
    /// false → the free-text editor is showing; true → the parsed list.
    @Published private(set) var coursesParsed = false

    /// Day/time picks for courses the parser couldn't schedule.
    @Published var scheduleDayByCourse: [UUID: Int] = [:]
    @Published var scheduleMinuteByCourse: [UUID: Int] = [:]

    private weak var studentStore: StudentStore?
    private var didStart = false

    func configure(studentStore: StudentStore) { self.studentStore = studentStore }

    var isUniversity: Bool { educationLevel == "university" }

    var courseDrafts: [OnboardingCourseDraft] {
        parsedCourses.map { OnboardingCourseDraft(code: $0.code, name: $0.name) }
    }

    /// Courses that still need a day/time in the schedule phase.
    var unscheduledCourses: [ParsedCourse] {
        parsedCourses.filter { !$0.hasSchedule }
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

    // MARK: - Education

    func chooseEducation(_ level: String) {
        educationLevel = level
        gradeLevel = level == "university" ? "1" : "9"
        if level == "university" {
            present([tr("aio_q_university")], phase: .university)
        } else {
            present([tr("aio_q_class")], phase: .grade)
        }
    }

    // MARK: - University (global alphabetical autocomplete)

    func universityQueryChanged(_ text: String) {
        universityQuery = text
        universitySearchTask?.cancel()

        let query = text.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else {
            universityMatches = []
            isSearchingUniversities = false
            return
        }

        isSearchingUniversities = true
        universitySearchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }

            do {
                let results = try await StudentCatalogService.fetchUniversities(query: query)
                guard !Task.isCancelled else { return }
                self?.universityMatches = Array(results.prefix(30))
            } catch {
                // Silent — the list simply stays as-is; typing again retries.
            }
            self?.isSearchingUniversities = false
        }
    }

    func selectUniversity(_ university: CatalogUniversity) {
        selectedUniversityID = university.id
        institutionName = university.name
        institutionCountry = university.country_code
        universityQuery = university.name
        universityMatches = []
        HapticManager.shared.success()

        present([trArg("aio_uni_confirm", institutionName), tr("aio_q_year")], phase: .grade)
    }

    // MARK: - Grade & track

    func chooseGrade(_ value: String) {
        gradeLevel = value
        if isUniversity {
            present([tr("aio_q_major_free")], phase: .major)
        } else {
            present([tr("aio_q_track")], phase: .track)
        }
    }

    func chooseTrack(_ value: String) {
        highSchoolTrack = value
        beginCoursesPhase()
    }

    // MARK: - Major (free text)

    func confirmMajor(_ text: String) {
        majorName = text.trimmingCharacters(in: .whitespacesAndNewlines)
        HapticManager.shared.selection()
        beginCoursesPhase()
    }

    // MARK: - Courses (type or paste → parser)

    private func beginCoursesPhase() {
        coursesParsed = false
        present([tr("aio_q_courses_1"), tr("aio_q_courses_2")], phase: .courses)
    }

    func parseCourseInput() {
        let parsed = OnboardingCourseParser.parse(courseInputText)

        guard !parsed.isEmpty else {
            HapticManager.shared.error()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                currentLine = tr("aio_courses_parse_empty")
            }
            speak()
            return
        }

        parsedCourses = parsed
        HapticManager.shared.success()

        let scheduledCount = parsed.filter(\.hasSchedule).count
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            coursesParsed = true
            currentLine = scheduledCount > 0
                ? trArg2("aio_courses_parsed_with_time", parsed.count, scheduledCount)
                : trArg("aio_courses_parsed", parsed.count)
        }
        speak()
    }

    func removeParsedCourse(_ id: UUID) {
        parsedCourses.removeAll { $0.id == id }
        HapticManager.shared.selection()
        if parsedCourses.isEmpty { editCoursesAgain() }
    }

    func editCoursesAgain() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            coursesParsed = false
            currentLine = tr("aio_q_courses_2")
        }
    }

    func confirmParsedCourses() {
        if unscheduledCourses.isEmpty {
            present([tr("aio_q_goal")], phase: .goal)
        } else {
            present([tr("aio_q_schedule")], phase: .schedule)
        }
    }

    func skipCourses() {
        parsedCourses = []
        present([tr("aio_q_goal")], phase: .goal)
    }

    // MARK: - Schedule fill (courses without a parsed day/time)

    func setScheduleDay(_ courseID: UUID, weekday: Int) {
        scheduleDayByCourse[courseID] = weekday
        HapticManager.shared.selection()
    }

    func setScheduleMinute(_ courseID: UUID, minute: Int) {
        scheduleMinuteByCourse[courseID] = minute
        HapticManager.shared.selection()
    }

    func confirmSchedule() {
        // Fold the picks back into the parsed courses; anything still missing
        // a day or time simply gets no weekly event (addable later in Week).
        for index in parsedCourses.indices where !parsedCourses[index].hasSchedule {
            let id = parsedCourses[index].id
            guard let day = scheduleDayByCourse[id], let minute = scheduleMinuteByCourse[id] else { continue }

            parsedCourses[index].slots = [
                ParsedCourseSlot(
                    weekday: day,
                    startMinute: minute,
                    durationMinute: OnboardingCourseParser.defaultDurationMinutes
                )
            ]
        }

        present([tr("aio_q_goal")], phase: .goal)
    }

    // MARK: - Goal & save

    func confirmGoal() {
        Task { await finish() }
    }

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
                courseDrafts: courseDrafts
            )
            if !courseDrafts.isEmpty {
                studentStore.forceRestoreCoursesFromOnboardingDrafts(courseDrafts)
            }

            // Weekly schedule: every parsed/picked slot becomes a real event.
            studentStore.createScheduleEvents(from: parsedCourses)

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

    static var weekdayShortNames: [String] {
        appLanguageIsEnglish()
            ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            : ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
    }

    static func minuteText(_ minute: Int) -> String {
        String(format: "%02d.%02d", minute / 60, minute % 60)
    }
}

private func trArg(_ key: String, _ arg: CVarArg) -> String { tr(key, arg) }
private func trArg2(_ key: String, _ a: CVarArg, _ b: CVarArg) -> String { tr(key, a, b) }
