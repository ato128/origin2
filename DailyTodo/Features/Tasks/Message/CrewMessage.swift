//
//  CrewMessage.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 15.03.2026.
//

import Foundation
import SwiftData

@Model
final class CrewMessage {
    var id: UUID
    var crewID: UUID
    var senderName: String
    var text: String
    var isFromMe: Bool
    var createdAt: Date
    var isRead: Bool
   

    init(
        id: UUID = UUID(),
        crewID: UUID,
        senderName: String,
        text: String,
        isFromMe: Bool,
        createdAt: Date = Date()
       
    ) {
        self.id = id
        self.crewID = crewID
        self.senderName = senderName
        self.text = text
        self.isFromMe = isFromMe
        self.createdAt = createdAt
        self.isRead = false
       
    }
}
