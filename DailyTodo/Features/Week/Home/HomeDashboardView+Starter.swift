//
//  HomeDashboardView+Starter.swift
//  DailyTodo
//
//  First-run activation card. Surfaces Updo's core powers as 3–4 first steps
//  that tick off automatically as the user actually uses each feature, then
//  the card retires itself. Shown only to genuinely new accounts.
//
//  State machine (`homeStarterStateRaw`):
//    0 = not yet evaluated · 1 = active (visible) · 2 = retired
//

import SwiftUI

// MARK: - Step Model

struct StarterStep: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
    let done: Bool
    let action: () -> Void
}

extension HomeDashboardView {

    // MARK: - Signals

    var starterSteps: [StarterStep] {
        [
            StarterStep(
                id: "task",
                icon: "checklist",
                title: tr("starter_step_task"),
                subtitle: tr("starter_step_task_sub"),
                accent: Color(arenaHex: AppArenaPalette.cyan),
                done: !userScopedTasks.isEmpty,
                action: { onAddTask() }
            ),
            StarterStep(
                id: "schedule",
                icon: "calendar",
                title: tr("starter_step_schedule"),
                subtitle: tr("starter_step_schedule_sub"),
                accent: Color(arenaHex: AppArenaPalette.blue),
                done: !userScopedEvents.isEmpty,
                action: { onOpenWeek() }
            ),
            StarterStep(
                id: "focus",
                icon: "scope",
                title: tr("starter_step_focus"),
                subtitle: tr("starter_step_focus_sub"),
                accent: Color(arenaHex: AppArenaPalette.purple),
                done: completedStarterFocusCount > 0,
                action: { onOpenFocus() }
            ),
            StarterStep(
                id: "social",
                icon: "person.2.fill",
                title: tr("starter_step_social"),
                subtitle: tr("starter_step_social_sub"),
                accent: Color(arenaHex: AppArenaPalette.coral),
                done: !friends.isEmpty || !crewStore.crews.isEmpty,
                action: { showFriendsShortcut = true }
            )
        ]
    }

    var completedStarterFocusCount: Int {
        allFocusRecords.filter { $0.isCompleted && $0.completedSeconds >= 60 }.count
    }

    var completedStarterStepCount: Int {
        starterSteps.filter(\.done).count
    }

    var allStarterStepsDone: Bool {
        completedStarterStepCount >= starterSteps.count
    }

    /// Visible only while the card is in its active state.
    var shouldShowStarterCard: Bool {
        homeStarterStateRaw == 1
    }

    // MARK: - Lifecycle

    /// Decides the card's fate the first time Home renders for this install.
    /// Established users (who already did most steps long ago) never see it.
    func evaluateStarterCardOnAppear() {
        guard homeStarterStateRaw == 0 else { return }
        homeStarterStateRaw = completedStarterStepCount >= 3 ? 2 : 1
    }

    func retireStarterCard() {
        HapticManager.shared.success()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            homeStarterStateRaw = 2
        }
    }

    func dismissStarterCard() {
        HapticManager.shared.navigation()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            homeStarterStateRaw = 2
        }
    }

    // MARK: - Card

    @ViewBuilder
    var starterCard: some View {
        let accent = Color(arenaHex: AppArenaPalette.cyan)
        let steps = starterSteps
        let completed = steps.filter(\.done).count
        let total = steps.count
        let allDone = completed >= total

        VStack(alignment: .leading, spacing: 16) {
            if allDone {
                starterCompletedHeader
            } else {
                starterActiveHeader(accent: accent, completed: completed, total: total)
            }

            VStack(spacing: 10) {
                ForEach(steps) { step in
                    starterStepRow(step)
                }
            }

            if allDone {
                Button {
                    retireStarterCard()
                } label: {
                    Text(tr("starter_done_cta"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(accent, in: Capsule())
                }
                .buttonStyle(UpdoPressButtonStyle())
            } else {
                Button {
                    dismissStarterCard()
                } label: {
                    Text(tr("starter_hide"))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.42))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(topCardBackground(accent: accent))
    }

    // MARK: - Header variants

    private func starterActiveHeader(accent: Color, completed: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(tr("starter_caps"))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(accent.opacity(0.92))

                Spacer(minLength: 8)

                Text(tr("starter_progress", completed, total))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(tr("starter_title"))
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(tr("starter_sub"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            starterProgressBar(accent: accent, completed: completed, total: total)
                .padding(.top, 2)
        }
    }

    private var starterCompletedHeader: some View {
        let accent = Color(arenaHex: AppArenaPalette.green)
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.14))
                    .frame(width: 48, height: 48)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(tr("starter_done_caps"))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(accent.opacity(0.92))

                Text(tr("starter_done_title"))
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(tr("starter_done_sub"))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private func starterProgressBar(accent: Color, completed: Int, total: Int) -> some View {
        GeometryReader { geo in
            let fraction = total > 0 ? CGFloat(completed) / CGFloat(total) : 0
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.07))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.8), accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, geo.size.width * fraction))
            }
        }
        .frame(height: 6)
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: completed)
    }

    // MARK: - Step row

    private func starterStepRow(_ step: StarterStep) -> some View {
        Button {
            guard !step.done else { return }
            HapticManager.shared.navigation()
            step.action()
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    if step.done {
                        Circle()
                            .fill(Color(arenaHex: AppArenaPalette.green).opacity(0.16))
                            .frame(width: 30, height: 30)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Color(arenaHex: AppArenaPalette.green))
                    } else {
                        Circle()
                            .fill(step.accent.opacity(0.13))
                            .frame(width: 30, height: 30)
                        Image(systemName: step.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(step.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(step.title)
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        .foregroundStyle(step.done ? .white.opacity(0.42) : .white)
                        .strikethrough(step.done, color: .white.opacity(0.3))
                        .lineLimit(1)

                    if !step.done {
                        Text(step.subtitle)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.42))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 6)

                if !step.done {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.28))
                }
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(step.done ? 0.02 : 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(step.done)
    }
}
