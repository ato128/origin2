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
                    Text("Join Focus")
                        .font(.title2.bold())

                    Text("\(friend.name) is currently in a shared focus session.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    infoRow(title: "Session", value: session.title)
                    infoRow(title: "Duration", value: "\(session.durationMinute) min")
                    infoRow(title: "Remaining", value: "\(minutesLeft) min left")
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
                            senderName: "Me",
                            text: "I joined \(friend.name)’s shared focus session.",
                            isFromMe: true
                        )

                        modelContext.insert(joinMessage)
                        try? modelContext.save()

                        showFocusSession = true
                    } label: {
                        Text("Start Focus Together")
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
                        Text("Not now")
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
            .navigationTitle("Shared Focus")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showFocusSession) {
                FocusSessionView(
                    taskTitle: "Focus with \(friend.name)",
                    onStartFocus: { _, _ in
                    },
                    onTick: { _ in
                    },
                    onFinishFocus: { _, _, _, _, _, _ in
                        dismiss()
                    }
                )
            }
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
