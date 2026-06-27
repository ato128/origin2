//
//  UpdoWidgetLogo.swift
//  WidgetExtensionExtension
//
//  Small Updo brand mark (crosshair ring + 4 ticks + north arrow) for use as a
//  premium corner watermark on the home widget and Live Activities. This mirrors
//  the app's `UpdoLogoMark` but is static (no animation) and lives in the widget
//  target so the extension can render it without pulling in the app module.
//

import SwiftUI

// MARK: - Crosshair north-arrow (matches the app icon glyph)

struct UpdoWidgetCrosshair: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let pts = [
            CGPoint(x: rect.minX + 0.50 * w, y: rect.minY + 0.02 * h),
            CGPoint(x: rect.minX + 0.97 * w, y: rect.minY + 0.97 * h),
            CGPoint(x: rect.minX + 0.50 * w, y: rect.minY + 0.66 * h),
            CGPoint(x: rect.minX + 0.03 * w, y: rect.minY + 0.97 * h)
        ]
        let radius = min(w, h) * 0.10
        var path = Path()
        let n = pts.count
        for i in 0..<n {
            let cur = pts[i], pr = pts[(i - 1 + n) % n], nx = pts[(i + 1) % n]
            let tP = unit(cur, pr), tN = unit(cur, nx)
            let rP = min(radius, dist(cur, pr) / 2), rN = min(radius, dist(cur, nx) / 2)
            let st = CGPoint(x: cur.x + tP.x * rP, y: cur.y + tP.y * rP)
            let en = CGPoint(x: cur.x + tN.x * rN, y: cur.y + tN.y * rN)
            if i == 0 { path.move(to: st) } else { path.addLine(to: st) }
            path.addQuadCurve(to: en, control: cur)
        }
        path.closeSubpath()
        return path
    }

    private func unit(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        let dx = b.x - a.x, dy = b.y - a.y, l = max((dx * dx + dy * dy).squareRoot(), 0.0001)
        return CGPoint(x: dx / l, y: dy / l)
    }

    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
    }
}

// MARK: - Logo mark (static)

struct UpdoWidgetLogo: View {
    var size: CGFloat = 22
    var tint: AnyShapeStyle = AnyShapeStyle(
        LinearGradient(
            colors: [UpdoWidgetPalette.cyan, UpdoWidgetPalette.purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )

    var body: some View {
        let lw = size * 0.062
        let r = size * 0.285
        let tick = size * 0.20

        ZStack {
            Circle()
                .stroke(tint, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                .frame(width: r * 2, height: r * 2)

            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(tint)
                    .frame(width: lw, height: tick)
                    .offset(y: -r)
                    .rotationEffect(.degrees(Double(i) * 90))
            }

            UpdoWidgetCrosshair()
                .fill(tint)
                .frame(width: size * 0.215, height: size * 0.235)
                .offset(y: -size * 0.005)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Auto-updating progress bar

/// A Live-Activity-safe progress bar. While the timer runs it uses
/// `ProgressView(timerInterval:)`, the ONLY bar that keeps advancing on the lock
/// screen / Dynamic Island without a push update. Paused/completed states fall
/// back to a premium static glow capsule.
struct UpdoLiveProgressBar: View {
    /// When set, the bar auto-advances across this interval.
    var running: ClosedRange<Date>? = nil
    /// Used for paused / completed (static) states.
    var staticProgress: CGFloat = 0
    let accent: Color
    var height: CGFloat = 8

    var body: some View {
        if let running, running.upperBound > running.lowerBound {
            ProgressView(timerInterval: running, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(accent)
            .frame(height: height)
        } else {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accent, accent.opacity(0.65)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, proxy.size.width * max(0, min(1, staticProgress))))
                        .shadow(color: accent.opacity(0.6), radius: 4)
                }
            }
            .frame(height: height)
        }
    }
}

/// Convenience: the logo (colored to match the selected app icon) plus a soft
/// glow halo, sized for a corner watermark.
struct UpdoWidgetCornerMark: View {
    var size: CGFloat = 20
    /// When nil, the mark follows the selected app-icon theme.
    var tint: AnyShapeStyle? = nil
    var opacity: Double = 0.92

    var body: some View {
        let theme = UpdoWidgetIconTheme.current()
        UpdoWidgetLogo(size: size, tint: tint ?? theme.mark)
            .opacity(opacity)
            .shadow(color: theme.glow.opacity(0.35), radius: 3)
    }
}
