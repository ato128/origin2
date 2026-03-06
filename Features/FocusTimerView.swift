//
//  FocusTimerView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 6.03.2026.
//

import SwiftUI

struct FocusTimerView: View {

    @State private var timeRemaining = 1500
    @State private var timer: Timer?

    var body: some View {

        VStack(spacing: 20) {

            Text("Focus Timer")
                .font(.title.bold())

            Text(timeString)
                .font(.system(size: 48, weight: .bold, design: .rounded))

            Button("Start") {
                startTimer()
            }

        }
        .padding()
    }

    var timeString: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func startTimer() {

        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            }
        }
    }
}
