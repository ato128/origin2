//
//  OnboardingShowcaseView.swift
//  DailyTodo
//
//  The "sell the app" stage of onboarding. After the student is personalized,
//  this walks them through the five pillars of Updo inside the real gold
//  iPhone frame (Apple device art, pre-composited in the asset catalog),
//  centered on the page over a soft premium colour cloud.
//
//  The first two pages are the user's OWN app, not a sample: Updo AI greeting
//  them by name with their next class, and the week they just set up
//  (`ShowcaseLiveAIScreen` / `ShowcaseLiveWeekScreen`, drawn live from their
//  saved data). The rest — and everything on iPad, and the week page when no
//  classes were added — are real screenshots.
//
//  Screenshots are per-language (`ob_shot_<key>_<en|tr>`); TR falls back to EN
//  until Turkish captures ship. Copy uses the app's own typography (monospaced
//  eyebrow · black title · italic-serif accent word).
//  Ends by presenting the Paywall, then calls `onFinish` to enter the app.
//

import SwiftUI
import SwiftData
import UIKit

struct OnboardingShowcaseView: View {

    var onFinish: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var studentStore: StudentStore
    @Query private var allEvents: [EventItem]
    @State private var index = 0
    @State private var scrolledID: Int? = 0
    @State private var showWidgetPromo = false
    @State private var showInvite = false
    @State private var pendingWidget = false
    @State private var appeared = false

    private let pages = ShowcasePageModel.all
    /// iPad shows real iPad captures in an iPad frame; iPhone keeps the gold iPhone.
    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    private var page: ShowcasePageModel { pages[index] }
    private var isLast: Bool { index == pages.count - 1 }

    /// The user's own classes, next class, goal and name.
    private var personal: OnboardingPersonalSnapshot {
        OnboardingPersonalSnapshot.make(
            events: allEvents,
            userID: session.currentUser?.id.uuidString,
            fullName: session.currentUser?.fullName,
            dailyGoalMinutes: studentStore.profile?.dailyStudyGoalMinutes
        )
    }

    /// Which pages show the user's own screen instead of a screenshot.
    private func liveKind(_ model: ShowcasePageModel, _ data: OnboardingPersonalSnapshot) -> ShowcaseLiveKind? {
        guard !isPad else { return nil }
        switch model.shotKey {
        case "home": return .ai
        case "week": return data.hasWeek ? .week : nil
        default: return nil
        }
    }

    var body: some View {
        ZStack {
            ArenaBackground(
                primaryGlow: page.accent,
                secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
                warmGlow: page.accentSoft,
                intensity: 0.95
            )
            .animation(.easeInOut(duration: 0.5), value: index)

            VStack(spacing: 0) {
                topRow
                    .padding(.horizontal, 22)
                    .padding(.top, 8)

                // Real gold-framed screenshots, centered, paging inside a soft
                // premium colour cloud that shifts to each page's accent. The
                // cloud sits *behind* the phones so it never clips at the edges.
                ZStack {
                    ShowcaseColorCloud(accent: page.accent, soft: page.accentSoft)
                        .scaleEffect(isPad ? 1.9 : 1)
                        .animation(.easeInOut(duration: 0.55), value: index)

                    phonePager
                }
                .frame(maxHeight: .infinity)
                .padding(.top, 14)

                // Copy block — cross-fades per page.
                copyBlock
                    .padding(.horizontal, 26)
                    .id(index)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                primaryButton
                    .padding(.horizontal, 22)
                    .padding(.top, 22)
                    .padding(.bottom, 40)
            }
            .opacity(appeared ? 1 : 0)
        }
        .updoColorScheme()
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
        // Akış: showcase → DAVET → widget → uygulama. Önce davet ekranı; kapanınca
        // (cover-üstüne-cover yarışı olmadan, dismiss sonrası) widget tanıtımı.
        .fullScreenCover(isPresented: $showInvite, onDismiss: {
            if pendingWidget { pendingWidget = false; showWidgetPromo = true }
        }) {
            OnboardingInviteView(onFinish: {
                pendingWidget = true
                showInvite = false
            })
            .updoReadableColumn()
        }
        // Son adım: widget tanıtımı → bittiğinde uygulamaya girilir.
        .fullScreenCover(isPresented: $showWidgetPromo) {
            OnboardingWidgetPromoView(onFinish: onFinish)
                .updoReadableColumn()
        }
    }

    // MARK: - Phone pager (premium paged carousel)

