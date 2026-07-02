import AppKit

@MainActor
final class DictationIndicatorController {
    private var window: DictationIndicatorWindow?

    func showListening() {
        show(mode: .listening)
    }

    func showProcessing() {
        show(mode: .processing)
    }

    func hide() {
        window?.hide()
    }

    private func show(mode: DictationIndicatorMode) {
        if window == nil {
            window = DictationIndicatorWindow(mode: mode)
        }

        window?.update(mode: mode)
        window?.show()
    }
}

enum DictationIndicatorMode {
    case listening
    case processing

    var title: String {
        switch self {
        case .listening: return "Listening"
        case .processing: return "Transcribing"
        }
    }
}

final class DictationIndicatorWindow: NSPanel {
    private enum Layout {
        static let expandedSize = NSSize(width: 340, height: 92)
        static let collapsedSize = NSSize(width: 190, height: 36)
        static let topBleed: CGFloat = 0
    }

    private var indicatorView: DictationIndicatorView?
    private var mode: DictationIndicatorMode
    private var isAnimatingOut = false

    init(mode: DictationIndicatorMode) {
        self.mode = mode
        super.init(
            contentRect: NSRect(origin: .zero, size: Layout.expandedSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupContent()
    }

    func update(mode: DictationIndicatorMode) {
        self.mode = mode
        indicatorView?.update(mode: mode)
    }

    func show() {
        let finalFrame = windowFrame(for: Layout.expandedSize)
        let initialFrame = windowFrame(for: Layout.collapsedSize)
        setFrame(
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? finalFrame : initialFrame,
            display: true
        )
        orderFrontRegardless()

        alphaValue = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 1 : 0
        setIsVisible(true)

        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            animator().alphaValue = 1
            animator().setFrame(finalFrame, display: true)
        }
    }

    func hide() {
        guard !isAnimatingOut else { return }
        isAnimatingOut = true

        let completionHandler = { [weak self] in
            self?.orderOut(nil)
            self?.setIsVisible(false)
            self?.isAnimatingOut = false
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

    private func setupContent() {
        let indicatorView = DictationIndicatorView(mode: mode)
        self.indicatorView = indicatorView
        contentView = indicatorView
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

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class DictationIndicatorView: NSView {
    private enum Layout {
        static let outerTopCornerRadius: CGFloat = 24
        static let outerBottomCornerRadius: CGFloat = 34
        static let islandInset = NSEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        static let minimumTextWidth: CGFloat = 92
        static let maximumTextWidth: CGFloat = 220
        static let contentGap: CGFloat = 12
        static let dotSize: CGFloat = 13
        static let pulseSize: CGFloat = 32
    }

    private let islandBodyLayer = CAShapeLayer()
    private let pulseLayer = CAShapeLayer()
    private let dotLayer = CAShapeLayer()
    private let titleLabel = NSTextField(labelWithString: "")
    private let progressIndicator = NSProgressIndicator()
    private var mode: DictationIndicatorMode

    init(mode: DictationIndicatorMode) {
        self.mode = mode
        super.init(frame: .zero)
        setupLayers()
        setupLabels()
        setupProgressIndicator()
        update(mode: mode)
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

        let topObscuredInset = window?.screen?.safeAreaInsets.top ?? 0
        let contentCenterY = islandFrame.midY - min(topObscuredInset / 2, islandFrame.height * 0.24)
        let textWidth = min(
            max(titleLabel.intrinsicContentSize.width + 6, Layout.minimumTextWidth),
            Layout.maximumTextWidth
        )
        let contentWidth = Layout.pulseSize + Layout.contentGap + textWidth
        let contentMinX = islandFrame.midX - contentWidth / 2
        let dotCenter = CGPoint(
            x: contentMinX + Layout.pulseSize / 2,
            y: contentCenterY
        )
        pulseLayer.frame = NSRect(
            x: dotCenter.x - Layout.pulseSize / 2,
            y: dotCenter.y - Layout.pulseSize / 2,
            width: Layout.pulseSize,
            height: Layout.pulseSize
        )
        pulseLayer.path = CGPath(ellipseIn: pulseLayer.bounds, transform: nil)

        dotLayer.frame = NSRect(
            x: dotCenter.x - Layout.dotSize / 2,
            y: dotCenter.y - Layout.dotSize / 2,
            width: Layout.dotSize,
            height: Layout.dotSize
        )
        dotLayer.path = CGPath(ellipseIn: dotLayer.bounds, transform: nil)

        progressIndicator.frame = NSRect(
            x: dotCenter.x - 8,
            y: dotCenter.y - 8,
            width: 16,
            height: 16
        )

        let textX = contentMinX + Layout.pulseSize + Layout.contentGap
        titleLabel.frame = NSRect(x: textX, y: contentCenterY - 9, width: textWidth, height: 18)
    }

    func update(mode: DictationIndicatorMode) {
        self.mode = mode
        titleLabel.stringValue = mode.title
        needsLayout = true

        let color: NSColor = mode == .listening ? .systemRed : .controlAccentColor
        dotLayer.fillColor = color.cgColor
        pulseLayer.fillColor = color.withAlphaComponent(mode == .listening ? 0.22 : 0.12).cgColor
        progressIndicator.isHidden = mode != .processing
        dotLayer.isHidden = mode == .processing

        if mode == .processing {
            progressIndicator.startAnimation(nil)
            pulseLayer.removeAnimation(forKey: "dictationPulse")
        } else {
            progressIndicator.stopAnimation(nil)
            startPulseAnimation()
        }
    }

    private func setupLayers() {
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor

        islandBodyLayer.fillColor = NSColor.black.cgColor
        islandBodyLayer.shadowOpacity = 0

        pulseLayer.opacity = 0.85

        layer?.addSublayer(islandBodyLayer)
        layer?.addSublayer(pulseLayer)
        layer?.addSublayer(dotLayer)
    }

    private func setupLabels() {
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.94)
        titleLabel.backgroundColor = .clear
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.alignment = .left

        addSubview(titleLabel)
    }

    private func setupProgressIndicator() {
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.isHidden = true
        addSubview(progressIndicator)
    }

    private func startPulseAnimation() {
        guard pulseLayer.animation(forKey: "dictationPulse") == nil else { return }

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.82
        scale.toValue = 1.18

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.85
        opacity.toValue = 0.28

        let group = CAAnimationGroup()
        group.animations = [scale, opacity]
        group.duration = 0.8
        group.autoreverses = true
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseLayer.add(group, forKey: "dictationPulse")
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
}
