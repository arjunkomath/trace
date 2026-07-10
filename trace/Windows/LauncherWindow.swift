//
//  LauncherWindow.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import Cocoa
import SwiftUI

class LauncherWindow: NSPanel {
    private var hostingView: NSHostingView<LauncherView>?
    private var preventAutoClose = false
    private let settingsManager = SettingsManager.shared
    private var isApplyingSavedPosition = false
    private var savePositionWorkItem: DispatchWorkItem?
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 810, height: 360),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupContent()
        setupPositionPersistence()
    }
    
    deinit {
        savePositionWorkItem?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupWindow() {
        isReleasedWhenClosed = false
        
        // Critical settings for full-screen overlay
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovable = true
        isMovableByWindowBackground = true
        
        // Essential collection behaviors for full-screen overlay
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Hide standard window buttons
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        
        // Accessibility permissions are only needed for window management features
        // The launcher and overlay work fine without them
    }
    
    private func setupContent() {
        let hostingView = NSHostingView(rootView: LauncherView { [weak self] in
            self?.hide()
        })
        
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        self.hostingView = hostingView
        contentView = hostingView
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    override func resignKey() {
        // Close panel when it loses key status for launcher behavior, unless we're showing a dialog
        super.resignKey()
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.preventAutoClose else { return }
            self.hide()
        }
    }
    
    override func becomeKey() {
        super.becomeKey()
        // Post notification when window becomes key so LauncherView can focus
        NotificationCenter.default.post(name: .launcherWindowDidBecomeKey, object: self)
    }
    
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        guard let screen = screen ?? self.screen ?? NSScreen.active else {
            return super.constrainFrameRect(frameRect, to: screen)
        }
        
        return horizontallyCenteredFrame(frameRect, on: screen)
    }
    
    func show() {
        let logger = AppLogger.launcherWindow
        logger.debug("🚪 LauncherWindow.show() called")
        
        positionOnScreen()
        
        // Activate the app to ensure the window can become visible
        logger.debug("🎯 Activating app for launcher visibility")
        NSApp.activate(ignoringOtherApps: true)
        
        // NSPanel specific showing for full-screen overlay
        logger.debug("📺 Making launcher window key and ordering front")
        orderFrontRegardless()
        makeKeyAndOrderFront(nil)
        
        // Log final window state
        logger.debug("✅ LauncherWindow show completed - isVisible: \(self.isVisible), isKeyWindow: \(self.isKeyWindow)")
        
        // Ensure focus is properly set after panel becomes key
        DispatchQueue.main.async { [weak self] in
            self?.ensureFocus()
        }
    }
    
    private func ensureFocus() {
        // Multiple attempts with increasing delays to ensure focus works
        let delays: [TimeInterval] = [0.05, 0.1, 0.2]
        
        for (_, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                NotificationCenter.default.post(name: .shouldFocusSearchField, object: nil)
            }
        }
    }
    
    func hide(restoreFocus: Bool = true) {
        let logger = AppLogger.launcherWindow
        logger.debug("🙈 LauncherWindow.hide() called with restoreFocus: \(restoreFocus)")
        
        preventAutoClose = false // Reset flag when hiding
        orderOut(nil)
        NotificationCenter.default.post(name: .launcherWindowWillHide, object: self)
        
        // Only restore focus to the previously active application if requested
        if restoreFocus, let lastApp = PermissionManager.shared.lastActiveApplication {
            lastApp.activate()
            logger.debug("🎯 Restored focus to app: \(lastApp.localizedName ?? lastApp.bundleIdentifier ?? "Unknown")")
        } else if !restoreFocus {
            logger.debug("🚫 Skipping focus restoration to allow natural focus change")
        }
        
        logger.debug("✅ LauncherWindow hide completed - isVisible: \(self.isVisible)")
    }
    
    func setPreventAutoClose(_ prevent: Bool) {
        preventAutoClose = prevent
    }
    
    private func setupPositionPersistence() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: self
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(launcherContentSizeDidChange),
            name: .launcherContentSizeDidChange,
            object: nil
        )
    }
    
    private func positionOnScreen() {
        // Place the launcher on the screen with the active window, not always the main display.
        guard let screen = NSScreen.active else { return }
        resizeToFitContent()
        
        let nextFrame = frame(
            on: screen,
            verticalPositionRatio: settingsManager.settings.launcherVerticalPositionRatio
        )
        
        isApplyingSavedPosition = true
        setFrame(nextFrame, display: false)
        DispatchQueue.main.async { [weak self] in
            self?.isApplyingSavedPosition = false
        }
    }
    
    @objc private func windowDidMove() {
        guard isVisible, !isApplyingSavedPosition else { return }
        guard let screen = screen ?? NSScreen.active else { return }
        
        let constrainedFrame = horizontallyCenteredFrame(frame, on: screen)
        if frame.origin != constrainedFrame.origin {
            isApplyingSavedPosition = true
            setFrameOrigin(constrainedFrame.origin)
            DispatchQueue.main.async { [weak self] in
                self?.isApplyingSavedPosition = false
            }
        }
        
        schedulePositionSave(for: constrainedFrame, on: screen)
    }

    @objc private func launcherContentSizeDidChange() {
        guard isVisible else { return }
        guard let screen = screen ?? NSScreen.active else { return }

        let previousMaxY = frame.maxY
        savePositionWorkItem?.cancel()
        isApplyingSavedPosition = true

        resizeToFitContent()
        var nextFrame = horizontallyCenteredFrame(frame, on: screen)
        nextFrame.origin.y = clamp(
            previousMaxY - nextFrame.height,
            min: screen.visibleFrame.minY,
            max: screen.visibleFrame.maxY - nextFrame.height
        )

        setFrame(nextFrame, display: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isApplyingSavedPosition = false
        }
    }

    private func resizeToFitContent() {
        guard let hostingView else { return }

        let fittingSize = hostingView.fittingSize
        guard fittingSize.width > 0, fittingSize.height > 0 else { return }

        setContentSize(fittingSize)
    }
    
    private func frame(on screen: NSScreen, verticalPositionRatio: Double) -> NSRect {
        var nextFrame = frame
        let screenFrame = screen.visibleFrame
        let clampedRatio = TraceSettings.clampLauncherVerticalPositionRatio(verticalPositionRatio)
        let centerY = screenFrame.minY + (screenFrame.height * CGFloat(clampedRatio))
        
        nextFrame.origin.x = screenFrame.midX - nextFrame.width / 2
        nextFrame.origin.y = centerY - nextFrame.height / 2
        nextFrame.origin.y = clamp(
            nextFrame.origin.y,
            min: screenFrame.minY,
            max: screenFrame.maxY - nextFrame.height
        )
        
        return nextFrame
    }
    
    private func horizontallyCenteredFrame(_ frameRect: NSRect, on screen: NSScreen) -> NSRect {
        var constrainedFrame = frameRect
        let screenFrame = screen.visibleFrame
        
        constrainedFrame.origin.x = screenFrame.midX - constrainedFrame.width / 2
        constrainedFrame.origin.y = clamp(
            constrainedFrame.origin.y,
            min: screenFrame.minY,
            max: screenFrame.maxY - constrainedFrame.height
        )
        
        return constrainedFrame
    }
    
    private func schedulePositionSave(for frame: NSRect, on screen: NSScreen) {
        let ratio = verticalPositionRatio(for: frame, on: screen)
        
        savePositionWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.settingsManager.updateLauncherVerticalPositionRatio(ratio)
        }
        
        savePositionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }
    
    private func verticalPositionRatio(for frame: NSRect, on screen: NSScreen) -> Double {
        let screenFrame = screen.visibleFrame
        guard screenFrame.height > 0 else {
            return TraceSettings.defaultLauncherVerticalPositionRatio
        }
        
        let ratio = Double((frame.midY - screenFrame.minY) / screenFrame.height)
        return TraceSettings.clampLauncherVerticalPositionRatio(ratio)
    }
    
    private func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        guard minValue <= maxValue else { return minValue }
        return Swift.min(Swift.max(value, minValue), maxValue)
    }
    
}

// MARK: - Notifications

extension Notification.Name {
    static let launcherWindowDidBecomeKey = Notification.Name("launcherWindowDidBecomeKey")
    static let shouldFocusSearchField = Notification.Name("shouldFocusSearchField")
    static let launcherWindowWillHide = Notification.Name("launcherWindowWillHide")
    static let launcherContentSizeDidChange = Notification.Name("launcherContentSizeDidChange")
}