    private var phonePager: some View {
        let data = personal
        return ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(pages.enumerated()), id: \.offset) { i, model in
                    framedDevice(model, data)
                        .containerRelativeFrame(.horizontal)
                        .scrollTransition(.interactive(timingCurve: .easeInOut)) { content, phase in
                            content
                                .opacity(reduceMotion ? (phase.isIdentity ? 1 : 0.4) : 1 - abs(phase.value) * 0.55)
                                .scaleEffect(reduceMotion ? 1 : 1 - abs(phase.value) * 0.16)
                                .rotation3DEffect(
                                    .degrees(reduceMotion ? 0 : phase.value * -11),
                                    axis: (x: 0, y: 1, z: 0), perspective: 0.5
                                )
                                .offset(y: reduceMotion ? 0 : abs(phase.value) * 16)
                        }
                        .id(i)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrolledID, anchor: .center)
        .scrollIndicators(.hidden)
        // Let the phone's glow/shadow spill past the scroll bounds instead of
        // being hard-clipped at the top/bottom edge.
        .scrollClipDisabled()
        // iPad: the readable column's side insets made each page narrower than
        // the paging stride, so pages drifted off-center. Page full-width there.
        .ignoresSafeArea(.container, edges: isPad ? .horizontal : [])
        .onChange(of: scrolledID) { _, new in
            guard let new, new != index else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { index = new }
        }
    }

    @ViewBuilder
    private func framedDevice(_ model: ShowcasePageModel, _ data: OnboardingPersonalSnapshot) -> some View {
        if isPad {
            ShowcasePadFrame(imageName: showcaseImageName(model.shotKey, pad: true))
                .frame(maxWidth: 660)
                .padding(.horizontal, 40)
                .padding(.vertical, 6)
                .shadow(color: .black.opacity(0.5), radius: 34, y: 22)
                .shadow(color: model.accent.opacity(0.26), radius: 44)
        } else {
            framedPhone(model, data)
        }
    }

    /// The screenshot layered UNDER the real gold frame overlay (same crop, so
    /// `scaledToFit` registers them exactly) — the bezel covers the screen edge,
    /// so it seats perfectly with no seam.
    private func framedPhone(_ model: ShowcasePageModel, _ data: OnboardingPersonalSnapshot) -> some View {
        ZStack {
            switch liveKind(model, data) {
            case .ai:
                ShowcaseLiveScreen { ShowcaseLiveAIScreen(data: data) }
            case .week:
                ShowcaseLiveScreen { ShowcaseLiveWeekScreen(data: data) }
            case nil:
                Image(showcaseImageName(model.shotKey))
                    .resizable()
                    .scaledToFit()
            }

            Image("ob_frame_gold")
                .resizable()
                .scaledToFit()
        }
        .padding(.horizontal, 52)
        .shadow(color: .black.opacity(0.5), radius: 28, y: 18)
        .shadow(color: model.accent.opacity(0.26), radius: 34)
    }

    // MARK: - Top row (progress + skip)

    private var topRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? page.accent : UpdoTheme.filmy(0.16))
                    .frame(width: i == index ? 22 : 7, height: 7)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
            }

            Spacer()

            Button {
                HapticManager.shared.navigation()
                showInvite = true
            } label: {
                Text(tr("common_skip"))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(UpdoTheme.filmy(0.42))
            }
        }
    }

    // MARK: - Copy block

    private var copyBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            let copy = pageCopy
            ArenaLargeTitle(
                eyebrow: tr(page.eyebrowKey),
                title: copy.title,
                accent: copy.accent,
                accentColor: page.accent
            )

            Text(copy.benefit)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(UpdoTheme.filmy(0.56))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The page's words — about the user's own setup on the live pages.
    private var pageCopy: (title: String, accent: String, benefit: String) {
        let data = personal
        switch liveKind(page, data) {
        case .ai:
            let benefit = data.hasWeek
                ? tr("ob_live_ai_benefit", OnboardingCount.courses(data.courseNames.count))
                : tr("ob_live_ai_benefit_empty")
            return (tr("ob_live_ai_title"), tr("ob_live_ai_accent"), benefit)
        case .week:
            var benefit = tr("ob_live_week_benefit", OnboardingCount.courses(data.courseNames.count), OnboardingCount.days(data.activeDayCount))
            if let next = data.nextClass {
                benefit += " " + tr("ob_live_week_next", next.whenText, next.block.title)
            }
            return (tr("ob_live_week_title"), tr("ob_live_week_accent"), benefit)
        case nil:
            return (tr(page.titleKey), tr(page.accentKey), tr(page.benefitKey))
        }
    }

    // MARK: - Primary button

    @ViewBuilder
    private var primaryButton: some View {
        Button {
            HapticManager.shared.action()
            if isLast {
                showInvite = true
            } else {
                // Drive the paged scroll; the scroll position's onChange syncs
                // `index` (cloud, copy, dots) with the same spring.
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                    scrolledID = index + 1
                }
            }
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
                Capsule().fill(
                    LinearGradient(
                        colors: [page.accent, page.accentSoft],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .shadow(color: page.accent.opacity(0.38), radius: 16, y: 8)
            )
        }
        .buttonStyle(ShowcaseScaleStyle())
    }
}

