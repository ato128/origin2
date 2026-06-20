//
//  OnboardingSpotlightTour.swift
//  DailyTodo
//
//  Premium guided tour that runs ON TOP OF THE REAL APP. The actual MainTabView
//  is shown live behind each step (tab forced per step, matching tab highlighted),
//  lightly dimmed so the real UI reads through. A bottom speech bubble — with a
//  tail pointing at the current tab — explains each screen and advances step by
//  step. The whole thing is framed by the animated EdgeGlowBorder.
//

import SwiftUI

// MARK: - Tab anchor plumbing (read the live tab-bar item frames)

struct OnboardingTabAnchorKey: PreferenceKey {
    static var defaultValue: [AppTab: Anchor<CGRect>] = [:]
    static func reduce(value: inout [AppTab: Anchor<CGRect>], nextValue: () -> [AppTab: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    func onboardingTabAnchor(_ tab: AppTab) -> some View {
        anchorPreference(key: OnboardingTabAnchorKey.self, value: .bounds) { [tab: $0] }
    }
}

// MARK: - Scale button style (premium tactile press)

struct OnboardingScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Tour

struct OnboardingSpotlightTour: View {
    var onFinish: () -> Void

    @State private var step = 0
    @State private var showPaywall = false
    @State private var bubbleIn = false

    private struct TourStep { let tab: AppTab; let descKey: String }

    private let steps: [TourStep] = [
        TourStep(tab: .tasks, descKey: "spot_home_desc"),
        TourStep(tab: .week, descKey: "spot_week_desc"),
        TourStep(tab: .focus, descKey: "spot_focus_desc"),
        TourStep(tab: .crew, descKey: "spot_crew_desc"),
        TourStep(tab: .insights, descKey: "spot_insights_desc")
    ]

    private var current: TourStep { steps[step] }
    private var isLast: Bool { step >= steps.count - 1 }

    private let cyan    = UpdoTheme.cyan
    private let surface = UpdoTheme.surface
    private let muted   = UpdoTheme.textMuted

    var body: some View {
        ZStack {
            // The real app, live behind, with the matching tab highlighted.
            MainTabView(openFocusFromNotification: .constant(false), forcedTab: current.tab)
                .disabled(true)
                .overlayPreferenceValue(OnboardingTabAnchorKey.self) { anchors in
                    GeometryReader { proxy in
                        let tabRect = anchors[current.tab].map { proxy[$0] }
                        ZStack {
                            Color.black.opacity(0.22).ignoresSafeArea()   // gentle dim
                            VStack {
                                Spacer()
                                bubble(tabRect: tabRect, width: proxy.size.width)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 104)
                            }
                        }
                    }
                }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.15)) { bubbleIn = true }
        }
        .fullScreenCover(isPresented: $showPaywall, onDismiss: { onFinish() }) {
            PaywallView(context: "onboarding")
        }
    }

    // MARK: - Bottom speech bubble

    private func bubble(tabRect: CGRect?, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                progressDots
                Spacer()
                Button {
                    HapticManager.shared.selection()
                    showPaywall = true
                } label: {
                    Text(tr("common_skip"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(muted)
                }
                .buttonStyle(.plain)
            }

            // ADIM x / 5 with cyan accent line
            HStack(spacing: 8) {
                Rectangle().fill(cyan).frame(width: 2, height: 12)
                Text(tr("spot_step_of", step + 1, steps.count))
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(cyan)
            }

            titleView
                .id("title-\(step)")

            Text(tr(current.descKey))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(muted)
                .fixedSize(horizontal: false, vertical: true)
                .id("sub-\(step)")

            Button {
                HapticManager.shared.action()
                if isLast { showPaywall = true } else { advance() }
            } label: {
                Text(isLast ? tr("common_start") : tr("common_continue"))
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Capsule().fill(cyan))
            }
            .buttonStyle(OnboardingScaleButtonStyle())
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(surface)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        )
        .overlay(alignment: .bottom) { tail(tabRect: tabRect, width: width) }
        .shadow(color: .black.opacity(0.45), radius: 26, y: 12)
        .opacity(bubbleIn ? 1 : 0)
        .offset(y: bubbleIn ? 0 : 30)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: step)
    }

    // Downward tail pointing at the highlighted tab.
    private func tail(tabRect: CGRect?, width: CGFloat) -> some View {
        let dx: CGFloat = {
            guard let r = tabRect else { return 0 }
            let cardMid = width / 2          // bubble is centered (16pt side padding each)
            return max(-width / 2 + 40, min(width / 2 - 40, r.midX - cardMid))
        }()
        return DownTail()
            .fill(surface)
            .overlay(DownTail().stroke(Color.white.opacity(0.08), lineWidth: 1).mask(DownTail().fill(.black)))
            .frame(width: 22, height: 11)
            .offset(x: dx, y: 10)
    }

    // MARK: - Title (signature italic-serif accent on the last word)

    private var titleView: some View {
        let words = tr(current.tab.tourTitleKey).split(separator: " ").map(String.init)
        let lead = words.dropLast().joined(separator: " ")
        let accent = words.last ?? ""
        return (
            Text(lead.isEmpty ? "" : lead + " ")
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(.white)
            + Text(accent)
                .font(.system(size: 27, weight: .bold, design: .serif))
                .italic()
                .foregroundStyle(cyan)
        )
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<steps.count, id: \.self) { i in
                Capsule()
                    .fill(i == step ? cyan : Color.white.opacity(0.15))
                    .frame(width: i == step ? 18 : 6, height: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: step)
            }
        }
    }

    private func advance() {
        guard !isLast else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { step += 1 }
    }
}

private struct DownTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private extension AppTab {
    var tourTitleKey: String {
        switch self {
        case .tasks: return "tab_home"
        case .week: return "tab_week"
        case .crew: return "tab_crew"
        case .focus: return "tab_focus"
        case .insights: return "tab_insights"
        }
    }
}
