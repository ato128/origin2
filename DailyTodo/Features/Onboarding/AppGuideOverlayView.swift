//
//  AppGuideOverlayView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.03.2026.
//

import SwiftUI

struct AppGuideOverlayView: View {
    @EnvironmentObject var guide: AppGuideManager

    let onPrimaryAction: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(guide.currentStep.title)
                            .font(.title3.bold())
                            .foregroundStyle(.white)

                        Spacer()

                        Text(guide.progressText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    Text(guide.currentStep.message)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.84))

                    if guide.currentStep.requiresUserAction {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.tap.fill")
                                .foregroundStyle(.yellow)

                            Text("Bu adım kullanıcı etkileşimiyle ilerler.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.86))
                        }
                        .padding(.top, 2)
                    }

                    HStack(spacing: 10) {
                        if guide.currentStep.rawValue > 0 {
                            Button {
                                onBack()
                            } label: {
                                Text("Back")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.08))
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            onPrimaryAction()
                        } label: {
                            Text(guide.currentStep.primaryButtonTitle)
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        onSkip()
                    } label: {
                        Text("Skip tutorial")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 120)
            }
        }
    }
}
