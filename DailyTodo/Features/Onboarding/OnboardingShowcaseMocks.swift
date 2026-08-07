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
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.6).foregroundStyle(accentColor.opacity(0.9))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(title).font(.system(size: 22, weight: .black)).foregroundStyle(.white)
                Text(accent).font(.system(size: 20, weight: .regular, design: .serif)).italic()
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
    private let icons = ["house.fill", "calendar", "person.3.fill", "timer", "person.fill"]
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
            // Top bar — streak flame + messages
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").font(.system(size: 10, weight: .black)).foregroundStyle(cGold)
                    Text("7").font(.system(size: 11, weight: .black, design: .rounded)).foregroundStyle(.white)
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Capsule().fill(cGold.opacity(0.13)).overlay(Capsule().stroke(cGold.opacity(0.28), lineWidth: 1)))
                Spacer()
                MockIconChip(icon: "bubble.left.and.bubble.right.fill")
            }

            // AI-first hero — orb + greeting + command bar + intent chips
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [cCyan.opacity(0.28), cPurple.opacity(0.10), .clear],
                                             center: .center, startRadius: 4, endRadius: 46))
                        .frame(width: 92, height: 92)
                    UpdoAIOrb(size: 54)
                }
                .frame(height: 74)

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(appLanguageIsEnglish() ? "What's" : "Bugün ne")
                        .font(.system(size: 19, weight: .black)).foregroundStyle(.white)
                    Text(appLanguageIsEnglish() ? "the plan?" : "planlayalım?")
                        .font(.system(size: 17, weight: .regular, design: .serif)).italic()
                        .foregroundStyle(LinearGradient(colors: [cCyan, cBlue, cPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .lineLimit(1).minimumScaleFactor(0.6)

                Text(appLanguageIsEnglish() ? "3 tasks today · 7-day streak" : "Bugün 3 görev · 7 günlük seri")
                    .font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.white.opacity(0.5))

                // Command bar
                HStack(spacing: 7) {
                    Text(appLanguageIsEnglish() ? "Ask Updo AI…" : "Updo AI'ya sor…")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.42))
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill").font(.system(size: 6, weight: .black))
                        Text("1000").font(.system(size: 7.5, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(cCyan.opacity(0.75))
                    Image(systemName: "arrow.up").font(.system(size: 9, weight: .bold)).foregroundStyle(.black)
                        .frame(width: 21, height: 21).background(Circle().fill(cCyan))
                }
                .padding(.leading, 12).padding(.trailing, 5).padding(.vertical, 5)
                .background(
                    Capsule().fill(Color.white.opacity(0.06))
                        .overlay(Capsule().stroke(LinearGradient(colors: [cCyan.opacity(0.35), cPurple.opacity(0.30)], startPoint: .leading, endPoint: .trailing), lineWidth: 1))
                )

                // Intent chips
                HStack(spacing: 6) {
                    miniChip("sparkles", tr("hv_chip_plan"))
                    miniChip("plus", tr("hv_chip_add"))
                    miniChip("flame", tr("hv_chip_motivation"))
                    miniChip("book.closed", tr("hv_chip_exam"))
                }
                .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)

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

    private func miniChip(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 7, weight: .black))
            Text(title).font(.system(size: 8, weight: .bold))
        }
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(
            Capsule().fill(Color.white.opacity(0.06))
                .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
        )
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

            // Day hero (coral) — active class + signature mini timeline
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    HStack(spacing: 4) {
                        Circle().fill(cCoral).frame(width: 5, height: 5)
                        Text(tr("ob_mk_now_live")).font(.system(size: 7, weight: .black, design: .monospaced)).tracking(1).foregroundStyle(cCoral)
                    }
                    Spacer()
                    Text("PER · 18 HAZ").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
                }
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("Operating Systems").font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                    Text(appLanguageIsEnglish() ? "live" : "aktif")
                        .font(.system(size: 14, weight: .regular, design: .serif)).italic()
                        .foregroundStyle(LinearGradient(colors: [cCoral, cBlue], startPoint: .leading, endPoint: .trailing))
                }
                .lineLimit(1).minimumScaleFactor(0.7)

                miniTimeline
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

    // Signature 06–24 mini timeline: hour labels + capsule bar with coloured
    // event blocks + a "now" indicator + summary — mirrors the real Week hero.
    private var miniTimeline: some View {
        VStack(spacing: 6) {
            HStack {
                ForEach([6, 9, 12, 15, 18, 21, 24], id: \.self) { h in
                    Text(String(format: "%02d", h))
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .foregroundStyle(h == 3 ? cCoral : .white.opacity(0.32))
                        .frame(maxWidth: .infinity)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))

                    Capsule().fill(cCoral).frame(width: geo.size.width * 0.16, height: 7).offset(x: geo.size.width * 0.05)
                    Capsule().fill(cBlue).frame(width: geo.size.width * 0.11, height: 7).offset(x: geo.size.width * 0.34)
                    Capsule().fill(cPurple).frame(width: geo.size.width * 0.13, height: 7).offset(x: geo.size.width * 0.60)

                    Capsule().fill(.white)
                        .frame(width: 2, height: 13)
                        .shadow(color: .white.opacity(0.6), radius: 3)
                        .offset(x: geo.size.width * 0.16 - 1)
                }
                .frame(height: 7)
            }
            .frame(height: 7)

            HStack {
                Text(tr("ob_mk_day_summary"))
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text(appLanguageIsEnglish() ? "70 MIN LEFT" : "70 DK KALDI")
                    .font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(cCoral)
            }
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
    var body: some View {
        VStack(spacing: 10) {
            // Header with two trailing icon buttons (real screen)
            HStack(alignment: .top) {
                MockHeader(eyebrow: "PERSONAL RHYTHM", title: "Focus", accent: "zone", accentColor: cCyan)
                MockIconChip(icon: "timer")
                MockIconChip(icon: "ellipsis")
            }

            // Mode segmented — underline style (Personal / Crew / Friend)
            HStack(spacing: 0) {
                fSegment("Personal", icon: "person.fill", active: true)
                fSegment("Crew", icon: "person.3.fill", active: false)
                fSegment("Friend", icon: "person.2.fill", active: false)
            }
            .padding(.top, 2)

            // Editorial big-number hero — the duration IS the page (no ring)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(cCyan).frame(width: 5, height: 5).shadow(color: cCyan.opacity(0.6), radius: 4)
                    Text(tr("ob_mk_ready").uppercased())
                        .font(.system(size: 8, weight: .black, design: .monospaced)).tracking(1.6)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Text("25")
                    .font(.system(size: 62, weight: .bold, design: .serif)).italic()
                    .foregroundStyle(LinearGradient(colors: [.white, Color(arenaHex: "#7C8AA8")], startPoint: .top, endPoint: .bottom))
                    .kerning(-1.2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(alignment: .leading) {
                        Ellipse().fill(cCyan.opacity(0.10)).frame(width: 170, height: 110).blur(radius: 55).offset(x: -20, y: 6)
                    }
                    .shadow(color: .black.opacity(0.5), radius: 10, y: 6)

                HStack(spacing: 8) {
                    Rectangle().fill(cCyan).frame(width: 26, height: 2)
                    Text(appLanguageIsEnglish() ? "MINUTES" : "DAKİKA")
                        .font(.system(size: 8, weight: .black, design: .monospaced)).tracking(2)
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer(minLength: 6)
                    Text(appLanguageIsEnglish() ? "ends 12:47" : "bitiş 12:47")
                        .font(.system(size: 8, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)

            // Duration pills — outline style
            HStack(spacing: 7) {
                durPill("15 dk", active: false)
                durPill("25 dk", active: true)
                durPill("45 dk", active: false)
                durPill(appLanguageIsEnglish() ? "Custom" : "Özel", active: false)
            }
            .padding(.top, 2)

            // Goal + Sound — stacked full-width rows
            VStack(spacing: 0) {
                settingRow(label: appLanguageIsEnglish() ? "GOAL" : "HEDEF",
                           value: appLanguageIsEnglish() ? "Study" : "Ders",
                           sub: appLanguageIsEnglish() ? "Class and review" : "Ders ve tekrar",
                           icon: "book.fill")
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                settingRow(label: appLanguageIsEnglish() ? "SOUND" : "SES",
                           value: appLanguageIsEnglish() ? "Silent" : "Sessiz",
                           sub: appLanguageIsEnglish() ? "Silent mode" : "Sessiz mod",
                           icon: "speaker.slash.fill")
            }

            Spacer(minLength: 4)

            // Start button
            HStack(spacing: 8) {
                Image(systemName: "play.fill").font(.system(size: 11, weight: .black))
                Text(appLanguageIsEnglish() ? "Start Personal Focus" : "Kişisel Odağı Başlat")
                    .font(.system(size: 13, weight: .black)).lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                Image(systemName: "arrow.right").font(.system(size: 11, weight: .black))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 16).frame(height: 44)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(LinearGradient(colors: [cCyan, cPurple], startPoint: .leading, endPoint: .trailing)))
            .shadow(color: cCyan.opacity(0.4), radius: 12, y: 4)

            Spacer(minLength: 0)
        }
    }

    private func fSegment(_ title: String, icon: String, active: Bool) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 9, weight: .black))
                Text(title).font(.system(size: 11, weight: .black)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(active ? .white : .white.opacity(0.38))
            ZStack {
                Capsule().fill(Color.white.opacity(0.05)).frame(height: 2.5)
                if active {
                    Capsule().fill(LinearGradient(colors: [cCyan, cPurple], startPoint: .leading, endPoint: .trailing)).frame(height: 2.5)
                        .shadow(color: cCyan.opacity(0.5), radius: 4, y: 1)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func durPill(_ t: String, active: Bool) -> some View {
        Text(t).font(.system(size: 10, weight: .black))
            .foregroundStyle(active ? cCyan : .white.opacity(0.5))
            .frame(maxWidth: .infinity).frame(height: 32)
            .background(
                Capsule().fill(active ? cCyan.opacity(0.10) : Color.white.opacity(0.02))
                    .overlay(Capsule().stroke(active ? cCyan.opacity(0.55) : Color.white.opacity(0.10), lineWidth: 1))
            )
    }

    private func settingRow(label: String, value: String, sub: String, icon: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon).font(.system(size: 13, weight: .black)).foregroundStyle(cCyan)
                .frame(width: 24)
            Text(label).font(.system(size: 8, weight: .black, design: .monospaced)).tracking(1)
                .foregroundStyle(.white.opacity(0.4)).frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 13, weight: .black)).foregroundStyle(.white)
                Text(sub).font(.system(size: 8, weight: .semibold)).foregroundStyle(.white.opacity(0.42))
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 9, weight: .black)).foregroundStyle(.white.opacity(0.35))
        }
        .frame(height: 44)
    }
}

