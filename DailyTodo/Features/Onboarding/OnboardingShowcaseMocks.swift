//
//  OnboardingShowcaseMocks.swift
//  DailyTodo
//
//  Faithful, hand-built recreations of the five Updo tabs, scaled to sit inside
//  the onboarding device frame. Mirrors the real screens (headers, cards, tab
//  bar with active label) using Arena tokens — localized, crisp, never stale.
//

import SwiftUI

enum ShowcaseMockKind {
    case home, week, focus, crew, insights

    var tabIndex: Int {
        switch self {
        case .home: return 0
        case .week: return 1
        case .crew: return 2
        case .focus: return 3
        case .insights: return 4
        }
    }
}

// MARK: - Screen shell

struct ShowcaseMockScreen: View {
    let kind: ShowcaseMockKind
    let accent: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(arenaHex: AppArenaPalette.backgroundTop),
                    Color(arenaHex: AppArenaPalette.backgroundMid),
                    Color(arenaHex: AppArenaPalette.backgroundBottom)
                ],
                startPoint: .top, endPoint: .bottom
            )
            Circle().fill(accent.opacity(0.14)).frame(width: 180, height: 180)
                .blur(radius: 80).offset(x: -70, y: -190)

            VStack(spacing: 0) {
                content
                    .padding(.horizontal, 13)
                    .padding(.top, 38)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                MockTabBar(active: kind.tabIndex, accent: accent)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .home:     HomeMock()
        case .week:     WeekMock()
        case .focus:    FocusMock()
        case .crew:     CrewMock()
        case .insights: InsightsMock()
        }
    }
}

// MARK: - Shared primitives

private let cCyan = Color(arenaHex: AppArenaPalette.cyan)
private let cBlue = Color(arenaHex: AppArenaPalette.blue)
private let cPurple = Color(arenaHex: AppArenaPalette.purple)
private let cPurpleSoft = Color(arenaHex: AppArenaPalette.purpleSoft)
private let cCoral = Color(arenaHex: AppArenaPalette.coral)
private let cGold = Color(arenaHex: AppArenaPalette.gold)
private let cGreen = Color(arenaHex: AppArenaPalette.green)

private struct MockHeader: View {
    let eyebrow: String
    let title: String
    let accent: String
    var accentColor: Color = cCyan
    var leadingDot: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                if let leadingDot {
                    Circle().fill(leadingDot).frame(width: 5, height: 5)
                } else {
                    Rectangle().fill(accentColor).frame(width: 12, height: 1)
                }
                Text(eyebrow)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1.6).foregroundStyle(accentColor.opacity(0.9))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(title).font(.system(size: 17, weight: .black)).foregroundStyle(.white)
                Text(accent).font(.system(size: 16, weight: .regular, design: .serif)).italic()
                    .foregroundStyle(accentColor)
            }
            .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func mockCard(_ tint: Color, radius: CGFloat = 16) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.11), Color.white.opacity(0.035)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(tint.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

private struct MockIconChip: View {
    let icon: String
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 11, weight: .black)).foregroundStyle(.white.opacity(0.75))
            .frame(width: 26, height: 26)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.07)))
    }
}