// MARK: - Page model

struct ShowcasePageModel {
    let shotKey: String          // asset base: ob_shot_<shotKey>_<lang>
    let eyebrowKey: String
    let titleKey: String
    let accentKey: String
    let benefitKey: String
    let accent: Color
    let accentSoft: Color

    static let all: [ShowcasePageModel] = [
        .init(shotKey: "home",
              eyebrowKey: "ob_home_eyebrow", titleKey: "ob_home_title",
              accentKey: "ob_home_accent", benefitKey: "ob_home_benefit",
              accent: Color(arenaHex: AppArenaPalette.cyan),
              accentSoft: Color(arenaHex: AppArenaPalette.blue)),
        .init(shotKey: "week",
              eyebrowKey: "ob_week_eyebrow", titleKey: "ob_week_title",
              accentKey: "ob_week_accent", benefitKey: "ob_week_benefit",
              accent: Color(arenaHex: AppArenaPalette.coral),
              accentSoft: Color(arenaHex: AppArenaPalette.gold)),
        // Social before Focus — mirrors the real tab-bar order.
        .init(shotKey: "social",
              eyebrowKey: "ob_crew_eyebrow", titleKey: "ob_crew_title",
              accentKey: "ob_crew_accent", benefitKey: "ob_crew_benefit",
              accent: Color(arenaHex: AppArenaPalette.blue),
              accentSoft: Color(arenaHex: AppArenaPalette.purpleSoft)),
        .init(shotKey: "focus",
              eyebrowKey: "ob_focus_eyebrow", titleKey: "ob_focus_title",
              accentKey: "ob_focus_accent", benefitKey: "ob_focus_benefit",
              accent: Color(arenaHex: AppArenaPalette.purple),
              accentSoft: Color(arenaHex: AppArenaPalette.cyan)),
        .init(shotKey: "profile",
              eyebrowKey: "ob_ins_eyebrow", titleKey: "ob_ins_title",
              accentKey: "ob_ins_accent", benefitKey: "ob_ins_benefit",
              accent: Color(arenaHex: AppArenaPalette.green),
              accentSoft: Color(arenaHex: AppArenaPalette.cyan))
    ]
}

/// Language-aware asset name: prefers the current language's capture, always
/// falls back to English (the guaranteed set) when a localized one is missing.
/// `pad` picks the iPad captures (`ob_pad_screen_<key>_<lang>`).
func showcaseImageName(_ key: String, pad: Bool = false) -> String {
    let base = pad ? "ob_pad_screen_\(key)" : "ob_screen_\(key)"
    let en = "\(base)_en"
    guard !appLanguageIsEnglish() else { return en }
    let tr = "\(base)_tr"
    return UIImage(named: tr) != nil ? tr : en
}

// MARK: - iPad frame

/// An iPad Pro (portrait) drawn around a real iPad capture — slim even bezel,
/// continuous corners and a brushed space-black rim. Drawn rather than a PNG
/// so it stays sharp at any size the pager gives it.
private struct ShowcasePadFrame: View {
    let imageName: String

    /// Screen is 3:4 (2064×2752); the bezel is ~4% of the screen width.
    private static let bezelRatio: CGFloat = 0.04
    private static let aspect: CGFloat = (3 + 2 * 3 * bezelRatio) / (4 + 2 * 3 * bezelRatio)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let bezel = w * Self.bezelRatio / (1 + 2 * Self.bezelRatio)
            let outer = w * 0.068
            let inner = max(outer - bezel, 4)

            ZStack {
                RoundedRectangle(cornerRadius: outer, style: .continuous)
                    .fill(Color(white: 0.035))

                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w - bezel * 2, height: geo.size.height - bezel * 2)
                    .clipShape(RoundedRectangle(cornerRadius: inner, style: .continuous))

                // Aluminium rim: a lit top-left edge falling off to graphite.
                RoundedRectangle(cornerRadius: outer, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(white: 0.58), Color(white: 0.22), Color(white: 0.16), Color(white: 0.40)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1.5, w * 0.0045)
                    )
            }
        }
        .aspectRatio(Self.aspect, contentMode: .fit)
    }
}

// MARK: - Live screens (the user's own app inside the gold frame)

enum ShowcaseLiveKind { case ai, week }

