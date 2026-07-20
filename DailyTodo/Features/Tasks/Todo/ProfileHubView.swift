//
//  ProfileHubView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 8.04.2026.
//

import SwiftUI
import SwiftData

struct ProfileHubView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var studentStore: StudentStore
    @ObservedObject private var subscription = SubscriptionManager.shared

    @AppStorage("smartEngineEnabled") private var smartEngineEnabled = true
    @AppStorage("showOnlyToday") private var showOnlyToday = false

    // Updo AI challenge streak (written from Home when a challenge is accepted).
    @AppStorage("challengeStreakCountV1") private var challengeStreakCount = 0
    @AppStorage("challengeAcceptedTotalV1") private var challengeAcceptedTotal = 0

    @State private var showAuthSheet = false
    @State private var showNotificationSettings = false
    @State private var showAboutApp = false
    @State private var showMadeWithCare = false
    @State private var showAppIconPicker = false
    @State private var showLiveStylePicker = false
    @State private var showWidgetStylePicker = false

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
                    if challengeAcceptedTotal > 0 {
                        challengeStreakBadge
                    }
                    // Account/profile editing lives on the Profile tab now —
                    // settings only offers sign-in when logged out.
                    if session.currentUser == nil {
                        accountSection
                    }
                    #if DEBUG
                    proTestSection
                    #endif
                    productivitySection
                    appearanceSection
                    languageSection
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
        .sheet(isPresented: $showAuthSheet) {
            AuthView()
                .environmentObject(session)
        }
        .sheet(isPresented: $showNotificationSettings) {
            SmartNotificationSettingsView()
        }
        .sheet(isPresented: $showAboutApp) {
            AboutUpdoView()
        }
        .sheet(isPresented: $showMadeWithCare) {
            MadeWithCareView()
        }
        .sheet(isPresented: $showAppIconPicker) {
            AppIconPickerView()
        }
        .sheet(isPresented: $showLiveStylePicker) {
            LiveActivityStylePickerView()
        }
        .sheet(isPresented: $showWidgetStylePicker) {
            WidgetStylePickerView()
        }
    }

    #if DEBUG
    // Debug-only toggle to preview Pro features without a purchase.
    // Compiled out of Release/App Store builds.
    var proTestSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: "TEST · GEÇİCİ",
                title: "Updo",
                italic: "Pro",
                subtitle: "Pro özelliklerini denemek için aç/kapat (yayın öncesi kaldırılacak).",
                icon: "crown.fill",
                tint: Color(arenaHex: AppArenaPalette.gold)
            )

            VStack(spacing: 16) {
                toggleRow(
                    icon: "crown.fill",
                    iconColor: Color(arenaHex: AppArenaPalette.gold),
                    title: "Pro (Test)",
                    subtitle: subscription.isPro ? "Pro aktif — tüm özellikler açık" : "Pro kapalı",
                    isOn: Binding(
                        get: { subscription.isPro },
                        set: { subscription.setDebugPro($0) }
                    )
                )
            }
            .padding(18)
            .background(
                arenaCardBackground(
                    tint: Color(arenaHex: AppArenaPalette.gold),
                    radius: 30,
                    strength: 0.52
                )
            )
        }
    }
    #endif

    var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: tr("ph_appearance_caps"),
                title: tr("ph_w_appearance_app"),
                italic: tr("ph_w_appearance_icon"),
                subtitle: tr("ph_appearance_sub"),
                icon: "app.badge.fill",
                tint: Color(arenaHex: AppArenaPalette.gold)
            )

            VStack(spacing: 16) {
                Button {
                    showAppIconPicker = true
                } label: {
                    profileRow(
                        icon: "app.dashed",
                        iconColor: Color(arenaHex: AppArenaPalette.gold),
                        title: tr("ph_app_icon_title"),
                        subtitle: tr("ph_app_icon_variants")
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showLiveStylePicker = true
                } label: {
                    profileRow(
                        icon: "timer.circle.fill",
                        iconColor: Color(arenaHex: AppArenaPalette.cyan),
                        title: tr("ph_live_style_title"),
                        subtitle: tr("ph_live_style_sub")
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showWidgetStylePicker = true
                } label: {
                    profileRow(
                        icon: "square.grid.2x2.fill",
                        iconColor: Color(arenaHex: AppArenaPalette.purple),
                        title: tr("ph_widget_style_title"),
                        subtitle: tr("ph_widget_style_sub")
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(
                arenaCardBackground(
                    tint: Color(arenaHex: AppArenaPalette.gold),
                    radius: 30,
                    strength: 0.52
                )
            )
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
                Image(systemName: "xmark").accessibilityLabel(tr("event_close"))
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(arenaCircleBackground(tint: .white.opacity(0.50)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 7) {
                Text(tr("ph_header_title"))
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }

            Spacer(minLength: 8)

            if session.currentUser == nil {
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

    var challengeStreakBadge: some View {
        let fire = Color(arenaHex: "#F97316")

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [fire, Color(arenaHex: "#EF4444")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 50, height: 50)
                    .shadow(color: fire.opacity(0.4), radius: 10, y: 4)

                Image(systemName: "flame.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(tr("ph_ch_streak_caps"))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Color(arenaHex: AppArenaPalette.gold))

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(challengeStreakCount)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    Text(tr("ph_ch_streak_title"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.78))
                }

                Text(tr("ph_ch_streak_total", challengeAcceptedTotal))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(arenaCardBackground(tint: fire, radius: 30, strength: 0.5))
    }

    var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: tr("ph_account_caps"),
                title: tr("ph_w_account"),
                italic: tr("ph_w_account_italic"),
                subtitle: tr("ph_account_sub"),
                icon: "person.crop.circle.fill",
                tint: pageAccent
            )

            VStack(alignment: .leading, spacing: 16) {
                Button {
                    showAuthSheet = true
                } label: {
                    profileRow(
                        icon: "person.crop.circle.badge.plus",
                        iconColor: pageAccent,
                        title: tr("ph_sign_in"),
                        subtitle: tr("ph_sign_in_sub")
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(arenaCardBackground(tint: pageAccent, radius: 30, strength: 0.70))
        }
    }

    

    var productivitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: tr("ph_smart_system_caps"),
                title: tr("ph_w_smart"),
                italic: tr("ph_w_flow"),
                subtitle: tr("ph_smart_sub"),
                icon: "sparkles",
                tint: Color(arenaHex: AppArenaPalette.green)
            )

            VStack(spacing: 16) {
                toggleRow(
                    icon: "brain.head.profile",
                    iconColor: Color(arenaHex: AppArenaPalette.green),
                    title: tr("ph_engine"),
                    subtitle: tr("ph_engine_sub"),
                    isOn: $smartEngineEnabled
                )

                Divider()
                    .overlay(Color.white.opacity(0.075))

                toggleRow(
                    icon: "calendar",
                    iconColor: warmAccent,
                    title: tr("ph_today_only"),
                    subtitle: tr("ph_today_only_sub"),
                    isOn: $showOnlyToday
                )

                Divider()
                    .overlay(Color.white.opacity(0.075))

                Button {
                    showNotificationSettings = true
                } label: {
                    profileRow(
                        icon: "bell.badge.fill",
                        iconColor: Color(arenaHex: AppArenaPalette.coral),
                        title: tr("ph_smart_notifs"),
                        subtitle: tr("ph_smart_notifs_sub")
                    )
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Color.white.opacity(0.075))

                profileRow(
                    icon: "timer",
                    iconColor: Color(arenaHex: AppArenaPalette.green),
                    title: tr("ph_focus_prefs"),
                    subtitle: tr("ph_focus_soon")
                )
                .opacity(0.72)
            }
            .padding(18)
            .background(
                arenaCardBackground(
                    tint: Color(arenaHex: AppArenaPalette.green),
                    radius: 30,
                    strength: 0.52
                )
            )
        }
    }

    var languageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: tr("ph_language_caps"),
                title: tr("ph_w_language"),
                italic: tr("ph_w_selection"),
                subtitle: tr("ph_lang_sub"),
                icon: "globe",
                tint: Color(arenaHex: AppArenaPalette.blue)
            )

            HStack(spacing: 12) {
                iconBox(icon: "character.bubble.fill", tint: Color(arenaHex: AppArenaPalette.blue))

                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("settings_app_language_title"))
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)

                    Text(tr("ph_lang_picker"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.48))
                }

                Spacer()

                Picker(
                    tr("settings_app_language_title"),
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

    

    var supportSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: tr("ph_updo_caps"),
                title: tr("ph_w_app"),
                italic: tr("ph_w_about_updo"),
                subtitle: tr("ph_about_sub"),
                icon: "info.circle.fill",
                tint: .white.opacity(0.72)
            )

            VStack(spacing: 16) {
                Button {
                    showAboutApp = true
                } label: {
                    profileRow(
                        icon: "info.circle.fill",
                        iconColor: pageAccent,
                        title: tr("ph_about"),
                        subtitle: tr("ph_about_row_sub")
                    )
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(Color.white.opacity(0.075))

                Button {
                    showMadeWithCare = true
                } label: {
                    profileRow(
                        icon: "heart.fill",
                        iconColor: Color(arenaHex: AppArenaPalette.coral),
                        title: tr("ph_made_care"),
                        subtitle: tr("ph_made_care_sub")
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(
                arenaCardBackground(
                    tint: .white.opacity(0.45),
                    radius: 30,
                    strength: 0.34
                )
            )
        }
    }
    
    var logoutSection: some View {
        Group {
            if session.currentUser != nil {
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader(
                        eyebrow: tr("ph_account_actions_caps"),
                        title: tr("ph_w_account"),
                        italic: tr("ph_w_actions"),
                        subtitle: tr("ph_actions_sub"),
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
                                Text(tr("ph_sign_out"))
                                    .font(.system(size: 17, weight: .black))
                                    .foregroundStyle(Color(arenaHex: AppArenaPalette.coral))

                                Text(tr("ph_sign_out_sub"))
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
                Text(user.fullName.isEmpty ? tr("ph_user") : user.fullName)
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
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(.white)

                    Text(italic)
                        .font(.system(size: 23, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(tint)
                }
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
            return tr("grade_prep")
        case "1":
            return tr("grade_uni_1")
        case "2":
            return tr("grade_uni_2")
        case "3":
            return tr("grade_uni_3")
        case "4":
            return tr("grade_uni_4")
        case "5":
            return tr("grade_uni_5")
        case "6":
            return tr("grade_uni_6")
        case "9":
            return tr("grade_hs_9")
        case "10":
            return tr("grade_hs_10")
        case "11":
            return tr("grade_hs_11")
        case "12":
            return tr("grade_hs_12")
        default:
            return value
        }
    }

    func formattedTrack(_ value: String?) -> String {
        switch value {
        case "sayisal":
            return tr("track_sayisal")
        case "sozel":
            return tr("track_sozel")
        case "esit_agirlik":
            return tr("track_esit_agirlik")
        case "dil":
            return tr("track_dil")
        default:
            return ""
        }
    }
}
// MARK: - Smart Notification Settings

private struct SmartNotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @Query private var allFocusRecords: [FocusSessionRecord]

    @AppStorage("smartNotificationsEnabled") private var smartNotificationsEnabled = true
    @AppStorage("smartExamNotificationsEnabled") private var smartExamNotificationsEnabled = true
    @AppStorage("smartStreakNotificationsEnabled") private var smartStreakNotificationsEnabled = true
    @AppStorage("smartDailyFocusNotificationsEnabled") private var smartDailyFocusNotificationsEnabled = true
    @AppStorage("smartTaskNotificationsEnabled") private var smartTaskNotificationsEnabled = true
    @AppStorage("smartAiSuggestionNotificationsEnabled") private var smartAiSuggestionNotificationsEnabled = true

    private var cyan: Color { Color(arenaHex: AppArenaPalette.cyan) }
    private var gold: Color { Color(arenaHex: AppArenaPalette.gold) }
    private var coral: Color { Color(arenaHex: AppArenaPalette.coral) }
    private var green: Color { Color(arenaHex: AppArenaPalette.green) }
    private var purple: Color { Color(arenaHex: AppArenaPalette.purple) }

    var body: some View {
        NavigationStack {
            ZStack {
                ArenaBackground(
                    primaryGlow: cyan,
                    secondaryGlow: purple,
                    warmGlow: gold,
                    intensity: 0.92
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        heroCard

                        settingsCard

                        if let rhythm = personalRhythmText {
                            rhythmCard(rhythm)
                        }

                        quietCard

                        philosophyCard

                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onChange(of: smartNotificationsEnabled) { _, newValue in
            guard newValue == false else { return }

            Task {
                await SmartNotificationScheduler.shared.cancelAllSmartNotifications()
                SmartNotificationHistory.shared.reset()
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark").accessibilityLabel(tr("event_close"))
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(circleBackground)
                }
                .buttonStyle(.plain)

                Spacer()

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(coral)
                    .frame(width: 44, height: 44)
                    .background(iconBackground(coral))
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(tr("ph_smart_notifs_caps"))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(coral)

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(tr("ph_w_smart"))
                        .font(.system(size: 38, weight: .black))
                        .foregroundStyle(.white)

                    Text(tr("ph_w_notifications_lc"))
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(coral)
                }
            }
        }
        .padding(18)
        .background(cardBackground(coral, strength: 0.60))
    }

    private var settingsCard: some View {
        VStack(spacing: 16) {
            toggleRow(
                icon: "sparkles",
                tint: cyan,
                title: tr("ph_smart_notifs"),
                subtitle: tr("ph_notif_master_sub"),
                isOn: $smartNotificationsEnabled
            )

            Divider().overlay(Color.white.opacity(0.075))

            toggleRow(
                icon: "graduationcap.fill",
                tint: gold,
                title: tr("ph_exam_reminders"),
                subtitle: tr("ph_exam_reminders_sub"),
                isOn: $smartExamNotificationsEnabled
            )
            .disabled(!smartNotificationsEnabled)
            .opacity(smartNotificationsEnabled ? 1 : 0.45)

            Divider().overlay(Color.white.opacity(0.075))

            toggleRow(
                icon: "flame.fill",
                tint: coral,
                title: tr("ph_streak_protect_title"),
                subtitle: tr("ph_focus_sug_hint"),
                isOn: $smartStreakNotificationsEnabled
            )
            .disabled(!smartNotificationsEnabled)
            .opacity(smartNotificationsEnabled ? 1 : 0.45)

            Divider().overlay(Color.white.opacity(0.075))

            toggleRow(
                icon: "timer",
                tint: green,
                title: tr("ph_focus_suggestions"),
                subtitle: tr("ph_focus_suggestions_sub"),
                isOn: $smartDailyFocusNotificationsEnabled
            )
            .disabled(!smartNotificationsEnabled)
            .opacity(smartNotificationsEnabled ? 1 : 0.45)

            Divider().overlay(Color.white.opacity(0.075))

            toggleRow(
                icon: "checklist",
                tint: purple,
                title: tr("ph_task_reminders"),
                subtitle: tr("ph_task_reminders_sub"),
                isOn: $smartTaskNotificationsEnabled
            )
            .disabled(!smartNotificationsEnabled)
            .opacity(smartNotificationsEnabled ? 1 : 0.45)

            Divider().overlay(Color.white.opacity(0.075))

            toggleRow(
                icon: "sparkles",
                tint: cyan,
                title: tr("ph_ai_suggestions"),
                subtitle: tr("ph_ai_suggestions_sub"),
                isOn: $smartAiSuggestionNotificationsEnabled
            )
            .disabled(!smartNotificationsEnabled)
            .opacity(smartNotificationsEnabled ? 1 : 0.45)
        }
        .padding(18)
        .background(cardBackground(cyan, strength: 0.46))
    }

    /// "Hatırlatmalar ritmine göre ~21:00'e ayarlı" — makes the adaptive
    /// timing visible so it feels intentional, not random. Hidden until there
    /// is enough real session data to personalize.
    private var personalRhythmText: String? {
        guard smartNotificationsEnabled else { return nil }
        guard let typical = SmartNotificationBrain.typicalFocusMinute(records: allFocusRecords) else {
            return nil
        }
        return tr("ph_rhythm_line", String(format: "%02d:%02d", typical / 60, typical % 60))
    }

    private func rhythmCard(_ text: String) -> some View {
        HStack(spacing: 13) {
            iconBox("waveform.path.ecg", tint: green)

            VStack(alignment: .leading, spacing: 4) {
                Text(tr("ph_rhythm_title"))
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)

                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(18)
        .background(cardBackground(green, strength: 0.32))
    }

    private var quietCard: some View {
        HStack(spacing: 13) {
            iconBox("moon.zzz.fill", tint: .white.opacity(0.70))

            VStack(alignment: .leading, spacing: 4) {
                Text(tr("ph_quiet_hours_title"))
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)

                Text(tr("ph_quiet_hours"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(18)
        .background(cardBackground(.white.opacity(0.46), strength: 0.28))
    }

    private var philosophyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                iconBox("hand.raised.fill", tint: gold)

                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("ph_not_spam"))
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)

                    Text(tr("ph_not_spam_sub"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                }
            }

            Text(tr("ph_not_spam_body"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.48))
                .lineSpacing(3)
        }
        .padding(18)
        .background(cardBackground(gold, strength: 0.38))
    }

    private func toggleRow(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            iconBox(icon, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(tint)
        }
    }

    private func iconBox(_ icon: String, tint: Color) -> some View {
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

    private var circleBackground: some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private func iconBackground(_ tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(tint.opacity(0.13))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tint.opacity(0.16), lineWidth: 1)
            )
    }

    private func cardBackground(_ tint: Color, strength: Double) -> some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.070 + strength * 0.035),
                        Color(arenaHex: AppArenaPalette.purple).opacity(0.035),
                        Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(tint.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 13, y: 7)
    }
}
// MARK: - About Updo

private struct AboutUpdoView: View {
    @Environment(\.dismiss) private var dismiss

    private var cyan: Color { Color(arenaHex: AppArenaPalette.cyan) }
    private var blue: Color { Color(arenaHex: AppArenaPalette.blue) }
    private var purple: Color { Color(arenaHex: AppArenaPalette.purple) }
    private var gold: Color { Color(arenaHex: AppArenaPalette.gold) }

    var body: some View {
        NavigationStack {
            ZStack {
                ArenaBackground(
                    primaryGlow: cyan,
                    secondaryGlow: purple,
                    warmGlow: gold,
                    intensity: 0.94
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header

                        missionCard

                        featureGrid

                        versionCard

                        Color.clear.frame(height: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark").accessibilityLabel(tr("event_close"))
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)

                Spacer()

                appLogo
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(tr("ph_about_updo_caps"))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(cyan)

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(tr("ph_about_title"))
                        .font(.system(size: 38, weight: .black))
                        .foregroundStyle(.white)

                    Text(tr("ph_about_title_italic"))
                        .font(.system(size: 31, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(cyan)
                }
                .lineLimit(2)

                Text(tr("ph_about_body1"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineSpacing(3)
            }
        }
        .padding(18)
        .background(cardBackground(cyan, strength: 0.56))
    }

    private var appLogo: some View {
        ZStack {
            Image(systemName: "scope")
                .font(.system(size: 42, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, cyan, blue, purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "location.north.fill")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(.white)
        }
        .frame(width: 54, height: 54)
        .background(
            Circle()
                .fill(Color.white.opacity(0.07))
                .overlay(Circle().stroke(cyan.opacity(0.20), lineWidth: 1))
        )
    }

    private var missionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("ph_about_why"))
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)

            Text(tr("ph_about_body2"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.52))
                .lineSpacing(4)
        }
        .padding(18)
        .background(cardBackground(blue, strength: 0.38))
    }

    private var featureGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            miniFeature(tr("ph_tasks_word"), "checklist", cyan)
            miniFeature(tr("ph_feat_week"), "calendar", blue)
            miniFeature(tr("ph_feat_focus"), "timer", gold)
            miniFeature(tr("ph_feat_crew"), "person.3.fill", purple)
        }
    }

    private func miniFeature(_ title: String, _ icon: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(tint)

            Text(title)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground(tint, strength: 0.28))
    }

    private var versionCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "app.badge.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(gold)
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(gold.opacity(0.13))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Updo")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)

                Text(tr("ph_about_version"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()
        }
        .padding(18)
        .background(cardBackground(gold, strength: 0.30))
    }

    private func cardBackground(_ tint: Color, strength: Double) -> some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.070 + strength * 0.035),
                        Color(arenaHex: AppArenaPalette.purple).opacity(0.035),
                        Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(tint.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 13, y: 7)
    }
}
// MARK: - Made With Care

