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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var session: SessionStore

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    @Query(sort: \SharedWeekItem.createdAt, order: .forward)
    private var allSharedItems: [SharedWeekItem]

    @Query(sort: \FriendFocusSession.startedAt, order: .reverse)
    private var allFocusSessions: [FriendFocusSession]

    @State private var showCopied = false
    @State private var showSharedFocusSheet = false
    @State private var showHero = false
    @State private var showSchedule = false
    @State private var showMessagesCard = false
    @State private var showActionsCard = false
    
    private var friendshipID: UUID? {
        friend.backendFriendshipID
    }

    private var backendMessages: [FriendChatMessageItem] {
        guard let friendshipID else { return [] }
        return friendStore.friendMessagesByFriendship[friendshipID] ?? []
    }

    private var isBackendFriend: Bool {
        friend.backendFriendshipID != nil
    }

    private var messages: [FriendChatMessageItem] {
        if isBackendFriend {
            return backendMessages
        } else {
            return []
        }
    }
    private var todaySchedule: [SharedWeekItem] {
        guard !isBackendFriend else { return [] }

        let today = weekdayIndexToday()
        return allSharedItems
            .filter { $0.friendID == friend.id && $0.weekday == today }
            .sorted { $0.startMinute < $1.startMinute }
    }

    private var weekCount: Int {
        allSharedItems.filter { $0.friendID == friend.id }.count
    }

    private var activeFocusSession: FriendFocusSession? {
        guard !isBackendFriend else { return nil }

        return allFocusSessions.first { $0.friendID == friend.id && $0.isActive }
    }
    
    

    var body: some View {
        ZStack(alignment: .top) {
            ambientBackground

            ScrollView {
                VStack(spacing: 18) {
                    Color.clear.frame(height: 76)

                    customHeader
                    Button("➕ Test Friend Request") {
                        Task {
                            guard let currentUserID = session.currentUser?.id else { return }

                            do {
                                let target = try await friendStore.findUserByUsername("berill")

                                try await friendStore.sendFriendRequest(
                                    to: target.id,
                                    currentUserID: currentUserID
                                )

                                print("✅ REQUEST SENT")
                            } catch {
                                print("❌ REQUEST ERROR:", error.localizedDescription)
                            }
                        }
                    }
                    .padding()

                    heroCard
                        .offset(y: showHero ? 0 : 18)
                        .opacity(showHero ? 1 : 0)
                        .scaleEffect(showHero ? 1 : 0.985)

                    todayScheduleCard
                        .offset(y: showSchedule ? 0 : 18)
                        .opacity(showSchedule ? 1 : 0)
                        .scaleEffect(showSchedule ? 1 : 0.985)

                    recentMessagesCard
                        .offset(y: showMessagesCard ? 0 : 18)
                        .opacity(showMessagesCard ? 1 : 0)
                        .scaleEffect(showMessagesCard ? 1 : 0.985)

                    actionsCard
                        .offset(y: showActionsCard ? 0 : 18)
                        .opacity(showActionsCard ? 1 : 0)
                        .scaleEffect(showActionsCard ? 1 : 0.985)

                    Spacer(minLength: 90)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottom) {
            if showCopied {
                Text("Copied")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(palette.cardFill)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(palette.cardStroke, lineWidth: 1)
                    )
                    .shadow(color: palette.shadowColor, radius: 8)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            

            showHero = false
            showSchedule = false
            showMessagesCard = false
            showActionsCard = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    showHero = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                    showSchedule = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                    showMessagesCard = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                    showActionsCard = true
                }
            }
        }
        .task {
            guard let friendshipID else { return }

            await friendStore.loadMessages(
                for: friendshipID,
                currentUserID: session.currentUser?.id
            )

            await friendStore.markMessagesSeen(
                friendshipID: friendshipID,
                currentUserID: session.currentUser?.id
            )

            friendStore.subscribeToFriendMessagesRealtime(
                friendshipID: friendshipID,
                currentUserID: session.currentUser?.id
            )
        }
        .sheet(isPresented: $showSharedFocusSheet) {
            FocusSessionView(
                taskID: nil, // 👈 EKLE

                taskTitle: "Focus with \(friend.name)",

                onStartFocus: { _, _ in },

                onTick: { _ in },

                onFinishFocus: { _, _, _, _, _, _ in },

                workoutExercises: nil
            )
        }
    }
}

private extension FriendDetailView {

    var ambientBackground: some View {
        ZStack(alignment: .topLeading) {
            AppBackground()

            if appTheme == AppTheme.gradient.rawValue {
                RadialGradient(
                    colors: [
                        hexColor(friend.colorHex).opacity(0.16),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 30,
                    endRadius: 260
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        Color.blue.opacity(0.08),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 60,
                    endRadius: 320
                )
                .ignoresSafeArea()
            }
        }
    }

    var customHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(palette.cardFill)
                            .overlay(
                                Circle()
                                    .stroke(palette.cardStroke, lineWidth: 1)
                            )
                    )
                    .shadow(color: palette.shadowColor, radius: 10, y: 4)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(friend.name)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Spacer()

