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

    @State private var isLoading = false
    @State private var catalogError: String?

    @FocusState private var focusedField: Field?

    private enum Field {
        case code
        case name
    }

    private var accent: Color { Color(arenaHex: CourseSetupPalette.cyan) }
    private var secondaryAccent: Color { Color(arenaHex: CourseSetupPalette.purple) }
    private var gold: Color { Color(arenaHex: CourseSetupPalette.gold) }
    private var green: Color { Color(arenaHex: CourseSetupPalette.green) }
    private var coral: Color { Color(arenaHex: CourseSetupPalette.coral) }
    private var blue: Color { Color(arenaHex: CourseSetupPalette.blue) }

    private var canSaveCatalogSelection: Bool {
        !selectedIDs.isEmpty
    }

    private var canAddManualCourse: Bool {
        !manualName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            CourseSetupBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    profileSection
                    catalogSection
                    manualSection
                    currentCoursesSection

                    Color.clear.frame(height: 34)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
        .task {
            await loadCatalog()
        }
    }
}

// MARK: - Header

private extension CourseSetupSheet {
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

                        Text(tr("css_setup_caps"))
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(2.1)
                            .foregroundStyle(accent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("css_courses"))
                            .font(.system(size: 42, weight: .heavy))
                            .tracking(-1.0)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Text(tr("css_build_semester"))
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
                    Image(systemName: "xmark").accessibilityLabel(tr("event_close"))
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

            Text(tr("css_header_body"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.50))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }
}

// MARK: - Profile

private extension CourseSetupSheet {
    var profileSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: tr("css_student_profile_caps"),
                title: tr("css_setup_source"),
                icon: "graduationcap.fill",
                tint: accent
            )

            HStack(spacing: 10) {
                infoCard(
                    title: tr("sas_university"),
                    value: studentStore.profile?.institutionName ?? "Not selected",
                    icon: "building.columns.fill",
                    tint: accent
                )

                infoCard(
                    title: tr("css_major"),
                    value: studentStore.profile?.majorName ?? "Not selected",
                    icon: "book.closed.fill",
                    tint: secondaryAccent
                )
            }

            HStack(spacing: 10) {
                infoCard(
                    title: tr("css_year"),
                    value: formattedGradeLevel,
                    icon: "calendar",
                    tint: gold
                )

                infoCard(
                    title: tr("css_country"),
                    value: formattedCountry,
                    icon: "globe.europe.africa.fill",
                    tint: blue
                )
            }
        }
        .padding(16)
        .background(cardSurface(tint: accent, radius: 28))
    }

    private var formattedGradeLevel: String {
        guard let profile = studentStore.profile else { return "—" }

        if profile.gradeLevel == "prep" {
            return "Prep"
        }

        return "\(profile.gradeLevel). Year"
    }

    private var formattedCountry: String {
        let raw = studentStore.profile?.institutionCountry ?? ""
        let normalized = normalizedCountryCode(raw)

        switch normalized {
        case "tr":
            return tr("up_turkey")
        case "kktc":
            return "KKTC"
        default:
            return raw.isEmpty ? "—" : raw.uppercased()
        }
    }
}

// MARK: - Catalog

