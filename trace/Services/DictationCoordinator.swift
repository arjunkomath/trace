import AppKit
import AVFoundation
import Foundation
import Speech

@MainActor
final class DictationCoordinator: ObservableObject {
    enum State: Equatable {
        case idle
        case starting
        case listening(Date)
        case processing
    }

    static let shared = DictationCoordinator()

    @Published private(set) var state: State = .idle

    private let settingsManager = SettingsManager.shared
    private let assetManager = DictationAssetManager.shared
    private let insertionService = TextInsertionService()
    private let indicator = DictationIndicatorController()
    private let logger = AppLogger.dictation

    private var session: DictationAnalyzerSession?
    private var startDate: Date?
    private var startTask: Task<Void, Never>?
    private var maxDurationTask: Task<Void, Never>?
    private let minimumDuration: TimeInterval = 0.45
    private let maximumDuration: TimeInterval = 90

    var isReady: Bool {
        let readyWithoutAccessibility =
            settingsManager.settings.dictationEnabled &&
            settingsManager.settings.dictationHotkeyKeyCode > 0 &&
            assetManager.state.isReady &&
            AVCaptureDevice.authorizationStatus(for: .audio) == .authorized &&
            SFSpeechRecognizer.authorizationStatus() == .authorized

        #if DEBUG
        return readyWithoutAccessibility
        #else
        return readyWithoutAccessibility && AXIsProcessTrusted()
        #endif
    }

    private init() {}

    func handlePress() {
        switch state {
        case .idle:
            guard settingsManager.settings.dictationEnabled else {
                openDictationSettings()
                return
            }
            guard settingsManager.settings.dictationHotkeyKeyCode > 0 else {
                openDictationSettings()
                return
            }
            guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
                openDictationSettings()
                return
            }
            guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
                openDictationSettings()
                return
            }
            #if !DEBUG
            guard AXIsProcessTrusted() else {
                openDictationSettings()
                return
            }
            #endif
            guard let locale = assetManager.resolvedLocale, assetManager.state.isReady else {
                openDictationSettings()
                return
            }

            start(locale: locale)

        case .starting, .listening, .processing:
            break
        }
    }

    func handleRelease() {
        switch state {
        case .starting:
            cancel()
        case .listening:
            stopAndTranscribe()
        case .idle, .processing:
            break
        }
    }

    func cancel() {
        startTask?.cancel()
        maxDurationTask?.cancel()
        let session = session
        self.session = nil
        state = .idle
        indicator.hide()

        Task {
            await session?.cancel()
        }
    }

    private func start(locale: Locale) {
        state = .starting
        indicator.showListening()
        let session = DictationAnalyzerSession(locale: locale)
        session.onAudioLevel = { [weak self] level in
            Task { @MainActor [weak self] in
                self?.indicator.updateAudioLevel(level)
            }
        }
        self.session = session

        startTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await session.start()
                guard !Task.isCancelled else {
                    await session.cancel()
                    return
                }
                await MainActor.run {
                    self.startDate = Date()
                    self.state = .listening(self.startDate ?? Date())
                    self.scheduleMaxDurationStop()
                }
            } catch {
                await session.cancel()
                if error is CancellationError {
                    return
                }
                await MainActor.run {
                    self.fail(error.localizedDescription)
                }
            }
        }
    }

    private func stopAndTranscribe() {
        guard case .listening = state else { return }
        guard let session else { return }
        let elapsed = Date().timeIntervalSince(startDate ?? Date())
        maxDurationTask?.cancel()
        maxDurationTask = nil

        if elapsed < minimumDuration {
            cancel()
            return
        }

        state = .processing
        indicator.showProcessing()

        Task { [weak self] in
            guard let self else { return }
            do {
                let transcript = try await session.stop()
                #if DEBUG
                self.logger.notice("Dictation transcript: \(transcript, privacy: .public)")
                #else
                do {
                    try await self.insertionService.insert(transcript)
                } catch TextInsertionService.InsertionError.accessibilityNotTrusted {
                    throw TextInsertionService.InsertionError.accessibilityNotTrusted
                }
                #endif
                await MainActor.run {
                    self.session = nil
                    self.state = .idle
                    self.indicator.hide()
                }
            } catch {
                await MainActor.run {
                    self.fail(error.localizedDescription)
                }
            }
        }
    }

    private func scheduleMaxDurationStop() {
        maxDurationTask?.cancel()
        maxDurationTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: UInt64(self.maximumDuration * 1_000_000_000))
            } catch {
                return
            }
            await MainActor.run {
                guard case .listening = self.state else { return }
                self.stopAndTranscribe()
            }
        }
    }

    private func fail(_ message: String) {
        logger.error("Dictation failed: \(message)")
        session = nil
        state = .idle
        indicator.hide()
        ToastManager.shared.showError(message)
    }

    private func openDictationSettings() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.showDictationSettings()
        } else {
            ToastManager.shared.showError("Open Dictation settings to finish setup.")
        }
    }
}