/// Seats a SwiftUI "screen" exactly where the screenshots sit under
/// `ob_frame_gold`: same 738×1500 canvas, same screen rect (9,3)–(729,1495).
/// The content is laid out at a real iPhone's logical width and scaled down,
/// so type and spacing keep their true proportions at any frame size.
private struct ShowcaseLiveScreen<Content: View>: View {
    @ViewBuilder var content: () -> Content

    private typealias Metrics = ShowcaseFrameMetrics

    var body: some View {
        Color.clear
            .aspectRatio(Metrics.canvas.width / Metrics.canvas.height, contentMode: .fit)
            .overlay(alignment: .topLeading) {
                GeometryReader { geo in
                    let unit = geo.size.width / Metrics.canvas.width
                    let width = Metrics.screen.width * unit
                    let height = Metrics.screen.height * unit
                    let scale = width / Metrics.logicalWidth

                    content()
                        .frame(width: Metrics.logicalWidth, height: height / scale)
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: width, height: height, alignment: .topLeading)
                        .clipShape(RoundedRectangle(cornerRadius: Metrics.logicalCorner * scale, style: .continuous))
                        .offset(x: Metrics.screen.minX * unit, y: Metrics.screen.minY * unit)
                }
            }
            // A picture of the app, not the app: nothing in it is tappable.
            .allowsHitTesting(false)
            .environment(\.colorScheme, .dark)
            .accessibilityHidden(true)
    }
}

/// Geometry of `ob_frame_gold` and the screenshots made for it.
private enum ShowcaseFrameMetrics {
    static let canvas = CGSize(width: 738, height: 1500)
    static let screen = CGRect(x: 9, y: 3, width: 720, height: 1492)
    /// The content is drawn as on an iPhone this wide, with its screen corner.
    static let logicalWidth: CGFloat = 402
    static let logicalCorner: CGFloat = 62
}

/// Fixed dark palette of the live screens — they sit next to dark screenshots
/// and must match them in either app appearance.
private enum LivePalette {
    static let ink = Color.white
    static let ground = Color(arenaHex: "#06070D")
    static let card = Color.white.opacity(0.055)
    static let hair = Color.white.opacity(0.10)
    static let cyan = Color(arenaHex: AppArenaPalette.cyan)
    static let blue = Color(arenaHex: AppArenaPalette.blue)
    static let purple = Color(arenaHex: AppArenaPalette.purple)
    static let coral = Color(arenaHex: AppArenaPalette.coral)
    static func soft(_ opacity: Double) -> Color { Color.white.opacity(opacity) }
}

/// Status bar with the Dynamic Island, as in the screenshots.
private struct LiveStatusBar: View {
    var body: some View {
        ZStack {
            Capsule().fill(.black).frame(width: 122, height: 36)
            HStack {
                Text("09:41").font(.system(size: 17, weight: .semibold))
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "cellularbars")
                    Image(systemName: "wifi")
                    Image(systemName: "battery.100")
                }
                .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(LivePalette.ink)
            .padding(.horizontal, 34)
        }
        .frame(height: 36)
        .padding(.top, 15)
    }
}

/// The floating tab bar, with one tab active.
private struct LiveTabBar: View {
    enum Tab { case home, week }
    var active: Tab

    var body: some View {
        HStack(spacing: 6) {
            item("house.fill", label: nil, isActive: active == .home)
            item("calendar", label: active == .week ? tr("tab_week") : nil, isActive: active == .week)
            item("person.3.fill", label: nil, isActive: false)
            item("timer", label: nil, isActive: false)
            Circle()
                .fill(LinearGradient(colors: [LivePalette.cyan, LivePalette.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 26, height: 26)
                .padding(.horizontal, 10)
        }
        .padding(6)
        .background(Capsule().fill(Color(arenaHex: "#0D1626").opacity(0.96)).overlay(Capsule().stroke(LivePalette.hair, lineWidth: 1)))
    }

    private func item(_ icon: String, label: String?, isActive: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold))
            if let label, isActive { Text(label).font(.system(size: 14, weight: .bold)) }
        }
        .foregroundStyle(isActive ? LivePalette.cyan : LivePalette.soft(0.45))
        .padding(.horizontal, isActive ? 16 : 12)
        .frame(height: 40)
        .background(Capsule().fill(isActive ? LivePalette.cyan.opacity(0.14) : .clear))
    }
}

/// Home: Updo AI talking to this user about their own week.
private struct ShowcaseLiveAIScreen: View {
    let data: OnboardingPersonalSnapshot

