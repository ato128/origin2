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

    var topSegment: some View {
        HStack(spacing: 8) {
            ForEach(HomeSection.allCases) { section in
                let isSelected = homeSection == section

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        homeSection = section
                    }
                } label: {
                    Text(section.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? palette.primaryText : palette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    isSelected
                                    ? Color.accentColor.opacity(appTheme == AppTheme.light.rawValue ? 0.14 : 0.18)
                                    : palette.secondaryCardFill
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    isSelected
                                    ? Color.accentColor.opacity(appTheme == AppTheme.light.rawValue ? 0.22 : 0.30)
                                    : palette.cardStroke.opacity(0.8),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    var tasksHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Home")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Spacer()

            HStack(spacing: 10) {
                Button {
                    showTasksShortcut = true
                    haptic(.light)
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "checklist")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(
                                overdueTaskCount > 0
                                ? Color.orange
                                : palette.primaryText
                            )
                            .frame(width: 42, height: 42)
                            .background(
                                Circle()
                                    .fill(palette.cardFill)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                overdueTaskCount > 0
                                                ? Color.orange.opacity(0.22)
                                                : palette.cardStroke,
                                                lineWidth: 1
                                            )
                                    )
                            )

                        if overdueTaskCount > 0 {
                            Text("\(min(overdueTaskCount, 9))")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(Color.orange)
                                .clipShape(Circle())
                                .offset(x: 6, y: -6)
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
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(palette.primaryText)
                            .frame(width: 42, height: 42)
                            .background(
                                Circle()
                                    .fill(palette.cardFill)
                                    .overlay(
                                        Circle()
                                            .stroke(palette.cardStroke, lineWidth: 1)
                                    )
                            )

                        if unreadCount > 0 {
                            Text("\(unreadCount)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 6, y: -6)
                        }
                    }
                }
                .buttonStyle(.plain)

                if homeSection == .personal, let next = nextClassInfo {
                    Button {
                        withAnimation(.easeInOut) {
                            selectedTab = .week
                        }
                        haptic(.light)
                    } label: {
                        LiveBadgeView(
                            next: next,
                            palette: palette,
                            appTheme: appTheme
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
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
        let appTheme: String

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

                    Text(isLive ? "LIVE" : "NEXT")
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
