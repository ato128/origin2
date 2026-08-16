//
//  OnboardingSpotlightTour.swift
//  DailyTodo
//
//  Rehberli tur GERÇEK MainTabView'in ÜSTÜNDE overlay olarak çalışır (ikinci
//  MainTabView render edilmez — donma olmaz). Her adımda ilgili tab `forcedTab`
//  ile zorlanır; o ekranın **öğesi** spotlight'lanır: sadece o öğe açık kalır,
//  gerisi koyulaşır, kenarları cyan glow ile yanar.
//
//  Konuşma baloncuğu asla anlatılan öğenin önünü kapatmaz: baloncuğun gerçek
//  yüksekliği ölçülür, öğenin boş tarafına (üstüne ya da altına) yerleştirilir.
//

import SwiftUI

// MARK: - Anchor plumbing

struct OnboardingTabAnchorKey: PreferenceKey {
    static var defaultValue: [AppTab: Anchor<CGRect>] = [:]
    static func reduce(value: inout [AppTab: Anchor<CGRect>], nextValue: () -> [AppTab: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct TourAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private struct BubbleSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

extension View {
    func onboardingTabAnchor(_ tab: AppTab) -> some View {
        anchorPreference(key: OnboardingTabAnchorKey.self, value: .bounds) { [tab: $0] }
    }

    /// Bir öğeyi rehberli tura tanıt (örn. .tourAnchor("home.ai")).
    func tourAnchor(_ id: String) -> some View {
        anchorPreference(key: TourAnchorKey.self, value: .bounds) { [id: $0] }
    }

    fileprivate func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask(
            ZStack {
                Rectangle()
                mask().blendMode(.destinationOut)
            }
            .compositingGroup()
        )
    }
}

struct OnboardingScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Tour (overlay)

struct OnboardingSpotlightTour: View {
    @Binding var forcedTab: AppTab?
    let size: CGSize
    /// anchorID → ekran koordinatındaki rect (RootView, canlı MainTabView'den çözer).
    let rectFor: (String) -> CGRect?
    var onFinish: () -> Void

    @State private var step = 0
    @State private var appeared = false
    @State private var pulse = false
    @State private var bubbleSize: CGSize = .zero

    private struct TourStep {
        let tab: AppTab
        let anchorID: String
        let titleKey: String
        let descKey: String
    }

    // Ekrandaki her önemli öğe, amacıyla — sekme sırasına göre.
    private let steps: [TourStep] = [
        // HOME
        .init(tab: .tasks, anchorID: "home.ai", titleKey: "spot_t_home_ai", descKey: "spot_d_home_ai"),
        .init(tab: .tasks, anchorID: "home.messages", titleKey: "spot_t_home_msg", descKey: "spot_d_home_msg"),
        .init(tab: .tasks, anchorID: "home.streak", titleKey: "spot_t_home_streak", descKey: "spot_d_home_streak"),
        .init(tab: .tasks, anchorID: "home.timeline", titleKey: "spot_t_home_timeline", descKey: "spot_d_home_timeline"),
        // WEEK
        .init(tab: .week, anchorID: "week.days", titleKey: "spot_t_week_days", descKey: "spot_d_week_days"),
        .init(tab: .week, anchorID: "week.schedule", titleKey: "spot_t_week_schedule", descKey: "spot_d_week_schedule"),
        .init(tab: .week, anchorID: "week.add", titleKey: "spot_t_week_add", descKey: "spot_d_week_add"),
        // FOCUS
        .init(tab: .focus, anchorID: "focus.duration", titleKey: "spot_t_focus_dur", descKey: "spot_d_focus_dur"),
        .init(tab: .focus, anchorID: "focus.start", titleKey: "spot_t_focus", descKey: "spot_d_focus"),
        // SOCIAL
        .init(tab: .crew, anchorID: "social.add", titleKey: "spot_t_social", descKey: "spot_d_social"),
        .init(tab: .crew, anchorID: "social.list", titleKey: "spot_t_social_list", descKey: "spot_d_social_list"),
        // INSIGHTS
        .init(tab: .insights, anchorID: "insights.main", titleKey: "spot_t_insights", descKey: "spot_d_insights"),
        .init(tab: .insights, anchorID: "insights.data", titleKey: "spot_t_insights_data", descKey: "spot_d_insights_data"),
        // SETTINGS (app icon · Live Activity · widgets) — son adım
        .init(tab: .insights, anchorID: "insights.settings", titleKey: "spot_t_settings", descKey: "spot_d_settings")
    ]

    private var current: TourStep { steps[step] }
    private var isLast: Bool { step >= steps.count - 1 }

    private let cyan = UpdoTheme.cyan
    private let surface = UpdoTheme.surface
    private let muted = UpdoTheme.textMuted

    private var bubbleWidth: CGFloat { min(340, size.width - 32) }

    var body: some View {
        let hole = rectFor(current.anchorID).map { $0.insetBy(dx: -12, dy: -10) }

        ZStack(alignment: .topLeading) {
            // Tur sırasında arkadaki gerçek app'e dokunuşu engelle (butonlar üstte aktif).
            Color.black.opacity(0.001)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())

            spotlight(hole: hole)

            bubble
                .position(bubbleCenter(hole: hole))
                .opacity(appeared ? 1 : 0)
        }
        .onPreferenceChange(BubbleSizeKey.self) { bubbleSize = $0 }
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: step)
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: bubbleSize)
        .onAppear {
            forcedTab = current.tab
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.15)) { appeared = true }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    // MARK: - Spotlight

    @ViewBuilder
    private func spotlight(hole: CGRect?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        Color.black.opacity(0.66)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .reverseMask {
                if let r = hole {
                    shape.frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY)
                }
            }
            .overlay {
                if let r = hole {
                    shape
                        .stroke(cyan, lineWidth: 2)
                        .frame(width: r.width, height: r.height)
                        .position(x: r.midX, y: r.midY)
                        .shadow(color: cyan.opacity(0.75), radius: pulse ? 15 : 8)
                }
            }
            .allowsHitTesting(false)
    }

    // MARK: - Bubble placement (öğenin önünü kapatmaz)

    private func bubbleCenter(hole: CGRect?) -> CGPoint {
        let bw = bubbleWidth
        let bh = max(bubbleSize.height, 150)
        let cx = size.width - bw / 2 - 16          // sağa dayalı
        let safeTop: CGFloat = 66                   // dinamik ada altı
        let safeBottom = size.height - 96           // tab bar / home indicator üstü
        let gap: CGFloat = 18

        var top: CGFloat
        if let h = hole {
            let above = h.minY - gap - bh           // öğenin ÜSTÜNE
            let below = h.maxY + gap                // öğenin ALTINA
            let elementLow = h.midY > size.height * 0.5
            if elementLow {
                // Öğe alttaysa baloncuk üste; sığmıyorsa alta.
                top = above >= safeTop ? above : below
            } else {
                // Öğe üsttteyse baloncuk alta; sığmıyorsa üste.
                top = (below + bh) <= safeBottom ? below : above
            }
            top = min(max(top, safeTop), max(safeTop, safeBottom - bh))
        } else {
            top = safeBottom - bh
        }
        return CGPoint(x: cx, y: top + bh / 2)
    }

    // MARK: - Bubble

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Başlık: küçük orb + "Updo AI" + adım + kapat
            HStack(spacing: 9) {
                UpdoAIOrb(size: 28)

                Text("Updo AI")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)

                Spacer(minLength: 8)

                Text(tr("spot_step_of", step + 1, steps.count))
                    .font(.system(size: 9.5, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(cyan)

                Button {
                    HapticManager.shared.subtle()
                    onFinish()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(muted)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("common_skip"))
            }

            titleView.id("t\(step)")

            Text(tr(current.descKey))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.66))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .id("d\(step)")

            HStack {
                progressDots
                Spacer()
                Button {
                    HapticManager.shared.action()
                    if isLast {
                        // Son adım (Ayarlar): turu bitir + insights tab'ında kal +
                        // gerçek Ayarlar sheet'ini aç (app-icon/Live Activity/widget).
                        if current.anchorID == "insights.settings" {
                            NotificationCenter.default.post(name: .openInsightsTab, object: nil)
                            NotificationCenter.default.post(name: .openSettingsHub, object: nil)
                        }
                        onFinish()
                    } else { advance() }
                } label: {
                    HStack(spacing: 6) {
                        Text(isLast ? tr("common_start") : tr("common_continue"))
                            .font(.system(size: 15, weight: .black))
                        Image(systemName: isLast ? "checkmark" : "arrow.right")
                            .font(.system(size: 13, weight: .black))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(Capsule().fill(cyan))
                }
                .buttonStyle(OnboardingScaleButtonStyle())
            }
        }
        .padding(16)
        .frame(width: bubbleWidth, alignment: .leading)
        .background(bubbleBackground)
        .background(
            GeometryReader { g in
                Color.clear.preference(key: BubbleSizeKey.self, value: g.size)
            }
        )
        .shadow(color: .black.opacity(0.55), radius: 26, y: 12)
    }

    private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(surface)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [cyan.opacity(0.32), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    private var titleView: some View {
        let words = tr(current.titleKey).split(separator: " ").map(String.init)
        let lead = words.dropLast().joined(separator: " ")
        let accent = words.last ?? ""
        return (
            Text(lead.isEmpty ? "" : lead + " ")
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(.white)
            + Text(accent)
                .font(.system(size: 23, weight: .bold, design: .serif))
                .italic()
                .foregroundStyle(cyan)
        )
    }

    private var progressDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<steps.count, id: \.self) { i in
                Capsule()
                    .fill(i == step ? cyan : Color.white.opacity(0.15))
                    .frame(width: i == step ? 16 : 5, height: 5)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: step)
            }
        }
    }

    private func advance() {
        guard !isLast else { return }
        step += 1
        forcedTab = current.tab
    }
}
