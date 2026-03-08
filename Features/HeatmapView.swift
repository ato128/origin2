//
//  HeatmapView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 7.03.2026.
//

import SwiftUI
import Foundation

struct HeatmapCell: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int
}

struct HeatmapView: View {
    let tasks: [DTTaskItem]

    @State private var selectedCell: HeatmapCell?
    @State private var animateCells = false

    private let calendar = Calendar.current

    private var cells: [HeatmapCell] {
        let today = calendar.startOfDay(for: Date())

        let completedMap: [Date: Int] = Dictionary(
            grouping: tasks.filter { $0.isDone }.compactMap { task in
                task.completedAt.map { calendar.startOfDay(for: $0) }
            },
            by: { $0 }
        ).mapValues { $0.count }

        return (0..<28).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -(27 - offset), to: today) else {
                return nil
            }

            let day = calendar.startOfDay(for: date)
            return HeatmapCell(
                date: day,
                value: completedMap[day, default: 0]
            )
        }
    }

    private var maxValue: Int {
        max(cells.map(\.value).max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last 4 Weeks")
                    .font(.headline)

                Spacer()

                Text("28 gün")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                spacing: 6
            ) {
                ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color(for: cell.value))
                        .frame(height: 14)
                        .overlay {
                            if calendar.isDateInToday(cell.date) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            }

                            if selectedCell?.id == cell.id {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(Color.blue.opacity(0.9), lineWidth: 1.4)
                            }
                        }
                        .scaleEffect(
                            selectedCell?.id == cell.id
                            ? 1.08
                            : (animateCells ? (cell.value > 0 ? 1.0 : 0.96) : 0.75)
                        )
                        .opacity(animateCells ? 1 : 0.15)
                        .offset(y: animateCells ? 0 : 8)
                        .animation(
                            .spring(response: 0.42, dampingFraction: 0.82)
                                .delay(Double(index) * 0.015),
                            value: animateCells
                        )
                        .animation(
                            .spring(response: 0.32, dampingFraction: 0.78),
                            value: selectedCell?.id == cell.id
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                selectedCell = cell
                            }
                        }
                }
            }

            HStack(spacing: 10) {
                Text("Az")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    legendBox(for: 0)
                    legendBox(for: 1)
                    legendBox(for: 2)
                    legendBox(for: 4)
                }

                Text("Çok")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            if let selectedCell {
                HStack(spacing: 8) {
                    Image(systemName: selectedCell.value > 0 ? "checkmark.circle.fill" : "calendar")
                        .foregroundStyle(selectedCell.value > 0 ? .blue : .secondary)

                    Text(detailText(for: selectedCell))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.top, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .onAppear {
            selectedCell = cells.last
            animateCells = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                animateCells = true
            }
        }
    }

    private func legendBox(for value: Int) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color(for: value))
            .frame(width: 18, height: 10)
    }

    private func color(for value: Int) -> Color {
        guard value > 0 else {
            return Color.gray.opacity(0.18)
        }

        let normalized = Double(value) / Double(maxValue)

        switch normalized {
        case 0..<0.25:
            return Color.blue.opacity(0.28)
        case 0.25..<0.5:
            return Color.blue.opacity(0.45)
        case 0.5..<0.8:
            return Color.blue.opacity(0.68)
        default:
            return Color.blue.opacity(0.95)
        }
    }

    private func detailText(for cell: HeatmapCell) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMM, EEE"

        if cell.value == 0 {
            return "\(formatter.string(from: cell.date)) • tamamlanan görev yok"
        } else if cell.value == 1 {
            return "\(formatter.string(from: cell.date)) • 1 görev tamamlandı"
        } else {
            return "\(formatter.string(from: cell.date)) • \(cell.value) görev tamamlandı"
        }
    }
}

#Preview {
    HeatmapView(tasks: [])
        .padding()
        .background(Color.black)
}