private struct MadeWithCareView: View {
    @Environment(\.dismiss) private var dismiss

    private var coral: Color { Color(arenaHex: AppArenaPalette.coral) }
    private var gold: Color { Color(arenaHex: AppArenaPalette.gold) }
    private var cyan: Color { Color(arenaHex: AppArenaPalette.cyan) }
    private var purple: Color { Color(arenaHex: AppArenaPalette.purple) }

    var body: some View {
        NavigationStack {
            ZStack {
                ArenaBackground(
                    primaryGlow: coral,
                    secondaryGlow: purple,
                    warmGlow: gold,
                    intensity: 0.94
                )

                VStack(spacing: 22) {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark").accessibilityLabel(tr("event_close"))
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    Spacer()

                    VStack(spacing: 22) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            coral.opacity(0.35),
                                            gold.opacity(0.16),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 4,
                                        endRadius: 88
                                    )
                                )
                                .frame(width: 180, height: 180)

                            Image(systemName: "heart.fill")
                                .font(.system(size: 58, weight: .black))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color.white,
                                            coral,
                                            gold
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: coral.opacity(0.34), radius: 22, y: 8)
                        }

                        VStack(spacing: 8) {
                            Text(tr("ph_made_care"))
                                .font(.system(size: 38, weight: .regular, design: .serif))
                                .italic()
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.white, coral, gold],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Text(tr("ph_made_body"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.55))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 24)
                        }

                        VStack(spacing: 12) {
                            careLine(tr("ph_reduce_clutter"), "sparkles", cyan)
                            careLine(tr("ph_protect_focus_rhythm"), "timer", gold)
                            careLine(tr("ph_reduce_clutter_sub"), "scope", coral)
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(Color(arenaHex: AppArenaPalette.surface).opacity(0.88))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 16)
                    }

                    Spacer()
                    Spacer()
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func careLine(_ text: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(tint.opacity(0.12))
                )

            Text(text)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white.opacity(0.86))

            Spacer()
        }
    }
}

