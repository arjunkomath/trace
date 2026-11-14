//
//  MirrorWindow.swift
//  trace
//
//  Created by Codex on 1/6/2026.
//

import AppKit
import AVFoundation

final class MirrorWindow: NSPanel {
    private enum Layout {
        static let cardSize = NSSize(width: 400, height: 274)
        static let cardCornerRadius: CGFloat = 30
        // Liquid Glass draws its shadow outside the card's bounds, mostly below it, so the window
        // needs transparent room around the card or the shadow gets clipped at the window edge.
        static let margin = NSEdgeInsets(top: 12, left: 48, bottom: 64, right: 48)
        static let slideDistance: CGFloat = 10
        static let windowSize = NSSize(
            width: cardSize.width + margin.left + margin.right,
            height: cardSize.height + margin.top + margin.bottom
        )
    }

    private let onClose: () -> Void
    private var isAnimatingOut = false
    private var targetScreen: NSScreen?

    init(session: AVCaptureSession, onClose: @escaping () -> Void) {
        self.onClose = onClose

        super.init(
            contentRect: NSRect(origin: .zero, size: Layout.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupContent(session: session)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onClose()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown, event.keyCode == KeyCode.escape else {
            return super.performKeyEquivalent(with: event)
        }

        onClose()
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode != KeyCode.escape else {
            onClose()
            return
        }

        super.keyDown(with: event)
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    func show() {
        let selectedScreen = NSScreen.active
        targetScreen = selectedScreen

        let finalFrame = windowFrame(on: selectedScreen)
        setFrame(
            reduceMotion ? finalFrame : finalFrame.offsetBy(dx: 0, dy: Layout.slideDistance),
            display: true
        )
        alphaValue = reduceMotion ? 1 : 0
        orderFrontRegardless()
        makeKeyAndOrderFront(nil)

        guard !reduceMotion else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            animator().alphaValue = 1
            animator().setFrame(finalFrame, display: true)
        }
    }

    func repositionOnActiveScreen() {
        guard let selectedScreen = NSScreen.active else { return }

        targetScreen = selectedScreen
        setFrame(windowFrame(on: selectedScreen), display: true)
    }

    func hide(notify: Bool = true, completion: (() -> Void)? = nil) {
        if notify {
            onClose()
            return
        }

        guard !isAnimatingOut else {
            completion?()
            return
        }
        isAnimatingOut = true

        let completionHandler = { [weak self] in
            self?.orderOut(nil)
            self?.isAnimatingOut = false
            completion?()
        }

        guard !reduceMotion else {
            alphaValue = 0
            completionHandler()
            return
        }

        let selectedScreen = screen ?? targetScreen ?? NSScreen.active
        let exitFrame = windowFrame(on: selectedScreen).offsetBy(dx: 0, dy: Layout.slideDistance)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
            animator().setFrame(exitFrame, display: true)
        }, completionHandler: completionHandler)
    }

    private func setupWindow() {
        isReleasedWhenClosed = false
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    private func setupContent(session: AVCaptureSession) {
        let cardFrame = NSRect(
            origin: NSPoint(x: Layout.margin.left, y: Layout.margin.bottom),
            size: Layout.cardSize
        )
        let glassView = NSGlassEffectView(frame: cardFrame)
        glassView.cornerRadius = Layout.cardCornerRadius
        glassView.autoresizingMask = [.width, .height]

        let previewView = MirrorPreviewView(session: session, onClose: onClose)
        previewView.frame = glassView.bounds
        previewView.autoresizingMask = [.width, .height]
        glassView.contentView = previewView

        let container = NSView(frame: NSRect(origin: .zero, size: Layout.windowSize))
        container.addSubview(glassView)
        contentView = container
    }

    private func windowFrame(on screen: NSScreen?) -> NSRect {
        guard let screen else {
            return NSRect(origin: .zero, size: Layout.windowSize)
        }

        // visibleFrame alone isn't enough: with an auto-hiding menu bar it reaches the top edge,
        // where a notch or Dynamic Island would cover the card. The safe area keeps us clear of either.
        let screenFrame = screen.frame
        let top = min(screen.visibleFrame.maxY, screenFrame.maxY - screen.safeAreaInsets.top)

        return NSRect(
            x: screenFrame.midX - Layout.windowSize.width / 2,
            y: top - Layout.windowSize.height,
            width: Layout.windowSize.width,
            height: Layout.windowSize.height
        )
    }
}

private enum KeyCode {
    static let escape: UInt16 = 53
}

private final class MirrorPreviewView: NSView {
    private enum Layout {
        static let previewInset = NSEdgeInsets(top: 10, left: 10, bottom: 52, right: 10)
        // Concentric with the glass card: card radius minus the inset.
        static let previewCornerRadius: CGFloat = 20
    }

    private let previewContainerLayer = CALayer()
    private let previewLayer: AVCaptureVideoPreviewLayer
    private let closeButton = NSButton(title: "Close", target: nil, action: nil)
    private let onClose: () -> Void
    private var didConfigureMirroring = false

    init(session: AVCaptureSession, onClose: @escaping () -> Void) {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        self.onClose = onClose

        super.init(frame: .zero)

        setupLayers()
        setupCloseButton()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let previewFrame = NSRect(
            x: bounds.minX + Layout.previewInset.left,
            y: bounds.minY + Layout.previewInset.bottom,
            width: bounds.width - Layout.previewInset.left - Layout.previewInset.right,
            height: bounds.height - Layout.previewInset.top - Layout.previewInset.bottom
        )
        previewContainerLayer.frame = previewFrame
        previewLayer.frame = previewContainerLayer.bounds
        configureMirroringIfNeeded()

        let buttonSize = closeButton.fittingSize
        closeButton.frame = NSRect(
            x: bounds.midX - buttonSize.width / 2,
            y: bounds.minY + (Layout.previewInset.bottom - buttonSize.height) / 2,
            width: buttonSize.width,
            height: buttonSize.height
        )
    }

    private func setupLayers() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        previewContainerLayer.masksToBounds = true
        previewContainerLayer.backgroundColor = NSColor.black.cgColor
        previewContainerLayer.cornerCurve = .continuous
        previewContainerLayer.cornerRadius = Layout.previewCornerRadius
        previewContainerLayer.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        previewContainerLayer.borderWidth = 1

        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.backgroundColor = NSColor.black.cgColor
        configureMirroringIfNeeded()

        previewContainerLayer.addSublayer(previewLayer)
        layer?.addSublayer(previewContainerLayer)
    }

    private func configureMirroringIfNeeded() {
        guard !didConfigureMirroring else { return }

        guard let connection = previewLayer.connection, connection.isVideoMirroringSupported else {
            previewLayer.transform = CATransform3DMakeScale(-1, 1, 1)
            return
        }

        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = true
        previewLayer.transform = CATransform3DIdentity
        didConfigureMirroring = true
    }

    private func setupCloseButton() {
        closeButton.bezelStyle = .glass
        closeButton.controlSize = .large
        closeButton.target = self
        closeButton.action = #selector(closePressed)
        closeButton.setAccessibilityLabel("Close Mirror")
        addSubview(closeButton)
    }

    @objc private func closePressed() {
        onClose()
    }
}