// MARK: - 4 · Crew

private struct CrewMock: View {
    private var isEN: Bool { appLanguageIsEnglish() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Masthead — eyebrow + "Sosyal Alan" + actions
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Rectangle().fill(cBlue).frame(width: 14, height: 1)
                        Text(tr("crew_active_zone_live", 0))
                            .font(.system(size: 7, weight: .black, design: .monospaced)).tracking(1.5).foregroundStyle(cCyan)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(tr("crew_title_first")).font(.system(size: 21, weight: .black)).foregroundStyle(.white)
                        Text(tr("crew_title_accent")).font(.system(size: 18, weight: .regular, design: .serif)).italic()
                            .foregroundStyle(LinearGradient(colors: [cCyan, cBlue], startPoint: .leading, endPoint: .trailing))
                    }
                    .lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer()
                MockIconChip(icon: "person.badge.plus")
                MockIconChip(icon: "tray")
                Image(systemName: "plus").accessibilityLabel(tr("common_add")).font(.system(size: 12, weight: .black)).foregroundStyle(.black)
                    .frame(width: 26, height: 26).background(Circle().fill(cBlue))
            }

            // Pro: "Share my stats" privacy toggle (real Pro state)
            HStack(spacing: 9) {
                Image(systemName: "eye.fill").font(.system(size: 11, weight: .black)).foregroundStyle(cGreen)
                VStack(alignment: .leading, spacing: 1) {
                    Text(isEN ? "Share my stats" : "İstatistiklerimi paylaş")
                        .font(.system(size: 10, weight: .black)).foregroundStyle(.white).lineLimit(1)
                    Text(isEN ? "Friends can see your streak, level and focus" : "Arkadaşların serini, seviyeni ve odağını görebilir")
                        .font(.system(size: 7.5, weight: .semibold)).foregroundStyle(.white.opacity(0.5)).lineLimit(1).minimumScaleFactor(0.75)
                }
                Spacer()
                Capsule().fill(cGreen).frame(width: 32, height: 19)
                    .overlay(alignment: .trailing) { Circle().fill(.white).frame(width: 15, height: 15).padding(2) }
            }
            .padding(.horizontal, 11).padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.035))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 1))
            )

            // Underline tab switcher (Crews / Friends) — Focus-style
            HStack(spacing: 0) {
                crewTab("Crews", icon: "person.3.fill", active: true)
                crewTab("Friends", icon: "person.2.fill", active: false)
            }

            crewCard

            Spacer(minLength: 0)
        }
    }

    // Faithful mini of CrewSocialCrewCard
    private var crewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(LinearGradient(colors: [cCoral.opacity(0.95), cPurple.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    Text("A").font(.system(size: 15, weight: .regular, design: .serif)).italic().foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("App").font(.system(size: 13, weight: .black)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                    Text(isEN ? "4 MEMBERS" : "4 ÜYE").font(.system(size: 7, weight: .bold, design: .monospaced)).tracking(0.5).foregroundStyle(.white.opacity(0.42))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("7h 16m").font(.system(size: 14, weight: .black)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                    HStack(spacing: 4) {
                        Circle().fill(cGreen).frame(width: 5, height: 5)
                        Text(isEN ? "ACTIVE" : "AKTİF").font(.system(size: 6.5, weight: .black, design: .monospaced)).tracking(0.6).foregroundStyle(cGreen)
                    }
                }
            }

            // Today progress (full)
            HStack(spacing: 6) {
                Text(tr("wv_today_caps")).font(.system(size: 7.5, weight: .black, design: .monospaced)).tracking(1).foregroundStyle(.white.opacity(0.34))
                Text("·").foregroundStyle(.white.opacity(0.22))
                Text(isEN ? "4/4 DONE" : "4/4 TAMAM").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(cCyan)
            }
            Capsule().fill(LinearGradient(colors: [cCyan, cPurple, cCoral], startPoint: .leading, endPoint: .trailing)).frame(height: 5)

            // Weekly goal
            HStack {
                Text(isEN ? "WEEKLY GOAL" : "HAFTALIK HEDEF").font(.system(size: 7.5, weight: .black, design: .monospaced)).tracking(0.8).foregroundStyle(.white.opacity(0.34))
                Spacer()
                Text("0m / 10h").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.42))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08)).frame(height: 4)
                    Capsule().fill(cCoral).frame(width: geo.size.width * 0.05, height: 4)
                }
            }
            .frame(height: 4)

            // Member avatars + crew chat
            HStack(spacing: 8) {
                HStack(spacing: -6) {
                    ForEach(Array(["A", "M", "B", "C"].enumerated()), id: \.offset) { _, ltr in
                        Text(ltr).font(.system(size: 8, weight: .black)).foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(LinearGradient(colors: [cBlue, cPurple], startPoint: .top, endPoint: .bottom)))
                            .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 1.5))
                    }
                }
                Text(isEN ? "Crew chat ready" : "Crew sohbeti hazır").font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .black)).foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .mockCard(cPurple)
    }

    private func crewTab(_ title: String, icon: String, active: Bool) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10, weight: .black))
                Text(title).font(.system(size: 11, weight: .black, design: .monospaced)).tracking(0.2)
            }
            .foregroundStyle(active ? .white : .white.opacity(0.38))
            ZStack {
                Capsule().fill(Color.white.opacity(0.05)).frame(height: 2.5)
                if active {
                    Capsule().fill(LinearGradient(colors: [cBlue, cCyan], startPoint: .leading, endPoint: .trailing)).frame(height: 2.5)
                        .shadow(color: cBlue.opacity(0.5), radius: 4, y: 1)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
    }
}