// MARK: - App Icon Picker (Pro alternate icons)

import UIKit

struct AppIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscription = SubscriptionManager.shared

    @State private var current: String? = UIApplication.shared.alternateIconName
    @State private var showPaywall = false

    private struct Option: Identifiable {
        let id: String?           // nil = default (Steel)
        let name: String
        let pro: Bool
        let fg: AnyShapeStyle
        let bg: Color
        var key: String { id ?? "__default__" }
    }

    private var options: [Option] {
        [
            Option(id: nil, name: tr("ph_icon_steel"), pro: false,
                   fg: AnyShapeStyle(Color(arenaHex: "#5AB6CC")), bg: Color(arenaHex: "#06070E")),
            Option(id: "AppIcon-Gold", name: "Gold", pro: true,
                   fg: AnyShapeStyle(LinearGradient(colors: [Color(arenaHex: "#FCD34D"), Color(arenaHex: "#D97706")], startPoint: .topLeading, endPoint: .bottomTrailing)),
                   bg: Color(arenaHex: "#0B0905")),
            Option(id: "AppIcon-Chrome", name: "Chrome", pro: true,
                   fg: AnyShapeStyle(LinearGradient(colors: [Color(arenaHex: "#EEF3F7"), Color(arenaHex: "#5B6770")], startPoint: .topLeading, endPoint: .bottomTrailing)),
                   bg: Color(arenaHex: "#0A0C10")),
            Option(id: "AppIcon-Aurora", name: "Aurora", pro: true,
                   fg: AnyShapeStyle(LinearGradient(colors: [Color(arenaHex: "#22D3EE"), Color(arenaHex: "#7C3AED"), Color(arenaHex: "#EC4899")], startPoint: .topLeading, endPoint: .bottomTrailing)),
                   bg: Color(arenaHex: "#07060F")),
            Option(id: "AppIcon-Sunset", name: "Sunset", pro: true,
                   fg: AnyShapeStyle(LinearGradient(colors: [Color(arenaHex: "#FBBF24"), Color(arenaHex: "#FB7185"), Color(arenaHex: "#F472B6")], startPoint: .topLeading, endPoint: .bottomTrailing)),
                   bg: Color(arenaHex: "#120705")),
            Option(id: "AppIcon-Emerald", name: "Emerald", pro: true,
                   fg: AnyShapeStyle(LinearGradient(colors: [Color(arenaHex: "#6EE7B7"), Color(arenaHex: "#10B981"), Color(arenaHex: "#047857")], startPoint: .topLeading, endPoint: .bottomTrailing)),
                   bg: Color(arenaHex: "#03100A")),
            Option(id: "AppIcon-Noir", name: "Noir", pro: true,
                   fg: AnyShapeStyle(Color(arenaHex: "#F2F4F7")), bg: Color(arenaHex: "#000000")),
            Option(id: "AppIcon-Carbon", name: "Carbon", pro: true,
                   fg: AnyShapeStyle(LinearGradient(colors: [Color(arenaHex: "#A8B0BA"), Color(arenaHex: "#4B5563"), Color(arenaHex: "#1F2937")], startPoint: .topLeading, endPoint: .bottomTrailing)),
                   bg: Color(arenaHex: "#08090C")),
            Option(id: "AppIcon-Ice", name: "Ice", pro: true,
                   fg: AnyShapeStyle(LinearGradient(colors: [Color(arenaHex: "#EAF7FF"), Color(arenaHex: "#7DD3FC"), Color(arenaHex: "#38BDF8")], startPoint: .topLeading, endPoint: .bottomTrailing)),
                   bg: Color(arenaHex: "#050A12"))
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArenaBackground(primaryGlow: Color(arenaHex: AppArenaPalette.gold),
                                secondaryGlow: Color(arenaHex: AppArenaPalette.cyan),
                                warmGlow: Color(arenaHex: AppArenaPalette.coral), intensity: 0.9)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(options) { opt in
                            iconRow(opt)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(tr("ph_app_icon_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("common_done")) { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showPaywall) {
                PaywallView(context: "app_icon")
            }
        }
    }

    private func iconRow(_ opt: Option) -> some View {
        let locked = opt.pro && !subscription.isPro
        let selected = (current == opt.id)
        return Button {
            if locked { showPaywall = true } else { apply(opt.id) }
        } label: {
            HStack(spacing: 14) {
                IconThumb(fg: opt.fg, bg: opt.bg)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.09), lineWidth: 1))

                VStack(alignment: .leading, spacing: 3) {
                    Text(opt.name)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                    Text(opt.pro ? "Updo Pro" : "Varsayılan")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(opt.pro ? Color(arenaHex: AppArenaPalette.gold) : .white.opacity(0.45))
                }

                Spacer()

                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color(arenaHex: AppArenaPalette.gold))
                } else if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(Color(arenaHex: AppArenaPalette.green))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(selected ? Color(arenaHex: AppArenaPalette.green).opacity(0.5) : Color.white.opacity(0.07), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func apply(_ id: String?) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(id) { _ in
            DispatchQueue.main.async {
                current = UIApplication.shared.alternateIconName
                NotificationCenter.default.post(name: .appIconDidChange, object: nil)
            }
        }
        current = id
        // Mirror the chosen icon into widgets / live activities.
        WidgetAppSync.updateIcon(id)
    }
}

