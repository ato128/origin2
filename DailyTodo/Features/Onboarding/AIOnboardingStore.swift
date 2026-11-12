//
//  AIOnboardingStore.swift
//  DailyTodo
//
//  Drives the onboarding conversation with Updo AI. The dialogue is SCRIPTED
//  (0 tokens) and reads like the real chat: Updo AI's lines are written out
//  one after another, the step's controls appear once it has finished
//  speaking, and each answer lands in the transcript as the user's message.
//
//  Flow — value first, questions after:
//  week (timetable photo scan, or a manual day-by-day tour) → "here is your
//  week" reveal → reminders primer (only once there are classes to remind
//  about) → education → university (single global search) → grade → (track
//  for HS / free-text major for uni) → daily goal → save (profile + courses +
//  weekly EventItems).
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
        case greeting
        case courseMethod   // first step: "fotoğraf atarım" vs "kendim eklerim"
        case coursePhotos   // 1-4 fotoğraf + tarama
        case weekReveal     // the scanned week, shown whole: accept or fix
        case weekTour       // Pzt→Paz gün gün kontrol/düzenleme
        case notify         // reminders primer, asked in context
        case education, university, grade, track, major
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

    // MARK: - Conversation

    /// One message in the conversation.
    struct ChatLine: Identifiable, Equatable {
        let id = UUID()
        let isUser: Bool
        var text: String
    }

    /// Everything said so far, oldest first.
    @Published private(set) var transcript: [ChatLine] = []
    /// The Updo AI line being written out right now (the view reports back
    /// through `lineFinished` when it is fully on screen).
    @Published private(set) var streamingLineID: UUID?
    /// How long the transcript was when the current step's controls appeared —
    /// stepping back cuts the conversation to here.
    private var phaseMark = 0

    /// The line Updo AI said last.
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

    // Geri (back) için ziyaret edilen adımların anlık görüntüleri.
    struct BackSnapshot { let phase: Phase; let line: String; let mark: Int }
    @Published private(set) var backStack: [BackSnapshot] = []
    var canGoBack: Bool { !backStack.isEmpty }


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

    // MARK: - Reminders primer

    /// True while iOS has never been asked — the only state in which our own
    /// question (and then the system prompt) makes sense.
    @Published private(set) var canAskNotifications = false
    private var didAskNotifications = false
    private var afterNotify: (() -> Void)?

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
        Analytics.shared.track("onboarding_setup_started")
        Task { canAskNotifications = await NotificationManager.shared.isUndetermined() }
        // The week comes first: it is the one step that hands something back.
        present([tr("aio_greet_1"), tr("aio_q_week_first")], phase: .courseMethod)
    }

    // MARK: - Dialogue engine (user-paced)

    /// Show `lines` one at a time; reveal the phase's input once the last line is reached.
    private func present(_ lines: [String], phase newPhase: Phase) {
        // İleri her geçişte mevcut (cevaplanabilir) adımı geri yığınına kaydet.
        switch phase {
        // `.notify` is answered once (iOS shows its prompt once), so it is
        // never a step to come back to.
        case .greeting, .saving, .finished, .notify: break
        default: backStack.append(BackSnapshot(phase: phase, line: currentLine, mark: phaseMark))
        }

        var l = lines
        let first = l.isEmpty ? nil : l.removeFirst()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            phase = newPhase
            pendingLines = l
            inputVisible = false
            isWorking = false
        }
        if let first { say(first) } else { revealInput() }
    }

    /// Updo AI says a line: it joins the transcript and is written out.
    private func say(_ text: String) {
        let line = ChatLine(isUser: false, text: text)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            currentLine = text
            transcript.append(line)
            streamingLineID = line.id
        }
        speak()
    }

    /// Same step, new wording (the day-by-day tour): the last Updo AI line is
    /// rewritten instead of piling up a line per day.
    private func sayInPlace(_ text: String) {
        if let last = transcript.last, !last.isUser {
            transcript.removeLast()
        }
        say(text)
    }

    /// The user's answer, as their message in the conversation.
    private func userSaid(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            transcript.append(ChatLine(isUser: true, text: clean))
        }
    }

    /// The view finished writing a line out: say the next queued one, or show
    /// this step's controls.
    func lineFinished(_ id: UUID) {
        guard streamingLineID == id else { return }
        streamingLineID = nil

        guard !pendingLines.isEmpty else { revealInput(); return }
        let next = pendingLines.removeFirst()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 260_000_000)
            say(next)
        }
    }

    private func revealInput() {
        phaseMark = transcript.count
        guard phase != .saving, phase != .finished else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { inputVisible = true }
    }

    /// Sol-üst geri tuşu: bir önceki adıma dön, o adımın sorusunu yeniden göster.
    func goBack() {
        guard let snap = backStack.popLast() else { return }
        HapticManager.shared.selection()
        universitySearchTask?.cancel()
        isScanningPhotos = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            phase = snap.phase
            currentLine = snap.line
            // Back to where that step's question had just been asked.
            transcript = Array(transcript.prefix(snap.mark))
            phaseMark = snap.mark
            streamingLineID = nil
            pendingLines = []
            inputVisible = true
            isWorking = false
            isSpeaking = false
        }
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
        userSaid(tr(level == "university" ? "aio_a_university" : "aio_a_highschool"))
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
        // student_profiles CHECK constraint wants lowercase codes (tr/kktc).
        institutionCountry = university.country_code.lowercased()
        universityQuery = university.name
        universityMatches = []
        HapticManager.shared.success()
        userSaid(university.name)

        present([trArg("aio_uni_confirm", institutionName), tr("aio_q_year")], phase: .grade)
    }

    // MARK: - Grade & track

    func chooseGrade(_ value: String) {
        userSaid(gradeDisplay(value))
        gradeLevel = value
        if isUniversity {
            present([tr("aio_q_major_free")], phase: .major)
        } else {
            present([tr("aio_q_track")], phase: .track)
        }
    }

    func chooseTrack(_ value: String) {
        userSaid(trackDisplay(value))
        highSchoolTrack = value
        beginGoalPhase()
    }

    // MARK: - Major (free text)

    func confirmMajor(_ text: String) {
        majorName = text.trimmingCharacters(in: .whitespacesAndNewlines)
        userSaid(majorName.isEmpty ? tr("aio_skip") : majorName)
        HapticManager.shared.selection()
        beginGoalPhase()
    }

    private func beginGoalPhase() {
        present([tr("aio_q_goal")], phase: .goal)
    }

    // MARK: - Profile questions (after the week is in place)

    private func beginProfilePhase() {
        present([tr(parsedCourses.isEmpty ? "aio_q_education" : "aio_q_education_after_week")], phase: .education)
    }

    // MARK: - Course method (fotoğraf mı, elle mi?)

    private func beginCoursesPhase() {
        present([tr("aio_q_week_first")], phase: .courseMethod)
    }

    func chooseCourseMethodPhoto() {
        HapticManager.shared.selection()
        userSaid(tr("aio_m_photo"))
        Analytics.shared.track("onboarding_week_method", properties: ["method": "photo"])
        present([tr("aio_photos_prompt")], phase: .coursePhotos)
    }

    func chooseCourseMethodManual() {
        HapticManager.shared.selection()
        userSaid(tr("aio_m_manual"))
        Analytics.shared.track("onboarding_week_method", properties: ["method": "manual"])
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
        userSaid(tr("aio_skip"))
        Analytics.shared.track("onboarding_week_method", properties: ["method": "skip"])
        parsedCourses = []
        tourEntries = []
        timelessCourseDrafts = []
        beginProfilePhase()
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
        Analytics.shared.track("onboarding_week_scanned", properties: ["courses": scanned.count, "slots": entries.count])

        // Nothing readable on the grid (no times) → there is no week to show
        // yet; go straight to the day-by-day tour to place them.
        guard !entries.isEmpty else {
            startWeekTour(lines: [trArg("aio_scan_done", scanned.count)])
            return
        }
        present([trArg2("aio_reveal_line", OnboardingCount.courses(scanned.count), OnboardingCount.days(Set(entries.map(\.weekday)).count))], phase: .weekReveal)
    }

    // MARK: - Week reveal (the whole scanned week at once)

    /// The scanned classes as grid blocks. Colours follow the order courses
    /// first appear in — the same order `createScheduleEvents` colours the
    /// real events in, so the preview matches the Week tab afterwards.
    var weekBlocks: [OnboardingWeekBlock] {
        var colorByCourse: [String: Int] = [:]
        return tourEntries.map { entry in
            let key = entry.name.lowercased()
            let index = colorByCourse[key] ?? colorByCourse.count
            colorByCourse[key] = index
            return OnboardingWeekBlock(
                id: entry.id,
                weekday: entry.weekday,
                startMinute: entry.startMinute,
                durationMinute: entry.durationMinute,
                title: entry.name,
                colorHex: OnboardingWeekBlock.palette[index % OnboardingWeekBlock.palette.count]
            )
        }
    }

    /// "Looks right" — keep the week as scanned.
    func acceptWeek() {
        userSaid(tr("aio_reveal_ok"))
        HapticManager.shared.success()
        finishWeekTour()
    }

    /// "Fix something" — walk the week day by day.
    func editWeek() {
        userSaid(tr("aio_reveal_fix"))
        HapticManager.shared.selection()
        startWeekTour(lines: [])
    }

    /// The photos were handed over — shown as the user's message while the
    /// scan runs.
    func photosSent(_ count: Int) {
        userSaid(tr(count == 1 ? "aio_user_photo_one" : "aio_user_photo_other", count))
    }

    func scanFailed(_ message: String) {
        isScanningPhotos = false
        HapticManager.shared.error()
        say(message)
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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { tourDay += 1 }
            sayInPlace(tourDayLine(tourDay))
        } else {
            finishWeekTour()
        }
    }

    func goBackInTour() {
        HapticManager.shared.selection()
        if tourDay > 0 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { tourDay -= 1 }
            sayInPlace(tourDayLine(tourDay))
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

        // Reminders are asked for here, where they mean something: right after
        // the classes they would announce are on screen.
        if result.contains(where: \.hasSchedule) {
            askNotifications(line: tr("aio_q_notify_class")) { [weak self] in self?.beginProfilePhase() }
        } else {
            beginProfilePhase()
        }
    }

    // MARK: - Reminders primer

    /// Asks our own question first; the system prompt only follows a "yes".
    /// Runs `next` straight away when iOS has already been asked, or we have.
    private func askNotifications(line: String, then next: @escaping () -> Void) {
        guard canAskNotifications, !didAskNotifications else { next(); return }
        afterNotify = next
        present([line], phase: .notify)
    }

    func answerNotifications(allow: Bool) {
        guard phase == .notify, !isWorking else { return }
        HapticManager.shared.selection()
        userSaid(tr(allow ? "aio_notify_yes" : "aio_notify_later"))
        Analytics.shared.track("onboarding_notify_primer", properties: ["answer": allow ? "yes" : "later"])
        // Marked on the answer, not on the question: stepping back and forward
        // again must still ask.
        didAskNotifications = true
        let next = afterNotify
        afterNotify = nil

        guard allow else {
            NotificationManager.shared.recordPrimerDeclined()
            next?()
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) { isWorking = true; inputVisible = false }
        Task {
            let granted = await NotificationManager.shared.requestPermissionFromPrimer()
            Analytics.shared.track("onboarding_notify_system", properties: ["granted": granted])
            canAskNotifications = false
            next?()
        }
    }

    // MARK: - Goal & save

    func confirmGoal() {
        userSaid(tr("aio_goal_value", Int(dailyStudyGoalMinutes)))
        // No classes yet → the reminders question comes here instead, tied to
        // the goal just set.
        askNotifications(line: tr("aio_q_notify_goal")) { [weak self] in
            Task { await self?.finish() }
        }
    }

    private func finish() async {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            phase = .saving
            pendingLines = []
            inputVisible = false
            isWorking = true
        }
        say(tr("aio_saving"))

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

            // The classes exist now — put their "10 minutes before" reminders
            // in place (a no-op unless notifications were just allowed).
            await studentStore.refreshClassReminders()
            Analytics.shared.track("onboarding_setup_finished", properties: [
                "courses": parsedCourses.count,
                "has_week": parsedCourses.contains(where: \.hasSchedule)
            ])

            // Kurulum artık YEREL + anlık (remote arkada senkronlanıyor). "setting
            // up…" mesajı flash gibi geçmesin diye kısa, kasıtlı bir beat — akıcı
            // ve premium hissettirir.
            try? await Task.sleep(nanoseconds: 650_000_000)

            withAnimation { isWorking = false; phase = .finished }
            say(tr("aio_done"))
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