            Color.clear.frame(width: 56, height: 56)
        }
    }

    var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(hexColor(friend.colorHex).opacity(0.16))
                        .frame(width: 78, height: 78)

                    Image(systemName: friend.avatarSymbol)
                        .font(.title.weight(.bold))
                        .foregroundStyle(hexColor(friend.colorHex))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(friend.name)
                    
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text(friend.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)

                    if isBackendFriend {
                        Text("Connected via server")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    HStack(spacing: 8) {
                        Circle()
                            .fill(friend.isOnline ? .green : Color.gray.opacity(0.5))
                            .frame(width: 8, height: 8)

                        Text(friend.isOnline ? "Online" : "Offline")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)
                    }

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

                Spacer()
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
        .shadow(color: hexColor(friend.colorHex).opacity(0.10), radius: 12, y: 6)
    }

    var todayScheduleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today Schedule")
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Text("\(todaySchedule.count) items")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
            }

            if todaySchedule.isEmpty {
                Text("No shared schedule for today.")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            } else {
                ForEach(todaySchedule) { item in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(hexColor(friend.colorHex).opacity(0.14))
                                .frame(width: 52, height: 52)

                            Image(systemName: "calendar")
                                .foregroundStyle(hexColor(friend.colorHex))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryText)

                            Text("\(hm(item.startMinute)) – \(hm(item.startMinute + item.durationMinute))")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(palette.secondaryCardFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(palette.cardStroke.opacity(0.7), lineWidth: 1)
                            )
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
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Text("\(messages.suffix(3).count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
            }

            if messages.isEmpty {
                Text(isBackendFriend ? "No backend messages yet." : "No messages yet.")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            } else {
                ForEach(Array(messages.suffix(3))) { message in
                    HStack {
                        if message.isFromMe { Spacer(minLength: 40) }

                        Text(message.text)
                            .font(.subheadline)
                            .foregroundStyle(message.isFromMe ? .white : palette.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(
                                        message.isFromMe
                                        ? Color.accentColor.opacity(appTheme == AppTheme.light.rawValue ? 0.90 : 0.24)
                                        : palette.secondaryCardFill
                                    )
                            )

                        if !message.isFromMe { Spacer(minLength: 40) }
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
                .foregroundStyle(palette.primaryText)

            HStack(spacing: 12) {
                NavigationLink {
                    if isBackendFriend {
                        FriendChatView(friend: friend)
                            .environmentObject(friendStore)
                            .environmentObject(session)
                    } else {
                        FriendChatView(friend: friend)
                            .environmentObject(friendStore)
                            .environmentObject(session)
                    }
                }label: {
                    actionTile(
                        title: "Message",
                        systemImage: "message.fill"
                    )
                }
                .buttonStyle(.plain)

                actionButton(
                    title: activeFocusSession == nil ? "Start Focus" : "Stop Focus",
                    systemImage: activeFocusSession == nil ? "stopwatch.fill" : "stop.circle.fill"
                ) {
                    if isBackendFriend {
                        print("🚫 Backend friend focus not implemented yet")
                        return
                    } else {
                        stopSharedFocus()
                    }
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

    func actionTile(title: String, systemImage: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(palette.primaryText)

            Text(title)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.secondaryCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardStroke.opacity(0.7), lineWidth: 1)
                )
        )
    }

    func startSharedFocusAndJoin() {
        let focusSession = FriendFocusSession(
            ownerUserID: session.currentUser?.id,
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

        let joinMessage = FriendMessage(
            friendID: friend.id,
            senderName: "Me",
            text: "I joined \(friend.name)’s shared focus session.",
            isFromMe: true
        )

        modelContext.insert(focusSession)
        modelContext.insert(startMessage)
        modelContext.insert(joinMessage)

        try? modelContext.save()

        UserDefaults.standard.set("shared", forKey: "focus_mode")
        UserDefaults.standard.set(friend.name, forKey: "focus_friend_name")
        UserDefaults.standard.set(friend.id.uuidString, forKey: "focus_friend_id")

        showSharedFocusSheet = true
    }

    func stopSharedFocus() {
        guard let active = activeFocusSession else { return }

        active.isActive = false

        let stopMessage = FriendMessage(
            friendID: friend.id,
            senderName: friend.name,
            text: "\(friend.name) ended the shared focus session.",
            isFromMe: false
        )

        modelContext.insert(stopMessage)
        try? modelContext.save()
    }

    func statPill(title: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.primaryText)
                .monospacedDigit()

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.secondaryCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardStroke.opacity(0.7), lineWidth: 1)
                )
        )
    }

    func actionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            actionTile(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
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
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }
}
