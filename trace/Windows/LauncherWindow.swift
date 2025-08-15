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
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 810, height: 360),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupContent()
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
        isMovableByWindowBackground = false
        
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
    
    func show() {
        let logger = AppLogger.launcherWindow
        logger.debug("🚪 LauncherWindow.show() called")
        
        centerOnScreen()
        
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
    
    func hide() {
        let logger = AppLogger.launcherWindow
        logger.debug("🙈 LauncherWindow.hide() called")
        
        preventAutoClose = false // Reset flag when hiding
        orderOut(nil)
        
        // Restore focus to the previously active application
        if let lastApp = PermissionManager.shared.lastActiveApplication {
            lastApp.activate()
            logger.debug("🎯 Restored focus to app: \(lastApp.localizedName ?? lastApp.bundleIdentifier ?? "Unknown")")
        }
        
        logger.debug("✅ LauncherWindow hide completed - isVisible: \(self.isVisible)")
    }
    
    func setPreventAutoClose(_ prevent: Bool) {
        preventAutoClose = prevent
    }
    
    private func centerOnScreen() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowFrame = frame
        
        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.midY - (windowFrame.height / 2) + (windowFrame.height * 2)
        
        setFrameOrigin(NSPoint(x: x, y: y))
    }
    
}

// MARK: - Notifications

extension Notification.Name {
    static let launcherWindowDidBecomeKey = Notification.Name("launcherWindowDidBecomeKey")
    static let shouldFocusSearchField = Notification.Name("shouldFocusSearchField")
}