// MARK: - 5 · Insights

private struct InsightsMock: View {
    private var isEN: Bool { appLanguageIsEnglish() }
    private let pink = Color(arenaHex: "#F472B6")

    var body: some View {
        VStack(spacing: 0) {
            // Header — YOUR PROGRESS / Profile + settings
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Rectangle().fill(cCyan).frame(width: 12, height: 1)
                        Text(isEN ? "YOUR PROGRESS" : "İLERLEMEN").font(.system(size: 8, weight: .black, design: .monospaced)).tracking(1.6).foregroundStyle(cCyan)
                    }
                    Text(isEN ? "Profile" : "Profil").font(.system(size: 20, weight: .black)).foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "gearshape.fill").font(.system(size: 12, weight: .black)).foregroundStyle(.white.opacity(0.7))
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.07)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 12)

            // Ring + monogram + LEVEL badge
            ZStack {
                Circle().fill(pink.opacity(0.16)).frame(width: 132, height: 132).blur(radius: 32)
                Circle().stroke(Color.white.opacity(0.07), lineWidth: 5).frame(width: 100, height: 100)
                ZStack {
                    Circle().trim(from: 0, to: 0.97)
                        .stroke(AngularGradient(colors: [pink, cBlue, cPurple, pink], center: .center),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .shadow(color: pink.opacity(0.4), radius: 8)
                    Circle().fill(.white).frame(width: 5, height: 5).shadow(color: pink.opacity(0.9), radius: 4)
                        .offset(x: 50).rotationEffect(.degrees(0.97 * 360))
                }
                .rotationEffect(.degrees(-90))
                .frame(width: 100, height: 100)

                ProfileAvatarCircle(image: nil, name: "Ada", accent: pink, size: 84)

                Text(isEN ? "LEVEL  9" : "SEVİYE  9")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Capsule().fill(LinearGradient(colors: [pink, cPurple], startPoint: .leading, endPoint: .trailing)))
                    .overlay(Capsule().stroke(Color.black.opacity(0.45), lineWidth: 2))
                    .offset(y: 54)
            }
            .frame(height: 118)

            Spacer(minLength: 12)

            VStack(spacing: 2) {
                Text("Ada Yılmaz").font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                Text(isEN ? "Habit Driver" : "Alışkanlık Sürücüsü")
                    .font(.system(size: 15, weight: .regular, design: .serif)).italic()
                    .foregroundStyle(LinearGradient(colors: [pink, cPurple], startPoint: .leading, endPoint: .trailing))
                Text(isEN ? "BOĞAZİÇİ UNIVERSITY · CMPE" : "BOĞAZİÇİ ÜNİVERSİTESİ · BİLGİSAYAR MÜH.")
                    .font(.system(size: 7, weight: .black, design: .monospaced)).tracking(1)
                    .foregroundStyle(.white.opacity(0.4)).padding(.top, 3).lineLimit(1).minimumScaleFactor(0.65)
                Text(isEN ? "ROAD TO LEVEL 10 · 97%" : "SEVİYE 10 YOLU · %97")
                    .font(.system(size: 7.5, weight: .black, design: .monospaced)).tracking(1)
                    .foregroundStyle(.white.opacity(0.5)).padding(.top, 6)
            }

            Spacer(minLength: 12)

            // Stats row
            HStack(spacing: 0) {
                statCell(isEN ? "FRIENDS" : "ARKADAŞ", "1")
                statDivider
                statCell(isEN ? "CREWS" : "CREW", "1")
                statDivider
                statCell(isEN ? "DAY STREAK" : "GÜN SERİ", "4", icon: "flame.fill", iconTint: cGold)
            }
            .frame(maxWidth: 240)

            Spacer(minLength: 12)

            // For the next level capsule
            HStack(spacing: 6) {
                Text(isEN ? "For the next level:" : "Sonraki seviye için:").font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                Text(isEN ? "2 tasks" : "2 görev").font(.system(size: 9, weight: .black)).foregroundStyle(pink)
                Image(systemName: "chevron.right").font(.system(size: 7, weight: .black)).foregroundStyle(pink)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(pink.opacity(0.08)).overlay(Capsule().stroke(pink.opacity(0.3), lineWidth: 1)))

            Spacer(minLength: 12)

            // Edit / Share
            HStack(spacing: 10) {
                actionBtn(isEN ? "Edit" : "Düzenle", icon: "pencil")
                actionBtn(isEN ? "Share" : "Paylaş", icon: "square.and.arrow.up")
            }

            Spacer(minLength: 10)

            VStack(spacing: 1) {
                Text(isEN ? "Your analytics" : "İstatistiklerin").font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.4))
                Image(systemName: "chevron.compact.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.35))
            }

            Spacer(minLength: 0)
        }
    }

    private func actionBtn(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 9, weight: .black))
            Text(title).font(.system(size: 11, weight: .black))
        }
        .foregroundStyle(.white.opacity(0.85))
        .frame(maxWidth: .infinity).frame(height: 34)
        .background(Capsule().fill(Color.white.opacity(0.05)).overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1)))
    }

    private var statDivider: some View {
        Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1, height: 22)
    }

    private func statCell(_ label: String, _ value: String, icon: String? = nil, iconTint: Color = .white) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 8, weight: .black)).foregroundStyle(iconTint)
                }
                Text(value).font(.system(size: 12, weight: .black)).foregroundStyle(.white)
            }
            Text(label).font(.system(size: 6, weight: .black, design: .monospaced)).tracking(0.8).foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}
