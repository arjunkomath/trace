//
//  LauncherWindow.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import Cocoa
import SwiftUI

class LauncherWindow: NSWindow {
    private var hostingView: NSHostingView<LauncherView>?
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 810, height: 360),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupContent()
    }
    
    private func setupWindow() {
        isReleasedWhenClosed = false
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
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
    
    func show() {
        centerOnScreen()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Ensure focus is properly set after window becomes key
        DispatchQueue.main.async { [weak self] in
            self?.ensureFocus()
        }
    }
    
    override func becomeKey() {
        super.becomeKey()
        // Post notification when window becomes key so LauncherView can focus
        NotificationCenter.default.post(name: .launcherWindowDidBecomeKey, object: self)
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
}

// MARK: - Notifications

extension Notification.Name {
    static let launcherWindowDidBecomeKey = Notification.Name("launcherWindowDidBecomeKey")
    static let shouldFocusSearchField = Notification.Name("shouldFocusSearchField")
}