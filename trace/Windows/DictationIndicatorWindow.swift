import AppKit
import SwiftUI

@MainActor
final class DictationIndicatorController {
    private let model = DictationIndicatorModel()
    private var window: DictationIndicatorWindow?

    func showListening() {
        show(mode: .listening)
    }

    func showProcessing() {
        show(mode: .processing)
    }

    func updateAudioLevel(_ level: Float) {
        model.ingestAudioLevel(level)
    }

    func hide() {
        window?.hide()
    }

    private func show(mode: DictationIndicatorMode) {
        let window = self.window ?? DictationIndicatorWindow(model: model)
        self.window = window
        model.setMode(mode)
        window.show()
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

@MainActor
@Observable
final class DictationIndicatorModel {
    private(set) var mode: DictationIndicatorMode = .listening
    private(set) var audioLevel: CGFloat = 0
    var isPresented = false

    @ObservationIgnored private var smoothedLevel: Float = 0

    func setMode(_ mode: DictationIndicatorMode) {
        self.mode = mode
        smoothedLevel = 0
        audioLevel = 0
    }

    func ingestAudioLevel(_ level: Float) {
        guard mode == .listening, isPresented else { return }

        // Gate out room noise, then rise fast and fall slower so speech reads as lively but not jittery.
        let gatedLevel = max(0, min(1, (level - 0.08) / 0.72))
        let responsiveLevel = Float(pow(Double(gatedLevel), 0.85))
        let smoothing: Float = responsiveLevel > smoothedLevel ? 0.82 : 0.58
        smoothedLevel += (responsiveLevel - smoothedLevel) * smoothing
        audioLevel = CGFloat(smoothedLevel)
    }
}

final class DictationIndicatorWindow: NSPanel {
    private enum Layout {
        // Oversized so the pill can change width and the glass can draw its edge without clipping.
        static let size = NSSize(width: 320, height: 72)
    }

    private let model: DictationIndicatorModel
    private var presentationGeneration = 0

    init(model: DictationIndicatorModel) {
        self.model = model
        super.init(
            contentRect: NSRect(origin: .zero, size: Layout.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupContent()
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    func show() {
        presentationGeneration += 1
        setFrame(windowFrame(), display: false)
        orderFrontRegardless()

        guard !model.isPresented else { return }
        if reduceMotion {
            model.isPresented = true
        } else {
            withAnimation(.spring(duration: 0.28, bounce: 0.18)) {
                model.isPresented = true
            }
        }
    }

    func hide() {
        guard model.isPresented else { return }
        presentationGeneration += 1
        let generation = presentationGeneration

        // A show() that lands mid fade-out bumps the generation, so the stale completion must not order the window out.
        let finish = { [weak self] in
            guard let self, self.presentationGeneration == generation else { return }
            self.orderOut(nil)
        }

        if reduceMotion {
            model.isPresented = false
            finish()
            return
        }

        withAnimation(.easeIn(duration: 0.16)) {
            model.isPresented = false
        } completion: {
            finish()
        }
    }

    private func setupWindow() {
        isReleasedWhenClosed = false
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
    }

    private func setupContent() {
        let hostingView = NSHostingView(rootView: DictationIndicatorView(model: model))
        hostingView.sizingOptions = []
        contentView = hostingView
    }

    private func windowFrame() -> NSRect {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return NSRect(origin: .zero, size: Layout.size)
        }

        // visibleFrame alone isn't enough: with an auto-hiding menu bar it reaches the top edge,
        // where a notch or Dynamic Island would cover the pill. The safe area keeps us clear of either.
        let screenFrame = screen.frame
        let top = min(screen.visibleFrame.maxY, screenFrame.maxY - screen.safeAreaInsets.top)

        return NSRect(
            x: screenFrame.midX - Layout.size.width / 2,
            y: top - Layout.size.height,
            width: Layout.size.width,
            height: Layout.size.height
        )
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct DictationIndicatorView: View {
    let model: DictationIndicatorModel

    var body: some View {
        HStack(spacing: 10) {
            DictationStatusGlyph(mode: model.mode, audioLevel: model.audioLevel)

            Text(model.mode.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .contentTransition(.opacity)
        }
        .padding(.leading, 10)
        .padding(.trailing, 16)
        .frame(height: 40)
        .glassEffect(.regular, in: Capsule())
        .animation(.snappy(duration: 0.2), value: model.mode)
        .scaleEffect(model.isPresented ? 1 : 0.88, anchor: .top)
        .opacity(model.isPresented ? 1 : 0)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
    }
}

private struct DictationStatusGlyph: View {
    let mode: DictationIndicatorMode
    let audioLevel: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            switch mode {
            case .listening:
                Circle()
                    .fill(Color.red.opacity(0.22))
                    .scaleEffect(isPulsing ? 1.15 : 0.82)
                    .opacity(isPulsing ? 0.3 : 0.85)
                    .onAppear(perform: startPulse)
                    .onDisappear { isPulsing = false }

                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .scaleEffect(0.45 + audioLevel * 1.35)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.05), value: audioLevel)

            case .processing:
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(width: 24, height: 24)
    }

    private func startPulse() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}
