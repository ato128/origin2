//
//  StudentStore.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 23.04.2026.
//

import Foundation
import SwiftData
import SwiftUI
import Combine
import Supabase

private struct StudentProfileRow: Codable {
    let user_id: UUID
    let education_level: String
    let grade_level: String
    let high_school_track: String?
    let institution_name: String?
    let institution_country: String?
    let major_name: String?
    let daily_study_goal_minutes: Int
    let weekly_study_goal_minutes: Int
    let onboarding_completed: Bool
    let academic_year_start: Int?
    let last_promoted_at: String?
    let created_at: String?
    let updated_at: String?
}

private struct StudentCourseRow: Codable {
    let id: UUID
    let user_id: UUID
    let course_code: String
    let course_name: String
    let institution_name: String?
    let major_name: String?
    let grade_level: String?
    let year_number: Int?
    let term_number: Int?
    let source_type: String
    let is_archived: Bool
    let created_at: String?
    let updated_at: String?
}

@MainActor
final class StudentStore: ObservableObject {
    private let context: ModelContext

    @Published private(set) var currentUserID: String?
    @Published private(set) var profile: StudentProfile?
    @Published private(set) var courses: [Course] = []

    @Published var isLoading: Bool = false
    @Published var didResolveRemoteProfile: Bool = false

    init(context: ModelContext, currentUserID: String? = nil) {
        self.context = context
        self.currentUserID = currentUserID
        reload()
    }

    var hasCompletedStudentProfile: Bool {
        profile?.onboardingCompleted == true
    }

    func setCurrentUserID(_ userID: String?) {
        currentUserID = userID
        didResolveRemoteProfile = false

        if userID == nil {
            profile = nil
            courses = []
            reload()
            return
        }

        reload()

        Task {
            await loadFromRemote()
        }
    }

    func reload() {
        guard let currentUserID else {
            profile = nil
            courses = []
            return
        }

        do {
            let profileDescriptor = FetchDescriptor<StudentProfile>()
            let allProfiles = try context.fetch(profileDescriptor)
            profile = allProfiles.first(where: { $0.ownerUserID == currentUserID })

            let courseDescriptor = FetchDescriptor<Course>(
                sortBy: [SortDescriptor(\Course.createdAt, order: .forward)]
            )
            let allCourses = try context.fetch(courseDescriptor)
            courses = allCourses.filter {
                $0.ownerUserID == currentUserID && !$0.isArchived
            }
        } catch {
            Log.debug("❌ StudentStore.reload error:", error)
            profile = nil
            courses = []
        }
    }

    // MARK: - Public Remote API

    func loadFromRemote() async {
        guard let currentUserID else {
            didResolveRemoteProfile = true
            return
        }

        guard let userUUID = UUID(uuidString: currentUserID) else {
            didResolveRemoteProfile = true
            return
        }

        isLoading = true
        defer {
            isLoading = false
            didResolveRemoteProfile = true
        }

        do {
            // Onboarding remote senkronu daha önce başarısız olduysa burada
            // sessizce telafi et (throttle'lı, güvenli) — sonra normal çekim.
            await retryPendingOnboardingSyncIfNeeded()

            let profileResponse = try await SupabaseManager.shared.client
                .from("student_profiles")
                .select()
                .eq("user_id", value: userUUID.uuidString)
                .limit(1)
                .execute()

            if let rows = try? JSONDecoder().decode([StudentProfileRow].self, from: profileResponse.data),
               let profileRow = rows.first {
                upsertLocalProfile(from: profileRow)
            }

            let coursesResponse = try await SupabaseManager.shared.client
                .from("student_courses")
                .select()
                .eq("user_id", value: userUUID.uuidString)
                .eq("is_archived", value: false)
                .order("created_at", ascending: true)
                .execute()

            if let rows = try? JSONDecoder().decode([StudentCourseRow].self, from: coursesResponse.data) {
                replaceLocalCourses(from: rows)
            }

            reload()
        } catch {
            Log.debug("❌ StudentStore.loadFromRemote error:", error)
            reload()
        }
    }