    private var lines: [String] {
        var out: [String] = []
        out.append(data.firstName.isEmpty ? tr("ob_live_ai_hi") : tr("ob_live_ai_hi_name", data.firstName))
        if data.hasWeek {
            out.append(tr("ob_live_ai_week", OnboardingCount.courses(data.courseNames.count), OnboardingCount.days(data.activeDayCount)))
            if let next = data.nextClass {
                out.append(tr("ob_live_ai_next", next.whenText, next.block.title))
            }
        }
        out.append(tr("ob_live_ai_goal", OnboardingGoalText.make(data.dailyGoalMinutes)))
        return out
    }

    private var chips: [String] {
        if let course = data.nextClass?.block.title ?? data.courseNames.first {
            return [tr("ob_live_ai_chip_course", course), tr("ob_live_ai_chip_week")]
        }
        return [tr("ob_live_ai_chip_week"), tr("ob_live_ai_chip_scan")]
    }

    var body: some View {
        ZStack {
            LivePalette.ground
            RadialGradient(colors: [LivePalette.purple.opacity(0.34), .clear], center: UnitPoint(x: 0.5, y: 0.2), startRadius: 0, endRadius: 330)

            VStack(spacing: 0) {
                LiveStatusBar()

                // Toolbar: menu + streak · Updo AI · chats
                HStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "line.3.horizontal")
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill").foregroundStyle(LivePalette.soft(0.4))
                            Text("0")
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LivePalette.soft(0.75))
                    .padding(.horizontal, 14).frame(height: 40)
                    .background(Capsule().fill(LivePalette.card).overlay(Capsule().stroke(LivePalette.hair, lineWidth: 1)))

                    HStack(spacing: 7) {
                        UpdoAIOrb(mode: .idle, size: 18)
                        Text("Updo").font(.system(size: 15, weight: .heavy)).foregroundStyle(LivePalette.ink)
                        + Text(" AI").font(.system(size: 15, weight: .regular, design: .serif)).italic().foregroundStyle(LivePalette.blue)
                    }
                    .padding(.horizontal, 14).frame(height: 36)
                    .background(Capsule().stroke(LivePalette.hair, lineWidth: 1))

                    Spacer(minLength: 0)

                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(LivePalette.soft(0.8))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(LivePalette.card).overlay(Circle().stroke(LivePalette.hair, lineWidth: 1)))
                }
                .padding(.horizontal, 26)
                .padding(.top, 22)

                UpdoAIOrb(mode: .speaking, size: 84)
                    .padding(.top, 34)

                // The coach's message — plain text, as replies are in the app.
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(size: index == 0 ? 25 : 18, weight: index == 0 ? .bold : .medium))
                            .foregroundStyle(index == 0 ? LivePalette.ink : LivePalette.soft(0.82))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)
                .padding(.top, 30)

                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(chips, id: \.self) { chip in
                        HStack(spacing: 9) {
                            Image(systemName: "sparkles").font(.system(size: 13, weight: .bold)).foregroundStyle(LivePalette.cyan)
                            Text(chip).font(.system(size: 15, weight: .semibold)).foregroundStyle(LivePalette.ink).lineLimit(1)
                        }
                        .padding(.horizontal, 15).frame(height: 44)
                        .background(Capsule().fill(LivePalette.card).overlay(Capsule().stroke(LivePalette.hair, lineWidth: 1)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 26)

                // Composer
                HStack(spacing: 12) {
                    Image(systemName: "plus").font(.system(size: 18, weight: .semibold)).foregroundStyle(LivePalette.cyan)
                    Text(tr("ob_live_ai_composer")).font(.system(size: 17)).foregroundStyle(LivePalette.soft(0.4))
                    Spacer()
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(LivePalette.soft(0.8))
                        .frame(width: 32, height: 32).background(Circle().fill(LivePalette.soft(0.16)))
                }
                .padding(.leading, 18).padding(.trailing, 9).frame(height: 52)
                .background(Capsule().fill(LivePalette.card).overlay(Capsule().stroke(LivePalette.hair, lineWidth: 1)))
                .padding(.horizontal, 24)
                .padding(.top, 14)

                LiveTabBar(active: .home)
                    .padding(.top, 18)
                    .padding(.bottom, 26)
            }
        }
    }
}

/// Week: the classes the user just set up, on the day the next one falls.
private struct ShowcaseLiveWeekScreen: View {
    let data: OnboardingPersonalSnapshot

    private var locale: Locale { Locale(identifier: appLanguageIsEnglish() ? "en" : "tr") }

    /// The day shown: the next class's day, else today.
    private var shownDay: Int { data.nextClass?.block.weekday ?? data.todayIndex }

    /// This week's Monday…Sunday as dates.
    private var weekDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let monday = calendar.date(byAdding: .day, value: -data.todayIndex, to: today) ?? today
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    private func text(_ date: Date, _ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(format)
        return formatter.string(from: date)
    }

