//
//  AudioRecorderManager.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 1.04.2026.
//
import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioRecorderManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording: Bool = false
    @Published var recordedURL: URL?
    @Published var elapsedSeconds: Int = 0
    @Published var averagePower: Float = -50

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var meterTimer: Timer?

    private(set) var minimumRecordDuration: Int = 1

    override init() {
        super.init()
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Permission
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Recording
    func startRecording() throws {
        resetRecordingState(keepRecordedURL: false)
        stopTimers()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()

        guard recorder.record() else {
            throw NSError(
                domain: "AudioRecorderManager",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Ses kaydı başlatılamadı."]
            )
        }

        self.recorder = recorder
        self.recordedURL = url
        self.elapsedSeconds = 0
        self.averagePower = -50
        self.isRecording = true

        startTimers()
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        stopTimers()

        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    func cancelRecording() {
        recorder?.stop()
        recorder = nil

        if let url = recordedURL {
            try? FileManager.default.removeItem(at: url)
        }

        resetRecordingState(keepRecordedURL: false)
        stopTimers()

        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    func canSendCurrentRecording() -> Bool {
        recordedURL != nil && elapsedSeconds >= minimumRecordDuration
    }

    func durationText() -> String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Timers
    private func startTimers() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.elapsedSeconds += 1
            }
        }

        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let recorder = self.recorder else { return }
                recorder.updateMeters()
                self.averagePower = recorder.averagePower(forChannel: 0)
            }
        }
    }

    private func stopTimers() {
        timer?.invalidate()
        timer = nil

        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func resetRecordingState(keepRecordedURL: Bool) {
        if !keepRecordedURL {
            recordedURL = nil
        }
        elapsedSeconds = 0
        averagePower = -50
        isRecording = false
    }

    // MARK: - Delegate
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        isRecording = false
        stopTimers()

        if !flag {
            if let url = recordedURL {
                try? FileManager.default.removeItem(at: url)
            }
            recordedURL = nil
        }
    }

    // MARK: - Notifications
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc
    private func handleAudioInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        if type == .began, isRecording {
            stopRecording()
        }
    }

    @objc
    private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        switch reason {
        case .oldDeviceUnavailable:
            if isRecording {
                stopRecording()
            }
        default:
            break
        }
    }
}
