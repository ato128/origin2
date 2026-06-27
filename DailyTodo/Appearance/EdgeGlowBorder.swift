//
//  EdgeGlowBorder.swift
//  DailyTodo
//
//  A flowing, colorful, animated edge-light that wraps the entire screen
//  perimeter following the device corner radius — premium iOS edge-lighting.
//
//  Reusable: tune `intensity` and `speed`, and gate the loop with `isActive`
//  (so it can frame onboarding now, and AI-active / Pro moments later).
//
//  Performance: only the AngularGradient ANGLE animates (cheap — no layout,
//  no scale). The blurred bloom layer is rasterized via .drawingGroup(), and
//  the loop is cancelled on disappear / when `isActive` becomes false.
//

import SwiftUI

struct EdgeGlowBorder: View {

    /// Device screen corner radius (~55pt on modern iPhones).
    var cornerRadius: CGFloat = 55
    /// Crisp stroke width — thin, Apple-Intelligence-style hairline.
    var lineWidth: CGFloat = 2.5
    /// Inset from the very edge.
    var inset: CGFloat = 2
    /// Blur radius of the outer bloom layer — wide & soft, not a hard line.
    var glowBlur: CGFloat = 26
    /// Overall opacity multiplier (0…1+).
    var intensity: Double = 1.0
    /// Seconds for one full 360° color rotation (lower = faster flow).
    var speed: Double = 9.0
    /// Runs the loop only while true; flips off to freeze (CPU-friendly).
    var isActive: Bool = true

    @State private var angle: Double = 0

    private var brandSweep: AngularGradient {
        // Soft, multi-stop pastel sweep — closer to Apple Intelligence's
        // diffuse spectrum than a hard 3-color edge.
        AngularGradient(
            gradient: Gradient(colors: [
                Color(arenaHex: "#F97316"),   // orange  (warm)
                Color(arenaHex: "#EC4899"),   // pink
                Color(arenaHex: "#7C3AED"),   // purple
                Color(arenaHex: "#2DD4FF"),   // cyan    (cool)
                Color(arenaHex: "#7C3AED"),   // purple
                Color(arenaHex: "#EC4899"),   // pink
                Color(arenaHex: "#F97316")    // loop back to orange
            ]),
            center: .center,
            angle: .degrees(angle)
        )
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            // Wide, diffuse outer halo — the soft "light leak" feel.
            shape
                .strokeBorder(brandSweep, lineWidth: lineWidth * 2.2)
                .blur(radius: glowBlur)
                .opacity(0.45 * intensity)
                .drawingGroup()

            // Crisp hairline edge on top — thin and precise.
            shape
                .strokeBorder(brandSweep, lineWidth: lineWidth)
                .opacity(0.9 * intensity)
        }
        .padding(inset)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { if isActive { startLoop() } }
        .onChange(of: isActive) { _, active in
            active ? startLoop() : freeze()
        }
        .onDisappear { freeze() }
    }

    private func startLoop() {
        angle = 0
        withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
            angle = 360
        }
    }

    /// Re-targets `angle` with a zero-duration animation, which replaces the
    /// running repeatForever animation on the property → the loop stops.
    private func freeze() {
        withAnimation(.linear(duration: 0)) { angle = angle }
    }
}

#Preview {
    ZStack {
        Color(arenaHex: "#080C18").ignoresSafeArea()
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [Color(arenaHex: "#2DD4FF"), Color(arenaHex: "#7C3AED")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            Text("EdgeGlowBorder")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        EdgeGlowBorder()
    }
}