    var body: some View {
        let dates = weekDates
        let dayBlocks = data.blocks(on: shownDay)
        let shownDate = dates.indices.contains(shownDay) ? dates[shownDay] : Date()
        let totalMinutes = dayBlocks.reduce(0) { $0 + $1.durationMinute }

        ZStack {
            LivePalette.ground
            RadialGradient(colors: [LivePalette.coral.opacity(0.16), .clear], center: UnitPoint(x: 0.9, y: 0.3), startRadius: 0, endRadius: 300)

            VStack(spacing: 0) {
                LiveStatusBar()

                // Header
                HStack {
                    circle("calendar", tint: LivePalette.cyan)
                    circle("list.bullet.rectangle", tint: LivePalette.cyan)
                    Spacer()
                    VStack(spacing: 2) {
                        Text(tr("ob_week_eyebrow"))
                            .font(.system(size: 10, weight: .black, design: .monospaced)).tracking(2.4)
                            .foregroundStyle(LivePalette.cyan)
                        Text(text(shownDate, "MMMM yyyy").capitalized(with: locale))
                            .font(.system(size: 16, weight: .heavy)).foregroundStyle(LivePalette.ink)
                    }
                    Spacer()
                    circle("checklist", tint: LivePalette.soft(0.8))
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(.black)
                        .frame(width: 40, height: 40).background(Circle().fill(LivePalette.cyan))
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)

                // Day strip
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { day in
                        let isShown = day == shownDay
                        VStack(spacing: 6) {
                            Text(AIOnboardingStore.weekdayShortNames[day].uppercased())
                                .font(.system(size: 9.5, weight: .black, design: .monospaced))
                            Text(dates.indices.contains(day) ? text(dates[day], "d") : "")
                                .font(.system(size: 17, weight: .heavy))
                            Circle()
                                .fill(isShown ? Color.black.opacity(0.55) : LivePalette.cyan)
                                .frame(width: 4, height: 4)
                                .opacity(data.blocks(on: day).isEmpty ? 0 : 1)
                        }
                        .foregroundStyle(isShown ? Color.black : LivePalette.soft(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(isShown ? LivePalette.cyan : .clear))
                    }
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LivePalette.card).overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(LivePalette.hair, lineWidth: 1)))
                .padding(.horizontal, 24)
                .padding(.top, 16)

                // Day hero
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Circle().fill(LivePalette.coral).frame(width: 5, height: 5)
                        Text(tr("ob_live_week_hero_eyebrow"))
                            .font(.system(size: 10, weight: .black, design: .monospaced)).tracking(2)
                            .foregroundStyle(LivePalette.coral)
                        Spacer()
                    }

                    (Text(AIOnboardingStore.weekdayFullNames[shownDay] + " ")
                        .font(.system(size: 24, weight: .black)).foregroundStyle(LivePalette.ink)
                     + Text(text(shownDate, "d MMMM"))
                        .font(.system(size: 22, weight: .regular, design: .serif)).italic().foregroundStyle(LivePalette.coral))

                    // The day as a strip, 06 → 24.
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(LivePalette.soft(0.07))
                            ForEach(dayBlocks) { block in
                                let start = CGFloat(max(block.startMinute - 360, 0)) / 1080
                                let length = CGFloat(block.durationMinute) / 1080
                                Capsule()
                                    .fill(Color(arenaHex: block.colorHex))
                                    .frame(width: max(length * geo.size.width, 8))
                                    .offset(x: min(start, 1) * geo.size.width)
                            }
                        }
                    }
                    .frame(height: 8)

                    Text(tr("ob_live_week_hero_sum", OnboardingCount.lessons(dayBlocks.count), OnboardingGoalText.make(totalMinutes)))
                        .font(.system(size: 14, weight: .medium)).foregroundStyle(LivePalette.soft(0.6))
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(LivePalette.coral.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(LivePalette.coral.opacity(0.28), lineWidth: 1)))
                .padding(.horizontal, 24)
                .padding(.top, 14)

                // The day's classes
                VStack(spacing: 9) {
                    ForEach(dayBlocks.prefix(4)) { block in
                        let color = Color(arenaHex: block.colorHex)
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(AIOnboardingStore.minuteText(block.startMinute).replacingOccurrences(of: ".", with: ":"))
                                    .font(.system(size: 15, weight: .bold, design: .monospaced)).foregroundStyle(LivePalette.ink)
                                Text(tr("aio_min_fmt", block.durationMinute))
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced)).foregroundStyle(LivePalette.soft(0.4))
                            }
                            .frame(width: 56, alignment: .leading)

                            RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 3, height: 34)

                            Text(block.title)
                                .font(.system(size: 17, weight: .heavy)).foregroundStyle(LivePalette.ink)
                                .lineLimit(1).minimumScaleFactor(0.8)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16).frame(height: 62)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(color.opacity(0.07)).overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(color.opacity(0.28), lineWidth: 1)))
                    }

                    if dayBlocks.count > 4 {
                        Text(tr("ob_live_week_more", dayBlocks.count - 4))
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(LivePalette.soft(0.45))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 6)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                Spacer(minLength: 10)

                LiveTabBar(active: .week)
                    .padding(.bottom, 26)
            }
        }
    }

    private func circle(_ icon: String, tint: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
            .frame(width: 40, height: 40)
            .background(Circle().fill(LivePalette.card).overlay(Circle().stroke(LivePalette.hair, lineWidth: 1)))
    }
}

