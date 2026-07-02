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
        static let windowSize = NSSize(width: 456, height: 304)
        static let collapsedSize = NSSize(width: 185, height: 32)
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
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
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
            context.duration = 0.18
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
        static let outerTopCornerRadius: CGFloat = 19
        static let outerBottomCornerRadius: CGFloat = 24
        static let innerCornerRadius: CGFloat = 22
        static let islandInset = NSEdgeInsets(top: 0, left: 14, bottom: 12, right: 14)
        static let previewInset = NSEdgeInsets(top: 44, left: 32, bottom: 48, right: 32)
        static let minimumPreviewSide: CGFloat = 72
        static let closeButtonSize = NSSize(width: 76, height: 30)
        static let closeButtonBottomInset: CGFloat = 11
    }

    private let islandBodyLayer = CAShapeLayer()
    private let previewContainerLayer = CALayer()
    private let previewBorderLayer = CALayer()
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

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let islandFrame = NSRect(
            x: bounds.minX + Layout.islandInset.left,
            y: bounds.minY + Layout.islandInset.bottom,
            width: bounds.width - Layout.islandInset.left - Layout.islandInset.right,
            height: bounds.height - Layout.islandInset.top - Layout.islandInset.bottom
        )
        islandBodyLayer.frame = islandFrame
        let islandPath = makeTopAttachedIslandPath(
            in: islandBodyLayer.bounds,
            topRadius: Layout.outerTopCornerRadius,
            bottomRadius: Layout.outerBottomCornerRadius
        )
        islandBodyLayer.path = islandPath
        islandBodyLayer.shadowPath = islandPath

        previewContainerLayer.frame = NSRect(
            x: islandFrame.minX + Layout.previewInset.left,
            y: islandFrame.minY + Layout.previewInset.bottom,
            width: islandFrame.width - Layout.previewInset.left - Layout.previewInset.right,
            height: islandFrame.height - Layout.previewInset.top - Layout.previewInset.bottom
        )
        let shouldShowPreview = previewContainerLayer.frame.width >= Layout.minimumPreviewSide
            && previewContainerLayer.frame.height >= Layout.minimumPreviewSide
        previewContainerLayer.isHidden = !shouldShowPreview
        previewBorderLayer.isHidden = !shouldShowPreview
        closeButton.isHidden = !shouldShowPreview

        previewContainerLayer.cornerRadius = Layout.innerCornerRadius
        previewBorderLayer.frame = previewContainerLayer.frame
        previewBorderLayer.cornerRadius = Layout.innerCornerRadius
        previewLayer.frame = previewContainerLayer.bounds
        previewLayer.position = CGPoint(
            x: previewContainerLayer.bounds.midX,
            y: previewContainerLayer.bounds.midY
        )
        configureMirroringIfNeeded()

        closeButton.frame = NSRect(
            x: islandFrame.midX - Layout.closeButtonSize.width / 2,
            y: islandFrame.minY + Layout.closeButtonBottomInset,
            width: Layout.closeButtonSize.width,
            height: Layout.closeButtonSize.height
        )
    }

    private func setupLayers() {
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor

        islandBodyLayer.fillColor = NSColor.black.cgColor
        islandBodyLayer.shadowOpacity = 0

        previewContainerLayer.masksToBounds = true
        previewContainerLayer.backgroundColor = NSColor.black.cgColor
        previewContainerLayer.cornerCurve = .continuous
        previewContainerLayer.cornerRadius = Layout.innerCornerRadius

        previewBorderLayer.cornerCurve = .continuous
        previewBorderLayer.borderColor = NSColor.white.withAlphaComponent(0.04).cgColor
        previewBorderLayer.borderWidth = 1

        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.backgroundColor = NSColor.black.cgColor
        configureMirroringIfNeeded()

        layer?.addSublayer(islandBodyLayer)
        previewContainerLayer.addSublayer(previewLayer)
        layer?.addSublayer(previewContainerLayer)
        layer?.addSublayer(previewBorderLayer)
    }

    private func makeTopAttachedIslandPath(
        in rect: CGRect,
        topRadius: CGFloat,
        bottomRadius: CGFloat
    ) -> CGPath {
        guard !rect.isEmpty else { return CGPath(rect: rect, transform: nil) }

        var topRadius = min(topRadius, rect.width / 2, rect.height / 2)
        var bottomRadius = min(bottomRadius, rect.width / 2, rect.height / 2)
        let combinedRadius = topRadius + bottomRadius
        if combinedRadius > rect.height, combinedRadius > 0 {
            let scale = rect.height / combinedRadius
            topRadius *= scale
            bottomRadius *= scale
        }

        let path = CGMutablePath()

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topRadius, y: rect.maxY - topRadius),
            control: CGPoint(x: rect.maxX - topRadius, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topRadius, y: rect.minY + bottomRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topRadius - bottomRadius, y: rect.minY),
            control: CGPoint(x: rect.maxX - topRadius, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + topRadius + bottomRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topRadius, y: rect.minY + bottomRadius),
            control: CGPoint(x: rect.minX + topRadius, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + topRadius, y: rect.maxY - topRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY),
            control: CGPoint(x: rect.minX + topRadius, y: rect.maxY)
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
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        visualLayer.cornerCurve = .continuous
        visualLayer.masksToBounds = true
        layer?.addSublayer(visualLayer)

        image = nil
        imagePosition = .noImage
        imageScaling = .scaleNone
        bezelStyle = .regularSquare
        isBordered = false
        focusRingType = .none

        updateAppearance()
    }

    private func updateAppearance() {
        visualLayer.frame = NSRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: bounds.height
        )
        visualLayer.cornerRadius = bounds.height / 2
        visualLayer.backgroundColor = backgroundColor.cgColor

        let foregroundColor = NSColor.white.withAlphaComponent(isHighlighted ? 0.96 : 0.86)
        attributedTitle = NSAttributedString(
            string: "Close",
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: foregroundColor
            ]
        )
        alphaValue = isHighlighted ? 0.9 : 1
    }

    private var backgroundColor: NSColor {
        if isHighlighted {
            return NSColor.white.withAlphaComponent(0.28)
        }

        if isHovered {
            return NSColor.gray.withAlphaComponent(0.20)
        }

        return NSColor.white.withAlphaComponent(0.10)
    }
}
