//
//  FriendRequest.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 20.03.2026.
//

import Foundation
import SwiftData

@Model
final class FriendRequest {
    var id: UUID
    var ownerUserID: UUID?
    var name: String
    var username: String
    var avatarSymbol: String
    var colorHex: String
    var createdAt: Date
    var directionRaw: String
    var statusRaw: String

    init(
        id: UUID = UUID(),
        ownerUserID: UUID? = nil,
        name: String,
        username: String,
        avatarSymbol: String = "person.fill",
        colorHex: String = "#3B82F6",
        createdAt: Date = Date(),
        direction: FriendRequestDirection,
        status: FriendRequestStatus = .pending
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.name = name
        self.username = username
        self.avatarSymbol = avatarSymbol
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.directionRaw = direction.rawValue
        self.statusRaw = status.rawValue
    }

    var direction: FriendRequestDirection {
        get { FriendRequestDirection(rawValue: directionRaw) ?? .incoming }
        set { directionRaw = newValue.rawValue }
    }

    var status: FriendRequestStatus {
        get { FriendRequestStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}

enum FriendRequestDirection: String, CaseIterable, Codable {
    case incoming
    case sent
}

enum FriendRequestStatus: String, CaseIterable, Codable {
    case pending
    case accepted
    case declined
    case cancelled
}
