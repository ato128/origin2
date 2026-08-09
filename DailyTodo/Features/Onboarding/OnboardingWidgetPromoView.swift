//
//  OnboardingWidgetPromoView.swift
//  DailyTodo
//
//  Onboarding'de showcase ekranlarından sonra gelen widget tanıtımı: arkada
//  GERÇEK Updo widget'ları (UpdoWidgetStylePreview) yavaşça gezer; önde
//  "Gelişimini widget'lardan takip et" + "Updo Pro'yu Keşfet" (→ paywall).
//  Paywall X ile kapansa da, satın alınsa da doğrudan uygulamaya girilir
//  (onboarding'e geri dönülmez). Sağ üstteki X de doğrudan uygulamaya geçer.
//

import SwiftUI

struct OnboardingWidgetPromoView: View {
    /// Uygulamaya geçiş (X ya da paywall sonrası).
    var onFinish: () -> Void

    @State private var showPaywall = false

    private var gold: Color { Color(arenaHex: AppArenaPalette.gold) }
    private var coral: Color { Color(arenaHex: AppArenaPalette.coral) }

    /// Widget'lar canlı görünsün diye örnek (dolu) kullanıcı durumu.
    private var sampleState: WidgetUserState {
        var s = WidgetUserState(
            iconName: nil,
            isPro: true,
            streak: 12,
            level: 6,
            todayFocusMinutes: 85,
            statsShared: true,
            longestStreak: 21
        )
        s.levelProgress = 0.62
        s.weekFocusMinutes = [40, 70, 30, 90, 55, 80, 85]
        s.prevWeekFocusMinutes = 300
        s.todayFocusDone = true
        s.todayTaskDone = true
        s.peakHour = 20
        return s
    }

    var body: some View {
        ZStack {
            Color(arenaHex: "#05070E").ignoresSafeArea()

            WidgetWall(state: sampleState)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.42),
                    Color.black.opacity(0.94)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        HapticManager.shared.navigation()
                        onFinish()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(0.92))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.white.opacity(0.14)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()

                VStack(alignment: .leading, spacing: 14) {
                    Text(tr("ob_widget_title"))
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(tr("ob_widget_sub"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        HapticManager.shared.action()
                        showPaywall = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 15, weight: .black))
                            Text(tr("ob_widget_cta"))
                                .font(.system(size: 17, weight: .black))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [gold, coral],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .shadow(color: gold.opacity(0.4), radius: 16, y: 8)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }
        }
        .preferredColorScheme(.dark)
        // Paywall widget ekranının üstünde açılır; kapanınca (X veya satın alma)
        // doğrudan uygulamaya geçilir — showcase'e/onboarding'e geri dönülmez.
        .fullScreenCover(isPresented: $showPaywall, onDismiss: { onFinish() }) {
            PaywallView(context: "onboarding")
        }
    }
}

// MARK: - Arkada gezen GERÇEK widget duvarı

private struct WidgetWall: View {
    let state: WidgetUserState

    @State private var drift = false

    /// Orta boy (2:1) gerçek widget'ı verilen genişliğe ölçekler.
    private func medium(_ style: FocusLiveStyle, width: CGFloat) -> some View {
        let scale = width / 338
        return UpdoWidgetStylePreview(style: style, state: state, isSmall: false)
            .scaleEffect(scale)
            .frame(width: width, height: 158 * scale)
    }

    /// Küçük (kare) gerçek widget'ı verilen genişliğe ölçekler.
    private func small(_ style: FocusLiveStyle, width: CGFloat) -> some View {
        let scale = width / 158
        return UpdoWidgetStylePreview(style: style, state: state, isSmall: true)
            .scaleEffect(scale)
            .frame(width: width, height: 158 * scale)
    }

    var body: some View {
        GeometryReader { geo in
            let side: CGFloat = 14
            let gap: CGFloat = 12
            let content = geo.size.width - side * 2
            let col = (content - gap) / 2

            // Ekranı dolduran (F1 tarzı) zengin grid — orta boy + iki küçük satırları.
            VStack(spacing: gap) {
                medium(.arena, width: content)
                HStack(spacing: gap) { small(.gold, width: col); small(.neon, width: col) }
                medium(.terminal, width: content)
                HStack(spacing: gap) { small(.aura, width: col); small(.zen, width: col) }
                medium(.poster, width: content)
                HStack(spacing: gap) { small(.classic, width: col); small(.minimal, width: col) }
                medium(.gold, width: content)
                HStack(spacing: gap) { small(.arena, width: col); small(.neon, width: col) }
            }
            .frame(width: geo.size.width)
            .offset(y: drift ? -70 : 6)
            .opacity(0.92)
            .onAppear {
                withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                    drift = true
                }
            }
        }
    }
}
