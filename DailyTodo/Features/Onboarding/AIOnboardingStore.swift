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
        case greeting, education, university, grade, track, major
        case courseMethod   // "kendim eklerim" vs "fotoğraf atarım"
        case coursePhotos   // 1-4 fotoğraf + tarama
        case weekTour       // Pzt→Paz gün gün kontrol/düzenleme
        case goal, saving, finished
    }

    /// Hafta turundaki tek satır: bir dersin bir günkü saati.
    struct TourEntry: Identifiable, Equatable {
        let id = UUID()
        var name: String
        var code: String = ""
        var weekday: Int
        var startMinute: Int
        var durationMinute: Int
        var room: String = ""
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

    // MARK: - Courses (photo scan or manual week tour)

    @Published private(set) var parsedCourses: [ParsedCourse] = []
    @Published private(set) var tourEntries: [TourEntry] = []
    /// Taramada bulunan ama saati okunamayan dersler — yine course olarak kaydedilir.
    @Published private(set) var timelessCourseDrafts: [OnboardingCourseDraft] = []
    @Published private(set) var tourDay: Int = 0
    @Published var isScanningPhotos = false

    private weak var studentStore: StudentStore?
    private var didStart = false

    func configure(studentStore: StudentStore) { self.studentStore = studentStore }

    var isUniversity: Bool { educationLevel == "university" }

    var courseDrafts: [OnboardingCourseDraft] {
        parsedCourses.map { OnboardingCourseDraft(code: $0.code, name: $0.name) }
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

    // MARK: - Course method (fotoğraf mı, elle mi?)

    private func beginCoursesPhase() {
        present([tr("aio_q_course_method")], phase: .courseMethod)
    }

    func chooseCourseMethodPhoto() {
        HapticManager.shared.selection()
        present([tr("aio_photos_prompt")], phase: .coursePhotos)
    }

    func chooseCourseMethodManual() {
        HapticManager.shared.selection()
        tourEntries = []
        timelessCourseDrafts = []
        startWeekTour(lines: [tr("aio_tour_intro_manual")])
    }

    /// Geri tuşu: yanlış seçimden yöntem ekranına dönüş.
    func backToCourseMethod() {
        isScanningPhotos = false
        HapticManager.shared.selection()
        beginCoursesPhase()
    }

    func skipCourses() {
        parsedCourses = []
        tourEntries = []
        timelessCourseDrafts = []
        present([tr("aio_q_goal")], phase: .goal)
    }

    // MARK: - Photo scan results

    func applyScanResults(_ scanned: [ScannedScheduleCourse]) {
        isScanningPhotos = false

        guard !scanned.isEmpty else {
            scanFailed(tr("css_scan_none"))
            return
        }

        var entries: [TourEntry] = []
        var timeless: [OnboardingCourseDraft] = []

        for course in scanned {
            if course.slots.isEmpty {
                timeless.append(OnboardingCourseDraft(code: course.code, name: course.name))
            }
            for slot in course.slots {
                entries.append(TourEntry(
                    name: course.name,
                    code: course.code,
                    weekday: slot.weekday,
                    startMinute: slot.startMinute,
                    durationMinute: slot.durationMinute,
                    room: slot.room ?? ""
                ))
            }
        }

        tourEntries = entries
        timelessCourseDrafts = timeless
        HapticManager.shared.success()
        startWeekTour(lines: [trArg("aio_scan_done", scanned.count)])
    }

    func scanFailed(_ message: String) {
        isScanningPhotos = false
        HapticManager.shared.error()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            currentLine = message
        }
        speak()
    }

    // MARK: - Week tour (Pzt → Paz, gün gün kontrol)

    private func startWeekTour(lines: [String]) {
        tourDay = 0
        present(lines + [tourDayLine(0)], phase: .weekTour)
    }

    private func tourDayLine(_ day: Int) -> String {
        trArg("aio_tour_day_q", Self.weekdayFullNames[day])
    }

    func entries(on day: Int) -> [TourEntry] {
        tourEntries
            .filter { $0.weekday == day }
            .sorted { $0.startMinute < $1.startMinute }
    }

    func addTourEntry(name: String, startMinute: Int, durationMinute: Int) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        tourEntries.append(TourEntry(
            name: clean,
            weekday: tourDay,
            startMinute: startMinute,
            durationMinute: durationMinute
        ))
        HapticManager.shared.success()
    }

    func removeTourEntry(_ id: UUID) {
        tourEntries.removeAll { $0.id == id }
        HapticManager.shared.selection()
    }

    func nextTourDay() {
        HapticManager.shared.selection()
        if tourDay < 6 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                tourDay += 1
                currentLine = tourDayLine(tourDay)
            }
            speak()
        } else {
            finishWeekTour()
        }
    }

    func goBackInTour() {
        HapticManager.shared.selection()
        if tourDay > 0 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                tourDay -= 1
                currentLine = tourDayLine(tourDay)
            }
            speak()
        } else {
            backToCourseMethod()
        }
    }

    private func finishWeekTour() {
        // Tur satırları → ders başına slot listesi (isim bazında grupla).
        var byKey: [String: ParsedCourse] = [:]
        var order: [String] = []

        for entry in tourEntries {
            let key = entry.name.lowercased()
            if byKey[key] == nil {
                byKey[key] = ParsedCourse(code: entry.code, name: entry.name, slots: [])
                order.append(key)
            }
            byKey[key]?.slots.append(ParsedCourseSlot(
                weekday: entry.weekday,
                startMinute: entry.startMinute,
                durationMinute: entry.durationMinute,
                room: entry.room.isEmpty ? nil : entry.room
            ))
        }

        var result = order.compactMap { byKey[$0] }

        // Saati okunamayan taranmış dersler de course olarak kaydedilir.
        for draft in timelessCourseDrafts where byKey[draft.name.lowercased()] == nil {
            result.append(ParsedCourse(code: draft.code, name: draft.name, slots: []))
        }

        parsedCourses = result
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

    static var weekdayFullNames: [String] {
        appLanguageIsEnglish()
            ? ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            : ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]
    }

    static func minuteText(_ minute: Int) -> String {
        String(format: "%02d.%02d", minute / 60, minute % 60)
    }
}

private func trArg(_ key: String, _ arg: CVarArg) -> String { tr(key, arg) }
private func trArg2(_ key: String, _ a: CVarArg, _ b: CVarArg) -> String { tr(key, a, b) }
