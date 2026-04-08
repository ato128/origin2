//
//  TodoListView+Headeer.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension TodoListView {

    var tasksAmbientBackground: some View {
        AppBackground()
    }

    var overdueTaskCount: Int {
        store.items.filter { task in
            !task.isDone && store.isOverdue(task)
        }.count
    }

    var tasksHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text(todoHeroTitle)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .shadow(color: .white.opacity(0.04), radius: 2, y: 1)

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        showTasksShortcut = true
                        haptic(.light)
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "checklist")
                                .font(.system(size: 15.5, weight: .semibold))
                                .foregroundStyle(
                                    overdueTaskCount > 0
                                    ? Color.orange
                                    : palette.primaryText
                                )
                                .frame(width: 38, height: 38)
                                .background(
                                    Circle()
                                        .fill(palette.cardFill.opacity(0.96))
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    overdueTaskCount > 0
                                                    ? Color.orange.opacity(0.18)
                                                    : palette.cardStroke.opacity(0.9),
                                                    lineWidth: 1
                                                )
                                        )
                                )

                            if overdueTaskCount > 0 {
                                Text("\(min(overdueTaskCount, 9))")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(5)
                                    .background(Color.orange)
                                    .clipShape(Circle())
                                    .offset(x: 5, y: -5)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        showMessages = true
                        haptic(.light)
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 15.5, weight: .semibold))
                                .foregroundStyle(palette.primaryText)
                                .frame(width: 38, height: 38)
                                .background(
                                    Circle()
                                        .fill(palette.cardFill.opacity(0.96))
                                        .overlay(
                                            Circle()
                                                .stroke(palette.cardStroke.opacity(0.9), lineWidth: 1)
                                        )
                                )

                            if unreadCount > 0 {
                                Text("\(min(unreadCount, 9))")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(5)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 5, y: -5)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    if let next = nextClassInfo {
                        Button {
                            withAnimation(.easeInOut) {
                                selectedTab = .week
                            }
                            haptic(.light)
                        } label: {
                            LiveBadgeView(
                                next: next,
                                palette: palette
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
    private var todoHeroTitle: String {
        if overdueTaskCount > 0 {
            return "İyi akşamlar"
        }

        if unreadCount > 0 {
            return "Seni bekleyenler var"
        }

        if let next = nextClassInfo {
            switch next.status {
            case .live:
                return "Akıştasın"
            case .next:
                return "İyi gidiyorsun"
            }
        }

        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Günaydın"
        case 12..<18:
            return "İyi gidiyor"
        default:
            return "İyi akşamlar"
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
    struct LiveBadgeView: View {
        let next: (title: String, timeText: String, status: TodoListView.NextClassStatus)
        let palette: ThemePalette

        var body: some View {
            let isLive = next.status == .live

            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(isLive ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                        .shadow(
                            color: isLive ? Color.green.opacity(0.45) : Color.orange.opacity(0.35),
                            radius: isLive ? 6 : 4
                        )

                    Text(
                        isLive
                        ? tr("todo_live_badge_live")
                        : tr("todo_live_badge_next")
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isLive ? Color.green : Color.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isLive ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isLive ? Color.green.opacity(0.22) : Color.orange.opacity(0.22),
                            lineWidth: 0.8
                        )
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(next.title.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .truncationMode(.tail)
                        .layoutPriority(1)

                    Text(next.timeText)
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(palette.cardFill)
                    .overlay(
                        Capsule()
                            .stroke(palette.cardStroke, lineWidth: 1)
                    )
            )
        }
    }
}
