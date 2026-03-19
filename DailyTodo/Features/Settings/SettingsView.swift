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
                    appSection
                    supportSection
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("Settings")
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
        Section("Account") {
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
                            title: "Edit Profile",
                            subtitle: "Change your name and username",
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
                                Text("Sign Out")
                                    .foregroundStyle(.red)

                                Text("Sign out from your account")
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
                        title: "Sign In / Create Account",
                        subtitle: "Prepare your account for sync, friends and crews",
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $appTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Label(theme.title, systemImage: theme.icon)
                        .tag(theme.rawValue)
                }
            }

            Toggle(isOn: $showOnlyToday) {
                settingsRow(
                    icon: "calendar",
                    iconColor: .orange,
                    title: "Show Only Today",
                    subtitle: "Focus on today’s tasks"
                )
            }
        }
    }

    private var productivitySection: some View {
        Section("Productivity") {
            Toggle(isOn: $smartEngineEnabled) {
                settingsRow(
                    icon: "brain.head.profile",
                    iconColor: .purple,
                    title: "Smart Task Engine",
                    subtitle: "AI suggestions and smart planning"
                )
            }

            settingsRow(
                icon: "bell.badge.fill",
                iconColor: .red,
                title: "Notifications",
                subtitle: "Focus reminders and task nudges"
            )

            settingsRow(
                icon: "timer",
                iconColor: .green,
                title: "Focus Preferences",
                subtitle: "Manage your focus experience"
            )

            settingsRow(
                icon: "globe",
                iconColor: .purple,
                title: "Language",
                subtitle: "Change app language later"
            )
        }
    }

    private var appSection: some View {
        Section("App") {
            Button {
                didFinishOnboarding = false
            } label: {
                settingsRow(
                    icon: "sparkles",
                    iconColor: .blue,
                    title: "Show Onboarding Again",
                    subtitle: "Replay the welcome screens",
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
                    title: "Show Permission Screen",
                    subtitle: "Replay notification intro",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var supportSection: some View {
        Section("Support") {
            settingsRow(
                icon: "info.circle.fill",
                iconColor: .secondary,
                title: "About DailyTodoo",
                subtitle: "Version 1.0"
            )

            settingsRow(
                icon: "heart.fill",
                iconColor: .pink,
                title: "Made with care",
                subtitle: "Built for focus, planning and crews"
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
