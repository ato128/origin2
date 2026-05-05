//
//  ProfileHubView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 8.04.2026.
//

import SwiftUI

struct ProfileHubView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var studentStore: StudentStore

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    @AppStorage("smartEngineEnabled") private var smartEngineEnabled = true
    @AppStorage("showOnlyToday") private var showOnlyToday = false
    @AppStorage("didFinishOnboarding") private var didFinishOnboarding = true
    @AppStorage("didFinishPermissionOnboarding") private var didFinishPermissionOnboarding = true

    @State private var showEditProfile = false
    @State private var showAuthSheet = false
    @State private var showStudentAcademicSettings = false

    private var pageAccent: Color {
        Color(arenaHex: AppArenaPalette.cyan)
    }

    private var secondaryAccent: Color {
        Color(arenaHex: AppArenaPalette.purple)
    }

    private var warmAccent: Color {
        Color(arenaHex: AppArenaPalette.gold)
    }

    var body: some View {
        ZStack {
            ArenaBackground(
                primaryGlow: pageAccent,
                secondaryGlow: secondaryAccent,
                warmGlow: warmAccent,
                intensity: 0.94
            )

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    headerSection
                    accountSection
                    appearanceSection
                    productivitySection
                    languageSection
                    appSection
                    supportSection
                    logoutSection

                    Color.clear.frame(height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environmentObject(session)
        }
        .sheet(isPresented: $showAuthSheet) {
            AuthView()
                .environmentObject(session)
        }
        .sheet(isPresented: $showStudentAcademicSettings) {
            StudentAcademicSettingsView()
                .environmentObject(studentStore)
        }
    }
}

// MARK: - Main Sections

private extension ProfileHubView {

    var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(arenaCircleBackground(tint: .white.opacity(0.50)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(pageAccent)
                        .frame(width: 20, height: 1)

                    Text("PROFILE HUB")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(2.3)
                        .foregroundStyle(pageAccent)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("Profil")
                        .font(.system(size: 38, weight: .black))
                        .foregroundStyle(.white)

                    Text("merkezi")
                        .font(.system(size: 35, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    pageAccent,
                                    secondaryAccent
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .lineLimit(1)
                .minimumScaleFactor(0.70)

                Text("Hesap, öğrenci profili, görünüm ve uygulama ayarların.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if session.currentUser != nil {
                Button {
                    showEditProfile = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(pageAccent)
                                .shadow(color: pageAccent.opacity(0.22), radius: 12, y: 6)
                        )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    showAuthSheet = true
                } label: {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(pageAccent)
                                .shadow(color: pageAccent.opacity(0.22), radius: 12, y: 6)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: "ACCOUNT",
                title: "Hesap",
                italic: "profili",
                subtitle: "Kimlik, akademik bilgiler ve profil düzenlemeleri",
                icon: "person.crop.circle.fill",
                tint: pageAccent
            )

            VStack(alignment: .leading, spacing: 16) {
                if let user = session.currentUser {
                    accountIdentityCard(user: user)

                    if hasAcademicProfile {
                        HStack(spacing: 10) {
                            miniStatChip(
                                icon: "graduationcap.fill",
                                title: gradeChipText,
                                tint: pageAccent
                            )

                            if let institutionChipText {
                                miniStatChip(
                                    icon: "building.columns.fill",
                                    title: institutionChipText,
                                    tint: warmAccent
                                )
                            }
                        }
                    }

                    Divider()
                        .overlay(Color.white.opacity(0.075))

                    Button {
                        showEditProfile = true
                    } label: {
                        profileRow(
                            icon: "pencil",
                            iconColor: pageAccent,
                            title: "Profili Düzenle",
                            subtitle: "Adını ve kullanıcı adını güncelle"
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .overlay(Color.white.opacity(0.075))

                    Button {
                        showStudentAcademicSettings = true
                    } label: {
                        profileRow(
                            icon: "graduationcap.fill",
                            iconColor: warmAccent,
                            title: "Öğrenci Bilgileri",
                            subtitle: "Üniversite, bölüm, yıl ve derslerini düzenle"
                        )
                    }
                    .buttonStyle(.plain)

                } else {
                    Button {
                        showAuthSheet = true
                    } label: {
                        profileRow(
                            icon: "person.crop.circle.badge.plus",
                            iconColor: pageAccent,
                            title: "Giriş Yap",
                            subtitle: "Hesabına giriş yap veya yeni hesap oluştur"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .background(arenaCardBackground(tint: pageAccent, radius: 30, strength: 0.70))
        }
    }

    var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: "APPEARANCE",
                title: "Görünüm",
                italic: "ayarları",
                subtitle: "Tema ve günlük görünüm tercihlerinin merkezi",
                icon: "paintpalette.fill",
                tint: secondaryAccent
            )

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        iconBox(icon: "circle.lefthalf.filled", tint: secondaryAccent)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Tema")
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(.white)

                            Text("Uygulama görünüm stilini seç")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.48))
                        }

                        Spacer()

                        Picker("Tema", selection: $appTheme) {
                            ForEach(AppTheme.allCases) { theme in
                                Label(theme.title, systemImage: theme.icon)
                                    .tag(theme.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.white)
                    }
                }

                Divider()
                    .overlay(Color.white.opacity(0.075))

                toggleRow(
                    icon: "calendar",
                    iconColor: warmAccent,
                    title: "Sadece Bugünü Göster",
                    subtitle: "Bugünün görevlerine odaklan",
                    isOn: $showOnlyToday
                )
            }
            .padding(18)
            .background(arenaCardBackground(tint: secondaryAccent, radius: 30, strength: 0.58))
        }
    }

    var productivitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: "PRODUCTIVITY",
                title: "Üretkenlik",
                italic: "kontrolü",
                subtitle: "Akıllı motor, bildirim ve focus tercihleri",
                icon: "brain.head.profile",
                tint: Color(arenaHex: AppArenaPalette.green)
            )

