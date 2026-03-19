//
//  CrewChatInfoBackendView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import SwiftUI

struct CrewChatInfoBackendView: View {
    let crew: WeekCrewItem

    var body: some View {
        List {
            Section("Crew") {
                HStack {
                    Image(systemName: crew.icon)
                    Text(crew.name)
                }

                Text("Backend crew chat info screen")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Crew Info")
        .navigationBarTitleDisplayMode(.inline)
    }
}
