//
//  UpdoProfileShareSheet.swift
//  DailyTodo
//
//  The profile share experience. Instead of dumping an image into the system
//  share sheet, the card is first staged in-app like a product: floating on a
//  glow, entrance animation, then a single share CTA that renders the exact
//  same card (ImageRenderer, story-friendly) into the system sheet.
//

import SwiftUI

// MARK: - Card data

struct ProfileShareCardData {
    let name: String
    let title: String
    let school: String?
    let level: Int
    let progress: CGFloat
    let accent: Color
    let secondary: Color
    let friendCount: Int
    let crewCount: Int
    let streak: Int
    let avatar: UIImage?
}

// MARK: - Presentation sheet

struct UpdoProfileShareSheet: View {
    let data: ProfileShareCardData

    @Environment(\.dismiss) private var dismiss

    @State private var appeared = false
    @State private var shareImage: UIImage?
    @State private var showSystemShare = false

    var body: some View {
        ZStack {
            // Stage: near-black with the card's own accent bleeding from above.
            Color(arenaHex: "#06080D").ignoresSafeArea()

            RadialGradient(
                colors: [data.accent.opacity(0.16), .clear],
                center: .top,
                startRadius: 30,
                endRadius: 460
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 18)

                Spacer(minLength: 16)

                UpdoProfileShareCard(data: data)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: data.accent.opacity(0.28), radius: 36, y: 18)
                    .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                    .scaleEffect(appeared ? 1 : 0.88)
                    .opacity(appeared ? 1 : 0)
                    .rotation3DEffect(
                        .degrees(appeared ? 0 : 7),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 0.6
                    )

                Text(tr("pe_share_caption"))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.42))
                    .padding(.top, 18)
                    .opacity(appeared ? 1 : 0)

                Spacer(minLength: 16)

                shareCTA
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.78).delay(0.08)) {
                appeared = true
            }
        }
        .sheet(isPresented: $showSystemShare) {
            if let shareImage {
                ShareSheet(items: [shareImage])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(data.accent)
                    .frame(width: 18, height: 1)

                Text(tr("pe_share_title_caps"))
                    .font(.system(size: 10.5, weight: .black, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(data.accent)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var shareCTA: some View {
        Button {
            HapticManager.shared.action()

            let renderer = ImageRenderer(content: UpdoProfileShareCard(data: data))
            renderer.scale = 3

            guard let image = renderer.uiImage else { return }
            shareImage = image
            showSystemShare = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .bold))

                Text(tr("pe_share_cta"))
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [data.accent, data.secondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            )
            .shadow(color: data.accent.opacity(0.35), radius: 14, y: 6)
        }
        .buttonStyle(UpdoPressButtonStyle())
    }
}

// MARK: - The card itself (static — ImageRenderer-safe)

struct UpdoProfileShareCard: View {
    let data: ProfileShareCardData

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 34)

            ZStack {
                Circle()
                    .fill(data.accent.opacity(0.16))
                    .frame(width: 210, height: 210)
                    .blur(radius: 40)

                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 8)
                    .frame(width: 134, height: 134)

                Circle()
                    .trim(from: 0, to: min(max(data.progress, 0), 1))
                    .stroke(
                        AngularGradient(
                            colors: [data.accent.opacity(0.55), data.secondary, data.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 134, height: 134)

                ProfileAvatarCircle(
                    image: data.avatar,
                    name: data.name,
                    accent: data.accent,
                    size: 112
                )

                HStack(spacing: 5) {
                    Text(tr("iid_level_caps"))
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(.black.opacity(0.6))

                    Text("\(data.level)")
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .italic()
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 11)
                .frame(height: 26)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [data.accent, data.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                )
                .offset(y: 67)
            }
            .padding(.bottom, 24)

            Text(data.name)
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(data.title)
                .font(.system(size: 22, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(
                    LinearGradient(
                        colors: [data.accent, data.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 2)

            if let school = data.school {
                Text(school.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 7)
            }

            HStack(spacing: 7) {
                Text("\(data.friendCount) \(tr("iid_stat_friends_caps"))")
                Text("·").foregroundStyle(.white.opacity(0.25))
                Text("\(data.crewCount) \(tr("iid_stat_crews_caps"))")

                if data.streak > 0 {
                    Text("·").foregroundStyle(.white.opacity(0.25))
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color(arenaHex: AppArenaPalette.gold))
                        Text("\(data.streak) \(tr("iid_stat_streak_caps"))")
                    }
                }
            }
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(.white.opacity(0.6))
            .padding(.top, 14)

            Spacer(minLength: 26)

            HStack(spacing: 5) {
                Text("updo")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white.opacity(0.85))

                Circle()
                    .fill(data.accent)
                    .frame(width: 4, height: 4)
                    .offset(y: 4)
            }
            .padding(.bottom, 22)
        }
        .frame(width: 340, height: 470)
        .background(
            ZStack {
                LinearGradient(
                    colors: [Color(arenaHex: "#0C101B"), Color(arenaHex: "#07090F")],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [data.accent.opacity(0.12), .clear],
                    center: .top,
                    startRadius: 20,
                    endRadius: 320
                )
            }
        )
    }
}
