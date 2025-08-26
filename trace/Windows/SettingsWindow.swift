//
//  SettingsWindow.swift
//  trace
//
//  Created by Arjun on 8/15/2025.
//

import Cocoa
import SwiftUI

class SettingsWindow: NSPanel {
    private var hostingView: NSHostingView<SettingsView>?
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 500),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupContent()
    }
    
    private func setupWindow() {
        // Window configuration for settings overlay
        isReleasedWhenClosed = false
        isFloatingPanel = true
        level = .statusBar
        title = "Trace Settings"
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        
        // Enable transparency and material effect
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        
        // Standard window behavior but non-activating
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        
        // Corner radius for modern look
        if #available(macOS 11.0, *) {
            titlebarSeparatorStyle = .none
        }
    }
    
    private func setupContent() {
        let settingsView = SettingsView()
        
        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.layer?.backgroundColor = .clear
        self.hostingView = hostingView
        contentView = hostingView
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    func show() {
        positionWindow()
        
        // Show window and make it key to allow input focus
        makeKeyAndOrderFront(nil)
        
        // Make window visible
        setIsVisible(true)
    }
    
    func hide() {
        orderOut(nil)
        setIsVisible(false)
    }
    
    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowFrame = frame
        
        // Center the window on screen
        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.midY - windowFrame.height / 2
        
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
