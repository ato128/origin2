//
//  CrewChatView+Header.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension CrewChatView {

    var ambientBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(crewChatHex: "#05060D"),
                    Color(crewChatHex: "#070713"),
                    Color(crewChatHex: "#07040C")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(hexColor(crew.colorHex).opacity(0.16))
                .frame(width: 300, height: 300)
                .blur(radius: 105)
                .offset(x: -175, y: 520)

            Circle()
                .fill(Color(crewChatHex: "#1593FF").opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 96)
                .offset(x: 165, y: -245)

            Circle()
                .fill(Color(crewChatHex: "#7C3AED").opacity(0.14))
                .frame(width: 300, height: 300)
                .blur(radius: 110)
                .offset(x: 180, y: 260)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.clear,
                    Color.black.opacity(0.44)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    var floatingTopControls: some View {
        ZStack(alignment: .top) {
            crewChatHeaderScrim
                .allowsHitTesting(false)

            HStack(alignment: .center, spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(crewChatCircleBackground)
                }
                .buttonStyle(.plain)

                Button {
                    showCrewInfo = true
                } label: {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        hexColor(crew.colorHex).opacity(0.92),
                                        Color(crewChatHex: "#7C3AED").opacity(0.78),
                                        Color(crewChatHex: "#FF5A44").opacity(0.52)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: crew.icon)
                                    .font(.system(size: 17, weight: .black))
                                    .foregroundStyle(.white)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(crew.name)
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            HStack(spacing: 6) {
                                Circle()
                                    .fill(activeFocusSession != nil ? Color(crewChatHex: "#A3E635") : Color(crewChatHex: "#2DD4FF"))
                                    .frame(width: 6, height: 6)

                                Text(activeFocusSession != nil ? "Live focus" : "Crew chat")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.58))
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 8)
                    .padding(.trailing, 12)
                    .frame(height: 46)
                    .background(crewChatCapsuleBackground)
                }
                .buttonStyle(.plain)

                Button {
                    showCrewInfo = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(crewChatCircleBackground)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }
    
    var crewChatHeaderScrim: some View {
        VStack(spacing: 0) {
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.94), location: 0.00),
                    .init(color: Color.black.opacity(0.86), location: 0.24),
                    .init(color: Color.black.opacity(0.62), location: 0.50),
                    .init(color: Color.black.opacity(0.30), location: 0.74),
                    .init(color: Color.black.opacity(0.10), location: 0.90),
                    .init(color: Color.clear, location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 168)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(0.10))
                    .frame(height: 34)
                    .blur(radius: 18)
                    .offset(y: 12)
            }

            Spacer(minLength: 0)
        }
        .background(
            VStack(spacing: 0) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.16)
                    .frame(height: 96)

                Spacer(minLength: 0)
            }
        )
    }

    func typingBanner(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "ellipsis.message.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color(crewChatHex: "#A3E635"))

            Text(text)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(crewChatHex: "#A3E635").opacity(0.075),
                            Color(crewChatHex: "#1593FF").opacity(0.050),
                            Color.white.opacity(0.045)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
        )
        .padding(.horizontal, 16)
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            hexColor(crew.colorHex).opacity(0.95),
                            Color(crewChatHex: "#7C3AED").opacity(0.82),
                            Color(crewChatHex: "#FF5A44").opacity(0.58)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 78, height: 78)
                .overlay(
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.white)
                )
                .shadow(color: hexColor(crew.colorHex).opacity(0.18), radius: 18, y: 8)

            VStack(spacing: 7) {
                Text("crew_chat_empty_title")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)

                Text("crew_chat_empty_subtitle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 26)
        .padding(.top, 80)
    }

    var crewChatCircleBackground: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.105),
                        Color.black.opacity(0.34),
                        Color.white.opacity(0.055)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.28)
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 14, y: 7)
    }
    var crewChatCapsuleBackground: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color(crewChatHex: "#1593FF").opacity(0.075),
                        Color(crewChatHex: "#7C3AED").opacity(0.060),
                        Color.white.opacity(0.055)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 12, y: 6)
    }
}

// MARK: - Color Hex

private extension Color {
    init(crewChatHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch cleaned.count {
        case 3:
            a = 255
            r = (int >> 8) * 17
            g = ((int >> 4) & 0xF) * 17
            b = (int & 0xF) * 17

        case 6:
            a = 255
            r = int >> 16
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        case 8:
            a = int >> 24
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        default:
            a = 255
            r = 255
            g = 255
            b = 255
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