private struct MockTabBar: View {
    let active: Int
    let accent: Color
    private let icons = ["house.fill", "calendar", "person.3.fill", "timer", "chart.bar.fill"]
    private let labelKeys = ["tab_home", "tab_week", "tab_crew", "tab_focus", "tab_insights"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<icons.count, id: \.self) { i in
                if i == active {
                    HStack(spacing: 6) {
                        Image(systemName: icons[i]).font(.system(size: 13, weight: .black))
                        Text(tr(labelKeys[i])).font(.system(size: 11, weight: .black))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(accent)
                    .padding(.horizontal, 11).padding(.vertical, 8)
                    .background(
                        Capsule().fill(accent.opacity(0.16))
                            .overlay(Capsule().stroke(accent.opacity(0.3), lineWidth: 1))
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    Image(systemName: icons[i])
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 9)
        .background(
            Capsule().fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Color.black.opacity(0.35)))
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
}

// MARK: - 1 · Home

private struct HomeMock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top bar
            HStack {
                Circle().fill(LinearGradient(colors: [cCyan, cBlue], startPoint: .top, endPoint: .bottom))
                    .frame(width: 26, height: 26)
                    .overlay(Text("A").font(.system(size: 12, weight: .black)).foregroundStyle(.white))
                Spacer()
                MockIconChip(icon: "checklist")
                MockIconChip(icon: "bubble.left.and.bubble.right.fill")
            }

            // Hero
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Circle().fill(cGreen).frame(width: 5, height: 5)
                    Text(tr("ob_mk_now_live")).font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(1.4).foregroundStyle(cGold)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Operating Systems").font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                    Text("aktif").font(.system(size: 14, weight: .regular, design: .serif)).italic()
                        .foregroundStyle(cBlue.opacity(0.7))
                }
                .lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 5) {
                    Image(systemName: "clock").font(.system(size: 8, weight: .bold))
                    Text("01:00 — 03:00 · \(tr("ob_mk_remaining"))")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.5))
            }

            // UPDO AI card
            HStack(spacing: 9) {
                Image(systemName: "sparkles").font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [cPurple, cBlue], startPoint: .topLeading, endPoint: .bottomTrailing)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("UPDO AI").font(.system(size: 9, weight: .black, design: .monospaced)).tracking(1)
                        .foregroundStyle(.white)
                    Text(tr("ob_mk_ai_hint")).font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5)).lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .black)).foregroundStyle(.white.opacity(0.4))
            }
            .padding(11)
            .frame(maxWidth: .infinity)
            .mockCard(cPurple)

            // Today's flow + timeline
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1).fill(cCyan).frame(width: 2, height: 11)
                Text(tr("ob_mk_today_flow")).font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1)
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(tr("ob_mk_detail")).font(.system(size: 7, weight: .black, design: .monospaced)).tracking(0.8)
                    .foregroundStyle(cCyan)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(cCyan.opacity(0.12)))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("2").font(.system(size: 18, weight: .black)).foregroundStyle(.white)
                    Text(tr("ob_mk_events")).font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text("01–10").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
                }
                timelineGraph
            }
            .padding(11)
            .frame(maxWidth: .infinity)
            .mockCard(cCyan)

            // Metrics
            HStack(spacing: 8) {
                metric(label: "FOCUS", value: "2", sub: "sa", icon: "timer", tint: cCyan)
                metric(label: tr("ob_mk_tasks_done"), value: "3", sub: tr("ob_mk_task_sub"), icon: "checklist", tint: cPurple)
                metric(label: "SERİ", value: "7", sub: tr("ob_mk_streak_sub"), icon: "flame.fill", tint: cGold)
            }

            Spacer(minLength: 0)
        }
    }

    private var timelineGraph: some View {
        ZStack {
            // dashed baseline curve
            Path { p in
                p.move(to: CGPoint(x: 0, y: 26))
                p.addCurve(to: CGPoint(x: 190, y: 24),
                           control1: CGPoint(x: 60, y: 4), control2: CGPoint(x: 120, y: 40))
            }
            .stroke(style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
            .foregroundStyle(cCyan.opacity(0.35))

            HStack {
                Circle().fill(cCyan).frame(width: 9, height: 9)
                    .overlay(Circle().stroke(cCyan.opacity(0.4), lineWidth: 4)).offset(y: -2)
                Spacer()
                Circle().fill(cPurple).frame(width: 8, height: 8).offset(x: -60, y: 6)
                Spacer()
            }
        }
        .frame(height: 40)
        .overlay(alignment: .bottom) {
            HStack {
                ForEach(["06", "09", "12", "15", "18", "21", "00"], id: \.self) { t in
                    Text(t).font(.system(size: 6.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3)).frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func metric(label: String, value: String, sub: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label).font(.system(size: 7, weight: .black, design: .monospaced)).tracking(0.6).foregroundStyle(tint)
                Spacer()
                Image(systemName: icon).font(.system(size: 9, weight: .black)).foregroundStyle(tint)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 17, weight: .black)).foregroundStyle(.white)
                Text(sub).font(.system(size: 7, weight: .bold)).foregroundStyle(.white.opacity(0.45))
            }
            .lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(9).frame(maxWidth: .infinity, alignment: .leading).frame(height: 52)
        .mockCard(tint, radius: 13)
    }
}

