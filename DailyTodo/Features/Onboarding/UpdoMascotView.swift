//
//  UpdoMascotView.swift
//  DailyTodo
//
//  The onboarding face of Updo AI — the same living orb the chat uses
//  (gradient sphere + voice bars), staged large on a quiet halo with the
//  wordmark underneath. One clean symbol, Apple-calm: it breathes at rest,
//  talks while speaking, and gives a soft pulse when a new line lands.
//

import SwiftUI

struct UpdoMascotView: View {

    /// While true the orb's voice bars dance energetically.
    var isSpeaking: Bool = false
    /// Bump this to fire a quick pulse (a new line landed).
    var flyTrigger: Int = 0
    /// Overall mascot height.
    var size: CGFloat = 152

    @State private var pulse: CGFloat = 1
    @State private var haloBreathe = false

    private var cyan: Color { Color(arenaHex: "#2DD4FF") }
    private var purple: Color { Color(arenaHex: "#7C3AED") }

    var body: some View {
        VStack(spacing: size * 0.14) {
            ZStack {
                // Ambient halo — constant blur input, only opacity animates,
                // so Core Animation composites a cached texture.
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [cyan, purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size * 1.15, height: size * 1.15)
                    .blur(radius: size * 0.30)
                    .opacity(haloBreathe ? 0.30 : 0.16)

                UpdoAIOrb(mode: isSpeaking ? .speaking : .idle, size: size * 0.68)
            }
            .scaleEffect(pulse)

            // Wordmark — the app's identity typography, quiet under the orb.
            HStack(spacing: 0) {
                Text("Updo")
                    .font(.system(size: size * 0.125, weight: .black))
                    .foregroundStyle(.white.opacity(0.92))

                Text(" AI")
                    .font(.system(size: size * 0.12, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [cyan, purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .opacity(isSpeaking ? 1.0 : 0.8)
            .animation(.easeInOut(duration: 0.4), value: isSpeaking)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                haloBreathe = true
            }
        }
        .onChange(of: flyTrigger) { _, _ in firePulse() }
    }

    private func firePulse() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) { pulse = 1.06 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { pulse = 1 }
        }
    }
}

#Preview {
    ZStack {
        Color(arenaHex: "#05060D").ignoresSafeArea()
        UpdoMascotView(isSpeaking: true)
    }
}