    func saveStudentProfile(
        educationLevel: String,
        gradeLevel: String,
        highSchoolTrack: String?,
        institutionName: String?,
        institutionCountry: String?,
        majorName: String?,
        dailyStudyGoalMinutes: Int,
        weeklyStudyGoalMinutes: Int
    ) {
        guard let currentUserID else { return }

        if let profile {
            profile.educationLevel = educationLevel
            profile.gradeLevel = gradeLevel
            profile.highSchoolTrack = highSchoolTrack
            profile.institutionName = institutionName
            profile.institutionCountry = institutionCountry
            profile.majorName = majorName
            profile.dailyStudyGoalMinutes = dailyStudyGoalMinutes
            profile.weeklyStudyGoalMinutes = weeklyStudyGoalMinutes
            profile.onboardingCompleted = true
            profile.updatedAt = Date()
        } else {
            let newProfile = StudentProfile(
                ownerUserID: currentUserID,
                educationLevel: educationLevel,
                gradeLevel: gradeLevel,
                highSchoolTrack: highSchoolTrack,
                institutionName: institutionName,
                institutionCountry: institutionCountry,
                majorName: majorName,
                onboardingCompleted: true,
                dailyStudyGoalMinutes: dailyStudyGoalMinutes,
                weeklyStudyGoalMinutes: weeklyStudyGoalMinutes
            )
            context.insert(newProfile)
        }

        saveAndReload()
    }

    /// The `student_profiles.institution_country` CHECK constraint only accepts
    /// lowercase codes (`tr`, `kktc`) or NULL. Catalog data can arrive uppercased
    /// or as a full name, so normalize here — unknowns fall back to NULL so the
    /// upsert never fails on this constraint.
    static func normalizedCountry(_ raw: String?) -> String? {
        guard let c = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !c.isEmpty else { return nil }
        switch c {
        case "tr", "türkiye", "turkiye", "turkey":
            return "tr"
        case "kktc", "kuzey kıbrıs", "kuzey kibris", "kıbrıs", "kibris",
             "north cyprus", "northern cyprus", "trnc":
            return "kktc"
        default:
            return nil
        }
    }

