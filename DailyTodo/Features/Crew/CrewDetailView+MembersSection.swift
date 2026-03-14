//
//  CrewDetailView+MembersSection.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 14.03.2026.
//

import SwiftUI
import SwiftData

extension CrewDetailView {
    func membersSection(_ crewMembers: [CrewMember]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Members")
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Button {
                    showAddMemberSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)

                Text("\(crewMembers.count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(palette.secondaryCardFill)
                    )
                    .foregroundStyle(palette.secondaryText)
            }

            if crewMembers.isEmpty {
                emptyMiniState(text: "No members yet • Tap + to add one")
            } else {
                ForEach(crewMembers) { member in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(hexColor(crew.colorHex).opacity(0.14))
                                .frame(width: 42, height: 42)

                            Image(systemName: member.avatarSymbol)
                                .foregroundStyle(hexColor(crew.colorHex))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryText)

                            Text(member.role)
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Circle()
                                .fill(member.isOnline ? Color.green : Color.gray.opacity(0.4))
                                .frame(width: 8, height: 8)

                            Text(member.isOnline ? "Online" : "Away")
                                .font(.caption2)
                                .foregroundStyle(palette.secondaryText)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(palette.secondaryCardFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
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
}
