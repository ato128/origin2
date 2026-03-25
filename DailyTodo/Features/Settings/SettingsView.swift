//
//  SettingsView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 5.03.2026.
//
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var languageManager: LanguageManager

    @AppStorage("smartEngineEnabled") private var smartEngineEnabled: Bool = true
    @AppStorage("didFinishOnboarding") private var didFinishOnboarding = true
    @AppStorage("didFinishPermissionOnboarding") private var didFinishPermissionOnboarding = true
    @AppStorage("showOnlyToday") private var showOnlyToday: Bool = false
    @AppStorage("appTheme") private var appTheme: String = AppTheme.gradient.rawValue

    @State private var showEditProfile = false
    @State private var showAuthSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                Form {
                    accountSection
                    appearanceSection
                    productivitySection
                    languageSection
                    appSection
                    supportSection
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("settings_title")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showAuthSheet) {
                AuthView()
                    .environmentObject(session)
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environmentObject(session)
            }
        }
    }

    private var accountSection: some View {
        Section("settings_section_account") {
            if let user = session.currentUser {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.16))
                                .frame(width: 46, height: 46)

                            Image(systemName: "person.fill")
                                .foregroundStyle(Color.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(user.fullName)
                                .font(.headline)

                            Text("@\(user.username)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(user.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)

                    Button {
                        showEditProfile = true
                    } label: {
                        settingsRow(
                            icon: "pencil",
                            iconColor: .blue,
                            title: String(localized: "settings_edit_profile_title"),
                            subtitle: String(localized: "settings_edit_profile_subtitle"),
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        session.signOut()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.red.opacity(0.14))
                                    .frame(width: 34, height: 34)

                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.red)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("settings_sign_out_title")
                                    .foregroundStyle(.red)

                                Text("settings_sign_out_subtitle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    showAuthSheet = true
                } label: {
                    settingsRow(
                        icon: "person.crop.circle.badge.plus",
                        iconColor: .blue,
                        title: String(localized: "settings_sign_in_title"),
                        subtitle: String(localized: "settings_sign_in_subtitle"),
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var appearanceSection: some View {
        Section("settings_section_appearance") {
            Picker("settings_theme_title", selection: $appTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Label(theme.title, systemImage: theme.icon)
                        .tag(theme.rawValue)
                }
            }

            Toggle(isOn: $showOnlyToday) {
                settingsRow(
                    icon: "calendar",
                    iconColor: .orange,
                    title: String(localized: "settings_show_only_today_title"),
                    subtitle: String(localized: "settings_show_only_today_subtitle")
                )
            }
        }
    }

    private var productivitySection: some View {
        Section("settings_section_productivity") {
            Toggle(isOn: $smartEngineEnabled) {
                settingsRow(
                    icon: "brain.head.profile",
                    iconColor: .purple,
                    title: String(localized: "settings_smart_engine_title"),
                    subtitle: String(localized: "settings_smart_engine_subtitle")
                )
            }

            settingsRow(
                icon: "bell.badge.fill",
                iconColor: .red,
                title: String(localized: "settings_notifications_title"),
                subtitle: String(localized: "settings_notifications_subtitle")
            )

            settingsRow(
                icon: "timer",
                iconColor: .green,
                title: String(localized: "settings_focus_preferences_title"),
                subtitle: String(localized: "settings_focus_preferences_subtitle")
            )
        }
    }

    private var languageSection: some View {
        Section("settings_section_language") {
            Picker("settings_app_language_title", selection: Binding(
                get: { languageManager.selectedLanguage },
                set: { languageManager.setLanguage($0) }
            )) {
                ForEach(AppLanguage.allCases) { language in
                    Text(LocalizedStringKey(language.titleKey))
                        .tag(language)
                }
            }
        }
    }

    private var appSection: some View {
        Section("settings_section_app") {
            Button {
                didFinishOnboarding = false
            } label: {
                settingsRow(
                    icon: "sparkles",
                    iconColor: .blue,
                    title: String(localized: "settings_show_onboarding_again_title"),
                    subtitle: String(localized: "settings_show_onboarding_again_subtitle"),
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            Button {
                didFinishPermissionOnboarding = false
            } label: {
                settingsRow(
                    icon: "bell.fill",
                    iconColor: .orange,
                    title: String(localized: "settings_show_permission_screen_title"),
                    subtitle: String(localized: "settings_show_permission_screen_subtitle"),
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var supportSection: some View {
        Section("settings_section_support") {
            settingsRow(
                icon: "info.circle.fill",
                iconColor: .secondary,
                title: String(localized: "settings_about_title"),
                subtitle: String(localized: "settings_about_subtitle")
            )

            settingsRow(
                icon: "heart.fill",
                iconColor: .pink,
                title: String(localized: "settings_made_with_care_title"),
                subtitle: String(localized: "settings_made_with_care_subtitle")
            )
        }
    }

    @ViewBuilder
    private func settingsRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        showsChevron: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
