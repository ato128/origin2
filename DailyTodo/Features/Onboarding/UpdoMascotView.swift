//
//  UpdoMascotView.swift
//  DailyTodo
//
//  "Updo" — the onboarding voice as a real audio waveform (reference style:
//  dense, thin, bright vertical needles mirrored around a center line with a
//  soft bloom). In the middle the waveform forms the brand mark
//  (location.north.fill); to either side it continues as a normal sound wave
//  that tapers off in a smooth hill. Everything dances while Updo speaks.
//
//  Rendered in a single 30 fps Canvas — every needle is one GPU fill, so the
//  whole field is cheap even at high bar counts. No animated blur radius.
//

import SwiftUI

struct UpdoMascotView: View {

    /// While true the spectrum is energetic; at rest it breathes quietly.
    var isSpeaking: Bool = false
    /// Bump this to fire a quick amplitude swell (a new line landed).
    var flyTrigger: Int = 0
    /// Overall mascot height.
    var size: CGFloat = 152

    /// Side-waveform density.
    private let barCount = 61
    /// Needles that fill the logo.
    private let arrowBarCount = 15

    @State private var burst: Double = 0
    @State private var glow: Double = 0

    // Gold engineering palette (no blue/purple).
    private let gBright = Color(arenaHex: "#FFF3D2")
    private let gGold   = Color(arenaHex: "#FBBF24")
    private let gAmber  = Color(arenaHex: "#F59E0B")
    private let gDeep   = Color(arenaHex: "#B45309")

    private var totalW: CGFloat { size * 2.30 }
    private var stripH: CGFloat { size * 1.05 }
    private var arrowW: CGFloat { size * 0.60 }
    private var arrowH: CGFloat { size * 0.80 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            VStack(spacing: size * 0.02) {
                ZStack {
                    // Soft central bloom (static radius — only haze, no per-frame blur).
                    Ellipse()
                        .fill(
                            RadialGradient(colors: [gGold.opacity(0.18 + 0.10 * glow), .clear],
                                           center: .center, startRadius: 1, endRadius: size * 0.85)
                        )
                        .frame(width: size * 1.6, height: size * 1.0)
                        .blur(radius: 14)

                    waveCanvas(t: t)
                        .frame(width: totalW, height: stripH)
                }
                wordmarkView
            }
            .scaleEffect(0.66)
        }
        .onAppear { start() }
        .onChange(of: flyTrigger) { _, _ in pulse() }
    }

    // MARK: - Waveform canvas

    private func waveCanvas(t: TimeInterval) -> some View {
        Canvas { ctx, sz in
            drawSideWave(ctx, size: sz, t: t)
            drawArrow(ctx, size: sz, t: t)
        }
    }

    /// Side waveform: thin mirrored needles in a hill envelope, suppressed in
    /// the middle so the logo can take over.
    private func drawSideWave(_ ctx: GraphicsContext, size sz: CGSize, t: TimeInterval) {
        var ctx = ctx
        let midY: CGFloat = sz.height / 2
        let inset: CGFloat = 6
        let span: CGFloat = sz.width - inset * 2
        let c: Double = Double(barCount - 1) / 2
        let barW: CGFloat = max(1.6, sz.width / CGFloat(barCount) * 0.34)

        ctx.addFilter(.shadow(color: gGold.opacity(0.55), radius: 4))

        for i in 0..<barCount {
            let nx: Double = (Double(i) - c) / c
            let hill: Double = exp(-pow(nx * 1.7, 2))
            let env: Double = 0.04 + 0.96 * hill
            let suppress: Double = smoothstep(0.20, 0.44, abs(nx))
            if suppress <= 0.001 { continue }

            let speed: Double = 2.2 + Double(i % 5) * 0.5
            let wave: Double = sin(t * speed + Double(i) * 0.5)
            let amp: Double = isSpeaking ? (0.50 + 0.50 * wave) : (0.34 + 0.07 * wave)
            let frac: Double = (env * max(0.05, amp) + burst * 0.25 * env) * suppress
            let h: CGFloat = CGFloat(frac) * sz.height

            let x: CGFloat = inset + CGFloat(Double(i) / Double(barCount - 1)) * span
            drawNeedle(ctx, x: x, midY: midY, height: max(barW, h), width: barW)
        }
    }

    /// The waveform forms the brand mark in the center.
    private func drawArrow(_ ctx: GraphicsContext, size sz: CGSize, t: TimeInterval) {
        let midY: CGFloat = sz.height / 2
        let barW: CGFloat = max(1.8, sz.width / CGFloat(barCount) * 0.40)

        let arrowRect = CGRect(x: (sz.width - arrowW) / 2,
                               y: midY - arrowH / 2,
                               width: arrowW, height: arrowH)
        let arrowPath = NorthArrowShape().path(in: arrowRect)

        // Faint solid base so the mark never fully disappears.
        ctx.fill(
            arrowPath,
            with: .linearGradient(
                Gradient(colors: [gGold.opacity(0.55), gAmber.opacity(0.55), gDeep.opacity(0.5)]),
                startPoint: CGPoint(x: arrowRect.midX, y: arrowRect.minY),
                endPoint: CGPoint(x: arrowRect.midX, y: arrowRect.maxY)
            )
        )

        // Bright vertical needles, clipped to the mark.
        var inner = ctx
        inner.clip(to: arrowPath)
        inner.addFilter(.shadow(color: gBright.opacity(0.5), radius: 3))

        for j in 0..<arrowBarCount {
            let wave: Double = sin(t * (2.6 + Double(j % 4) * 0.4) + Double(j) * 0.7)
            let fill: Double = isSpeaking ? (0.80 + 0.20 * wave) : (0.92 + 0.05 * wave)
            let h: CGFloat = arrowH * CGFloat(min(1.0, fill)) + CGFloat(burst) * 6
            let x: CGFloat = arrowRect.minX + CGFloat(Double(j) / Double(arrowBarCount - 1)) * arrowW
            drawNeedle(inner, x: x, midY: arrowRect.midY, height: h, width: barW)
        }
    }

    /// One mirrored needle: a thin rounded bar with a bright core fading to
    /// transparent tips (the reference look).
    private func drawNeedle(_ ctx: GraphicsContext, x: CGFloat, midY: CGFloat, height: CGFloat, width: CGFloat) {
        let rect = CGRect(x: x - width / 2, y: midY - height / 2, width: width, height: height)
        let path = Path(roundedRect: rect, cornerRadius: width / 2)
        ctx.fill(
            path,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: gGold.opacity(0.25), location: 0.18),
                    .init(color: gBright, location: 0.5),
                    .init(color: gGold.opacity(0.25), location: 0.82),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
        )
    }

    // MARK: - Wordmark ("updo ai" — static; glows while speaking)

    private var wordmarkView: some View {
        Text("updo ai")
            .font(.system(size: size * 0.155, weight: .heavy, design: .rounded))
            .tracking(size * 0.02)
            .foregroundStyle(
                LinearGradient(colors: [gGold, gAmber, gDeep], startPoint: .top, endPoint: .bottom)
            )
            .opacity(isSpeaking ? 1.0 : 0.72)
            .shadow(color: gGold.opacity(isSpeaking ? 0.9 : 0.22), radius: 10)
            .shadow(color: gBright.opacity(isSpeaking ? 0.55 : 0.0), radius: 18)
            .animation(.easeInOut(duration: 0.4), value: isSpeaking)
    }

    // MARK: - Animation

    private func start() {
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            glow = 1
        }
    }

    private func pulse() {
        withAnimation(.easeOut(duration: 0.16)) { burst = 0.5 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.55)) { burst = 0 }
        }
    }

    private func smoothstep(_ e0: Double, _ e1: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - e0) / (e1 - e0)))
        return t * t * (3 - 2 * t)
    }
}

