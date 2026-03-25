//
//  NextClassCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 5.03.2026.
//

import SwiftUI

extension HomeDashboardView {
    var nextClassCard: some View {
        let classColor = nextEvent.map { hexColor($0.colorHex) } ?? .secondary
        let animatedClassColor = classColor

        let startsSoon: Bool = {
            guard let nextEvent else { return false }
            let now = currentMinuteOfDay()
            let diff = nextEvent.startMinute - now
            return diff > 0 && diff <= 30
        }()

        let startsVerySoon: Bool = {
            guard let nextEvent else { return false }
            let now = currentMinuteOfDay()
            let diff = nextEvent.startMinute - now
            return diff > 0 && diff <= 5
        }()

        let isLiveNow: Bool = {
            guard let nextEvent else { return false }
            let now = currentMinuteOfDay()
            let start = nextEvent.startMinute
            let end = nextEvent.startMinute + nextEvent.durationMinute
            return now >= start && now < end
        }()

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("home_next_class")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(nextEvent == nil ? .primary : animatedClassColor)

                Spacer()

                Button {
                    onOpenWeek()
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .padding(9)
                        .background(
                            Circle()
                                .fill(animatedClassColor.opacity(0.16))
                        )
                }
                .buttonStyle(.plain)
            }

            if let nextEvent {
                HStack(spacing: 12) {
                    Circle()
                        .fill(animatedClassColor)
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(nextEvent.title)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(animatedClassColor)
                            .lineLimit(1)

                        Text(nextEventTimeText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            if nextEventStatusText.contains("aktif") || nextEventStatusText.contains("Active") {
                                Text("home_live")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(Color.green.opacity(0.18))
                                    )
                                    .foregroundStyle(.green)
                            }

                            Text(nextEventStatusText)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .id("\(nextEvent.title)-\(nextEvent.startMinute)-\(nextEvent.weekday)-\(nextEvent.colorHex)")
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.98)),
                        removal: .move(edge: .leading)
                            .combined(with: .opacity)
                    )
                )
            } else {
                Text("home_no_more_classes_today")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .id("no-next-class")
                    .transition(.opacity)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(animatedClassColor.opacity(nextEvent == nil ? 0.0 : 0.05))

                        if startsSoon {
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    animatedClassColor.opacity(0.03),
                                    animatedClassColor.opacity(0.10)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .clipShape(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                            )
                        }

                        if isLiveNow {
                            RadialGradient(
                                colors: [
                                    animatedClassColor.opacity(0.10),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 180
                            )
                            .clipShape(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                            )
                        }

                        if nextClassSweep {
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.22),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(width: 90)
                            .rotationEffect(.degrees(18))
                            .offset(x: nextClassSweep ? 220 : -220)
                            .blendMode(.plusLighter)
                            .animation(.easeInOut(duration: 0.9), value: nextClassSweep)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                            )
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            animatedClassColor.opacity(
                                nextEvent == nil
                                ? 0.08
                                : (isLiveNow ? 0.24 : (startsSoon ? 0.20 : 0.18))
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: animatedClassColor.opacity(
                nextEvent == nil
                ? 0.0
                : (isLiveNow ? 0.16 : (startsSoon ? 0.10 : 0.10))
            ),
            radius: isLiveNow ? 14 : 10,
            x: 0,
            y: 4
        )
        .animation(.interactiveSpring(response: 0.55, dampingFraction: 0.82, blendDuration: 0.25), value: nextEvent?.title)
        .animation(.interactiveSpring(response: 0.55, dampingFraction: 0.82, blendDuration: 0.25), value: nextEvent?.startMinute)
        .animation(.interactiveSpring(response: 0.55, dampingFraction: 0.82, blendDuration: 0.25), value: nextEventStatusText)
        .animation(.easeInOut(duration: 0.7), value: nextEvent?.colorHex)
        .scaleEffect(startsVerySoon ? (nextClassPulse ? 1.012 : 1.0) : 1.0)
        .shadow(
            color: animatedClassColor.opacity(
                startsVerySoon
                ? (nextClassPulse ? 0.22 : 0.12)
                : 0.0
            ),
            radius: startsVerySoon ? (nextClassPulse ? 18 : 10) : 0,
            x: 0,
            y: 0
        )
        .animation(
            startsVerySoon
            ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
            : .easeInOut(duration: 0.2),
            value: nextClassPulse
        )
        .onAppear {
            if startsVerySoon {
                nextClassPulse = true
            }
        }
        .onChange(of: startsVerySoon) { _, newValue in
            nextClassPulse = newValue
        }
        .onChange(of: isLiveNow) { _, newValue in
            guard newValue else { return }

            nextClassSweep = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                nextClassSweep = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                nextClassSweep = false
            }
        }
    }
}
