//
//  FriendDetailView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI
import SwiftData

struct FriendDetailView: View {
    let friend: Friend

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FriendMessage.createdAt, order: .forward)
    private var allMessages: [FriendMessage]

    @Query(sort: \SharedWeekItem.createdAt, order: .forward)
    private var allSharedItems: [SharedWeekItem]
    
    @Query(sort: \FriendFocusSession.startedAt, order: .reverse)
    private var allFocusSessions: [FriendFocusSession]

    @State private var showCopied = false

    private var messages: [FriendMessage] {
        allMessages.filter { $0.friendID == friend.id }
    }

    private var todaySchedule: [SharedWeekItem] {
        let today = weekdayIndexToday()
        return allSharedItems
            .filter { $0.friendID == friend.id && $0.weekday == today }
            .sorted { $0.startMinute < $1.startMinute }
    }

    private var weekCount: Int {
        allSharedItems.filter { $0.friendID == friend.id }.count
    }
    private var activeFocusSession: FriendFocusSession? {
        allFocusSessions.first { $0.friendID == friend.id && $0.isActive }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                heroCard
                todayScheduleCard
                recentMessagesCard
                actionsCard
            }
            .padding(16)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(friend.name)
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
        .onAppear {
            seedFriendDetailIfNeeded()
        }
    }
}

private extension FriendDetailView {

    var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(hexColor(friend.colorHex).opacity(0.16))
                        .frame(width: 72, height: 72)

                    Image(systemName: friend.avatarSymbol)
                        .font(.title.bold())
                        .foregroundStyle(hexColor(friend.colorHex))
                }

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(friend.isOnline ? .green : Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)

                    Text(friend.isOnline ? "Online" : "Offline")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(friend.name)
                            .font(.title2.bold())

                        Text(friend.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let session = activeFocusSession {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 8, height: 8)

                                Text("In focus now • \(session.durationMinute) min")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.title2.bold())

                Text(friend.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                statPill(title: "\(weekCount)", subtitle: "This Week")
                statPill(title: "\(todaySchedule.count)", subtitle: "Today")
                statPill(title: "\(messages.count)", subtitle: "Messages")
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

            if todaySchedule.isEmpty {
                Text("No shared schedule for today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(todaySchedule) { item in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(hexColor(friend.colorHex).opacity(0.14))
                                .frame(width: 42, height: 42)

                            Image(systemName: "calendar")
                                .foregroundStyle(hexColor(friend.colorHex))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))

                            Text("\(hm(item.startMinute)) – \(hm(item.startMinute + item.durationMinute))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var recentMessagesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent Messages")
                    .font(.headline)

                Spacer()

                Text("\(messages.suffix(3).count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if messages.isEmpty {
                Text("No messages yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(messages.suffix(3))) { message in
                    HStack {
                        if message.isFromMe { Spacer() }

                        Text(message.text)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(message.isFromMe ? Color.accentColor.opacity(0.16) : Color.white.opacity(0.06))
                            )

                        if !message.isFromMe { Spacer() }
                    }
                }
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
                NavigationLink {
                    FriendChatView(friend: friend)
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "message.fill")
                            .font(.title3)

                        Text("Message")
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

                actionButton(
                    title: activeFocusSession == nil ? "Start Focus" : "Stop Focus",
                    systemImage: activeFocusSession == nil ? "timer.circle.fill" : "stop.circle.fill"
                ) {
                    toggleSharedFocus()
                }

                actionButton(
                    title: "Share My Week",
                    systemImage: "square.and.arrow.up.fill"
                ) {
                    UIPasteboard.general.string = "Check out my week on DailyTodo"
                    withAnimation { showCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showCopied = false }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
    func toggleSharedFocus() {
        if let active = activeFocusSession {
            active.isActive = false

            let stopMessage = FriendMessage(
                friendID: friend.id,
                senderName: friend.name,
                text: "\(friend.name) ended the shared focus session.",
                isFromMe: false
            )

            modelContext.insert(stopMessage)
            try? modelContext.save()
            return
        }

        let session = FriendFocusSession(
            friendID: friend.id,
            title: "Shared Focus",
            startedAt: Date(),
            durationMinute: 25,
            isActive: true
        )

        let startMessage = FriendMessage(
            friendID: friend.id,
            senderName: friend.name,
            text: "\(friend.name) started a 25 min shared focus session.",
            isFromMe: false
        )

        modelContext.insert(session)
        modelContext.insert(startMessage)
        try? modelContext.save()
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

    func seedFriendDetailIfNeeded() {
        let existingShared = allSharedItems.filter { $0.friendID == friend.id }
        if existingShared.isEmpty {
            let today = weekdayIndexToday()

            let sample = [
                SharedWeekItem(friendID: friend.id, title: "Math Lecture", weekday: today, startMinute: 9 * 60, durationMinute: 90),
                SharedWeekItem(friendID: friend.id, title: "UI Study Session", weekday: today, startMinute: 13 * 60, durationMinute: 60),
                SharedWeekItem(friendID: friend.id, title: "Physics Lab Prep", weekday: today, startMinute: 18 * 60, durationMinute: 60)
            ]

            for item in sample {
                modelContext.insert(item)
            }
        }

        let existingMessages = allMessages.filter { $0.friendID == friend.id }
        if existingMessages.isEmpty {
            let sampleMessages = [
                FriendMessage(friendID: friend.id, senderName: friend.name, text: "Hey, are you free after class?", isFromMe: false),
                FriendMessage(friendID: friend.id, senderName: "Me", text: "Yes, probably after 5.", isFromMe: true),
                FriendMessage(friendID: friend.id, senderName: friend.name, text: "Nice, let's plan study time.", isFromMe: false)
            ]

            for item in sampleMessages {
                modelContext.insert(item)
            }
        }

        try? modelContext.save()
    }

    func weekdayIndexToday() -> Int {
        let w = Calendar.current.component(.weekday, from: Date())
        return (w + 5) % 7
    }

    func hm(_ minute: Int) -> String {
        let m = max(0, min(1439, minute))
        let h = m / 60
        let mm = m % 60
        return String(format: "%02d:%02d", h, mm)
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
