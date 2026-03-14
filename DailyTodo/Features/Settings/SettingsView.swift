//
//  SettingsView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 5.03.2026.
//
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("smartEngineEnabled") private var smartEngineEnabled: Bool = true
    @AppStorage("didFinishOnboarding") private var didFinishOnboarding = true
    @AppStorage("didFinishPermissionOnboarding") private var didFinishPermissionOnboarding = true
    @AppStorage("showOnlyToday") private var showOnlyToday: Bool = false
    @AppStorage("appTheme") private var appTheme: String = AppTheme.gradient.rawValue

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                Form {
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