            VStack(spacing: 16) {
                toggleRow(
                    icon: "brain.head.profile",
                    iconColor: Color(arenaHex: AppArenaPalette.green),
                    title: "Akıllı Görev Motoru",
                    subtitle: "YZ önerileri ve akıllı planlama",
                    isOn: $smartEngineEnabled
                )

                Divider()
                    .overlay(Color.white.opacity(0.075))

                profileRow(
                    icon: "bell.badge.fill",
                    iconColor: Color(arenaHex: AppArenaPalette.coral),
                    title: "Bildirimler",
                    subtitle: "Hatırlatıcı ve sistem tercihleri"
                )

                Divider()
                    .overlay(Color.white.opacity(0.075))

                profileRow(
                    icon: "timer",
                    iconColor: Color(arenaHex: AppArenaPalette.green),
                    title: "Focus Tercihleri",
                    subtitle: "Odak seans ayarlarını düzenle"
                )
            }
            .padding(18)
            .background(arenaCardBackground(tint: Color(arenaHex: AppArenaPalette.green), radius: 30, strength: 0.52))
        }
    }

    var languageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: "LANGUAGE",
                title: "Dil",
                italic: "seçimi",
                subtitle: "Uygulama dilini burada değiştirebilirsin",
                icon: "globe",
                tint: Color(arenaHex: AppArenaPalette.blue)
            )

            HStack(spacing: 12) {
                iconBox(icon: "character.bubble.fill", tint: Color(arenaHex: AppArenaPalette.blue))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Uygulama Dili")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)

                    Text("Arayüz dilini seç")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.48))
                }

                Spacer()

                Picker(
                    "Uygulama Dili",
                    selection: Binding(
                        get: { languageManager.selectedLanguage },
                        set: { languageManager.setLanguage($0) }
                    )
                ) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(LocalizedStringKey(language.titleKey))
                            .tag(language)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
            }
            .padding(18)
            .background(arenaCardBackground(tint: Color(arenaHex: AppArenaPalette.blue), radius: 30, strength: 0.50))
        }
    }

    var appSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: "APP FLOW",
                title: "Uygulama",
                italic: "akışı",
                subtitle: "Başlangıç ve izin ekranlarını yeniden yönet",
                icon: "sparkles",
                tint: warmAccent
            )

            VStack(spacing: 16) {
                Button {
                    didFinishOnboarding = false
                    dismiss()
                } label: {
                    profileRow(
                        icon: "sparkles",
                        iconColor: warmAccent,
                        title: "Onboarding’i Tekrar Göster",
                        subtitle: "Giriş ekranlarını yeniden başlat"
                    )
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Color.white.opacity(0.075))

                Button {
                    didFinishPermissionOnboarding = false
                    dismiss()
                } label: {
                    profileRow(
                        icon: "bell.fill",
                        iconColor: Color(arenaHex: AppArenaPalette.coral),
                        title: "İzin Ekranını Tekrar Göster",
                        subtitle: "Bildirim ve izin adımlarını yenile"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(arenaCardBackground(tint: warmAccent, radius: 30, strength: 0.56))
        }
    }

    var supportSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: "SUPPORT",
                title: "Destek",
                italic: "bilgileri",
                subtitle: "Uygulama hakkında kısa bilgiler",
                icon: "info.circle.fill",
                tint: .white.opacity(0.70)
            )

            VStack(spacing: 16) {
                profileRow(
                    icon: "info.circle.fill",
                    iconColor: .white.opacity(0.66),
                    title: "Hakkında",
                    subtitle: "Uygulama ve sürüm bilgileri"
                )

                Divider()
                    .overlay(Color.white.opacity(0.075))

                profileRow(
                    icon: "heart.fill",
                    iconColor: Color(arenaHex: AppArenaPalette.coral),
                    title: "Özenle yapıldı",
                    subtitle: "DailyTodo deneyimini geliştirmeye devam ediyoruz"
                )
            }
            .padding(18)
            .background(arenaCardBackground(tint: .white.opacity(0.45), radius: 30, strength: 0.34))
        }
    }

    var logoutSection: some View {
        Group {
            if session.currentUser != nil {
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader(
                        eyebrow: "ACCOUNT ACTIONS",
                        title: "Hesap",
                        italic: "işlemleri",
                        subtitle: "Oturum yönetimi ve güvenli çıkış",
                        icon: "rectangle.portrait.and.arrow.right",
                        tint: Color(arenaHex: AppArenaPalette.coral)
                    )

                    Button {
                        session.signOut()
                        studentStore.clearForSignOut()
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            iconBox(
                                icon: "rectangle.portrait.and.arrow.right",
                                tint: Color(arenaHex: AppArenaPalette.coral)
                            )

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Çıkış Yap")
                                    .font(.system(size: 17, weight: .black))
                                    .foregroundStyle(Color(arenaHex: AppArenaPalette.coral))

                                Text("Hesabından güvenli çıkış yap")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.48))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(.white.opacity(0.34))
                        }
                        .padding(18)
                        .background(arenaCardBackground(tint: Color(arenaHex: AppArenaPalette.coral), radius: 30, strength: 0.48))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Account

private extension ProfileHubView {

    func accountIdentityCard(user: AppUser) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                pageAccent.opacity(0.42),
                                secondaryAccent.opacity(0.32),
                                Color.white.opacity(0.060)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .stroke(pageAccent.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: pageAccent.opacity(0.18), radius: 12, y: 5)

                Image(systemName: "person.fill")
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(.white.opacity(0.96))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(user.fullName.isEmpty ? "Kullanıcı" : user.fullName)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let academicLine = academicPrimaryLine {
                    Text(academicLine)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(pageAccent)
                        .lineLimit(1)
                } else {
                    Text("@\(user.username)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }

                if let academicSecondaryLine {
                    Text(academicSecondaryLine)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.46))
                        .lineLimit(1)
                } else {
                    Text(user.email)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.38))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
    }

    var hasAcademicProfile: Bool {
        studentStore.profile != nil
    }

    var academicPrimaryLine: String? {
        guard let profile = studentStore.profile else { return nil }

        if profile.educationLevel == "university" {
            guard
                let institution = profile.institutionName,
                !institution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return "University • \(formattedGrade(profile.gradeLevel))"
            }

            return "\(formattedGrade(profile.gradeLevel)) • \(institution)"
        } else {
            let track = formattedTrack(profile.highSchoolTrack)
            return track.isEmpty
                ? "\(formattedGrade(profile.gradeLevel))"
                : "\(formattedGrade(profile.gradeLevel)) • \(track)"
        }
    }

    var academicSecondaryLine: String? {
        guard let profile = studentStore.profile else { return nil }

        if profile.educationLevel == "university" {
            let trimmedMajor = profile.majorName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmedMajor.isEmpty ? session.currentUser?.email : trimmedMajor
        } else {
            return session.currentUser?.email
        }
    }

    var gradeChipText: String {
        guard let profile = studentStore.profile else { return "No grade" }
        return formattedGrade(profile.gradeLevel)
    }

    var institutionChipText: String? {
        guard let profile = studentStore.profile else { return nil }

        let trimmed = profile.institutionName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Components

private extension ProfileHubView {

    func sectionHeader(
        eyebrow: String,
        title: String,
        italic: String,
        subtitle: String,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(tint)
                        .frame(width: 18, height: 1)

                    Text(eyebrow)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.7)
                        .foregroundStyle(tint)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(.white)

                    Text(italic)
                        .font(.system(size: 23, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(tint)
                }

                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: icon)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.13))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(tint.opacity(0.16), lineWidth: 1)
                        )
                )
        }
    }

    func profileRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 12) {
            iconBox(icon: icon, tint: iconColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white.opacity(0.34))
        }
    }

    func toggleRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            iconBox(icon: icon, tint: iconColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(iconColor)
        }
    }

    func miniStatChip(
        icon: String,
        title: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(tint)

            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.45)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.15), lineWidth: 1)
                )
        )
    }

    func iconBox(icon: String, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(tint.opacity(0.13))
            .frame(width: 46, height: 46)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(tint.opacity(0.15), lineWidth: 1)
            )
    }
}

