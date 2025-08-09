//
//  LauncherWindow.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import Cocoa
import SwiftUI
import ApplicationServices

class LauncherWindow: NSPanel {
    private var hostingView: NSHostingView<LauncherView>?
    
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
        
        // Request accessibility permissions if not already granted
        requestAccessibilityPermissions()
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
        // Close panel when it loses key status for launcher behavior
        super.resignKey()
        DispatchQueue.main.async { [weak self] in
            self?.hide()
        }
    }
    
    override func becomeKey() {
        super.becomeKey()
        // Ensure app is activated when panel becomes key
        NSApp.activate(ignoringOtherApps: true)
        // Post notification when window becomes key so LauncherView can focus
        NotificationCenter.default.post(name: .launcherWindowDidBecomeKey, object: self)
    }
    
    func show() {
        centerOnScreen()
        
        // NSPanel specific showing for full-screen overlay
        orderFrontRegardless()
        makeKeyAndOrderFront(nil)
        
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
        orderOut(nil)
    }
    
    private func centerOnScreen() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowFrame = frame
        
        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.midY - windowFrame.height / 2 + 200 // Position higher for better visual balance with results
        
        setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    // MARK: - Accessibility Permissions
    
    private func requestAccessibilityPermissions() {
        // Check if accessibility is already enabled
        let trusted = AXIsProcessTrusted()
        
        if !trusted {
            // Request accessibility permissions
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let launcherWindowDidBecomeKey = Notification.Name("launcherWindowDidBecomeKey")
    static let shouldFocusSearchField = Notification.Name("shouldFocusSearchField")
}