    func completeOnboardingAndSync(
        educationLevel: String,
        gradeLevel: String,
        highSchoolTrack: String?,
        institutionName: String?,
        institutionCountry: String?,
        majorName: String?,
        dailyStudyGoalMinutes: Int,
        weeklyStudyGoalMinutes: Int,
        courseDrafts: [OnboardingCourseDraft]
    ) async throws {
        guard let currentUserID else {
            throw NSError(
                domain: "StudentStore",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Missing current user."]
            )
        }

        guard let userUUID = UUID(uuidString: currentUserID) else {
            throw NSError(
                domain: "StudentStore",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid current user id."]
            )
        }

        let normalizedCourses = courseDrafts
            .map {
                OnboardingCourseDraft(
                    code: $0.code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                    name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    isSuggested: $0.isSuggested
                )
            }
            .filter { !$0.name.isEmpty }

        isLoading = true
        defer { isLoading = false }

        // ── 1) LOCAL-FIRST ─────────────────────────────────────────────────
        // Onboarding'in tamamlanması YEREL bir kilometre taşıdır: profili +
        // dersleri önce cihaza yazarız. Bu her koşulda çalışır → kullanıcı
        // uygulamaya GİRER. (App Store 2.1a reddinin kök nedeni buydu: eski
        // sıralama remote-önceydi → tek bir geçici network/RLS hatası tüm
        // kurulumu throw edip kullanıcıyı çıkışsız onboarding'de kilitliyordu.)
        saveStudentProfile(
            educationLevel: educationLevel,
            gradeLevel: gradeLevel,
            highSchoolTrack: highSchoolTrack,
            institutionName: institutionName,
            institutionCountry: institutionCountry,
            majorName: majorName,
            dailyStudyGoalMinutes: dailyStudyGoalMinutes,
            weeklyStudyGoalMinutes: weeklyStudyGoalMinutes
        )

        clearLocalCoursesForCurrentUser()

        for draft in normalizedCourses {
            addCourse(
                name: draft.name,
                code: draft.code,
                sourceType: draft.isSuggested ? "catalog" : "manual",
                yearNumber: normalizedYearNumber(from: gradeLevel),
                termNumber: nil
            )
        }

        // ── 2) REMOTE: BEST-EFFORT ─────────────────────────────────────────
        // Supabase senkronu dener; başarısız olursa payload'u retry kuyruğuna
        // bırakır ve THROW ETMEZ — kurulum yerelde zaten tamamlandı. Kuyruk bir
        // sonraki `loadFromRemote()`'ta (uygulama açılışı/yenileme) otomatik
        // yeniden denenir.
        let profilePayload = StudentProfileUpsertPayload(
            user_id: userUUID,
            education_level: educationLevel,
            grade_level: gradeLevel,
            high_school_track: highSchoolTrack,
            institution_name: institutionName,
            institution_country: Self.normalizedCountry(institutionCountry),
            major_name: majorName,
            daily_study_goal_minutes: dailyStudyGoalMinutes,
            weekly_study_goal_minutes: weeklyStudyGoalMinutes,
            onboarding_completed: true
        )

        let coursePayloads = normalizedCourses.map { draft in
            StudentCourseInsertPayload(
                user_id: userUUID,
                course_code: draft.code,
                course_name: draft.name,
                institution_name: institutionName,
                major_name: majorName,
                grade_level: gradeLevel,
                year_number: normalizedYearNumber(from: gradeLevel),
                term_number: nil,
                source_type: draft.isSuggested ? "catalog" : "manual",
                is_archived: false
            )
        }

        // Payload'u kuyruğa al, sonra arkada senkronu TETİKLE. Onboarding'i
        // BLOKLAMAZ → kullanıcı ANINDA ilerler (yavaş internette bile beklemez).
        // Başarısızsa kuyrukta kalır; bir sonraki `loadFromRemote()` (açılış/
        // yenileme) telafi eder. Tüm push'lar tek yoldan (in-flight guard +
        // throttle) geçer → eşzamanlı yazım / aşırı deneme yok, çökme yok.
        savePendingOnboardingSync(
            PendingOnboardingSync(profile: profilePayload, courses: coursePayloads),
            userID: currentUserID
        )
        Task { [weak self] in
            await self?.retryPendingOnboardingSyncIfNeeded(force: true)
        }
    }

    /// Onboarding verisini Supabase'e yazar: profil upsert + dersleri sıfırla &
    /// yeniden ekle. Best-effort çağrılır; hata çağıran tarafta yakalanır.
    private func pushOnboardingToRemote(
        userUUID: UUID,
        profile: StudentProfileUpsertPayload,
        courses: [StudentCourseInsertPayload]
    ) async throws {
        try await SupabaseManager.shared.client
            .from("student_profiles")
            .upsert(profile, onConflict: "user_id")
            .execute()

        try await SupabaseManager.shared.client
            .from("student_courses")
            .delete()
            .eq("user_id", value: userUUID.uuidString)
            .execute()

        for payload in courses {
            try await SupabaseManager.shared.client
                .from("student_courses")
                .insert(payload)
                .execute()
        }
    }

    // MARK: - Deferred onboarding sync (offline / retry-later)

    private struct PendingOnboardingSync: Codable {
        let profile: StudentProfileUpsertPayload
        let courses: [StudentCourseInsertPayload]
    }

    private func pendingOnboardingSyncKey(_ userID: String) -> String {
        "pending_onboarding_sync_\(userID)"
    }

