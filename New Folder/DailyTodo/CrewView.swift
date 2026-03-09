//
//  CrewView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 9.03.2026.
//

import SwiftUI
import SwiftData

struct CrewView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Crew.createdAt, order: .reverse)
    private var crews: [Crew]

    @Query private var members: [CrewMember]
    @Query private var tasks: [CrewTask]

    @State private var showCreateCrew = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection

                    if crews.isEmpty {
                        emptyStateCard
                    } else {
                        crewsSection
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Crew")
            .sheet(isPresented: $showCreateCrew) {
                CreateCrewView()
            }
        }
    }
}

// MARK: - Sections
private extension CrewView {

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Crews")
                        .font(.title2.bold())

                    Text("Build together, focus together.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showCreateCrew = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.accentColor.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    var emptyStateCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 34))
                .foregroundStyle(.accent)

            Text("No crew yet")
                .font(.headline)

            Text("Create your first crew and start building projects together.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showCreateCrew = true
            } label: {
                Text("Create Crew")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(cardBackground)
    }

    var crewsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(crews) { crew in
                NavigationLink {
                    CrewDetailView(crew: crew)
                } label: {
                    crewCard(for: crew)
                }
                .buttonStyle(.plain)
            }
        }
    }

    func crewCard(for crew: Crew) -> some View {
        let crewMembers = members.filter { $0.crewID == crew.id }
        let crewTasks = tasks.filter { $0.crewID == crew.id }
        let completedTasks = crewTasks.filter(\.isDone).count
        let progress = crewTasks.isEmpty ? 0 : Double(completedTasks) / Double(crewTasks.count)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: crew.colorHex).opacity(0.18))
                        .frame(width: 48, height: 48)

                    Image(systemName: crew.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color(hex: crew.colorHex))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(crew.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("\(crewMembers.count) members")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(progress * 100))%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: progress)
                    .tint(Color(hex: crew.colorHex))
                    .scaleEffect(y: 1.6)
            }

            HStack(spacing: 10) {
                miniPill(
                    icon: "checkmark.circle.fill",
                    text: "\(completedTasks)/\(crewTasks.count) tasks",
                    tint: Color(hex: crew.colorHex)
                )

                if let firstMember = crewMembers.first {
                    miniPill(
                        icon: firstMember.avatarSymbol,
                        text: firstMember.name,
                        tint: .secondary
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    func miniPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
        )
        .foregroundStyle(tint)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

// MARK: - Preview helper color
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
