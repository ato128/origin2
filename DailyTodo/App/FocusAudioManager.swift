//
//  FocusAudioManager.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 10.04.2026.
//

import Foundation
import AVFoundation

final class FocusAudioManager {
    static let shared = FocusAudioManager()

    private var player: AVAudioPlayer?

    private init() {}

    func play(style: FocusStyle) {
        stop()

        guard let fileName = fileName(for: style) else { return }

        guard let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") else {
            print("🔇 Audio file not found: \(fileName).mp3")
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.volume = 0.45
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("🔇 Audio playback error: \(error)")
        }
    }

    func pause() {
        player?.pause()
    }

    func resume() {
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
    }

    private func fileName(for style: FocusStyle) -> String? {
        switch style {
        case .silent:
            return nil
        case .ambient:
            return "ambient_loop"
        case .rain:
            return "rain_loop"
        case .library:
            return "library_loop"
        }
    }
}