    private func savePendingOnboardingSync(_ sync: PendingOnboardingSync, userID: String) {
        guard let data = try? JSONEncoder().encode(sync) else { return }
        UserDefaults.standard.set(data, forKey: pendingOnboardingSyncKey(userID))
    }

    private func clearPendingOnboardingSync(userID: String) {
        UserDefaults.standard.removeObject(forKey: pendingOnboardingSyncKey(userID))
    }

    /// Eşzamanlı push'u engeller (in-flight guard) + oturum içinde 60 sn throttle
    /// → retry sunucuyu hammer'lamaz, kendini tetikleyip döngüye girmez.
    private var isOnboardingSyncInFlight = false
    private var lastOnboardingSyncAttempt: Date?

    /// Kuyruktaki onboarding senkronunu (offline/hata sonrası) yeniden dener.
    /// `loadFromRemote()` içinden çağrılır → açılış/yenilemede otomatik telafi;
    /// onboarding bittiğinde `force: true` ile anında bir kez denenir. Başarılıysa
    /// kuyruğu temizler, değilse sessizce bekletir. Delete-then-insert deseni →
    /// tekrar çalışsa bile idempotent (mükerrer ders oluşmaz). TÜM hatalar
    /// yutulur → ASLA çökmez, ASLA UI'ı bloklamaz.
    func retryPendingOnboardingSyncIfNeeded(force: Bool = false) async {
        guard !isOnboardingSyncInFlight else { return }
        if !force,
           let last = lastOnboardingSyncAttempt,
           Date().timeIntervalSince(last) < 60 { return }

        guard let currentUserID,
              let userUUID = UUID(uuidString: currentUserID),
              let data = UserDefaults.standard.data(forKey: pendingOnboardingSyncKey(currentUserID)),
              let pending = try? JSONDecoder().decode(PendingOnboardingSync.self, from: data)
        else { return }

        isOnboardingSyncInFlight = true
        lastOnboardingSyncAttempt = Date()
        defer { isOnboardingSyncInFlight = false }

        do {
            try await pushOnboardingToRemote(
                userUUID: userUUID,
                profile: pending.profile,
                courses: pending.courses
            )
            clearPendingOnboardingSync(userID: currentUserID)
            Log.debug("✅ onboarding sync completed")
        } catch {
            Log.debug("⚠️ onboarding sync failed; queued for later:", error)
        }
    }
    
    private struct StudentProfileUpsertPayload: Codable {
        let user_id: UUID
        let education_level: String
        let grade_level: String
        let high_school_track: String?
        let institution_name: String?
        let institution_country: String?
        let major_name: String?
        let daily_study_goal_minutes: Int
        let weekly_study_goal_minutes: Int
        let onboarding_completed: Bool
    }

    private struct StudentCourseInsertPayload: Codable {
        let user_id: UUID
        let course_code: String
        let course_name: String
        let institution_name: String?
        let major_name: String?
        let grade_level: String?
        let year_number: Int?
        let term_number: Int?
        let source_type: String
        let is_archived: Bool
    }

    func addCourse(
        name: String,
        code: String = "",
        colorHex: String = "#3B82F6",
        sourceType: String = "user_created",
        yearNumber: Int? = nil,
        termNumber: Int? = nil
    ) {
        guard let currentUserID else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else { return }

        let course = Course(
            ownerUserID: currentUserID,
            name: trimmedName,
            code: trimmedCode,
            colorHex: colorHex,
            sourceType: sourceType,
            yearNumber: yearNumber,
            termNumber: termNumber
        )

        context.insert(course)
        saveAndReload()
    }
    