private extension CourseSetupSheet {
    var catalogSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: tr("sas_catalog_caps"),
                title: tr("css_recommended"),
                icon: "books.vertical.fill",
                tint: gold
            )

            if isLoading {
                loadingCatalogCard
            } else if let catalogError {
                catalogErrorCard(catalogError)
            } else if catalogCourses.isEmpty {
                emptyCatalogCard
            } else {
                VStack(spacing: 10) {
                    ForEach(catalogCourses) { item in
                        catalogCourseRow(item)
                    }
                }

                if canSaveCatalogSelection {
                    Button {
                        saveSelected()
                    } label: {
                        primaryActionButton(
                            title: tr("css_add_selected_caps"),
                            icon: "checkmark.circle.fill",
                            tint: green,
                            foreground: .black
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .background(cardSurface(tint: gold, radius: 28))
    }

    var loadingCatalogCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(gold)
                .scaleEffect(0.94)

            VStack(alignment: .leading, spacing: 3) {
                Text(tr("css_loading_catalog"))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)

                Text(tr("css_finding_courses"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))
            }

            Spacer()
        }
        .padding(14)
        .background(rowSurface(tint: gold))
    }

    var emptyCatalogCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(gold.opacity(0.12))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(gold)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("css_no_catalog_yet"))
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)

                    Text(tr("css_add_manual_for_now"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.48))
                }

                Spacer()
            }

            Button {
                Task {
                    await loadCatalog()
                }
            } label: {
                secondaryActionButton(
                    title: tr("css_retry_catalog_caps"),
                    icon: "arrow.clockwise",
                    tint: gold
                )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(rowSurface(tint: gold))
    }

    func catalogErrorCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(coral.opacity(0.13))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(coral)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("css_catalog_unavailable"))
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)

                    Text(text)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(3)
                }

                Spacer()
            }

            Button {
                Task {
                    await loadCatalog()
                }
            } label: {
                secondaryActionButton(
                    title: tr("css_try_again_caps"),
                    icon: "arrow.clockwise",
                    tint: coral
                )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(rowSurface(tint: coral))
    }

    func catalogCourseRow(_ item: CatalogCurriculumCourse) -> some View {
        let isSelected = selectedIDs.contains(item.id)
        let tint = isSelected ? green : gold

        return Button {
            toggle(item.id)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(isSelected ? 0.20 : 0.12))
                        .frame(width: 38, height: 38)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.course_name)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 7) {
                        if !item.course_code.isEmpty {
                            miniLabel(item.course_code, tint: gold)
                        }

                        miniLabel("Y\(item.year_number) T\(item.term_number ?? 0)", tint: .white.opacity(0.46))

                        if item.is_elective == true {
                            miniLabel(tr("sas_elective_caps"), tint: secondaryAccent)
                        }
                    }
                }

                Spacer(minLength: 8)
            }
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(isSelected ? 0.120 : 0.070),
                                Color.white.opacity(0.040),
                                Color.black.opacity(0.025)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(tint.opacity(isSelected ? 0.24 : 0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Manual

private extension CourseSetupSheet {
    var manualSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: tr("sas_custom_course_caps"),
                title: tr("sas_add_manually"),
                icon: "plus.circle.fill",
                tint: green
            )

            HStack(spacing: 10) {
                courseTextField(
                    placeholder: tr("sas_code"),
                    text: $manualCode,
                    icon: "number",
                    tint: green,
                    capitalization: .characters
                )
                .frame(width: 112)
                .focused($focusedField, equals: .code)

                courseTextField(
                    placeholder: tr("ae_class_name"),
                    text: $manualName,
                    icon: "pencil",
                    tint: green,
                    capitalization: .words
                )
                .focused($focusedField, equals: .name)
            }

            Button {
                addManualCourse()
            } label: {
                primaryActionButton(
                    title: tr("css_add_course_caps"),
                    icon: "plus.circle.fill",
                    tint: green,
                    foreground: .black
                )
            }
            .buttonStyle(.plain)
            .disabled(!canAddManualCourse)
            .opacity(canAddManualCourse ? 1 : 0.44)
        }
        .padding(16)
        .background(cardSurface(tint: green, radius: 28))
    }
}

// MARK: - Current Courses

private extension CourseSetupSheet {
    var currentCoursesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: tr("sas_active_caps"),
                title: tr("css_current_courses"),
                icon: "checkmark.seal.fill",
                tint: blue
            )

            if studentStore.courses.isEmpty {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(blue.opacity(0.12))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "tray")
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(blue)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("sas_no_active_courses"))
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(.white)

                        Text(tr("sas_add_catalog_or_manual"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.48))
                    }

                    Spacer()
                }
                .padding(14)
                .background(rowSurface(tint: blue))
            } else {
                VStack(spacing: 10) {
                    ForEach(studentStore.courses) { course in
                        currentCourseRow(course)
                    }
                }
            }
        }
        .padding(16)
        .background(cardSurface(tint: blue, radius: 28))
    }

    func currentCourseRow(_ course: Course) -> some View {
        let tint = colorFromHex(course.colorHex, fallback: blue)

        return HStack(spacing: 12) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)
                .shadow(color: tint.opacity(0.24), radius: 6)

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

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(green)
        }
        .padding(13)
        .background(rowSurface(tint: tint))
    }
}

// MARK: - Reusable UI

private extension CourseSetupSheet {
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

