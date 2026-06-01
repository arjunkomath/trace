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
        static let windowSize = NSSize(width: 456, height: 290)
        static let collapsedSize = NSSize(width: 174, height: 38)
        static let topBleed: CGFloat = 0
    }

    private let onClose: () -> Void
    private var isAnimatingOut = false

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

    func show() {
        let finalFrame = windowFrame(for: Layout.windowSize)
        let initialFrame = windowFrame(for: Layout.collapsedSize)
        setFrame(
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? finalFrame : initialFrame,
            display: true
        )
        orderFrontRegardless()
        makeKeyAndOrderFront(nil)

        alphaValue = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 1 : 0
        setIsVisible(true)

        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
            animator().setFrame(finalFrame, display: true)
        }
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
            self?.setIsVisible(false)
            self?.isAnimatingOut = false
            completion?()
        }

        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            alphaValue = 0
            setFrame(windowFrame(for: Layout.collapsedSize), display: true)
            completionHandler()
            return
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
            animator().setFrame(windowFrame(for: Layout.collapsedSize), display: true)
        }, completionHandler: completionHandler)
    }

    private func setupWindow() {
        isReleasedWhenClosed = false
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }

    private func setupContent(session: AVCaptureSession) {
        contentView = MirrorPreviewView(session: session, onClose: onClose)
    }

    private func windowFrame(for size: NSSize) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else {
            return NSRect(origin: .zero, size: size)
        }

        let screenFrame = screen.frame
        let x = screenFrame.midX - size.width / 2
        let y = screenFrame.maxY - size.height + Layout.topBleed

        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}

private enum KeyCode {
    static let escape: UInt16 = 53
}

private final class MirrorPreviewView: NSView {
    private enum Layout {
        static let islandBorderWidth: CGFloat = 14
        static let outerCornerRadius: CGFloat = 30
        static let innerCornerRadius: CGFloat = outerCornerRadius - islandBorderWidth
        static let islandInset = NSEdgeInsets(top: 0, left: 10, bottom: 10, right: 10)
        static let previewInset = NSEdgeInsets(top: 36, left: 14, bottom: 14, right: 14)
        static let closeButtonSize: CGFloat = 32
        static let closeButtonInset: CGFloat = 4
    }

    private let islandBodyLayer = CAShapeLayer()
    private let previewContainerLayer = CALayer()
    private let previewMaskLayer = CAShapeLayer()
    private let previewLayer: AVCaptureVideoPreviewLayer
    private let closeButton = MirrorCloseButton()
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

        let islandFrame = NSRect(
            x: bounds.minX + Layout.islandInset.left,
            y: bounds.minY + Layout.islandInset.bottom,
            width: bounds.width - Layout.islandInset.left - Layout.islandInset.right,
            height: bounds.height - Layout.islandInset.top - Layout.islandInset.bottom
        )
        islandBodyLayer.frame = islandFrame
        islandBodyLayer.path = makeTopAttachedIslandPath(
            in: islandBodyLayer.bounds,
            bottomRadius: Layout.outerCornerRadius
        )
        previewContainerLayer.frame = NSRect(
            x: islandFrame.minX + Layout.previewInset.left,
            y: islandFrame.minY + Layout.previewInset.bottom,
            width: islandFrame.width - Layout.previewInset.left - Layout.previewInset.right,
            height: islandFrame.height - Layout.previewInset.top - Layout.previewInset.bottom
        )
        previewMaskLayer.frame = previewContainerLayer.bounds
        previewMaskLayer.path = makeRoundedRectPath(
            in: previewMaskLayer.bounds,
            topRadius: Layout.innerCornerRadius,
            bottomRadius: Layout.innerCornerRadius
        )
        previewLayer.frame = previewContainerLayer.bounds
        previewLayer.position = CGPoint(
            x: previewContainerLayer.bounds.midX,
            y: previewContainerLayer.bounds.midY
        )
        configureMirroringIfNeeded()

        closeButton.frame = NSRect(
            x: islandFrame.maxX - Layout.closeButtonInset - Layout.closeButtonSize,
            y: islandFrame.maxY - Layout.closeButtonInset - Layout.closeButtonSize,
            width: Layout.closeButtonSize,
            height: Layout.closeButtonSize
        )
    }

    private func setupLayers() {
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor

        islandBodyLayer.fillColor = NSColor.black.cgColor

        previewContainerLayer.masksToBounds = true
        previewContainerLayer.backgroundColor = NSColor.black.cgColor
        previewContainerLayer.mask = previewMaskLayer

        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.backgroundColor = NSColor.black.cgColor
        configureMirroringIfNeeded()

        layer?.addSublayer(islandBodyLayer)
        previewContainerLayer.addSublayer(previewLayer)
        layer?.addSublayer(previewContainerLayer)
    }

    private func makeTopAttachedIslandPath(
        in rect: CGRect,
        bottomRadius: CGFloat
    ) -> CGPath {
        let bottomRadius = min(bottomRadius, rect.width / 2, rect.height / 2)
        let path = CGMutablePath()

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + bottomRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomRadius, y: rect.minY),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + bottomRadius),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }

    private func makeRoundedRectPath(
        in rect: CGRect,
        topRadius: CGFloat,
        bottomRadius: CGFloat
    ) -> CGPath {
        let topRadius = min(topRadius, rect.width / 2, rect.height / 2)
        let bottomRadius = min(bottomRadius, rect.width / 2, rect.height / 2)
        let path = CGMutablePath()

        path.move(to: CGPoint(x: rect.minX + topRadius, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - topRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - topRadius),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + bottomRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomRadius, y: rect.minY),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + bottomRadius),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - topRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topRadius, y: rect.maxY),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()

        return path
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
        closeButton.setAccessibilityLabel("Close Mirror")
        closeButton.target = self
        closeButton.action = #selector(closePressed)
        addSubview(closeButton)
    }

    @objc private func closePressed() {
        onClose()
    }
}

private final class MirrorCloseButton: NSButton {
    private enum Layout {
        static let visualSize: CGFloat = 24
        static let hoverVisualSize: CGFloat = 26
    }

    private let visualLayer = CALayer()
    private var trackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet { updateAppearance() }
    }

    override var isHighlighted: Bool {
        didSet { updateAppearance() }
    }

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func layout() {
        super.layout()
        updateAppearance()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    private func setup() {
        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        visualLayer.cornerCurve = .continuous
        visualLayer.masksToBounds = true
        layer?.addSublayer(visualLayer)

        image = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfiguration)
        imagePosition = .imageOnly
        imageScaling = .scaleNone
        contentTintColor = NSColor.white.withAlphaComponent(0.88)
        bezelStyle = .regularSquare
        isBordered = false
        focusRingType = .none

        updateAppearance()
    }

    private func updateAppearance() {
        let visualSize = isHovered ? Layout.hoverVisualSize : Layout.visualSize
        visualLayer.frame = NSRect(
            x: bounds.midX - visualSize / 2,
            y: bounds.midY - visualSize / 2,
            width: visualSize,
            height: visualSize
        )
        visualLayer.cornerRadius = visualSize / 2
        visualLayer.backgroundColor = backgroundColor.cgColor

        contentTintColor = NSColor.white.withAlphaComponent(isHighlighted ? 0.96 : 0.86)
        alphaValue = isHighlighted ? 0.9 : 1
    }

    private var backgroundColor: NSColor {
        if isHighlighted {
            return NSColor.white.withAlphaComponent(0.28)
        }

        if isHovered {
            return NSColor.white.withAlphaComponent(0.22)
        }

        return NSColor.white.withAlphaComponent(0.16)
    }
}