    func addCourseAndSync(
        name: String,
        code: String = "",
        colorHex: String = "#3B82F6",
        sourceType: String = "manual",
        yearNumber: Int? = nil,
        termNumber: Int? = nil
    ) async {
        guard let currentUserID,
              let userUUID = UUID(uuidString: currentUserID)
        else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard !trimmedName.isEmpty else { return }

        let alreadyExists = courses.contains {
            $0.ownerUserID == currentUserID &&
            $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame &&
            $0.code.caseInsensitiveCompare(trimmedCode) == .orderedSame
        }

        guard !alreadyExists else { return }

        addCourse(
            name: trimmedName,
            code: trimmedCode,
            colorHex: colorHex,
            sourceType: sourceType,
            yearNumber: yearNumber,
            termNumber: termNumber
        )

        do {
            let payload = StudentCourseInsertPayload(
                user_id: userUUID,
                course_code: trimmedCode,
                course_name: trimmedName,
                institution_name: profile?.institutionName,
                major_name: profile?.majorName,
                grade_level: profile?.gradeLevel,
                year_number: yearNumber,
                term_number: termNumber,
                source_type: sourceType,
                is_archived: false
            )

            try await SupabaseManager.shared.client
                .from("student_courses")
                .insert(payload)
                .execute()

            reload()
        } catch {
            Log.debug("❌ addCourseAndSync error:", error)
        }
    }
    
    func deleteCourseAndSync(_ course: Course) async {
        guard let currentUserID,
              let userUUID = UUID(uuidString: currentUserID)
        else { return }

        let code = course.code
        let name = course.name

        deleteCourse(course)

        do {
            try await SupabaseManager.shared.client
                .from("student_courses")
                .delete()
                .eq("user_id", value: userUUID.uuidString)
                .eq("course_code", value: code)
                .eq("course_name", value: name)
                .execute()

            reload()
        } catch {
            Log.debug("❌ deleteCourseAndSync error:", error)
        }
    }

    func deleteCourse(_ course: Course) {
        guard course.ownerUserID == currentUserID else { return }
        context.delete(course)
        saveAndReload()
    }

    func clearForSignOut() {
        currentUserID = nil
        profile = nil
        courses = []
        didResolveRemoteProfile = false
    }

    /// Onboarding schedule → real weekly EventItems (one per parsed slot).
    /// Courses without a day/time are skipped; the Week tab adds them later.
    func createScheduleEvents(from parsedCourses: [ParsedCourse]) {
        guard let currentUserID else { return }

        let palette = ["#22D3EE", "#8B5CF6", "#F59E0B", "#34D399", "#F472B6", "#60A5FA", "#F97316"]
        var colorIndex = 0

        for course in parsedCourses where course.hasSchedule {
            let color = palette[colorIndex % palette.count]
            colorIndex += 1

            for slot in course.slots {
                let event = EventItem(
                    ownerUserID: currentUserID,
                    title: course.name,
                    weekday: min(max(slot.weekday, 0), 6),
                    startMinute: min(max(slot.startMinute, 0), 1439),
                    durationMinute: max(slot.durationMinute, 15),
                    scheduledDate: nil,
                    location: slot.room?.isEmpty == false ? slot.room : nil,
                    notes: nil,
                    colorHex: color
                )
                context.insert(event)
            }
        }

        do {
            try context.save()
        } catch {
            Log.debug("❌ createScheduleEvents save error:", error.localizedDescription)
        }
    }

    func forceRestoreCoursesFromOnboardingDrafts(_ drafts: [OnboardingCourseDraft]) {
        guard let currentUserID else {
            Log.debug("❌ forceRestoreCourses failed: currentUserID nil")
            return
        }

        let cleaned = drafts
            .map {
                OnboardingCourseDraft(
                    code: $0.code.trimmingCharacters(in: .whitespacesAndNewlines),
                    name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    isSuggested: $0.isSuggested
                )
            }
            .filter { !$0.name.isEmpty }

        guard !cleaned.isEmpty else { return }

        for draft in cleaned {
            let alreadyExists = courses.contains {
                $0.ownerUserID == currentUserID &&
                $0.name.caseInsensitiveCompare(draft.name) == .orderedSame &&
                $0.code.caseInsensitiveCompare(draft.code) == .orderedSame
            }

            if !alreadyExists {
                addCourse(
                    name: draft.name,
                    code: draft.code,
                    sourceType: draft.isSuggested ? "catalog" : "manual",
                    yearNumber: profile.map { normalizedYearNumberPublic(from: $0.gradeLevel) } ?? nil,
                    termNumber: nil
                )
            }
        }

        reload()
    }