    func infoCard(
        title: String,
        value: String,
        icon: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(tint)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.36))

                Text(value)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.70)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
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
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.060))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.13), lineWidth: 1)
                )
        )
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

    func secondaryActionButton(
        title: String,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .black))

            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(0.7)

            Spacer()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.100))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
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

// MARK: - Logic

private extension CourseSetupSheet {
    func addManualCourse() {
        let name = manualName.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = manualCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard !name.isEmpty else { return }

        studentStore.addCourse(
            name: name,
            code: code,
            sourceType: "manual"
        )

        manualCode = ""
        manualName = ""
        focusedField = nil

        studentStore.reload()
        Haptics.notify(.success)
    }

    func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func saveSelected() {
        let selectedCourses = catalogCourses.filter { selectedIDs.contains($0.id) }

        guard !selectedCourses.isEmpty else { return }

        for item in selectedCourses {
            studentStore.addCourse(
                name: item.course_name,
                code: item.course_code,
                sourceType: "catalog",
                yearNumber: item.year_number,
                termNumber: item.term_number
            )
        }

        selectedIDs.removeAll()
        studentStore.reload()
        Haptics.notify(.success)
    }

    @MainActor
    func loadCatalog() async {
        guard let profile = studentStore.profile else {
            catalogCourses = []
            catalogError = "Student profile is missing."
            return
        }

        let institutionName = (profile.institutionName ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let majorName = (profile.majorName ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !institutionName.isEmpty, !majorName.isEmpty else {
            catalogCourses = []
            catalogError = "University or major is missing."
            return
        }

        isLoading = true
        catalogError = nil
        selectedIDs.removeAll()

        defer {
            isLoading = false
        }

        do {
            let country = normalizedCountryCode(profile.institutionCountry)

            Log.debug("📚 CourseSetup loadCatalog country:", country)
            Log.debug("📚 CourseSetup institution:", institutionName)
            Log.debug("📚 CourseSetup major:", majorName)

            let universities = try await StudentCatalogService.fetchUniversities(
                countryCode: country
            )

            guard let university = bestUniversityMatch(
                universities: universities,
                profileInstitutionName: institutionName
            ) else {
                catalogCourses = []
                catalogError = "University catalog match not found."
                Log.debug("❌ CourseSetup university match not found:", institutionName)
                Log.debug("❌ Available universities:", universities.map(\.name).joined(separator: ", "))
                return
            }

            let majors = try await StudentCatalogService.fetchMajors(
                universityID: university.id
            )

            guard let major = bestMajorMatch(
                majors: majors,
                profileMajorName: majorName
            ) else {
                catalogCourses = []
                catalogError = "Major catalog match not found."
                Log.debug("❌ CourseSetup major match not found:", majorName)
                Log.debug("❌ Available majors:", majors.map(\.name).joined(separator: ", "))
                return
            }

            let courses = try await StudentCatalogService.fetchCurriculumCourses(
                majorID: major.id,
                gradeLevel: profile.gradeLevel
            )

            catalogCourses = courses
            catalogError = nil

            Log.debug("✅ CourseSetup catalog courses:", courses.count)
        } catch {
            catalogCourses = []
            catalogError = error.localizedDescription
            Log.debug("❌ CourseSetup loadCatalog error:", error.localizedDescription)
        }
    }

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
            if value.isEmpty {
                return "kktc"
            }

            return value
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

// MARK: - Palette

private enum CourseSetupPalette {
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

// MARK: - Background

private struct CourseSetupBackground: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(arenaHex: CourseSetupPalette.backgroundTop),
                    Color(arenaHex: CourseSetupPalette.backgroundMid),
                    Color(arenaHex: CourseSetupPalette.backgroundBottom)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(arenaHex: CourseSetupPalette.blue).opacity(0.11))
                .frame(width: 270, height: 270)
                .blur(radius: 100)
                .offset(x: 170, y: -220)

            Circle()
                .fill(Color(arenaHex: CourseSetupPalette.purple).opacity(0.14))
                .frame(width: 330, height: 330)
                .blur(radius: 118)
                .offset(x: -190, y: 500)

            Circle()
                .fill(Color(arenaHex: CourseSetupPalette.coral).opacity(0.060))
                .frame(width: 280, height: 280)
                .blur(radius: 110)
                .offset(x: 165, y: 285)

            Circle()
                .fill(Color(arenaHex: CourseSetupPalette.gold).opacity(0.045))
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

// MARK: - Color Hex
