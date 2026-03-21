//
//  SharedWeekView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 21.03.2026.
//

import SwiftUI

struct SharedWeekView: View {
    let friend: Friend

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var session: SessionStore
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    private let palette = ThemePalette()
    private let dayTitles = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]

    @State private var selectedDay: Int = 0

    private var friendUserID: UUID? {
        friend.backendUserID
    }

    private var isSharedEnabled: Bool {
        guard let friendUserID else { return false }
        return friendStore.weekShareEnabledByUserID[friendUserID] ?? false
    }

    private var sharedItems: [FriendWeekShareDTO] {
        guard let friendUserID else { return [] }
        return friendStore.sharedWeekItemsByUserID[friendUserID] ?? []
    }

    private var selectedDayItems: [FriendWeekShareDTO] {
        sharedItems
            .filter { $0.weekday == selectedDay }
            .sorted { $0.start_minute < $1.start_minute }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 18) {
                    header

                    VStack(alignment: .leading, spacing: 16) {
                        Text("\(friend.name)'s Shared Week")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)

                        if isSharedEnabled {
                            Text("Haftalık planını seninle paylaştı.")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        } else {
                            Text("\(friend.name) henüz haftasını seninle paylaşmadı.")
                                .font(.subheadline)
                                .foregroundStyle(palette.secondaryText)
                        }

                        dayPicker

                        if !isSharedEnabled {
                            emptyShareState
                        } else if selectedDayItems.isEmpty {
                            emptyDayState
                        } else {
                            VStack(spacing: 12) {
                                ForEach(selectedDayItems) { item in
                                    sharedRow(item: item)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(cardBackground)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            selectedDay = weekdayIndexToday()

            guard let friendUserID else { return }

            await friendStore.loadWeekShareState(for: friendUserID)
            await friendStore.loadSharedWeekItems(for: friendUserID)
        }
    }

    var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(palette.cardFill)
                            .overlay(
                                Circle().stroke(palette.cardStroke, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Shared Week")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
    }

    var dayPicker: some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { day in
                let selected = selectedDay == day

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        selectedDay = day
                    }
                } label: {
                    Text(dayTitles[day])
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selected ? .white : palette.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selected ? Color.accentColor : palette.secondaryCardFill)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    var emptyShareState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(palette.secondaryText)

            Text("Paylaşılan hafta görünmüyor")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            Text("Arkadaşın Share My Week ayarını açtığında burada gerçek planı göreceksin.")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    var emptyDayState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 28))
                .foregroundStyle(palette.secondaryText)

            Text("Bu gün için plan yok")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            Text("\(friend.name) bu gün için bir etkinlik paylaşmamış.")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    func sharedRow(item: FriendWeekShareDTO) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor.opacity(0.14))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "calendar")
                        .foregroundStyle(Color.accentColor)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Text("\(hm(item.start_minute)) – \(hm(item.start_minute + item.duration_minute))")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)

                if let details = item.details,
                   !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.secondaryCardFill)
        )
    }

    func weekdayIndexToday() -> Int {
        let w = Calendar.current.component(.weekday, from: Date())
        return (w + 5) % 7
    }

    func hm(_ minute: Int) -> String {
        let m = max(0, min(1439, minute))
        let h = m / 60
        let mm = m % 60
        return String(format: "%02d:%02d", h, mm)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }
}