// MARK: - 2 · Week

private struct WeekMock: View {
    private let days = ["PZT", "SAL", "ÇAR", "PER", "CUM", "CMT", "PAZ"]
    private let nums = ["15", "16", "17", "18", "19", "20", "21"]

    var body: some View {
        VStack(spacing: 10) {
            // Top bar
            HStack {
                MockIconChip(icon: "calendar")
                Spacer()
                VStack(spacing: 1) {
                    Text("WEEK").font(.system(size: 7, weight: .black, design: .monospaced)).tracking(1.5).foregroundStyle(cCyan)
                    Text("Haziran 2026").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "plus").accessibilityLabel(tr("common_add")).font(.system(size: 12, weight: .black)).foregroundStyle(.black)
                    .frame(width: 26, height: 26).background(Circle().fill(cCyan))
            }

            // Day selector
            HStack(spacing: 4) {
                ForEach(0..<days.count, id: \.self) { i in
                    VStack(spacing: 2) {
                        Text(days[i]).font(.system(size: 6.5, weight: .black, design: .monospaced))
                            .foregroundStyle(i == 3 ? .black : .white.opacity(0.4))
                        Text(nums[i]).font(.system(size: 11, weight: .black))
                            .foregroundStyle(i == 3 ? .black : .white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(i == 3 ? cCyan : Color.white.opacity(0.04)))
                }
            }

            // Day hero (coral)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    HStack(spacing: 4) {
                        Circle().fill(cCoral).frame(width: 5, height: 5)
                        Text(tr("ob_mk_now_live")).font(.system(size: 7, weight: .black, design: .monospaced)).tracking(1).foregroundStyle(cCoral)
                    }
                    Spacer()
                    Text("PER · 18 HAZ").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
                }
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(localizedWeekdayFull(3)).font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                    Text("18 Haziran").font(.system(size: 14, weight: .regular, design: .serif)).italic().foregroundStyle(cCoral)
                }
                .lineLimit(1).minimumScaleFactor(0.7)
                // progress line
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 4)
                    Capsule().fill(cBlue).frame(width: 36, height: 4).offset(x: 30)
                }
                HStack {
                    Text(tr("ob_mk_day_summary")).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text(tr("ob_mk_remaining_caps")).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(cCoral)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .mockCard(cCoral)

            // Events
            eventRow(time: "01:00", dur: "120dk", name: "Operating Systems", note: "· \(tr("ob_mk_remaining"))",
                     tint: cCoral, trailing: .liveDot, dashed: false)
            eventRow(time: "03:00", dur: "360dk", name: tr("ob_mk_free_time") + " · 6 sa", note: nil,
                     tint: .white, trailing: .add, dashed: true)
            eventRow(time: "09:00", dur: "60dk", name: "Data Structures", note: nil,
                     tint: cBlue, trailing: .repeatT, dashed: false)

            Spacer(minLength: 0)
        }
    }

    private enum Trailing { case liveDot, add, repeatT }

    private func eventRow(time: String, dur: String, name: String, note: String?, tint: Color, trailing: Trailing, dashed: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(time).font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(dashed ? .white.opacity(0.5) : tint)
                Text(dur).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.35))
            }
            .frame(width: 40, alignment: .leading)

            if !dashed {
                RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 3, height: 26)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 11, weight: .bold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                if let note {
                    Text(note).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(tint)
                }
            }
            Spacer()

            switch trailing {
            case .liveDot:
                Circle().fill(cCoral).frame(width: 7, height: 7)
            case .add:
                Text("+ EKLE").font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(cCyan)
                    .padding(.horizontal, 7).padding(.vertical, 4).background(Capsule().fill(cCyan.opacity(0.12)))
            case .repeatT:
                HStack(spacing: 3) {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 7, weight: .black))
                    Text("TEKRAR").font(.system(size: 7, weight: .black, design: .monospaced))
                }
                .foregroundStyle(cBlue).padding(.horizontal, 7).padding(.vertical, 4).background(Capsule().fill(cBlue.opacity(0.12)))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(dashed ? Color.clear : tint.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: dashed ? [4, 3] : []))
                        .foregroundStyle(dashed ? Color.white.opacity(0.15) : tint.opacity(0.18))
                )
        )
    }
}

