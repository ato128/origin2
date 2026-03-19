//
//  CrewChatView+Focus.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension CrewChatView {
    var focusDurationSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("Start Shared Focus")
                    .font(.title3.bold())
                    .padding(.top, 8)

                Button {
                    startFocusSession(minutes: 25)
                } label: {
                    focusOptionRow(title: "25 min", subtitle: "Quick focus")
                }
                .buttonStyle(.plain)

                Button {
                    startFocusSession(minutes: 50)
                } label: {
                    focusOptionRow(title: "50 min", subtitle: "Deep work")
                }
                .buttonStyle(.plain)

                VStack(spacing: 10) {
                    Stepper("Custom: \(customFocusMinutes) min", value: $customFocusMinutes, in: 5...180, step: 5)

                    Button {
                        startFocusSession(minutes: customFocusMinutes)
                    } label: {
                        Text("Start Custom Focus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green.opacity(0.16))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(palette.cardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(palette.cardStroke, lineWidth: 1)
                        )
                )

                Spacer()
            }
            .padding(20)
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        showFocusDurationSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    func focusOptionRow(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer()

            Image(systemName: "timer")
                .foregroundStyle(.green)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    func startFocusSession(minutes: Int) {
        showFocusDurationSheet = false

        let memberName = currentDisplayName()
        let senderID = session.currentUser?.id

        Task {
            await crewStore.createFocusRecord(
                crewID: crew.id,
                userID: senderID,
                memberName: memberName,
                minutes: minutes
            )

            await crewStore.createActivity(
                crewID: crew.id,
                memberName: memberName,
                actionText: "started a \(minutes) min shared focus session"
            )

            do {
                try await crewStore.createCrewMessage(
                    crewID: crew.id,
                    senderID: senderID,
                    senderName: memberName,
                    text: "started a \(minutes) min shared focus session",
                    isSystemMessage: true
                )
            } catch {
                print("START FOCUS MESSAGE ERROR:", error.localizedDescription)
            }
        }
    }
}
