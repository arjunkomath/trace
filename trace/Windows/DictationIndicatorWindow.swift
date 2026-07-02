import AppKit
import SwiftUI

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
    private var hostingView: NSHostingView<DictationIndicatorView>?
    private var mode: DictationIndicatorMode

    init(mode: DictationIndicatorMode) {
        self.mode = mode
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 184, height: 54),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupContent()
    }

    func update(mode: DictationIndicatorMode) {
        self.mode = mode
        hostingView?.rootView = DictationIndicatorView(mode: mode)
    }

    func show() {
        positionWindow()
        alphaValue = 0
        orderFrontRegardless()
        setIsVisible(true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            alphaValue = 1
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.16
            alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.setIsVisible(false)
        })
    }

    private func setupWindow() {
        isReleasedWhenClosed = false
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    private func setupContent() {
        let hostingView = NSHostingView(rootView: DictationIndicatorView(mode: mode))
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        self.hostingView = hostingView
        contentView = hostingView
    }

    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.minY + 120
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

struct DictationIndicatorView: View {
    let mode: DictationIndicatorMode
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(mode == .listening ? 0.18 : 0.08))
                    .frame(width: pulse ? 42 : 30, height: pulse ? 42 : 30)
                    .opacity(pulse ? 0.35 : 0.85)

                Circle()
                    .fill(mode == .listening ? Color.red : Color.accentColor)
                    .frame(width: 16, height: 16)
                    .overlay {
                        if mode == .processing {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.45)
                                .frame(width: 16, height: 16)
                        }
                    }
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(mode.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(mode == .listening ? "Release to dictate" : "Preparing text…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(width: 184, height: 54)
        .liquidGlassEffect(interactive: false)
        .overlay(
            RoundedRectangle(cornerRadius: adaptiveCornerRadius)
                .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
