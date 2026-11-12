//
//  OnboardingWidgetPromoView.swift
//  DailyTodo
//

import SwiftUI

/// Onboarding, after the showcase: what Updo looks like OUTSIDE the app. A
/// composed tableau of the real thing — the Live Activity as it sits on the
/// lock screen, and the Focus Card widgets as they sit on the home screen
/// (the exact views the extension draws) — then one line on how to add them.
/// The sample numbers are shown against the student's own daily goal.
struct OnboardingWidgetPromoView: View {
    /// Next step. The paywall no longer lives here — it follows the user's
    /// first action (see `OnboardingHandoff`).
    var onFinish: () -> Void

    @EnvironmentObject private var studentStore: StudentStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var floating = false

    private let isPad = UIDevice.current.userInterfaceIdiom == .pad
    private var cyan: Color { Color(arenaHex: AppArenaPalette.cyan) }
    private var blue: Color { Color(arenaHex: AppArenaPalette.blue) }

    private var goalMinutes: Int { studentStore.profile?.dailyStudyGoalMinutes ?? 120 }

    /// A lived-in sample so the widgets read as they will after a week.
    private var sampleState: WidgetUserState {
        var s = WidgetUserState(
            iconName: nil,
            isPro: true,
            streak: 12,
            level: 6,
            todayFocusMinutes: Int(Double(goalMinutes) * 0.7),
            statsShared: true,
            longestStreak: 21
        )
        s.levelProgress = 0.62
        s.weekFocusMinutes = [40, 70, 30, 90, 55, 80, Int(Double(goalMinutes) * 0.7)]
        s.prevWeekFocusMinutes = 300
        s.todayFocusDone = true
        s.todayTaskDone = true
        s.peakHour = 20
        return s
    }

    private var liveState: FocusAttributes.ContentState {
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
        ZStack {
            ArenaBackground(
                primaryGlow: cyan,
                secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
                warmGlow: blue,
                intensity: 0.9
            )

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        HapticManager.shared.navigation()
                        onFinish()
                    } label: {
                        Text(tr("common_skip"))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .foregroundStyle(UpdoTheme.filmy(0.42))
                            .frame(height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)

                GeometryReader { geo in
                    // Laid out at its natural size, then scaled as one piece to
                    // whatever height the screen leaves — never cropped, never
                    // running under the words below.
                    let width = min(geo.size.width - 44, isPad ? 460 : 400)
                    let natural = Self.tableauHeight(width: width)
                    let scale = min(1, max(0.5, geo.size.height / natural))

                    tableau(width: width)
                        .scaleEffect(scale, anchor: .center)
                        .frame(width: width * scale, height: natural * scale)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.top, 6)
                .padding(.bottom, 14)

                VStack(alignment: .leading, spacing: 12) {
                    ArenaLargeTitle(
                        eyebrow: tr("ob_widget_eyebrow"),
                        title: tr("ob_widget_title_a"),
                        accent: tr("ob_widget_title_b"),
                        accentColor: cyan
                    )

                    Text(tr("ob_widget_sub"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(UpdoTheme.filmy(0.56))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    // How to get them — the one thing people don't know.
                    HStack(spacing: 9) {
                        Image(systemName: "plus.app")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(cyan)
                        Text(tr("ob_widget_hint"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(UpdoTheme.filmy(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(UpdoTheme.filmy(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(UpdoTheme.filmy(0.09), lineWidth: 1))
                    )

                    Button {
                        HapticManager.shared.action()
                        onFinish()
                    } label: {
                        HStack(spacing: 8) {
                            Text(tr("common_continue"))
                                .font(.system(size: 17, weight: .black))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 15, weight: .black))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Capsule().fill(LinearGradient(colors: [cyan, blue], startPoint: .leading, endPoint: .trailing))
                                .shadow(color: cyan.opacity(0.36), radius: 16, y: 8)
                        )
                    }
                    .buttonStyle(OnboardingScaleButtonStyle())
                    .padding(.top, 6)
                }
                .frame(maxWidth: isPad ? 560 : .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.84)) { appeared = true }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) { floating = true }
        }
    }

    // MARK: - Tableau (lock screen card, then the home-screen widgets)

    /// Height of the tableau at `width`: the lock-screen card, the medium
    /// widget, the row of small ones, two place labels and the gaps.
    private static func tableauHeight(width: CGFloat) -> CGFloat {
        let liveCard: CGFloat = 142
        let medium = 158 * width / 338
        let smallRow = (width - 12) / 2
        return liveCard + medium + smallRow + 58
    }

    private func tableau(width: CGFloat) -> some View {
        let gap: CGFloat = 12
        let half = (width - gap) / 2

        return VStack(alignment: .leading, spacing: 10) {
            piece(0, label: tr("ob_widget_lock")) {
                FocusLiveStyleCard(
                    style: .classic,
                    state: liveState,
                    userState: sampleState,
                    totalMinutes: 25,
                    themeAccent: cyan
                )
                .frame(width: width)
            }

            piece(1, label: tr("ob_widget_home")) {
                widget(.classic, small: false, width: width)
            }

            piece(2, label: nil) {
                HStack(spacing: gap) {
                    widget(.aura, small: true, width: half)
                    widget(.gold, small: true, width: half)
                }
            }
        }
        .frame(width: width)
        // The whole composition breathes a little; nothing drifts or loops fast.
        .offset(y: floating ? -5 : 5)
    }

    /// One row of the tableau, with its place label and staggered entrance.
    private func piece<Content: View>(_ index: Int, label: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                Text(label)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(UpdoTheme.filmy(0.4))
                    .padding(.leading, 4)
            }
            content()
                .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 22)
        .scaleEffect(appeared ? 1 : 0.96)
        .animation(
            reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.82).delay(0.08 + Double(index) * 0.11),
            value: appeared
        )
    }

    /// The real widget view, scaled from its native size to `width`.
    private func widget(_ style: FocusLiveStyle, small: Bool, width: CGFloat) -> some View {
        let native: CGFloat = small ? 158 : 338
        let scale = width / native
        return UpdoWidgetStylePreview(style: style, state: sampleState, isSmall: small, dailyGoalMinutes: goalMinutes)
            .scaleEffect(scale)
            .frame(width: width, height: 158 * scale)
    }
}
