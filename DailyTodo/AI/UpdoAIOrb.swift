//
//  UpdoAIOrb.swift
//  DailyTodo
//
//  The Updo AI symbol — a Siri-grade glass orb. Inside a deep glass sphere,
//  blurred clouds of cyan / blue / purple / pink drift and swirl (additive
//  blending, clipped to the sphere); a glass rim light and a soft specular
//  catch sell the material. Idle it drifts slowly; while the AI is thinking
//  or streaming the clouds speed up, brighten and the orb quickens its
//  breath. TimelineView-driven — no assets, no shaders.
//

import SwiftUI

struct UpdoAIOrb: View {
    enum Mode {
        case idle
        case speaking
    }

    var mode: Mode = .idle
    var size: CGFloat = 28

    private var cyan: Color { Color(arenaHex: "#2DD4FF") }
    private var blue: Color { Color(arenaHex: "#3B82F6") }
    private var purple: Color { Color(arenaHex: "#8B5CF6") }
    private var pink: Color { Color(arenaHex: "#F472B6") }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            orb(t: t)
        }
        .frame(width: size * 1.3, height: size * 1.3)
    }

    @ViewBuilder
    private func orb(t: TimeInterval) -> some View {
        // Speaking is a LIGHT change, not a motion change: the clouds keep
        // their calm drift and the orb keeps its slow breath — only the
        // interior brightens, like a voice lighting the glass from within.
        let speaking = mode == .speaking
        let speed: Double = speaking ? 0.75 : 0.55
        let energy: Double = speaking ? 1.0 : 0.55
        let breathe = 1 + 0.014 * sin(t * 1.3)

        ZStack {
            // Ambient glow around the sphere.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            cyan.opacity(0.30 * energy),
                            purple.opacity(0.16 * energy),
                            .clear
                        ],
                        center: .center,
                        startRadius: size * 0.30,
                        endRadius: size * 0.70
                    )
                )
                .frame(width: size * 1.3, height: size * 1.3)

            // ── Glass sphere ────────────────────────────────────────────
            ZStack {
                // Deep glass base, lit slightly from the upper left.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(arenaHex: "#101A38"), Color(arenaHex: "#05070F")],
                            center: .init(x: 0.38, y: 0.30),
                            startRadius: 0,
                            endRadius: size * 0.85
                        )
                    )

                // Flowing colour clouds — each drifts on its own orbit.
                Group {
                    cloud(t: t, speed: speed, color: cyan,
                          diameter: 0.78, blur: 0.16,
                          fx: 0.9, fy: 1.3, px: 0.0, py: 1.6,
                          ax: 0.20, ay: 0.16,
                          opacity: 0.85 * energy + 0.10)

                    cloud(t: t, speed: speed, color: purple,
                          diameter: 0.84, blur: 0.18,
                          fx: 1.15, fy: 0.8, px: 3.4, py: 0.7,
                          ax: 0.22, ay: 0.20,
                          opacity: 0.80 * energy + 0.10)

                    cloud(t: t, speed: speed, color: blue,
                          diameter: 0.62, blur: 0.14,
                          fx: 1.5, fy: 1.05, px: 5.1, py: 2.9,
                          ax: 0.24, ay: 0.22,
                          opacity: 0.65 * energy + 0.08)

                    cloud(t: t, speed: speed, color: pink,
                          diameter: 0.40, blur: 0.11,
                          fx: 2.1, fy: 1.7, px: 1.2, py: 4.4,
                          ax: 0.26, ay: 0.24,
                          opacity: 0.55 * energy)

                    // Hot core shimmer — brightens while speaking.
                    cloud(t: t, speed: speed, color: .white,
                          diameter: 0.26, blur: 0.10,
                          fx: 2.6, fy: 2.2, px: 2.2, py: 0.3,
                          ax: 0.18, ay: 0.16,
                          opacity: speaking ? 0.34 : 0.16)
                }
                .blendMode(.plusLighter)

                // Spherical shading: darken toward the edge for depth.
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .clear, location: 0.62),
                                .init(color: Color.black.opacity(0.38), location: 1.0)
                            ],
                            center: .init(x: 0.42, y: 0.36),
                            startRadius: 0,
                            endRadius: size * 0.62
                        )
                    )
            }
            .compositingGroup()
            .clipShape(Circle())
            .frame(width: size, height: size)

            // Glass rim light — bright at the top-left, whisper elsewhere;
            // rotates almost imperceptibly so the glass feels real.
            Circle()
                .strokeBorder(
                    AngularGradient(
                        stops: [
                            .init(color: .white.opacity(0.75), location: 0.0),
                            .init(color: .white.opacity(0.06), location: 0.20),
                            .init(color: cyan.opacity(0.35), location: 0.45),
                            .init(color: .white.opacity(0.05), location: 0.68),
                            .init(color: purple.opacity(0.30), location: 0.85),
                            .init(color: .white.opacity(0.75), location: 1.0)
                        ],
                        center: .center,
                        angle: .degrees(-58 + 6 * sin(t * 0.5))
                    ),
                    lineWidth: max(0.9, size * 0.022)
                )
                .frame(width: size, height: size)

            // Specular catch — the glass "window" reflection.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.55), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.16
                    )
                )
                .frame(width: size * 0.34, height: size * 0.20)
                .rotationEffect(.degrees(-28))
                .offset(x: -size * 0.16, y: -size * 0.24)
        }
        .scaleEffect(breathe)
        .drawingGroup()
        .shadow(color: purple.opacity(speaking ? 0.45 : 0.25), radius: size * 0.16, y: size * 0.05)
    }

    /// One blurred colour cloud on a Lissajous orbit inside the sphere.
    private func cloud(
        t: TimeInterval,
        speed: Double,
        color: Color,
        diameter: CGFloat,
        blur: CGFloat,
        fx: Double, fy: Double,
        px: Double, py: Double,
        ax: CGFloat, ay: CGFloat,
        opacity: Double
    ) -> some View {
        Circle()
            .fill(color)
            .frame(width: size * diameter, height: size * diameter)
            .blur(radius: size * blur)
            .offset(
                x: size * ax * CGFloat(cos(t * speed * fx + px)),
                y: size * ay * CGFloat(sin(t * speed * fy + py))
            )
            .opacity(opacity)
    }
}

#Preview {
    ZStack {
        Color(arenaHex: "#05060D").ignoresSafeArea()
        VStack(spacing: 40) {
            UpdoAIOrb(mode: .speaking, size: 120)
            UpdoAIOrb(mode: .idle, size: 60)
            HStack(spacing: 24) {
                UpdoAIOrb(mode: .idle, size: 24)
                UpdoAIOrb(mode: .speaking, size: 17)
            }
        }
    }
}