/// Counted nouns that read right in both languages ("1 course" / "3 courses").
enum OnboardingCount {
    static func courses(_ n: Int) -> String { tr(n == 1 ? "ob_n_course_one" : "ob_n_course_other", n) }
    static func days(_ n: Int) -> String { tr(n == 1 ? "ob_n_day_one" : "ob_n_day_other", n) }
    static func lessons(_ n: Int) -> String { tr(n == 1 ? "ob_n_lesson_one" : "ob_n_lesson_other", n) }
}

/// "45 dk" · "2 sa" · "2 sa 30 dk"
enum OnboardingGoalText {
    static func make(_ minutes: Int) -> String {
        let hours = minutes / 60, rest = minutes % 60
        if hours == 0 { return tr("ob_dur_min", rest) }
        if rest == 0 { return tr("ob_dur_hour", hours) }
        return tr("ob_dur_hour_min", hours, rest)
    }
}

// MARK: - Button style

private struct ShowcaseScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Colour cloud

/// A soft WWDC-style colour cloud behind the framed phone — a few big blurred
/// blooms in the page's accent that give the page a premium, glowing depth.
/// Static (no repeating animation); the per-page colour cross-fades via the
/// caller's `.animation(value: index)`.
private struct ShowcaseColorCloud: View {
    var accent: Color
    var soft: Color

    private var purple: Color { Color(arenaHex: AppArenaPalette.purple) }

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.34))
                .frame(width: 300, height: 300)
                .blur(radius: 72)
                .offset(x: -46, y: -70)

            Circle()
                .fill(purple.opacity(0.28))
                .frame(width: 290, height: 290)
                .blur(radius: 84)
                .offset(x: 64, y: 30)

            Circle()
                .fill(soft.opacity(0.26))
                .frame(width: 250, height: 250)
                .blur(radius: 78)
                .offset(x: 10, y: 128)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

// MARK: - Referral invite (post-showcase)
//
// Referral (Model B): invite friends who are new to Updo. When 3 newly-installed
// friends add you, the backend grants 1 month free Updo Premium (gold). No codes.
//   • progress — X/3 pips + Share + "maybe later".
//   • earned   — celebrate the free month, then upsell Premium AI.
// (Kept in this file because Features/Onboarding uses explicit pbxproj membership.)

struct OnboardingInviteView: View {
    var onFinish: () -> Void = {}

    @EnvironmentObject var session: SessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var status: ReferralBackendClient.Status?
    @State private var appeared = false
    @State private var heroIn = false
    @State private var showPremiumAI = false

    private var gold: Color { Color(arenaHex: AppArenaPalette.gold) }
    private var coral: Color { Color(arenaHex: AppArenaPalette.coral) }
    private var cyan: Color { Color(arenaHex: AppArenaPalette.cyan) }
    private var blue: Color { Color(arenaHex: AppArenaPalette.blue) }

    private var qualified: Int { min(status?.qualified ?? 0, needed) }
    private var needed: Int { status?.needed ?? 3 }
    private var rewardGranted: Bool { status?.rewardGranted ?? false }
    // updo.me landing page isn't built yet → share the App Store link directly.
    // (When updo.me ships with referral attribution, restore `status?.link ??`.)
    private var link: String { AppLinks.appStore }

