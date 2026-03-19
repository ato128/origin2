//
//  CrewChatView+Models.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import SwiftUI

struct TypingDotsView: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            dot(delay: 0.0)
            dot(delay: 0.18)
            dot(delay: 0.36)
        }
        .onAppear {
            animate = true
        }
        .onDisappear {
            animate = false
        }
    }

    private func dot(delay: Double) -> some View {
        Circle()
            .fill(Color.secondary)
            .frame(width: 5, height: 5)
            .scaleEffect(animate ? 1.0 : 0.7)
            .opacity(animate ? 1.0 : 0.45)
            .animation(
                .easeInOut(duration: 0.75)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: animate
            )
    }
}

struct OptimisticCrewMessage: Identifiable, Equatable {
    let id: UUID
    let crewID: UUID
    let senderID: UUID?
    let senderName: String
    let text: String
    let createdAt: Date
}

enum CrewMessageRowItem: Identifiable, Equatable {
    case backend(CrewMessageDTO)
    case optimistic(OptimisticCrewMessage)

    var id: UUID {
        switch self {
        case .backend(let message): return message.id
        case .optimistic(let message): return message.id
        }
    }

    var text: String {
        switch self {
        case .backend(let message): return message.text
        case .optimistic(let message): return message.text
        }
    }

    var senderID: UUID? {
        switch self {
        case .backend(let message): return message.sender_id
        case .optimistic(let message): return message.senderID
        }
    }

    var senderName: String {
        switch self {
        case .backend(let message): return message.sender_name
        case .optimistic(let message): return message.senderName
        }
    }

    var createdAt: Date {
        switch self {
        case .backend(let message):
            return ISO8601DateFormatter().date(from: message.created_at) ?? Date()
        case .optimistic(let message):
            return message.createdAt
        }
    }

    var reaction: String? {
        switch self {
        case .backend(let message): return message.reaction
        case .optimistic: return nil
        }
    }

    var backendMessage: CrewMessageDTO? {
        switch self {
        case .backend(let message): return message
        case .optimistic: return nil
        }
    }

    var isOptimistic: Bool {
        switch self {
        case .backend: return false
        case .optimistic: return true
        }
    }
}
