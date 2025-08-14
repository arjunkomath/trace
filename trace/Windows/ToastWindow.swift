//
//  ToastWindow.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import Cocoa
import SwiftUI

class ToastWindow: NSPanel {
    private var hostingView: NSHostingView<ToastView>?
    private var hideTimer: Timer?
    
    init(message: String, type: ToastType) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupContent(message: message, type: type)
    }
    
    private func setupWindow() {
        // Window configuration for toast overlay
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
        
        // Hide standard window buttons
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }
    
    private func setupContent(message: String, type: ToastType) {
        let toastView = ToastView(
            message: message,
            type: type,
            onDismiss: { [weak self] in
                self?.hide()
            }
        )
        
        let hostingView = NSHostingView(rootView: toastView)
        self.hostingView = hostingView
        contentView = hostingView
    }
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    func show() {
        positionWindow()
        
        // Show window without activation
        orderFrontRegardless()
        
        // Make window visible
        alphaValue = 0
        setIsVisible(true)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            alphaValue = 1.0
        }
    }
    
    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.setIsVisible(false)
        })
    }
    
    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowFrame = frame
        
        // Position at top-right with padding
        let padding: CGFloat = 20
        let x = screenFrame.maxX - windowFrame.width - padding
        let y = screenFrame.maxY - windowFrame.height - padding
        
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