// MARK: - 3 · Focus

private struct FocusMock: View {
    private let ringGrad = LinearGradient(colors: [cCyan, cPurple], startPoint: .topTrailing, endPoint: .bottomLeading)

    var body: some View {
        VStack(spacing: 10) {
            // Header with two trailing icon buttons (real screen)
            HStack(alignment: .top) {
                MockHeader(eyebrow: "PERSONAL RHYTHM", title: "Focus", accent: "zone", accentColor: cCyan)
                MockIconChip(icon: "timer")
                MockIconChip(icon: "ellipsis")
            }

            // Segmented
            HStack(spacing: 6) {
                segment("Personal", icon: "person.fill", active: true)
                segment("Crew", icon: "person.3.fill", active: false)
                segment("Friend", icon: "person.2.fill", active: false)
            }

            // Focus card
            VStack(spacing: 11) {
                HStack {
                    HStack(spacing: 4) {
                        Rectangle().fill(cCyan).frame(width: 10, height: 1)
                        Text("PERSONAL RHYTHM").font(.system(size: 7, weight: .black, design: .monospaced)).tracking(1).foregroundStyle(cCyan)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(cCyan).frame(width: 5, height: 5)
                        Text(tr("ob_mk_ready").uppercased()).font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(cCyan)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 4).background(Capsule().fill(cCyan.opacity(0.12)))
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(tr("ob_mk_personal")).font(.system(size: 15, weight: .black)).foregroundStyle(.white)
                    Text("Focus").font(.system(size: 14, weight: .regular, design: .serif)).italic().foregroundStyle(cCyan)
                    Spacer()
                }

                ZStack {
                    Circle().stroke(Color.white.opacity(0.06), lineWidth: 12)
                    Circle().trim(from: 0, to: 0.7)
                        .stroke(ringGrad, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: cPurple.opacity(0.45), radius: 9)
                    VStack(spacing: 2) {
                        Text("25 dk").font(.system(size: 32, weight: .black)).foregroundStyle(.white)
                        Text(tr("ob_mk_ready")).font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.75))
                    }
                }
                .frame(width: 124, height: 124)

                // Status pill under the ring
                HStack(spacing: 6) {
                    Circle().fill(cCyan).frame(width: 5, height: 5)
                    Text(tr("ob_mk_ready")).font(.system(size: 9, weight: .black)).foregroundStyle(cCyan)
                    Text("· Study • Silent").font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.05)))
            }
            .padding(13)
            .frame(maxWidth: .infinity)
            .mockCard(cCyan)

            // Duration pills
            HStack(spacing: 6) {
                durPill("15 dk", active: false)
                durPill("25 dk", active: true)
                durPill("45 dk", active: false)
                durPill(tr("ob_mk_custom"), active: false)
            }

            // Goal + Sound cards
            HStack(spacing: 8) {
                settingCard(label: tr("ob_mk_goal"), value: "Study", icon: "book.fill")
                settingCard(label: tr("ob_mk_sound"), value: "Silent", icon: "speaker.slash.fill")
            }

            Spacer(minLength: 0)
        }
    }

    private func segment(_ title: String, icon: String, active: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 9, weight: .black))
            Text(title).font(.system(size: 10, weight: .black)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundStyle(active ? .white : .white.opacity(0.45))
        .frame(maxWidth: .infinity).frame(height: 34)
        .background(
            Capsule().fill(active
                ? AnyShapeStyle(LinearGradient(colors: [cCyan, cPurple], startPoint: .leading, endPoint: .trailing))
                : AnyShapeStyle(Color.white.opacity(0.04)))
        )
    }

    private func durPill(_ t: String, active: Bool) -> some View {
        Text(t).font(.system(size: 10, weight: .black))
            .foregroundStyle(active ? .white : .white.opacity(0.5))
            .frame(maxWidth: .infinity).frame(height: 32)
            .background(Capsule().fill(active
                ? AnyShapeStyle(LinearGradient(colors: [cCyan, cPurple], startPoint: .leading, endPoint: .trailing))
                : AnyShapeStyle(Color.white.opacity(0.04))))
    }

    private func settingCard(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 11, weight: .black)).foregroundStyle(cCyan)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(cCyan.opacity(0.13)))
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 7, weight: .black, design: .monospaced)).tracking(0.6)
                    .foregroundStyle(.white.opacity(0.4)).lineLimit(1).minimumScaleFactor(0.7)
                Text(value).font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).frame(maxWidth: .infinity).frame(height: 48)
        .mockCard(cCyan, radius: 14)
    }
}

