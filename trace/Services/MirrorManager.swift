//
//  MirrorManager.swift
//  trace
//
//  Created by Codex on 1/6/2026.
//

import AppKit
@preconcurrency import AVFoundation

@MainActor
final class MirrorManager {
    static let defaultDisplayDuration: TimeInterval = 60

    private let logger = AppLogger.mirrorManager
    private let sessionQueue = DispatchQueue(label: "com.techulus.trace.mirror.session")

    private var session: AVCaptureSession?
    private var mirrorWindow: MirrorWindow?
    private var retiringMirrorWindow: MirrorWindow?
    private var autoHideWorkItem: DispatchWorkItem?
    private var runtimeErrorObserver: NSObjectProtocol?

    var isVisible: Bool {
        mirrorWindow?.isVisible == true
    }

    func show() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showAuthorizedMirror()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }

                    if granted {
                        self.showAuthorizedMirror()
                    } else {
                        ToastManager.shared.showWarning("Camera access is required for Mirror")
                    }
                }
            }

        case .denied, .restricted:
            ToastManager.shared.showWarning("Camera access is required for Mirror")

        @unknown default:
            ToastManager.shared.showWarning("Camera access is required for Mirror")
        }
    }

    func hide() {
        stopAutoHideTimer()
        stopRuntimeErrorObservation()

        guard let mirrorWindow else {
            if retiringMirrorWindow == nil {
                stopSession(session)
            }
            return
        }

        let outgoingSession = session
        retiringMirrorWindow = mirrorWindow
        self.mirrorWindow = nil
        mirrorWindow.hide(notify: false) { [weak self, weak mirrorWindow] in
            guard let self else { return }

            if self.retiringMirrorWindow === mirrorWindow {
                self.retiringMirrorWindow = nil
            }

            self.stopSession(outgoingSession)
        }
    }

    private func stopSession(_ sessionToStop: AVCaptureSession?) {
        guard let session = sessionToStop else { return }
        if session === self.session {
            self.session = nil
        }

        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func showAuthorizedMirror() {
        if let mirrorWindow, mirrorWindow.isVisible {
            mirrorWindow.orderFrontRegardless()
            scheduleAutoHide()
            return
        }

        do {
            let session = try makePreviewSession()
            let mirrorWindow = MirrorWindow(session: session) { [weak self] in
                self?.hide()
            }

            self.session = session
            self.mirrorWindow = mirrorWindow

            observeRuntimeErrors(for: session)
            mirrorWindow.show()
            scheduleAutoHide()

            sessionQueue.async {
                session.startRunning()
            }
        } catch {
            logger.error("Failed to start Mirror camera session: \(error.localizedDescription)")
            ToastManager.shared.showError("Mirror could not start the camera")
            hide()
        }
    }

    private func makePreviewSession() throws -> AVCaptureSession {
        let session = AVCaptureSession()
        session.beginConfiguration()

        guard let camera = AVCaptureDevice.default(for: .video) else {
            session.commitConfiguration()
            throw MirrorError.noCamera
        }

        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw MirrorError.inputUnavailable
        }

        session.addInput(input)
        configureUserSelectedVideoEffects(for: camera)

        session.commitConfiguration()
        return session
    }

    private func configureUserSelectedVideoEffects(for camera: AVCaptureDevice) {
        if #available(macOS 12.3, *) {
            AVCaptureDevice.centerStageControlMode = .cooperative
        }

        guard let preferredFormat = preferredVideoEffectsFormat(on: camera) else {
            return
        }

        do {
            try camera.lockForConfiguration()
            camera.activeFormat = preferredFormat
            configureFrameDurationForUserSelectedVideoEffects(on: camera)
            camera.unlockForConfiguration()
        } catch {
            logger.warning("Failed to configure Mirror video effects format: \(error.localizedDescription)")
        }
    }

    private func preferredVideoEffectsFormat(on camera: AVCaptureDevice) -> AVCaptureDevice.Format? {
        let currentFormat = camera.activeFormat
        let bestFormat = camera.formats.max { videoEffectsScore(for: $0) < videoEffectsScore(for: $1) }

        guard let bestFormat, videoEffectsScore(for: bestFormat) > videoEffectsScore(for: currentFormat) else {
            return nil
        }

        return bestFormat
    }

    private func videoEffectsScore(for format: AVCaptureDevice.Format) -> Int {
        var score = 0

        if #available(macOS 12.3, *), format.isCenterStageSupported {
            score += 16
        }

        if #available(macOS 12.0, *), format.isPortraitEffectSupported {
            score += 8
        }

        if #available(macOS 13.0, *), format.isStudioLightSupported {
            score += 8
        }

        if #available(macOS 14.0, *), format.reactionEffectsSupported {
            score += 4
        }

        if #available(macOS 15.0, *), format.isBackgroundReplacementSupported {
            score += 8
        }

        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        score += min(Int(dimensions.width * dimensions.height / 100_000), 20)

        return score
    }

    private func configureFrameDurationForUserSelectedVideoEffects(on camera: AVCaptureDevice) {
        var minimumFrameRate = 15.0
        var maximumFrameRate = 30.0

        func include(_ range: AVFrameRateRange?) {
            guard let range else { return }
            minimumFrameRate = max(minimumFrameRate, range.minFrameRate)
            maximumFrameRate = min(maximumFrameRate, range.maxFrameRate)
        }

        if #available(macOS 12.3, *), AVCaptureDevice.isCenterStageEnabled {
            include(camera.activeFormat.videoFrameRateRangeForCenterStage)
        }

        if #available(macOS 12.0, *), AVCaptureDevice.isPortraitEffectEnabled {
            include(camera.activeFormat.videoFrameRateRangeForPortraitEffect)
        }

        if #available(macOS 13.0, *), AVCaptureDevice.isStudioLightEnabled {
            include(camera.activeFormat.videoFrameRateRangeForStudioLight)
        }

        if #available(macOS 15.0, *), AVCaptureDevice.isBackgroundReplacementEnabled {
            include(camera.activeFormat.videoFrameRateRangeForBackgroundReplacement)
        }

        guard minimumFrameRate <= maximumFrameRate else { return }

        let frameRate = min(maximumFrameRate, max(minimumFrameRate, 30.0))
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate.rounded()))
        camera.activeVideoMinFrameDuration = frameDuration
        camera.activeVideoMaxFrameDuration = frameDuration
    }

    private func scheduleAutoHide() {
        stopAutoHideTimer()

        let workItem = DispatchWorkItem { [weak self] in
            self?.hide()
        }

        autoHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.defaultDisplayDuration,
            execute: workItem
        )
    }

    private func stopAutoHideTimer() {
        autoHideWorkItem?.cancel()
        autoHideWorkItem = nil
    }

    private func observeRuntimeErrors(for session: AVCaptureSession) {
        stopRuntimeErrorObservation()

        runtimeErrorObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self else { return }

                if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError {
                    self.logger.error("Mirror camera runtime error: \(error.localizedDescription)")
                }

                ToastManager.shared.showError("Mirror could not start the camera")
                self.hide()
            }
        }
    }

    private func stopRuntimeErrorObservation() {
        if let runtimeErrorObserver {
            NotificationCenter.default.removeObserver(runtimeErrorObserver)
            self.runtimeErrorObserver = nil
        }
    }
}

private enum MirrorError: LocalizedError {
    case noCamera
    case inputUnavailable

    var errorDescription: String? {
        switch self {
        case .noCamera:
            return "No camera is available."
        case .inputUnavailable:
            return "The camera input could not be added."
        }
    }
}
