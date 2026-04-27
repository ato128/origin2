//
//  IdentityLevelUpCelebrationView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 27.04.2026.
//

import SwiftUI
import UIKit

struct IdentityLevelUpCelebrationView: View {
    let oldLevel: Int
    let newLevel: Int
    let title: String
    let accent: Color
    let onFinish: () -> Void

    @State private var showContent = false
    @State private var burst = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [
                    accent.opacity(0.45),
                    .clear
                ],
                center: .center,
                startRadius: 10,
                endRadius: 420
            )
            .ignoresSafeArea()
            .scaleEffect(burst ? 1.25 : 0.75)
            .opacity(burst ? 1 : 0.4)

            ForEach(0..<28, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? accent : .white)
                    .frame(width: CGFloat.random(in: 5...10), height: CGFloat.random(in: 5...10))
                    .offset(
                        x: burst ? CGFloat.random(in: -180...180) : 0,
                        y: burst ? CGFloat.random(in: -330...330) : 0
                    )
                    .opacity(burst ? 0.95 : 0)
                    .animation(.spring(response: 0.85, dampingFraction: 0.72).delay(Double(index) * 0.012), value: burst)
            }

            VStack(spacing: 22) {
                Text("LEVEL UP")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(accent)
                    .opacity(showContent ? 1 : 0)

                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 154, height: 154)

                    Circle()
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                        .frame(width: 154, height: 154)

                    VStack(spacing: 2) {
                        Text("Lv")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))

                        Text("\(newLevel)")
                            .font(.system(size: 68, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .scaleEffect(showContent ? 1 : 0.65)
                .opacity(showContent ? 1 : 0)

                VStack(spacing: 8) {
                    Text("Lv.\(oldLevel) → Lv.\(newLevel)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))

                    Text(title)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 18)

                Button {
                    onFinish()
                } label: {
                    Text("Devam Et")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .padding(.top, 8)
                .opacity(showContent ? 1 : 0)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            withAnimation(.spring(response: 0.65, dampingFraction: 0.75)) {
                showContent = true
                burst = true
            }
        }
    }
}