// MARK: - Brand arrow shape (location.north.fill silhouette, rounded)

struct NorthArrowShape: Shape {
    /// Corner rounding as a fraction of the smaller dimension.
    var rounding: CGFloat = 0.12

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let pts = [
            CGPoint(x: rect.minX + 0.50 * w, y: rect.minY + 0.02 * h),   // top tip
            CGPoint(x: rect.minX + 0.97 * w, y: rect.minY + 0.97 * h),   // right wing
            CGPoint(x: rect.minX + 0.50 * w, y: rect.minY + 0.66 * h),   // bottom notch
            CGPoint(x: rect.minX + 0.03 * w, y: rect.minY + 0.97 * h)    // left wing
        ]
        let r = rounding * min(w, h)
        return Self.roundedPolygon(pts, radius: r)
    }

    /// Rounds every vertex of a closed polygon with quadratic corners.
    static func roundedPolygon(_ points: [CGPoint], radius: CGFloat) -> Path {
        var path = Path()
        let n = points.count
        guard n >= 3 else { return path }

        for i in 0..<n {
            let curr = points[i]
            let prev = points[(i - 1 + n) % n]
            let next = points[(i + 1) % n]

            let toPrev = unit(from: curr, to: prev)
            let toNext = unit(from: curr, to: next)

            let rPrev = min(radius, distance(curr, prev) / 2)
            let rNext = min(radius, distance(curr, next) / 2)

            let start = CGPoint(x: curr.x + toPrev.x * rPrev, y: curr.y + toPrev.y * rPrev)
            let end = CGPoint(x: curr.x + toNext.x * rNext, y: curr.y + toNext.y * rNext)

            if i == 0 { path.move(to: start) } else { path.addLine(to: start) }
            path.addQuadCurve(to: end, control: curr)
        }
        path.closeSubpath()
        return path
    }

    private static func unit(from a: CGPoint, to b: CGPoint) -> CGPoint {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(sqrt(dx * dx + dy * dy), 0.0001)
        return CGPoint(x: dx / len, y: dy / len)
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
    }
}

#Preview {
    ZStack {
        Color(arenaHex: "#05060D").ignoresSafeArea()
        UpdoMascotView(isSpeaking: true)
    }
}