// MARK: - 4 · Crew

private struct CrewMock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            // Header
            HStack {
                MockHeader(eyebrow: tr("crew_active_zone_live", 0), title: tr("crew_title_first"), accent: tr("crew_title_accent"), accentColor: cBlue)
                MockIconChip(icon: "person.badge.plus")
                Image(systemName: "plus").accessibilityLabel(tr("common_add")).font(.system(size: 12, weight: .black)).foregroundStyle(.black)
                    .frame(width: 26, height: 26).background(Circle().fill(cBlue))
            }

            // Workspace card
            HStack(spacing: 10) {
                Image(systemName: "person.3.fill").font(.system(size: 14, weight: .black)).foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(LinearGradient(colors: [cBlue, cPurple], startPoint: .topLeading, endPoint: .bottomTrailing)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("ob_mk_workspace")).font(.system(size: 7, weight: .black, design: .monospaced)).tracking(1).foregroundStyle(cCyan)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("2").font(.system(size: 15, weight: .black)).foregroundStyle(cCyan)
                        Text("crew").font(.system(size: 11, weight: .regular, design: .serif)).italic().foregroundStyle(.white.opacity(0.8))
                        Text("· 5").font(.system(size: 15, weight: .black)).foregroundStyle(.white)
                        Text(tr("ob_mk_friend")).font(.system(size: 11, weight: .regular, design: .serif)).italic().foregroundStyle(.white.opacity(0.8))
                    }
                    .lineLimit(1).minimumScaleFactor(0.7)
                    HStack(spacing: 4) {
                        Circle().fill(cGreen).frame(width: 4, height: 4)
                        Text(tr("ob_mk_in_focus")).font(.system(size: 8, weight: .bold)).foregroundStyle(cGreen)
                    }
                }
                Spacer()
                VStack(spacing: 0) {
                    Text("3").font(.system(size: 17, weight: .black)).foregroundStyle(.white)
                    Text("LIVE").font(.system(size: 6.5, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .mockCard(cBlue)

            // Tabs
            HStack(spacing: 8) {
                crewTab(tr("ob_mk_crews"), count: "2", active: true)
                crewTab(tr("ob_mk_friends"), count: "5", active: false)
            }

            // Crew card
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 10) {
                    Text("A").font(.system(size: 17, weight: .black, design: .serif)).foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(LinearGradient(colors: [cCoral, cPurple], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("App").font(.system(size: 14, weight: .black)).foregroundStyle(.white)
                        HStack(spacing: 5) {
                            Text("CMSE #6").font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(cCyan)
                                .padding(.horizontal, 5).padding(.vertical, 2).background(Capsule().fill(cCyan.opacity(0.14)))
                            Text("1 \(tr("ob_mk_members"))").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("3h").font(.system(size: 15, weight: .black)).foregroundStyle(.white)
                        HStack(spacing: 3) {
                            Circle().fill(cGreen).frame(width: 4, height: 4)
                            Text("ACTIVE").font(.system(size: 6.5, weight: .black, design: .monospaced)).foregroundStyle(cGreen)
                        }
                    }
                }
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill").font(.system(size: 8)).foregroundStyle(cGold)
                    Text("7 \(tr("ob_mk_streak_sub")) · \(tr("ob_mk_task_sub"))").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                }
                Capsule().fill(Color.white.opacity(0.08)).frame(height: 5)
                    .overlay(alignment: .leading) {
                        Capsule().fill(LinearGradient(colors: [cCyan, cCoral], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 96, height: 5)
                    }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .mockCard(cPurple)

            Spacer(minLength: 0)
        }
    }

    private func crewTab(_ title: String, count: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.system(size: 11, weight: .black)).foregroundStyle(active ? .white : .white.opacity(0.4))
            Text(count).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(active ? .black : .white.opacity(0.6))
                .frame(width: 16, height: 16).background(Circle().fill(active ? cCyan : Color.white.opacity(0.1)))
        }
        .frame(maxWidth: .infinity).frame(height: 36)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(active ? cBlue.opacity(0.14) : Color.white.opacity(0.03))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(active ? cBlue.opacity(0.3) : .clear, lineWidth: 1)))
    }
}