// MARK: - Styles

private extension ProfileHubView {

    func arenaCircleBackground(tint: Color) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.100),
                        Color.black.opacity(0.26),
                        Color.white.opacity(0.050)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 14, y: 7)
    }

    func arenaCardBackground(tint: Color, radius: CGFloat, strength: Double) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.070 + strength * 0.035),
                        secondaryAccent.opacity(0.040),
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
                                tint.opacity(0.10 + strength * 0.075),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 8,
                            endRadius: 220
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(tint.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 13, y: 7)
    }
}

// MARK: - Academic Formatting

private extension ProfileHubView {

    func formattedGrade(_ value: String) -> String {
        switch value {
        case "prep":
            return "Hazırlık"
        case "1":
            return "1. Year"
        case "2":
            return "2. Year"
        case "3":
            return "3. Year"
        case "4":
            return "4. Year"
        case "5":
            return "5. Year"
        case "6":
            return "6. Year"
        case "9":
            return "9. Sınıf"
        case "10":
            return "10. Sınıf"
        case "11":
            return "11. Sınıf"
        case "12":
            return "12. Sınıf"
        default:
            return value
        }
    }

    func formattedTrack(_ value: String?) -> String {
        switch value {
        case "sayisal":
            return "Sayısal"
        case "sozel":
            return "Sözel"
        case "esit_agirlik":
            return "Eşit Ağırlık"
        case "dil":
            return "Dil"
        default:
            return ""
        }
    }
}