// MARK: - Live Activity style picker
//
// Same gating pattern as the app-icon picker (Klasik free, the rest Pro), but
// with a big LIVE preview on top: the picker renders the exact same
// FocusLiveStyleCard the widget extension uses, ticking timer included, so the
// user sees precisely what their lock screen will look like.

struct LiveActivityStylePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscription = SubscriptionManager.shared

    @State private var current: String = WidgetShared.readLiveActivityStyle()
    @State private var previewStyle: FocusLiveStyle = .classic
    @State private var showPaywall = false

    private let gold = Color(arenaHex: AppArenaPalette.gold)
    private let cyan = Color(arenaHex: AppArenaPalette.cyan)

    /// Selection with defaults applied (never chosen → Pro sees gold, free classic).
    private var effectiveCurrent: FocusLiveStyle {
        if let chosen = FocusLiveStyle(rawValue: current), !current.isEmpty { return chosen }
        return subscription.isPro ? .gold : .classic
    }

    private var previewLocked: Bool {
        previewStyle.isProOnly && !subscription.isPro
    }

    /// A believable mid-session mock so every style previews with real content.
    private var previewState: FocusAttributes.ContentState {
        FocusAttributes.ContentState(
            title: tr("las_preview_title"),
            subtitle: tr("las_preview_sub"),
            startDate: Date().addingTimeInterval(-11 * 60),
            endDate: Date().addingTimeInterval(14 * 60),
            modeRaw: "personal",
            isPaused: false,
            isResting: false,
            pausedRemainingSeconds: nil,
            pausedProgress: nil
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArenaBackground(primaryGlow: cyan,
                                secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
                                warmGlow: gold, intensity: 0.9)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        previewSection
                        styleGrid

                        Text(tr("las_hint"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.40))
                    }
                    .padding(20)
                }
            }
            .navigationTitle(tr("ph_live_style_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("common_done")) { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showPaywall) {
                PaywallView(context: "live_activity_style")
            }
            .onAppear { previewStyle = effectiveCurrent }
        }
    }

    // MARK: Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("— \(tr("las_preview_caps")) —")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(.white.opacity(0.34))

                Spacer()

                Text(previewStyle.displayName)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(previewStyle.isProOnly ? gold : .white.opacity(0.5))
            }

            FocusLiveStyleCard(
                style: previewStyle,
                state: previewState,
                userState: WidgetShared.readUserState(),
                totalMinutes: 25,
                themeAccent: cyan
            )
            .id(previewStyle)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .animation(.easeOut(duration: 0.18), value: previewStyle)

            if previewLocked {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 12, weight: .black))
                        Text(tr("las_unlock"))
                            .font(.system(size: 14, weight: .black))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(gold)
                            .shadow(color: gold.opacity(0.3), radius: 12, y: 6)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Style grid

    private var styleGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(FocusLiveStyle.allCases, id: \.rawValue) { style in
                styleCell(style)
            }
        }
    }

    private func styleCell(_ style: FocusLiveStyle) -> some View {
        let locked = style.isProOnly && !subscription.isPro
        let selected = effectiveCurrent == style
        let previewing = previewStyle == style

        return Button {
            HapticManager.shared.navigation()
            previewStyle = style

            if !locked {
                current = style.rawValue
                WidgetShared.writeLiveActivityStyle(style.rawValue)
            }
        } label: {
            VStack(spacing: 5) {
                Text(style.displayName)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(gold)
                } else if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color(arenaHex: AppArenaPalette.green))
                } else {
                    Text(style.isProOnly ? "PRO" : tr("las_default"))
                        .font(.system(size: 8.5, weight: .black, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(style.isProOnly ? gold.opacity(0.85) : .white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(previewing ? 0.09 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                previewing
                                ? cyan.opacity(0.55)
                                : (selected
                                   ? Color(arenaHex: AppArenaPalette.green).opacity(0.5)
                                   : Color.white.opacity(0.07)),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Widget style picker
//
// Home-screen twin of the Live Activity picker: same nine style identities,
// same gating (Klasik free, rest Pro), with the REAL widget card previewed
// on top in both sizes — the preview is the exact view the widget extension
// renders, fed by the user's real mirrored stats.

struct WidgetStylePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscription = SubscriptionManager.shared

    @State private var current: String = WidgetShared.readWidgetStyle()
    @State private var previewStyle: FocusLiveStyle = .classic
    @State private var previewSmall = false
    @State private var showPaywall = false

    private let gold = Color(arenaHex: AppArenaPalette.gold)
    private let cyan = Color(arenaHex: AppArenaPalette.cyan)

    private var effectiveCurrent: FocusLiveStyle {
        if let chosen = FocusLiveStyle(rawValue: current), !current.isEmpty { return chosen }
        return .classic
    }

    private var previewLocked: Bool {
        previewStyle.isProOnly && !subscription.isPro
    }

    /// Real mirrored stats — with a friendly floor so an empty account still
    /// previews something readable.
    private var previewState: WidgetUserState {
        var state = WidgetShared.readUserState()
        if state.todayFocusMinutes == 0 && state.streak == 0 {
            state.todayFocusMinutes = 45
            state.streak = 12
            state.level = max(state.level, 7)
            state.levelProgress = state.levelProgress ?? 0.62
            if state.weekFocusMinutes == nil { state.weekFocusMinutes = [25, 40, 10, 95, 70, 55, 45] }
        }
        return state
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArenaBackground(primaryGlow: Color(arenaHex: AppArenaPalette.purple),
                                secondaryGlow: cyan,
                                warmGlow: gold, intensity: 0.9)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        previewSection
                        styleGrid

                        Text(tr("ws_hint"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.40))
                    }
                    .padding(20)
                }
            }
            .navigationTitle(tr("ph_widget_style_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("common_done")) { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showPaywall) {
                PaywallView(context: "widget_style")
            }
            .onAppear { previewStyle = effectiveCurrent }
        }
    }

    // MARK: Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("— \(tr("las_preview_caps")) —")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(.white.opacity(0.34))

                Spacer()

                sizeToggle

                Text(previewStyle.displayName)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(previewStyle.isProOnly ? gold : .white.opacity(0.5))
            }

            HStack {
                Spacer(minLength: 0)
                UpdoWidgetStylePreview(
                    style: previewStyle,
                    state: previewState,
                    isSmall: previewSmall
                )
                .id("\(previewStyle.rawValue)-\(previewSmall)")
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                Spacer(minLength: 0)
            }
            .animation(.easeOut(duration: 0.18), value: previewStyle)
            .animation(.easeOut(duration: 0.18), value: previewSmall)

            if previewLocked {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 12, weight: .black))
                        Text(tr("las_unlock"))
                            .font(.system(size: 14, weight: .black))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(gold)
                            .shadow(color: gold.opacity(0.3), radius: 12, y: 6)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var sizeToggle: some View {
        HStack(spacing: 4) {
            sizeChip("S", isOn: previewSmall) { previewSmall = true }
            sizeChip("M", isOn: !previewSmall) { previewSmall = false }
        }
    }

    private func sizeChip(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(isOn ? .black : .white.opacity(0.5))
                .frame(width: 22, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isOn ? cyan : Color.white.opacity(0.07))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Style grid

    private var styleGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(FocusLiveStyle.allCases, id: \.rawValue) { style in
                styleCell(style)
            }
        }
    }

    private func styleCell(_ style: FocusLiveStyle) -> some View {
        let locked = style.isProOnly && !subscription.isPro
        let selected = effectiveCurrent == style
        let previewing = previewStyle == style

        return Button {
            HapticManager.shared.navigation()
            previewStyle = style

            if !locked {
                current = style.rawValue
                WidgetAppSync.updateWidgetStyle(style.rawValue)
            }
        } label: {
            VStack(spacing: 5) {
                Text(style.displayName)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(gold)
                } else if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color(arenaHex: AppArenaPalette.green))
                } else {
                    Text(style.isProOnly ? "PRO" : tr("las_default"))
                        .font(.system(size: 8.5, weight: .black, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(style.isProOnly ? gold.opacity(0.85) : .white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(previewing ? 0.09 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                previewing
                                ? cyan.opacity(0.55)
                                : (selected
                                   ? Color(arenaHex: AppArenaPalette.green).opacity(0.5)
                                   : Color.white.opacity(0.07)),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct IconThumb: View {
    let fg: AnyShapeStyle
    let bg: Color
    var body: some View {
        GeometryReader { geo in
            let n = min(geo.size.width, geo.size.height)
            let lw = n * 0.052
            let r = n * 0.285
            ZStack {
                bg
                Circle().stroke(style: StrokeStyle(lineWidth: lw, lineCap: .round)).fill(fg)
                    .frame(width: r*2, height: r*2)
                ForEach(0..<4, id: \.self) { i in
                    Capsule().fill(fg).frame(width: lw, height: n*0.20)
                        .offset(y: -r).rotationEffect(.degrees(Double(i)*90))
                }
                ProfileNorthArrow().fill(fg).frame(width: n*0.215, height: n*0.235).offset(y: -n*0.005)
            }
            .frame(width: n, height: n)
        }
    }
}

private struct ProfileNorthArrow: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let pts = [
            CGPoint(x: rect.minX + 0.50*w, y: rect.minY + 0.02*h),
            CGPoint(x: rect.minX + 0.97*w, y: rect.minY + 0.97*h),
            CGPoint(x: rect.minX + 0.50*w, y: rect.minY + 0.66*h),
            CGPoint(x: rect.minX + 0.03*w, y: rect.minY + 0.97*h)
        ]
        let radius = min(w, h) * 0.10
        var path = Path()
        let n = pts.count
        for i in 0..<n {
            let cur = pts[i], pr = pts[(i-1+n)%n], nx = pts[(i+1)%n]
            let tP = unit(cur, pr), tN = unit(cur, nx)
            let rP = min(radius, dist(cur, pr)/2), rN = min(radius, dist(cur, nx)/2)
            let st = CGPoint(x: cur.x+tP.x*rP, y: cur.y+tP.y*rP)
            let en = CGPoint(x: cur.x+tN.x*rN, y: cur.y+tN.y*rN)
            if i == 0 { path.move(to: st) } else { path.addLine(to: st) }
            path.addQuadCurve(to: en, control: cur)
        }
        path.closeSubpath()
        return path
    }
    private func unit(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        let dx = b.x-a.x, dy = b.y-a.y, l = max((dx*dx+dy*dy).squareRoot(), 0.0001)
        return CGPoint(x: dx/l, y: dy/l)
    }
    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { ((a.x-b.x)*(a.x-b.x)+(a.y-b.y)*(a.y-b.y)).squareRoot() }
}
