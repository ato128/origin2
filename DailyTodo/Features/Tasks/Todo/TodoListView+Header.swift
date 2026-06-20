//
//  TodoListView+Headeer.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension TodoListView {

    var tasksAmbientBackground: some View {
        ArenaBackground(
            primaryGlow: Color(arenaHex: AppArenaPalette.blue),
            secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
            warmGlow: Color(arenaHex: AppArenaPalette.coral),
            intensity: 0.92
        )
    }
    var overdueTaskCount: Int {
        store.items.filter { task in
            !task.isDone && store.isOverdue(task)
        }.count
    }

   
    var tasksHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    showProfileHub = true
                    haptic(.light)
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(arenaHex: AppArenaPalette.blue).opacity(0.88),
                                        Color(arenaHex: AppArenaPalette.purple).opacity(0.76)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)

                        Circle()
                            .stroke(Color.white.opacity(0.11), lineWidth: 1)
                            .frame(width: 50, height: 50)

                        Image(systemName: "person.fill")
                            .font(.system(size: 19, weight: .black))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Color(arenaHex: AppArenaPalette.blue).opacity(0.18), radius: 14, y: 7)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 3) {
                    Text(todoHeroTitle)
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    HStack(spacing: 7) {
                        Circle()
                            .fill(headerStatusTint)
                            .frame(width: 6, height: 6)

                        Text(todoHeaderSubtitle)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(headerStatusTint.opacity(0.95))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }

                Spacer(minLength: 8)

                HStack(spacing: 9) {
                    headerCircleButton(
                        systemName: "checklist",
                        tint: overdueTaskCount > 0 ? Color(arenaHex: AppArenaPalette.gold) : .white.opacity(0.88),
                        badge: overdueTaskCount > 0 ? "\(min(overdueTaskCount, 9))" : nil
                    ) {
                        showTasksShortcut = true
                        haptic(.light)
                    }

                    headerCircleButton(
                        systemName: "bubble.left.and.bubble.right.fill",
                        tint: unreadCount > 0 ? Color(arenaHex: AppArenaPalette.coral) : .white.opacity(0.88),
                        badge: unreadCount > 0 ? "\(min(unreadCount, 9))" : nil
                    ) {
                        showMessages = true
                        haptic(.light)
                    }
                }
            }

            if let next = nextClassInfo {
                Button {
                    withAnimation(.easeInOut) {
                        selectedTab = .week
                    }
                    haptic(.light)
                } label: {
                    ArenaLiveBadgeView(
                        next: next,
                        tint: next.status == .live
                        ? Color(arenaHex: AppArenaPalette.green)
                        : Color(arenaHex: AppArenaPalette.gold)
                    )
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }
    
    private var headerStatusTint: Color {
        if overdueTaskCount > 0 {
            return Color(arenaHex: AppArenaPalette.gold)
        }

        if unreadCount > 0 {
            return Color(arenaHex: AppArenaPalette.coral)
        }

        if let next = nextClassInfo {
            switch next.status {
            case .live:
                return Color(arenaHex: AppArenaPalette.green)
            case .next:
                return Color(arenaHex: AppArenaPalette.cyan)
            }
        }

        return Color(arenaHex: AppArenaPalette.cyan)
    }

    private var todoHeaderSubtitle: String {
        if overdueTaskCount > 0 {
            return tr("tlh_tasks_waiting", overdueTaskCount)
        }

        if unreadCount > 0 {
            return "\(unreadCount) MESAJ VAR"
        }

        if let next = nextClassInfo {
            switch next.status {
            case .live:
                return tr("tlh_class_active")
            case .next:
                return tr("tlh_next_class")
            }
        }

        return tr("tlh_today_calm")
    }

    func headerCircleButton(
        systemName: String,
        tint: Color,
        badge: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemName)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 46, height: 46)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.090),
                                        Color.white.opacity(0.050)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.11), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.22), radius: 12, y: 6)
                    )

                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(
                            Circle()
                                .fill(Color(arenaHex: AppArenaPalette.gold))
                        )
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
    }
    private var todoHeroTitle: String {
        if overdueTaskCount > 0 {
            return tr("hh_good_evening")
        }

        if unreadCount > 0 {
            return "Seni bekleyenler var"
        }

        if let next = nextClassInfo {
            switch next.status {
            case .live:
                return tr("hh_in_flow")
            case .next:
                return tr("hh_doing_well")
            }
        }

        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return tr("hh_good_morning")
        case 12..<18:
            return tr("hh_going_well")
        default:
            return tr("hh_good_evening")
        }
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            EmptyView()
        }

        ToolbarItem(placement: .topBarTrailing) {
            EmptyView()
        }
    }
}

extension TodoListView {
    struct ArenaLiveBadgeView: View {
        let next: (title: String, timeText: String, status: TodoListView.NextClassStatus)
        let tint: Color

        var body: some View {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(tint)
                        .frame(width: 7, height: 7)
                        .shadow(color: tint.opacity(0.45), radius: 7)

                    Text(next.status == .live ? "LIVE" : "NEXT")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(tint)
                }
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(
                    Capsule()
                        .fill(tint.opacity(0.13))
                        .overlay(
                            Capsule()
                                .stroke(tint.opacity(0.20), lineWidth: 1)
                        )
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(next.title.uppercased())
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)

                    Text(next.timeText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(tint.opacity(0.85))
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.060),
                                Color(arenaHex: AppArenaPalette.purple).opacity(0.040),
                                Color.white.opacity(0.036)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.080), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 10, y: 5)
            )
        }
    }
}
