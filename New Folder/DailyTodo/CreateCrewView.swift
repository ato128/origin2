//
//  CreateCrewView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 10.03.2026.
//

import SwiftUI
import SwiftData

struct CreateCrewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var crewName: String = ""
    @State private var selectedIcon: String = "person.3.fill"
    @State private var selectedColorHex: String = "#3B82F6"

    private let iconOptions = [
        "person.3.fill",
        "books.vertical.fill",
        "hammer.fill",
        "laptopcomputer",
        "graduationcap.fill",
        "bolt.fill"
    ]

    private let colorOptions = [
        "#3B82F6",
        "#22C55E",
        "#F59E0B",
        "#EF4444",
        "#8B5CF6",
        "#14B8A6"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Crew Name") {
                    TextField("App Dev Crew", text: $crewName)
                }

                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(iconOptions, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.title3)
                                        .frame(width: 42, height: 42)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(selectedIcon == icon ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.10))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section("Color") {
                    HStack(spacing: 12) {
                        ForEach(colorOptions, id: \.self) { hex in
                            Button {
                                selectedColorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColorHex == hex ? Color.primary : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    Button("Create Crew") {
                        createCrew()
                    }
                    .disabled(crewName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Create Crew")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func createCrew() {
        let crew = Crew(
            name: crewName.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: selectedIcon,
            colorHex: selectedColorHex
        )

        modelContext.insert(crew)

        let sampleMembers = [
            CrewMember(crewID: crew.id, name: "Atakan", role: "Manager", isOnline: true, avatarSymbol: "person.fill"),
            CrewMember(crewID: crew.id, name: "Ahmet", role: "Designer", isOnline: false, avatarSymbol: "paintpalette.fill"),
            CrewMember(crewID: crew.id, name: "Selin", role: "Engineer", isOnline: true, avatarSymbol: "gearshape.fill")
        ]

        let sampleTasks = [
            CrewTask(crewID: crew.id, title: "Build first screen", assignedTo: "Atakan"),
            CrewTask(crewID: crew.id, title: "Plan project structure", assignedTo: "Ahmet"),
            CrewTask(crewID: crew.id, title: "Review ideas", assignedTo: "Selin", isDone: true)
        ]

        let sampleActivities = [
            CrewActivity(crewID: crew.id, memberName: "Atakan", actionText: "created the crew"),
            CrewActivity(crewID: crew.id, memberName: "Ahmet", actionText: "joined the crew"),
            CrewActivity(crewID: crew.id, memberName: "Selin", actionText: "completed a task")
        ]

        for item in sampleMembers { modelContext.insert(item) }
        for item in sampleTasks { modelContext.insert(item) }
        for item in sampleActivities { modelContext.insert(item) }

        try? modelContext.save()
        dismiss()
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 8:
            (a, r, g, b) = (
                (int >> 24) & 0xff,
                (int >> 16) & 0xff,
                (int >> 8) & 0xff,
                int & 0xff
            )
        case 6:
            (a, r, g, b) = (
                255,
                (int >> 16) & 0xff,
                (int >> 8) & 0xff,
                int & 0xff
            )
        default:
            (a, r, g, b) = (255, 59, 130, 246)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
