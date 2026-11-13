//
//  OnboardingWidgetPromoView.swift
//  DailyTodo
//

import SwiftUI

/// Onboarding, after the showcase: what Updo looks like OUTSIDE the app. One
/// phone screen that moves between the two places Updo lives — the lock screen
/// (the Live Activity) and the home screen (the Focus Card widgets) — drawn
/// with the exact views the extension draws, and walking through the styles.
/// The sample numbers are shown against the student's own daily goal.
struct OnboardingWidgetPromoView: View {
    /// Next step. The paywall no longer lives here — it follows the user's
    /// first action (see `OnboardingHandoff`).
    var onFinish: () -> Void

    @EnvironmentObject private var studentStore: StudentStore
    @Environment(\.modelContext) private var modelContext
    /// The student's own day for the "Focus + Schedule" widget.
    @State private var dayEvents: [WidgetEvent] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var place: Place = .lock
    @State private var styleIndex = 0
    /// Stops alternating places once the student picks one themselves.
    @State private var autoplay = true

    private enum Place { case lock, home }
    /// Poster opens the page; the rest follow in turn.
    private static let styles: [FocusLiveStyle] = [.poster, .gold, .aura, .neon, .arena, .classic]
    private var style: FocusLiveStyle { Self.styles[styleIndex % Self.styles.count] }
    private var nextStyle: FocusLiveStyle { Self.styles[(styleIndex + 1) % Self.styles.count] }

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
                    // The screen runs on downwards and dissolves into a blur
                    // behind the words, instead of ending in a closed frame.
                    let width = Self.phoneWidth(in: geo.size, isPad: isPad)

                    ZStack(alignment: .bottom) {
                        fadingPhone(
                            width: width,
                            height: geo.size.height + 130,
                            sharpEnd: geo.size.height - Self.fadeReserve
                        )
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .top)

