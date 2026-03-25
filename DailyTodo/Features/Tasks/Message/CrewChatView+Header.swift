//
//  CrewChatView+Header.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension CrewChatView {
    var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle()
                            .fill(palette.cardFill)
                            .overlay(
                                Circle()
                                    .stroke(palette.cardStroke, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            Button {
                showCrewInfo = true
            } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(hexColor(crew.colorHex).opacity(0.16))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: crew.icon)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(hexColor(crew.colorHex))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(crew.name)
                            .font(.headline)
                            .foregroundStyle(palette.primaryText)

                        Text("crew_chat_header_subtitle")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.35))
                .ignoresSafeArea(edges: .top)
        )
    }

    var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(hexColor(crew.colorHex).opacity(0.14))
                    .frame(width: 82, height: 82)

                Image(systemName: "person.3.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(hexColor(crew.colorHex))
            }

            Text("crew_chat_empty_title")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.primaryText)

            Text("crew_chat_empty_subtitle")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