// MARK: - 5 · Insights

private struct InsightsMock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            MockHeader(eyebrow: "PERFORMANCE CENTER", title: "Insights", accent: "arena", accentColor: cCyan)

            // Identity / driver card
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 4) {
                            Rectangle().fill(cCoral).frame(width: 10, height: 1)
                            Text("DRIVER · LV 3").font(.system(size: 7, weight: .black, design: .monospaced)).tracking(0.8).foregroundStyle(cCoral)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("Ada").font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                            Text("Yıldız").font(.system(size: 14, weight: .regular, design: .serif)).italic().foregroundStyle(cCoral)
                        }
                        Text(tr("ob_mk_progress_active")).font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                    VStack(spacing: 1) {
                        Text("TIER").font(.system(size: 6, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
                        Text("M").font(.system(size: 18, weight: .black)).foregroundStyle(.white)
                    }
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(LinearGradient(colors: [cCyan, cPurpleSoft], startPoint: .topLeading, endPoint: .bottomTrailing)))
                }

                HStack(spacing: 0) {
                    statCol(value: "24", label: "FOCUS", sub: tr("ob_mk_focus_sessions"), tint: cCyan)
                    statCol(value: "7", label: "STREAK", sub: tr("ob_mk_days"), tint: cGold)
                    statCol(value: "18", label: tr("ob_mk_done"), sub: tr("ob_mk_tasks_done"), tint: cGreen)
                    statCol(value: "3", label: "LEVEL", sub: tr("ob_mk_level_unit"), tint: cPurpleSoft)
                }
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.white.opacity(0.03)))

                HStack(spacing: 6) {
                    Text("LV 3").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(cCoral)
                    Image(systemName: "arrow.right").font(.system(size: 7, weight: .black)).foregroundStyle(.white.opacity(0.4))
                    Text("LV 4").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.white)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08)).frame(height: 4)
                        Capsule().fill(cCoral).frame(width: 52, height: 4)
                    }
                    Text("64%").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .mockCard(cCoral)

            // Journey card
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 4) {
                    Rectangle().fill(cGreen).frame(width: 10, height: 1)
                    Text("JOURNEY · SON 4 HAFTA").font(.system(size: 7, weight: .black, design: .monospaced)).tracking(0.8).foregroundStyle(cGreen)
                    Spacer()
                    Text("+38%").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(cGreen)
                }
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array([0.45, 0.6, 0.5, 1.0].enumerated()), id: \.offset) { i, h in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(i == 3
                                      ? AnyShapeStyle(LinearGradient(colors: [cGreen, cCyan], startPoint: .top, endPoint: .bottom))
                                      : AnyShapeStyle(Color.white.opacity(0.14)))
                                .frame(maxWidth: .infinity).frame(height: 40 * h)
                            Text(["H-3", "H-2", "H-1", "BU"][i]).font(.system(size: 6.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(i == 3 ? cCyan : .white.opacity(0.3))
                        }
                    }
                }
                .frame(height: 56, alignment: .bottom)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .mockCard(cGreen)

            Spacer(minLength: 0)
        }
    }

    private func statCol(value: String, label: String, sub: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 6.5, weight: .black, design: .monospaced)).tracking(0.4).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.6)
            Text(value).font(.system(size: 17, weight: .black)).foregroundStyle(.white)
            Text(sub).font(.system(size: 6, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.4)).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }
}