                        switcher
                            .frame(width: min(width, geo.size.width - 48))
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 16)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.94)

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
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "plus.app.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(cyan)
                        Text(tr("ob_widget_hint"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(UpdoTheme.filmy(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }

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
            loadDayEvents()
            withAnimation(reduceMotion ? nil : .spring(response: 0.75, dampingFraction: 0.84)) { appeared = true }
        }
        .task {
            // Lock screen → home screen → next style, at a readable pace.
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_400_000_000)
                if Task.isCancelled { break }
                withAnimation(.spring(response: 0.62, dampingFraction: 0.86)) {
                    if autoplay {
                        if place == .home { styleIndex += 1 }
                        place = place == .lock ? .home : .lock
                    } else {
                        styleIndex += 1
                    }
                }
            }
        }
    }

    /// The programme the student just built: today's, or — on a free day —
    /// their next day with lessons, so the widget is shown doing its job.
    private func loadDayEvents() {
        WidgetAppSync.refreshFromSwiftData(context: modelContext)
        let payload = WidgetShared.readPayload()
        let today = Date()
        for offset in 0..<7 {
            guard let day = Calendar.current.date(byAdding: .day, value: offset, to: today) else { continue }
            let events = payload?.events(on: day) ?? []
            if !events.isEmpty { dayEvents = events; return }
        }
        dayEvents = [
            WidgetEvent(id: "s1", title: tr("ob_widget_sample_1"), weekday: 0, startMinute: 9 * 60, durationMinute: 90, location: nil, colorHex: "#2DD4FF"),
            WidgetEvent(id: "s2", title: tr("ob_widget_sample_2"), weekday: 0, startMinute: 11 * 60, durationMinute: 90, location: nil, colorHex: "#7C3AED"),
            WidgetEvent(id: "s3", title: tr("ob_widget_sample_3"), weekday: 0, startMinute: 14 * 60, durationMinute: 60, location: nil, colorHex: "#1593FF")
        ]
    }

    // MARK: - Stage (one phone screen, two places)

    private static let switcherHeight: CGFloat = 34
    /// Everything inside the screen is laid out in real iPhone points and
    /// scaled as one piece, so the widgets sit exactly as they do at home.
    private static let realWidth: CGFloat = 393
    /// Where the home-screen widgets end, in real points.
    private static let realContentBottom: CGFloat = 404
    /// Height at the foot of the hero given over to the dissolve.
    private static let fadeReserve: CGFloat = 56

    /// As wide as the screen allows while the widgets still clear the dissolve.
    private static func phoneWidth(in size: CGSize, isPad: Bool) -> CGFloat {
        let byHeight = (size.height - fadeReserve) / realContentBottom * realWidth
        return max(200, min(size.width - 52, isPad ? 380 : 352, byHeight))
    }

    /// The screen, sharp above `sharpEnd` and melting into blur below it.
    private func fadingPhone(width: CGFloat, height: CGFloat, sharpEnd: CGFloat) -> some View {
        let a = min(0.74, max(0.1, sharpEnd / height))

        return ZStack {
            phoneScreen(width: width, height: height)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: a),
                            .init(color: .black.opacity(0.35), location: min(1, a + 0.1)),
                            .init(color: .clear, location: min(1, a + 0.24))
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            phoneScreen(width: width, height: height)
                .blur(radius: 12)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: max(0, a - 0.03)),
                            .init(color: .black.opacity(0.7), location: min(1, a + 0.08)),
                            .init(color: .black.opacity(0.3), location: min(1, a + 0.2)),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .compositingGroup()
        .shadow(color: cyan.opacity(0.16), radius: 34, y: 10)
        .shadow(color: .black.opacity(0.5), radius: 22, y: 12)
    }

    private func phoneScreen(width: CGFloat, height: CGFloat) -> some View {
        let unit = width / Self.realWidth
        let realHeight = height / unit
        let screen = UnevenRoundedRectangle(topLeadingRadius: 54, topTrailingRadius: 54, style: .continuous)
        let bezel = UnevenRoundedRectangle(topLeadingRadius: 60, topTrailingRadius: 60, style: .continuous)

        return ZStack(alignment: .top) {
            wallpaper

            ZStack(alignment: .top) {
                if place == .lock {
                    lockScene
                        .transition(.opacity.combined(with: .scale(scale: 1.04)))
                } else {
                    homeScene
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                }
            }
            .frame(width: Self.realWidth, height: realHeight, alignment: .top)

            Capsule()
                .fill(.black)
                .frame(width: 122, height: 36)
                .padding(.top, 12)
        }
        .frame(width: Self.realWidth, height: realHeight)
        .clipShape(screen)
        .overlay(screen.strokeBorder(Color.white.opacity(0.16), lineWidth: 1.2))
        // The device edge: a dark bezel with a soft outer rim.
        .padding([.horizontal, .top], 6)
        .background(bezel.fill(Color.black))
        .overlay(bezel.strokeBorder(Color.white.opacity(0.1), lineWidth: 1.2))
        .scaleEffect(unit, anchor: .top)
        .frame(width: width + 12 * unit, height: height, alignment: .top)
    }

    private var wallpaper: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.07, blue: 0.15), Color(red: 0.02, green: 0.02, blue: 0.05)],
                startPoint: .top, endPoint: .bottom
            )
            Circle().fill(cyan.opacity(0.34)).frame(width: 300, height: 300).blur(radius: 80).offset(x: -130, y: -40)
                .frame(maxHeight: .infinity, alignment: .top)
            Circle().fill(Color(arenaHex: AppArenaPalette.purple).opacity(0.36)).frame(width: 320, height: 320).blur(radius: 90).offset(x: 130, y: 240)
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: Lock screen (real points)

    private var sceneLocale: Locale { Locale(identifier: appLanguageIsEnglish() ? "en_US" : "tr_TR") }

    private var lockScene: some View {
        VStack(spacing: 0) {
            Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(sceneLocale)))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))
                .padding(.top, 64)

            Text(Date().formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(Locale(identifier: "tr_TR"))))
                .font(.system(size: 96, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.92))
                .padding(.top, -6)

            FocusLiveStyleCard(
                style: style,
                state: liveState,
                userState: sampleState,
                totalMinutes: 25,
                themeAccent: cyan
            )
            .frame(width: 369)
            .id(style)
            .transition(.opacity.combined(with: .offset(y: 14)))
            .shadow(color: .black.opacity(0.4), radius: 14, y: 8)
            .padding(.top, 8)

            // Older notifications underneath, already out of focus.
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.075))
                    .frame(width: 369, height: 76)
                    .padding(.top, 10)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: Home screen (real points: 27 pt margins, 22 pt gutters)

    private var homeScene: some View {
        VStack(spacing: 22) {
            // Two medium widgets take turns: today's programme, then the week.
            UpdoWidgetStylePreview(
                style: style,
                state: sampleState,
                isSmall: false,
                dailyGoalMinutes: goalMinutes,
                schedule: styleIndex.isMultiple(of: 2) ? dayEvents : nil,
                now: Calendar.current.startOfDay(for: Date())
            )
                .id(style)
                .transition(.opacity)
                .shadow(color: .black.opacity(0.35), radius: 12, y: 7)

            HStack(spacing: 22) {
                UpdoWidgetStylePreview(style: nextStyle, state: sampleState, isSmall: true, dailyGoalMinutes: goalMinutes)
                    .id(nextStyle)
                    .transition(.opacity)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 7)

                VStack(spacing: 16) {
                    HStack(spacing: 38) { appIcon(0); appIcon(1) }
                    HStack(spacing: 38) { appIcon(2); appIcon(3) }
                }
                .frame(width: 158, height: 158)
            }

            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 98.0 / 3) {
                    ForEach(0..<4, id: \.self) { appIcon(row * 4 + $0 + 4) }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(width: 338)
        .padding(.top, 66)
    }

    /// A stand-in for someone else's app: quiet, so the widgets carry the scene.
    private func appIcon(_ index: Int) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(index.isMultiple(of: 3) ? 0.14 : 0.09))
                .frame(width: 60, height: 60)
            Capsule()
                .fill(Color.white.opacity(0.1))
                .frame(width: 30, height: 5)
        }
    }

    // MARK: Switcher (where you're looking + which style)

    private var switcher: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                segment(.lock, icon: "lock.fill", title: tr("ob_widget_lock"))
                segment(.home, icon: "square.grid.2x2.fill", title: tr("ob_widget_home"))
            }
            .padding(3)
            .background(Capsule().fill(UpdoTheme.filmy(0.07)))
            .overlay(Capsule().strokeBorder(UpdoTheme.filmy(0.09), lineWidth: 1))

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(cyan)
                Text(style.displayName.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(UpdoTheme.filmy(0.72))
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, 11)
            .frame(height: Self.switcherHeight - 6)
            .background(Capsule().fill(UpdoTheme.filmy(0.05)))
        }
        .frame(height: Self.switcherHeight)
    }

    private func segment(_ target: Place, icon: String, title: String) -> some View {
        let on = place == target
        return Button {
            HapticManager.shared.navigation()
            autoplay = false
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { place = target }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(0.6)
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(on ? Color.black : UpdoTheme.filmy(0.5))
            .padding(.horizontal, 10)
            .frame(height: Self.switcherHeight - 6)
            .background(Capsule().fill(on ? cyan : Color.clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
