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

    @State private var loading = false

    private var accent: Color {
        Color(arenaHex: AppArenaPalette.cyan)
    }

    private var secondaryAccent: Color {
        Color(arenaHex: AppArenaPalette.purple)
    }

    var body: some View {
        ZStack {
            ArenaBackground(
                primaryGlow: accent,
                secondaryGlow: secondaryAccent,
                warmGlow: Color(arenaHex: AppArenaPalette.gold),
                intensity: 0.94
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    profileSection
                    catalogSection
                    manualSection
                    currentCoursesSection

                    Spacer(minLength: 42)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .task {
            await loadCatalog()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(accent)
                        .frame(width: 20, height: 1)

                    Text("COURSE SETUP")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(2.3)
                        .foregroundStyle(accent)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("Derslerini")
                        .font(.system(size: 35, weight: .black))
                        .foregroundStyle(.white)

                    Text("seç")
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    accent,
                                    secondaryAccent
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .lineLimit(1)
                .minimumScaleFactor(0.72)

                Text("Katalogdan seç veya kendi dersini manuel ekle.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(2)
            }

            Spacer()

            Button {
                saveSelected()
                dismiss()
            } label: {
                Text("KAYDET")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 13)
                    .frame(height: 36)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accent,
                                        secondaryAccent
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
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
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Profil",
                eyebrow: "STUDENT PROFILE",
                icon: "person.crop.circle.fill",
                tint: accent
            )

            HStack(spacing: 10) {
                infoPill(
                    title: "Okul",
                    value: studentStore.profile?.institutionName ?? "-",
                    tint: accent
                )

                infoPill(
                    title: "Bölüm",
                    value: studentStore.profile?.majorName ?? "-",
                    tint: secondaryAccent
                )
            }
        }
        .padding(18)
        .background(cardBackground(tint: accent, radius: 28, strength: 0.62))
    }

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Önerilen Dersler",
                eyebrow: "CATALOG",
                icon: "books.vertical.fill",
                tint: Color(arenaHex: AppArenaPalette.gold)
            )

            if loading {
                loadingCard
            } else if catalogCourses.isEmpty {
                emptyCatalogCard
            } else {
                VStack(spacing: 10) {
                    ForEach(catalogCourses) { item in
                        catalogCourseRow(item)
                    }
                }
            }
        }
        .padding(18)
        .background(cardBackground(tint: Color(arenaHex: AppArenaPalette.gold), radius: 28, strength: 0.58))
    }

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Manuel Ekle",
                eyebrow: "CUSTOM COURSE",
                icon: "plus.circle.fill",
                tint: Color(arenaHex: AppArenaPalette.green)
            )

            arenaTextField("Kod", text: $manualCode, capitalization: .characters)
            arenaTextField("Ders Adı", text: $manualName)

            Button {
                addManualCourse()
            } label: {
                primaryActionButton(
                    title: "DERSİ EKLE",
                    icon: "plus.circle.fill",
                    tint: Color(arenaHex: AppArenaPalette.green)
                )
            }
            .buttonStyle(.plain)
            .disabled(manualName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(manualName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        }
        .padding(18)
        .background(cardBackground(tint: Color(arenaHex: AppArenaPalette.green), radius: 28, strength: 0.54))
    }

    private var currentCoursesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Mevcut Dersler",
                eyebrow: "ACTIVE",
                icon: "checkmark.seal.fill",
                tint: Color(arenaHex: AppArenaPalette.blue)
            )

            if studentStore.courses.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white.opacity(0.42))

                    Text("Henüz ders eklenmedi.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))

                    Spacer()
                }
                .padding(14)
                .background(rowBackground(tint: Color(arenaHex: AppArenaPalette.blue)))
            } else {
                VStack(spacing: 10) {
                    ForEach(studentStore.courses) { course in
                        currentCourseRow(course)
                    }
                }
            }
        }
        .padding(18)
        .background(cardBackground(tint: Color(arenaHex: AppArenaPalette.blue), radius: 28, strength: 0.50))
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Color(arenaHex: AppArenaPalette.gold))

            Text("Katalog yükleniyor...")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white.opacity(0.68))

            Spacer()
        }
        .padding(15)
        .background(rowBackground(tint: Color(arenaHex: AppArenaPalette.gold)))
    }

    private var emptyCatalogCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color(arenaHex: AppArenaPalette.gold))

            VStack(alignment: .leading, spacing: 3) {
                Text("Katalog dersi bulunamadı")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)

                Text("Dersi manuel ekleyebilirsin.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
            }

            Spacer()
        }
        .padding(15)
        .background(rowBackground(tint: Color(arenaHex: AppArenaPalette.gold)))
    }

    private func catalogCourseRow(_ item: CatalogCurriculumCourse) -> some View {
        let isSelected = selectedIDs.contains(item.id)
        let tint = isSelected ? Color(arenaHex: AppArenaPalette.green) : Color(arenaHex: AppArenaPalette.gold)

        return Button {
            toggle(item.id)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(tint)
                    .frame(width: 10, height: 10)
                    .shadow(color: tint.opacity(0.28), radius: 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.course_name)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if !item.course_code.isEmpty {
                            miniPill(item.course_code, tint: Color(arenaHex: AppArenaPalette.gold))
                        }

                        miniPill("Y\(item.year_number) T\(item.term_number)", tint: .white.opacity(0.44))
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(tint)
            }
            .padding(15)
            .background(rowBackground(tint: tint))
        }
        .buttonStyle(.plain)
    }

    private func currentCourseRow(_ course: Course) -> some View {
        let tint = colorFromHex(course.colorHex)

        return HStack(spacing: 12) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)
                .shadow(color: tint.opacity(0.28), radius: 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if !course.code.isEmpty {
                    Text(course.code.uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(.white.opacity(0.42))
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color(arenaHex: AppArenaPalette.green))
        }
        .padding(15)
        .background(rowBackground(tint: tint))
    }

    private func sectionHeader(
        title: String,
        eyebrow: String,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(tint)
                        .frame(width: 18, height: 1)

                    Text(eyebrow)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(tint)
                }

                Text(title)
                    .font(.system(size: 23, weight: .black))
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

    private func infoPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.40))

            Text(value)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .background(rowBackground(tint: tint))
    }

    private func arenaTextField(
        _ placeholder: String,
        text: Binding<String>,
        capitalization: TextInputAutocapitalization = .sentences
    ) -> some View {
        TextField(placeholder, text: text)
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled()
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .tint(accent)
            .padding(14)
            .background(inputBackground)
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.060))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
    }

    private func primaryActionButton(title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(title)
            Spacer()
            Image(systemName: "arrow.right")
        }
        .font(.system(size: 11, weight: .black, design: .monospaced))
        .tracking(0.8)
        .foregroundStyle(.black)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint)
                .shadow(color: tint.opacity(0.18), radius: 10, y: 5)
        )
    }

    private func miniPill(_ text: String, tint: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.16), lineWidth: 1)
                    )
            )
    }

    private func rowBackground(tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.075),
                        Color.white.opacity(0.035)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tint.opacity(0.12), lineWidth: 1)
            )
    }

    private func cardBackground(tint: Color, radius: CGFloat, strength: Double) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.070 + strength * 0.035),
                        Color(arenaHex: AppArenaPalette.purple).opacity(0.038),
                        Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
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
                                tint.opacity(0.10 + strength * 0.08),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 6,
                            endRadius: 180
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(tint.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 13, y: 7)
    }

    private func addManualCourse() {
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
        for item in catalogCourses where selectedIDs.contains(item.id) {
            studentStore.addCourse(
                name: item.course_name,
                code: item.course_code,
                sourceType: "catalog",
                yearNumber: item.year_number,
                termNumber: item.term_number
            )
        }
    }

    func loadCatalog() async {
        guard let major = studentStore.profile?.majorName else { return }
        _ = major

        loading = true
        defer { loading = false }

        guard let profile = studentStore.profile else { return }

        do {
            let universities = try await StudentCatalogService.fetchUniversities(
                countryCode: profile.institutionCountry ?? "CY"
            )

            guard let uni = universities.first(where: {
                $0.name == profile.institutionName
            }) else { return }

            let majors = try await StudentCatalogService.fetchMajors(
                universityID: uni.id
            )

            guard let major = majors.first(where: {
                $0.name == profile.majorName
            }) else { return }

            catalogCourses =
                try await StudentCatalogService.fetchCurriculumCourses(
                    majorID: major.id,
                    gradeLevel: profile.gradeLevel
                )

        } catch {
            print(error)
        }
    }

    private func colorFromHex(_ hex: String) -> Color {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        clean = clean.replacingOccurrences(of: "#", with: "")

        guard clean.count == 6 else {
            return accent
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
