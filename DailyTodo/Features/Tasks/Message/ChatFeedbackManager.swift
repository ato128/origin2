//
//  ChatFeedbackManager.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.05.2026.
//

import Foundation
import UIKit
import AVFoundation
import AudioToolbox

@MainActor
final class ChatFeedbackManager {
    static let shared = ChatFeedbackManager()

    private var sentPlayer: AVAudioPlayer?
    private var incomingPlayer: AVAudioPlayer?

    private init() {
        configureAudioSession()
        preparePlayers()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            Log.debug("✅ CHAT AUDIO SESSION ACTIVE")
        } catch {
            Log.debug("CHAT AUDIO SESSION ERROR:", error.localizedDescription)
        }
    }
    private func preparePlayers() {
        sentPlayer = makePlayer(fileName: "chat_sent", fileExtension: "caf")
        incomingPlayer = makePlayer(fileName: "chat_incoming", fileExtension: "caf")
    }

    private func makePlayer(fileName: String, fileExtension: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(
            forResource: fileName,
            withExtension: fileExtension
        ) else {
            Log.debug("⚠️ Chat sound missing:", "\(fileName).\(fileExtension)")
            return nil
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 1.0
            player.prepareToPlay()
            Log.debug("✅ Chat sound loaded:", "\(fileName).\(fileExtension)")
            return player
        } catch {
            Log.debug("CHAT SOUND PLAYER ERROR:", error.localizedDescription)
            return nil
        }
    }

    func playSent() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.55)

        if let sentPlayer {
            play(player: sentPlayer)
        } else {
            AudioServicesPlaySystemSound(1104)
        }
    }

    func playIncoming() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)

        if let incomingPlayer {
            play(player: incomingPlayer)
        } else {
            AudioServicesPlaySystemSound(1003)
        }
    }

    private func play(player: AVAudioPlayer) {
        if player.isPlaying {
            player.currentTime = 0
        }

        let ok = player.play()
        Log.debug("🔊 CHAT SOUND PLAY RESULT:", ok)
    }
}
