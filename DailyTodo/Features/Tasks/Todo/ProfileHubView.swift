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

    private var palette: ThemePalette { ThemePalette() }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Color.clear.frame(height: 24)

                    headerSection
                    accountSection
                    appearanceSection
                    productivitySection
                    languageSection
                    appSection
                    supportSection
                    logoutSection

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
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
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(palette.cardFill)
                            .overlay(
                                Circle()
                                    .stroke(palette.cardStroke, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Profil")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Spacer()

            Circle()
                .fill(Color.clear)
                .frame(width: 40, height: 40)
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Hesap")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            VStack(alignment: .leading, spacing: 16) {
                if let user = session.currentUser {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.blue.opacity(0.42),
                                            Color.purple.opacity(0.28)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 58, height: 58)

                            Image(systemName: "person.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white.opacity(0.95))
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text(user.fullName.isEmpty ? "Kullanıcı" : user.fullName)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.primaryText)

                            if let academicLine = academicPrimaryLine {
                                Text(academicLine)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.blue)
                            } else {
                                Text("@\(user.username)")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(palette.secondaryText)
                            }

                            if let academicSecondaryLine {
                                Text(academicSecondaryLine)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(palette.secondaryText)
                            } else {
                                Text(user.email)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(palette.tertiaryText)
                            }
                        }

                        Spacer()
                    }

                    if hasAcademicProfile {
                        HStack(spacing: 10) {
                            miniStatChip(
                                icon: "graduationcap.fill",
                                title: gradeChipText
                            )

                            if let institutionChipText {
                                miniStatChip(
                                    icon: "building.columns.fill",
                                    title: institutionChipText
                                )
                            }
                        }
                    }

                    Button {
                        showEditProfile = true
                    } label: {
                        profileRow(
                            icon: "pencil",
                            iconColor: .blue,
                            title: "Profili Düzenle",
                            subtitle: "Adını ve kullanıcı adını güncelle"
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        showAuthSheet = true
                    } label: {
                        profileRow(
                            icon: "person.crop.circle.badge.plus",
                            iconColor: .blue,
                            title: "Giriş Yap",
                            subtitle: "Hesabına giriş yap veya yeni hesap oluştur"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .background(sectionCardBackground)
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Görünüm")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Tema")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.primaryText)

                        Spacer()
                    }

                    Picker("Tema", selection: $appTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Label(theme.title, systemImage: theme.icon)
                                .tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(palette.primaryText)
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))

                toggleRow(
                    icon: "calendar",
                    iconColor: .orange,
                    title: "Sadece Bugünü Göster",
                    subtitle: "Bugünün görevlerine odaklan",
                    isOn: $showOnlyToday
                )
            }
            .padding(18)
            .background(sectionCardBackground)
        }
    }

    private var productivitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Üretkenlik")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            VStack(spacing: 16) {
                toggleRow(
                    icon: "brain.head.profile",
                    iconColor: .purple,
                    title: "Akıllı Görev Motoru",
                    subtitle: "YZ önerileri ve akıllı planlama",
                    isOn: $smartEngineEnabled
                )

                Divider()
                    .overlay(Color.white.opacity(0.08))

                profileRow(
                    icon: "bell.badge.fill",
                    iconColor: .red,
                    title: "Bildirimler",
                    subtitle: "Hatırlatıcı ve sistem tercihleri"
                )

                Divider()
                    .overlay(Color.white.opacity(0.08))

                profileRow(
                    icon: "timer",
                    iconColor: .green,
                    title: "Focus Tercihleri",
                    subtitle: "Odak seans ayarlarını düzenle"
                )
            }
            .padding(18)
            .background(sectionCardBackground)
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Dil")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            VStack(alignment: .leading, spacing: 10) {
                Text("Uygulama Dili")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

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
                .tint(palette.primaryText)
            }
            .padding(18)
            .background(sectionCardBackground)
        }
    }

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Uygulama")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            VStack(spacing: 16) {
                Button {
                    didFinishOnboarding = false
                    dismiss()
                } label: {
                    profileRow(
                        icon: "sparkles",
                        iconColor: .blue,
                        title: "Onboarding’i Tekrar Göster",
                        subtitle: "Giriş ekranlarını yeniden başlat"
                    )
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Color.white.opacity(0.08))

                Button {
                    didFinishPermissionOnboarding = false
                    dismiss()
                } label: {
                    profileRow(
                        icon: "bell.fill",
                        iconColor: .orange,
                        title: "İzin Ekranını Tekrar Göster",
                        subtitle: "Bildirim ve izin adımlarını yenile"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(sectionCardBackground)
        }
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Destek")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            VStack(spacing: 16) {
                profileRow(
                    icon: "info.circle.fill",
                    iconColor: .secondary,
                    title: "Hakkında",
                    subtitle: "Uygulama ve sürüm bilgileri"
                )

                Divider()
                    .overlay(Color.white.opacity(0.08))

                profileRow(
                    icon: "heart.fill",
                    iconColor: .pink,
                    title: "Özenle yapıldı",
                    subtitle: "DailyTodo deneyimini geliştirmeye devam ediyoruz"
                )
            }
            .padding(18)
            .background(sectionCardBackground)
        }
    }

    private var logoutSection: some View {
        Group {
            if session.currentUser != nil {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Hesap İşlemleri")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Button {
                        session.signOut()
                        studentStore.clearForSignOut()
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.red.opacity(0.14))
                                    .frame(width: 44, height: 44)

                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.red)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Çıkış Yap")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(.red)

                                Text("Hesabından güvenli çıkış yap")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(palette.secondaryText)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(palette.tertiaryText)
                        }
                        .padding(18)
                        .background(sectionCardBackground)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var hasAcademicProfile: Bool {
        studentStore.profile != nil
    }

    private var academicPrimaryLine: String? {
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

    private var academicSecondaryLine: String? {
        guard let profile = studentStore.profile else { return nil }

        if profile.educationLevel == "university" {
            let trimmedMajor = profile.majorName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmedMajor.isEmpty ? session.currentUser?.email : trimmedMajor
        } else {
            return session.currentUser?.email
        }
    }

    private var gradeChipText: String {
        guard let profile = studentStore.profile else { return "No grade" }
        return formattedGrade(profile.gradeLevel)
    }

    private var institutionChipText: String? {
        guard let profile = studentStore.profile else { return nil }

        let trimmed = profile.institutionName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func formattedGrade(_ value: String) -> String {
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

    private func formattedTrack(_ value: String?) -> String {
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

    private func miniStatChip(
        icon: String,
        title: String
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.blue)

            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(palette.cardFill.opacity(0.9))
                .overlay(
                    Capsule()
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    private func profileRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(palette.tertiaryText)
        }
    }

    private func toggleRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
        }
    }

    private var sectionCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }
}
