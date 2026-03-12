//
//  FriendDetailView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct FriendDetailView: View {
    let name: String
    let subtitle: String
    let isOnline: Bool
    let color: Color

    @State private var showCopied = false

    private let todaySchedule: [(title: String, time: String, type: String)] = [
        ("Math Lecture", "09:00 – 10:30", "Class"),
        ("UI Study Session", "13:00 – 14:00", "Focus"),
        ("Physics Lab Prep", "18:00 – 19:00", "Task")
    ]

    private let weekStats: [(title: String, value: String)] = [
        ("This Week", "8 events"),
        ("Today", "3 plans"),
        ("Shared", "2 items")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroCard
                todayScheduleCard
                actionsCard
            }
            .padding(16)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if showCopied {
                Text("Copied")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 8)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

private extension FriendDetailView {

    var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.16))
                        .frame(width: 72, height: 72)

                    Text(String(name.prefix(1)).uppercased())
                        .font(.title.bold())
                        .foregroundStyle(color)
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(isOnline ? .green : Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)

                    Text(isOnline ? "Online" : "Offline")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.title2.bold())

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                ForEach(weekStats, id: \.title) { item in
                    statPill(title: item.value, subtitle: item.title)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var todayScheduleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today Schedule")
                    .font(.headline)

                Spacer()

                Text("\(todaySchedule.count) items")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ForEach(todaySchedule, id: \.title) { item in
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(color.opacity(0.14))
                            .frame(width: 42, height: 42)

                        Image(systemName: iconForType(item.type))
                            .foregroundStyle(color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))

                        Text(item.time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(item.type)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                        )
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var actionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Actions")
                .font(.headline)

            HStack(spacing: 12) {
                actionButton(
                    title: "Message",
                    systemImage: "message.fill"
                ) {
                }

                actionButton(
                    title: "Share My Week",
                    systemImage: "square.and.arrow.up.fill"
                ) {
                    UIPasteboard.general.string = "Check out my week on DailyTodo"
                    withAnimation {
                        showCopied = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            showCopied = false
                        }
                    }
                }

                actionButton(
                    title: "Invite",
                    systemImage: "person.badge.plus.fill"
                ) {
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    func statPill(title: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.bold))

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    func actionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }

    func iconForType(_ type: String) -> String {
        switch type {
        case "Class": return "book.closed.fill"
        case "Focus": return "scope"
        case "Task": return "checkmark.circle.fill"
        default: return "calendar"
        }
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
