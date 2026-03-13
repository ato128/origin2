//
//  EventRow.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 11.03.2026.
//

import SwiftUI

struct EventRow: View {
    
    @State private var pulse: Bool = false
    @State private var glowPhase: Bool = false
    
    let event: EventItem
    let timeText: String
    let hasConflict: Bool
    let nowMinute: Int
    let isTodaySelected: Bool
    
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var start: Int { event.startMinute }
    private var end: Int { event.startMinute + event.durationMinute }
    private var duration: Int { max(1, event.durationMinute) }
    
    private var isLive: Bool {
        guard isTodaySelected else { return false }
        return nowMinute >= start && nowMinute < end
    }
    
    private var isUpNext: Bool {
        guard isTodaySelected else { return false }
        return nowMinute < start && (start - nowMinute) <= 15
    }
    
    private var isSoon: Bool {
        guard isTodaySelected else { return false }
        let diff = start - nowMinute
        return diff > 0 && diff <= 5
    }
    
    private var isDone: Bool {
        guard isTodaySelected else { return false }
        return nowMinute >= end
    }
    
    private var progress: Double {
        guard isLive else { return 0 }
        return min(1, max(0, Double(nowMinute - start) / Double(duration)))
    }
    
    private var minutesLeft: Int { max(0, end - nowMinute) }
    private var minutesUntilStart: Int { max(0, start - nowMinute) }
    
    private func hm(_ minute: Int) -> String {
        let m = max(0, min(1439, minute))
        let h = m / 60
        let mm = m % 60
        return String(format: "%02d:%02d", h, mm)
    }
    
    var body: some View {
        let baseColor = hexColor(event.colorHex)
        
        let accent: Color = {
            if isDone { return Color.secondary.opacity(0.52) }
            if isSoon { return .orange }
            return baseColor
        }()
        
        let bg: Color = {
            if isDone { return Color.secondary.opacity(0.045) }
            return accent.opacity(isLive ? 0.14 : (isUpNext ? 0.10 : 0.075))
        }()
        
        let strokeColor: Color = {
            if hasConflict { return .red.opacity(0.28) }
            if isDone { return .secondary.opacity(0.11) }
            if isLive { return accent.opacity(glowPhase ? 0.60 : 0.32) }
            if isSoon { return .orange.opacity(0.54) }
            if isUpNext { return accent.opacity(0.22) }
            return .secondary.opacity(0.06)
        }()
        
        let strokeWidth: CGFloat =
        hasConflict ? 1.35 :
        (isLive ? 1.8 :
            (isSoon ? 1.55 :
                (isUpNext ? 1.15 : 1.0)))
        
        let mainTextOpacity: Double = isDone ? 0.55 : 1.0
        let secondaryTextOpacity: Double = isDone ? 0.55 : 1.0
        
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(1.0), accent.opacity(0.70)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: isLive ? 9 : 7)
                .shadow(color: isLive ? accent.opacity(0.55) : .clear, radius: isLive ? 10 : 0)
                .padding(.vertical, 10)
                .opacity(isDone ? 0.72 : 1.0)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(event.title)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                        .opacity(mainTextOpacity)
                    
                    if isLive {
                        statusPill("Şu an", tint: accent)
                    } else if isSoon {
                        statusPill("5 dk", tint: .orange)
                    } else if isDone {
                        statusPill("Bitti", tint: .secondary)
                            .opacity(0.9)
                    }
                    
                    Spacer(minLength: 6)
                    
                    if hasConflict {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                    
                    Text(timeText)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(
                                    isDone
                                    ? Color.secondary.opacity(0.08)
                                    : accent.opacity(isLive ? 0.22 : 0.14)
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isDone
                                    ? Color.secondary.opacity(0.14)
                                    : accent.opacity(isLive ? 0.34 : 0.22),
                                    lineWidth: 1
                                )
                        )
                        .opacity(secondaryTextOpacity)
                }
                
                HStack(spacing: 8) {
                    if let loc = event.location,
                       !loc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Label(loc, systemImage: "mappin.and.ellipse")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.secondary.opacity(0.08)))
                            .opacity(secondaryTextOpacity)
                    }
                    
                    Spacer()
                    
                    Text("\(max(15, event.durationMinute)) dk")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .opacity(secondaryTextOpacity)
                }
                
                if isLive {
                    VStack(alignment: .leading, spacing: 5) {
                        ProgressView(value: progress)
                            .tint(baseColor)
                            .animation(.smooth, value: progress)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "hourglass")
                                .font(.caption2)
                                .foregroundStyle(baseColor)
                            
                            Text("%\(Int(progress * 100))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text("\(minutesLeft) dk kaldı")
                                .font(.caption2.weight(.semibold))
                        }
                    }
                }
                
                if isUpNext {
                    HStack(spacing: 6) {
                        Text("\(minutesUntilStart) dk")
                            .font(.caption2.weight(.bold))
                            .monospacedDigit()
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(accent.opacity(0.14)))
                            .overlay(
                                Capsule()
                                    .stroke(accent.opacity(0.22), lineWidth: 1)
                            )
                        
                        Text("sonra (\(hm(start)))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 10)
        }
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isLive ? 0.18 : 0.04),
                                    Color.white.opacity(0.00)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(strokeColor, lineWidth: strokeWidth)
        )
        .shadow(color: isLive ? baseColor.opacity(glowPhase ? 0.30 : 0.14) : .clear, radius: isLive ? 12 : 0)
        .shadow(color: isSoon ? Color.orange.opacity(0.18) : .clear, radius: isSoon ? 8 : 0)
        .shadow(
            color: accent.opacity(0.25),
            radius: 10,
            x: 0,
            y: 8
        )
        .scaleEffect(isLive && pulse ? 1.006 : 1.0)
        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: glowPhase)
        .onAppear {
            pulse = isLive
            glowPhase = isLive
        }
        .onChange(of: isLive) { _, newValue in
            pulse = newValue
            glowPhase = newValue
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.impact(.light)
            onTap()
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                Haptics.impact(.light)
                onTap()
            } label: {
                Label("Details", systemImage: "info.circle")
            }
            .tint(.indigo)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Haptics.impact(.heavy)
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    @ViewBuilder
    private func statusPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.18)))
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.30), lineWidth: 1)
            )
    }
}
