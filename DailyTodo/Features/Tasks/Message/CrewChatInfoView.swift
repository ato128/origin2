//
//  CrewChatInfoView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 15.03.2026.
//

import SwiftUI
import SwiftData
import UIKit

struct CrewChatInfoView: View {
    @Bindable var crew: Crew

    @Query private var members: [CrewMember]
    @Query private var tasks: [CrewTask]

    @Environment(\.dismiss) private var dismiss

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    @State private var badgeGlow = false
    @State private var previousBadgeTitle: String = ""
    @State private var showBadgeUnlocked: Bool = false

    private var crewMembers: [CrewMember] {
        members.filter { $0.crewID == crew.id }
    }

    private var crewTasks: [CrewTask] {
        tasks.filter { $0.crewID == crew.id }
    }

    private var completedCount: Int {
        crewTasks.filter(\.isDone).count
    }
    private var focusBadgeTitle: String {
        CrewBadgeHelper.title(for: crew.totalFocusMinutes)
    }

    private var focusBadgeColor: Color {
        CrewBadgeHelper.color(for: crew.totalFocusMinutes)
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 18) {
                    topHeader
                    profileCard
                    statsCard
                    CrewBadgeCard(
                        crew: crew,
                        palette: palette
                    )
                    membersCard
                    settingsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            previousBadgeTitle = focusBadgeTitle

            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                badgeGlow = true
            }
        }
        .onChange(of: crew.totalFocusMinutes) { _, _ in
            let newBadgeTitle = focusBadgeTitle

            guard newBadgeTitle != previousBadgeTitle else { return }
            guard newBadgeTitle != "No Badge" else {
                previousBadgeTitle = newBadgeTitle
                return
            }

            previousBadgeTitle = newBadgeTitle
            showBadgeUnlocked = true

            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.prepare()
            gen.impactOccurred()

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showBadgeUnlocked = false
                }
            }
        }
    }
}

private extension CrewChatInfoView {
    var topHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 44, height: 44)
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

            Text("Crew Info")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
    }

    var profileCard: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(hexColor(crew.colorHex).opacity(0.16))
                    .frame(width: 94, height: 94)

                Image(systemName: crew.icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(hexColor(crew.colorHex))
            }

            VStack(spacing: 4) {
                Text(crew.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Text("Crew workspace")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(cardBackground)
    }

    var statsCard: some View {
        HStack(spacing: 12) {
            statItem(value: "\(crewMembers.count)", title: "Members")
            statItem(value: "\(crewTasks.count)", title: "Tasks")
            statItem(value: "\(completedCount)", title: "Done")
        }
        .padding(18)
        .background(cardBackground)
    }

   
    var membersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Members")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            if crewMembers.isEmpty {
                Text("No members yet")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            } else {
                ForEach(crewMembers) { member in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(hexColor(crew.colorHex).opacity(0.14))
                                .frame(width: 38, height: 38)

                            Image(systemName: "person.fill")
                                .foregroundStyle(hexColor(crew.colorHex))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryText)

                            Text(member.role)
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }

                        Spacer()
                    }
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var settingsCard: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $crew.isMuted) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Mute Crew Notifications")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.primaryText)

                    Text("Stop alerts from this crew")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
            }
            .tint(Color.accentColor)
            .padding(.vertical, 14)

            Divider()
                .overlay(palette.cardStroke)

            Button {
            } label: {
                HStack {
                    Image(systemName: "person.3.fill")
                    Text("Open Crew Later")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(palette.secondaryText)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .background(cardBackground)
    }

    func statItem(value: String, title: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(palette.primaryText)

            Text(title)
                .font(.caption)
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.secondaryCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardStroke.opacity(0.7), lineWidth: 1)
                )
        )
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }
}
