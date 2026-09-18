//
//  OnboardingShowcaseView.swift
//  DailyTodo
//
//  The "sell the app" stage of onboarding. After the student is personalized,
//  this walks them through the five pillars of Updo — each shown as a REAL
//  screenshot inside the real gold iPhone frame (Apple device art, pre-composited
//  in the asset catalog), centered on the page over a soft premium colour cloud.
//
//  Screenshots are per-language (`ob_shot_<key>_<en|tr>`); TR falls back to EN
//  until Turkish captures ship. Copy uses the app's own typography (monospaced
//  eyebrow · black title · italic-serif accent word).
//  Ends by presenting the Paywall, then calls `onFinish` to enter the app.
//

import SwiftUI
import UIKit

struct OnboardingShowcaseView: View {

    var onFinish: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var scrolledID: Int? = 0
    @State private var showWidgetPromo = false
    @State private var showInvite = false
    @State private var pendingWidget = false
    @State private var appeared = false

    private let pages = ShowcasePageModel.all

    private var page: ShowcasePageModel { pages[index] }
    private var isLast: Bool { index == pages.count - 1 }

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
        }
        // Son adım: widget tanıtımı → bittiğinde uygulamaya girilir.
        .fullScreenCover(isPresented: $showWidgetPromo) {
            OnboardingWidgetPromoView(onFinish: onFinish)
        }
    }

    // MARK: - Phone pager (premium paged carousel)

    private var phonePager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(pages.enumerated()), id: \.offset) { i, model in
                    framedPhone(model)
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
        .onChange(of: scrolledID) { _, new in
            guard let new, new != index else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { index = new }
        }
    }

    /// The screenshot layered UNDER the real gold frame overlay (same crop, so
    /// `scaledToFit` registers them exactly) — the bezel covers the screen edge,
    /// so it seats perfectly with no seam.
    private func framedPhone(_ model: ShowcasePageModel) -> some View {
        ZStack {
            Image(showcaseImageName(model.shotKey))
                .resizable()
                .scaledToFit()

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
            ArenaLargeTitle(
                eyebrow: tr(page.eyebrowKey),
                title: tr(page.titleKey),
                accent: tr(page.accentKey),
                accentColor: page.accent
            )

            Text(tr(page.benefitKey))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(UpdoTheme.filmy(0.56))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
func showcaseImageName(_ key: String) -> String {
    let en = "ob_screen_\(key)_en"
    guard !appLanguageIsEnglish() else { return en }
    let tr = "ob_screen_\(key)_tr"
    return UIImage(named: tr) != nil ? tr : en
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
