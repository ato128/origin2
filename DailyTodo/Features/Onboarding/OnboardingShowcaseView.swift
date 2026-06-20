//
//  OnboardingShowcaseView.swift
//  DailyTodo
//
//  The "sell the app" stage of onboarding. After the student is personalized,
//  this walks them through the five pillars of Updo — each shown as a faithful,
//  hand-built Arena mockup inside a premium device frame, with the app's own
//  typography (monospaced eyebrow · black title · italic-serif accent word).
//
//  Pure design-system reuse: ArenaBackground, AppArenaPalette, ArenaLargeTitle.
//  No screenshots — every screen is recreated so it stays localized & crisp.
//  Ends by presenting the Paywall, then calls `onFinish` to enter the app.
//

import SwiftUI

struct OnboardingShowcaseView: View {

    var onFinish: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var showPaywall = false
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

                // The device frame stays put; only the screen content swipes
                // *inside* it. Keeping the glow outside the paging container means
                // it never gets clipped at the top/bottom of the phone.
                PhoneFrame(glow: page.accent) {
                    TabView(selection: $index) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { i, model in
                            ShowcaseMockScreen(kind: model.kind, accent: model.accent)
                                .tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
                .frame(maxHeight: .infinity)
                .padding(.top, 18)

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
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
        .fullScreenCover(isPresented: $showPaywall, onDismiss: { onFinish() }) {
            PaywallView(context: "onboarding")
        }
    }

    // MARK: - Top row (progress + skip)

    private var topRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? page.accent : Color.white.opacity(0.16))
                    .frame(width: i == index ? 22 : 7, height: 7)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
            }

            Spacer()

            Button {
                HapticManager.shared.navigation()
                showPaywall = true
            } label: {
                Text(tr("common_skip"))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.42))
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
                .foregroundStyle(.white.opacity(0.56))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Primary button

    private var goldPro: Color { Color(arenaHex: AppArenaPalette.gold) }
    private var coralPro: Color { Color(arenaHex: AppArenaPalette.coral) }

    @ViewBuilder
    private var primaryButton: some View {
        VStack(spacing: 11) {
            // On the final page, invite the user into Pro rather than just "start".
            if isLast {
                Text(tr("ob_sc_more_prompt"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.52))
                    .multilineTextAlignment(.center)
            }

            Button {
                HapticManager.shared.action()
                if isLast {
                    showPaywall = true
                } else {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        index += 1
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(isLast ? tr("ob_sc_see_pro") : tr("common_continue"))
                        .font(.system(size: 17, weight: .black))
                    Image(systemName: isLast ? "sparkles" : "arrow.right")
                        .font(.system(size: 15, weight: .black))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: isLast ? [goldPro, coralPro] : [page.accent, page.accentSoft],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .shadow(color: (isLast ? goldPro : page.accent).opacity(0.38), radius: 16, y: 8)
                )
            }
            .buttonStyle(ShowcaseScaleStyle())
        }
    }
}

// MARK: - Page model

struct ShowcasePageModel {
    let kind: ShowcaseMockKind
    let eyebrowKey: String
    let titleKey: String
    let accentKey: String
    let benefitKey: String
    let accent: Color
    let accentSoft: Color

    static let all: [ShowcasePageModel] = [
        .init(kind: .home,
              eyebrowKey: "ob_home_eyebrow", titleKey: "ob_home_title",
              accentKey: "ob_home_accent", benefitKey: "ob_home_benefit",
              accent: Color(arenaHex: AppArenaPalette.cyan),
              accentSoft: Color(arenaHex: AppArenaPalette.blue)),
        .init(kind: .week,
              eyebrowKey: "ob_week_eyebrow", titleKey: "ob_week_title",
              accentKey: "ob_week_accent", benefitKey: "ob_week_benefit",
              accent: Color(arenaHex: AppArenaPalette.coral),
              accentSoft: Color(arenaHex: AppArenaPalette.gold)),
        .init(kind: .focus,
              eyebrowKey: "ob_focus_eyebrow", titleKey: "ob_focus_title",
              accentKey: "ob_focus_accent", benefitKey: "ob_focus_benefit",
              accent: Color(arenaHex: AppArenaPalette.purple),
              accentSoft: Color(arenaHex: AppArenaPalette.cyan)),
        .init(kind: .crew,
              eyebrowKey: "ob_crew_eyebrow", titleKey: "ob_crew_title",
              accentKey: "ob_crew_accent", benefitKey: "ob_crew_benefit",
              accent: Color(arenaHex: AppArenaPalette.blue),
              accentSoft: Color(arenaHex: AppArenaPalette.purpleSoft)),
        .init(kind: .insights,
              eyebrowKey: "ob_ins_eyebrow", titleKey: "ob_ins_title",
              accentKey: "ob_ins_accent", benefitKey: "ob_ins_benefit",
              accent: Color(arenaHex: AppArenaPalette.green),
              accentSoft: Color(arenaHex: AppArenaPalette.cyan))
    ]
}

// MARK: - Button style

private struct ShowcaseScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Device frame

private struct PhoneFrame<Content: View>: View {
    var glow: Color
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(width: 234, height: 488)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
            .overlay(alignment: .top) {
                // Dynamic-island pill.
                Capsule()
                    .fill(Color.black)
                    .frame(width: 78, height: 22)
                    .padding(.top, 9)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 44, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.32), Color.white.opacity(0.06)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 5
                    )
            )
            // Symmetric colored halo (no big vertical offset, so it reads evenly
            // around all four sides) + a soft grounding shadow underneath.
            .shadow(color: glow.opacity(0.30), radius: 34)
            .shadow(color: .black.opacity(0.45), radius: 22, y: 16)
    }
}

#Preview {
    OnboardingShowcaseView()
}
