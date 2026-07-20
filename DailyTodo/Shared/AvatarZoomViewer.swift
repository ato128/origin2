//
//  AvatarZoomViewer.swift
//  DailyTodo
//
//  Fullscreen profile-photo viewer: pinch to zoom, double-tap to toggle,
//  drag down to dismiss. Presented from profile details wherever a real
//  photo exists.
//

import SwiftUI
import UIKit

struct AvatarZoomViewer: View {
    let image: UIImage
    let name: String

    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black
                .opacity(dismissProgressOpacity)
                .ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(magnification.simultaneously(with: drag))
                .onTapGesture(count: 2) { toggleZoom() }

            VStack {
                HStack {
                    Text(name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle().fill(Color.white.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    /// Background fades as the photo is dragged down at 1x — the standard
    /// "sürükle kapat" affordance.
    private var dismissProgressOpacity: Double {
        guard scale <= 1.01 else { return 1 }
        let progress = min(max(offset.height, 0) / 300, 0.6)
        return 1 - progress
    }

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 5)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.02 {
                    withAnimation(.spring(response: 0.3)) {
                        scale = 1
                        offset = .zero
                    }
                    lastScale = 1
                    lastOffset = .zero
                }
            }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1.01 {
                    // Zoomed: pan the image.
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                } else {
                    // 1x: vertical pull toward dismiss.
                    offset = CGSize(width: 0, height: max(0, value.translation.height))
                }
            }
            .onEnded { value in
                if scale > 1.01 {
                    lastOffset = offset
                } else if offset.height > 130 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.3)) { offset = .zero }
                    lastOffset = .zero
                }
            }
    }

    private func toggleZoom() {
        withAnimation(.spring(response: 0.3)) {
            if scale > 1.01 {
                scale = 1
                offset = .zero
            } else {
                scale = 2.4
            }
        }
        lastScale = scale
        lastOffset = offset
    }
}