    private func normalizedYearNumberPublic(from gradeLevel: String) -> Int? {
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

    // MARK: - Local Sync Helpers

    private func upsertLocalProfile(from row: StudentProfileRow) {
        let userID = row.user_id.uuidString

        let existing: StudentProfile?
        do {
            let descriptor = FetchDescriptor<StudentProfile>()
            let all = try context.fetch(descriptor)
            existing = all.first(where: { $0.ownerUserID == userID })
        } catch {
            Log.debug("❌ upsertLocalProfile fetch error:", error)
            return
        }

        if let existing {
            existing.educationLevel = row.education_level
            existing.gradeLevel = row.grade_level
            existing.highSchoolTrack = row.high_school_track
            existing.institutionName = row.institution_name
            existing.institutionCountry = row.institution_country
            existing.majorName = row.major_name
            existing.dailyStudyGoalMinutes = row.daily_study_goal_minutes
            existing.weeklyStudyGoalMinutes = row.weekly_study_goal_minutes
            existing.onboardingCompleted = row.onboarding_completed
            existing.updatedAt = Date()
        } else {
            let newProfile = StudentProfile(
                ownerUserID: userID,
                educationLevel: row.education_level,
                gradeLevel: row.grade_level,
                highSchoolTrack: row.high_school_track,
                institutionName: row.institution_name,
                institutionCountry: row.institution_country,
                majorName: row.major_name,
                onboardingCompleted: row.onboarding_completed,
                dailyStudyGoalMinutes: row.daily_study_goal_minutes,
                weeklyStudyGoalMinutes: row.weekly_study_goal_minutes
            )
            context.insert(newProfile)
        }

        saveContextOnly()
    }

    private func replaceLocalCourses(from rows: [StudentCourseRow]) {
        guard let currentUserID else { return }

        do {
            let descriptor = FetchDescriptor<Course>()
            let all = try context.fetch(descriptor)
            let mine = all.filter { $0.ownerUserID == currentUserID }
            for item in mine {
                context.delete(item)
            }

            for row in rows where row.user_id.uuidString == currentUserID {
                let course = Course(
                    ownerUserID: currentUserID,
                    name: row.course_name,
                    code: row.course_code,
                    colorHex: "#3B82F6",
                    sourceType: row.source_type,
                    yearNumber: row.year_number,
                    termNumber: row.term_number,
                    isArchived: row.is_archived
                )
                context.insert(course)
            }

            saveContextOnly()
        } catch {
            Log.debug("❌ replaceLocalCourses error:", error)
        }
    }

    private func clearLocalCoursesForCurrentUser() {
        guard let currentUserID else { return }

        do {
            let descriptor = FetchDescriptor<Course>()
            let all = try context.fetch(descriptor)
            let mine = all.filter { $0.ownerUserID == currentUserID }
            for item in mine {
                context.delete(item)
            }
            saveContextOnly()
            reload()
        } catch {
            Log.debug("❌ clearLocalCoursesForCurrentUser error:", error)
        }
    }

    private func normalizedYearNumber(from gradeLevel: String) -> Int? {
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

    private func saveAndReload() {
        saveContextOnly()
        reload()
        objectWillChange.send()
    }

    private func saveContextOnly() {
        do {
            try context.save()
        } catch {
            Log.debug("❌ StudentStore.save error:", error)
        }
    }
}