    private var shareText: String {
        var text = tr("ob_invite_share_text") + link
        if let username = session.currentUser?.username,
           !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text += "\n@\(username)"
        }
        return text
    }

    var body: some View {
        ZStack {
            // Background glow reflects the emblem art (rocket cyan/coral/orange,
            // logo cyan/blue) — the "photo colours bleed onto the screen".
            ArenaBackground(
                primaryGlow: cyan,
                secondaryGlow: rewardGranted ? blue : coral,
                warmGlow: rewardGranted ? cyan : gold,
                intensity: 0.95
            )

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 8)
                hero
                    .opacity(heroIn ? 1 : 0)
                    .offset(y: heroIn ? 0 : 18)
                Spacer(minLength: 8)
                actions
                    .opacity(heroIn ? 1 : 0)
                    .offset(y: heroIn ? 0 : 12)
            }
            .opacity(appeared ? 1 : 0)
        }
        // Adaptive — respects the app's light/dark theme.
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
            withAnimation(.spring(response: 0.62, dampingFraction: 0.84).delay(0.08)) { heroIn = true }
        }
        .task { status = try? await ReferralBackendClient.shared.status() }
        .fullScreenCover(isPresented: $showPremiumAI, onDismiss: { onFinish() }) {
            PaywallView(context: "referral_premium_ai")
                .updoReadableColumn()
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                HapticManager.shared.navigation()
                onFinish()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(UpdoTheme.filmy(0.92))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(UpdoTheme.filmy(0.14)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var hero: some View {
        VStack(spacing: 18) {
            badge

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Rectangle().fill(gold).frame(width: 20, height: 1)
                    Text(rewardGranted ? tr("ob_invite_reward_eyebrow") : tr("ob_invite_eyebrow"))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(2.4)
                        .foregroundStyle(gold)
                    Rectangle().fill(gold).frame(width: 20, height: 1)
                }

                Text(rewardGranted ? tr("ob_invite_reward_title") : tr("ob_invite_title"))
                    .font(.system(size: 32, weight: .black))
                    .foregroundStyle(UpdoTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(rewardGranted ? tr("ob_invite_reward_accent") : tr("ob_invite_accent"))
                    .font(.system(size: 27, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(colors: [gold, coral], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .multilineTextAlignment(.center)
            }

            Text(rewardGranted ? tr("ob_invite_reward_sub") : tr("ob_invite_sub"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(UpdoTheme.filmy(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 30)

            if !rewardGranted {
                progressPips.padding(.top, 4)
            }
        }
        .padding(.horizontal, 24)
    }

    private var badge: some View {
        ZStack {
            // Colour reflection from the emblem art — soft blurred blooms in the
            // image's own palette bleeding onto the screen behind it.
            if rewardGranted {
                Circle().fill(cyan.opacity(0.34)).frame(width: 200, height: 200).blur(radius: 62)
                Circle().fill(blue.opacity(0.22)).frame(width: 150, height: 150).blur(radius: 54).offset(y: 26)
            } else {
                Circle().fill(cyan.opacity(0.30)).frame(width: 150, height: 150).blur(radius: 52).offset(x: -34, y: -26)
                Circle().fill(coral.opacity(0.26)).frame(width: 150, height: 150).blur(radius: 52).offset(x: 42, y: 4)
                Circle().fill(gold.opacity(0.24)).frame(width: 140, height: 140).blur(radius: 52).offset(x: 4, y: 54)
            }

            Image(rewardGranted ? "ob_invite_logo" : "ob_invite_rocket")
                .resizable()
                .scaledToFit()
                .frame(width: rewardGranted ? 176 : 158, height: rewardGranted ? 176 : 158)
                .shadow(color: cyan.opacity(0.40), radius: 22, y: 6)
        }
        .scaleEffect(heroIn ? 1 : 0.82)
    }

    private var progressPips: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ForEach(0..<needed, id: \.self) { i in
                    Circle()
                        .fill(i < qualified
                              ? AnyShapeStyle(LinearGradient(colors: [gold, coral], startPoint: .top, endPoint: .bottom))
                              : AnyShapeStyle(UpdoTheme.filmy(0.14)))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(i < qualified ? gold.opacity(0.5) : UpdoTheme.filmy(0.18), lineWidth: 1))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: qualified)
                }
            }
            Text(tr("ob_invite_progress", qualified, needed))
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(UpdoTheme.filmy(0.5))
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 12) {
            if rewardGranted {
                Button {
                    HapticManager.shared.action()
                    showPremiumAI = true
                } label: {
                    primaryLabel(icon: "sparkles", title: tr("ob_invite_discover_ai"))
                }
                .buttonStyle(.plain)
                secondaryButton(tr("common_continue")) { onFinish() }
            } else {
                ShareLink(item: shareText) {
                    primaryLabel(icon: "square.and.arrow.up", title: tr("ob_invite_share"))
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { HapticManager.shared.action() })

                secondaryButton(tr("common_continue")) { onFinish() }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 40)
    }

    private func primaryLabel(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 15, weight: .black))
            Text(title).font(.system(size: 17, weight: .black))
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            Capsule()
                .fill(LinearGradient(colors: [gold, coral], startPoint: .leading, endPoint: .trailing))
                .shadow(color: gold.opacity(0.4), radius: 16, y: 8)
        )
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(UpdoTheme.filmy(0.55))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingShowcaseView()
}
