//
//  JoinFocusSheet.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI
import SwiftData

struct JoinFocusSheet: View {
    let friend: Friend
    let session: FriendFocusSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale

    @State private var showFocusSession = false

    private var minutesLeft: Int {
        let endDate = session.startedAt.addingTimeInterval(TimeInterval(session.durationMinute * 60))
        let remaining = Int(endDate.timeIntervalSinceNow / 60.0)
        return max(0, remaining)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(hexColor(friend.colorHex).opacity(0.16))
                        .frame(width: 84, height: 84)

                    Image(systemName: friend.avatarSymbol)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(hexColor(friend.colorHex))
                }

                VStack(spacing: 8) {
                    Text("join_focus_title")
                        .font(.title2.bold())

                    Text(localizedSharedFocusSubtitle())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    infoRow(title: String(localized: "join_focus_session"), value: session.title)
                    infoRow(title: String(localized: "join_focus_duration"), value: localizedMinutes(session.durationMinute))
                    infoRow(title: String(localized: "join_focus_remaining"), value: localizedMinutesLeft(minutesLeft))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                )

                VStack(spacing: 12) {
                    Button {
                        let joinMessage = FriendMessage(
                            friendID: friend.id,
                            senderName: locale.language.languageCode?.identifier == "tr" ? "Ben" : "Me",
                            text: localizedJoinedMessage(),
                            isFromMe: true
                        )

                        modelContext.insert(joinMessage)
                        try? modelContext.save()

                        UserDefaults.standard.set("shared", forKey: "focus_mode")
                        UserDefaults.standard.set(friend.name, forKey: "focus_friend_name")
                        UserDefaults.standard.set(friend.id.uuidString, forKey: "focus_friend_id")

                        showFocusSession = true
                    } label: {
                        Text("join_focus_start_together")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        dismiss()
                    } label: {
                        Text("join_focus_not_now")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.06))
                            .foregroundStyle(.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("join_focus_shared_focus")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showFocusSession) {
                FocusSessionView(
                    taskID: nil,
                    taskTitle: localizedFocusWithFriendTitle(),
                    onStartFocus: { _, _ in },
                    onTick: { _ in },
                    onFinishFocus: { _, _, _, _, _, _ in
                        dismiss()
                    },
                    workoutExercises: nil
                )
            }
        }
    }

    func localizedSharedFocusSubtitle() -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(friend.name) şu anda paylaşılan bir odak oturumunda."
        } else {
            return "\(friend.name) is currently in a shared focus session."
        }
    }

    func localizedMinutes(_ minutes: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(minutes) dk"
        } else {
            return "\(minutes) min"
        }
    }

    func localizedMinutesLeft(_ minutes: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(minutes) dk kaldı"
        } else {
            return "\(minutes) min left"
        }
    }

    func localizedJoinedMessage() -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(friend.name) ile paylaşılan odak oturumuna katıldım."
        } else {
            return "I joined \(friend.name)’s shared focus session."
        }
    }

    func localizedFocusWithFriendTitle() -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(friend.name) ile odaklan"
        } else {
            return "Focus with \(friend.name)"
        }
    }

    func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }
}
