//
//  SettingsWindow.swift
//  trace
//
//  Created by Arjun on 8/15/2025.
//

import Cocoa
import SwiftUI

class SettingsWindow: NSWindow {
    private var hostingView: NSHostingView<SettingsView>?
    
    init() {
        super.init(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: AppConstants.Window.settingsWidth,
                height: AppConstants.Window.settingsHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupContent()
    }
    
    private func setupWindow() {
        isReleasedWhenClosed = false
        level = .normal
        title = "Trace Settings"
        titleVisibility = .hidden
        minSize = NSSize(width: 700, height: 560)
        setContentSize(NSSize(
            width: AppConstants.Window.settingsWidth,
            height: AppConstants.Window.settingsHeight
        ))
        center()
        
        isMovableByWindowBackground = true
        collectionBehavior = [.managed, .fullScreenAuxiliary]
        
        isOpaque = false
        backgroundColor = .windowBackgroundColor
        hasShadow = true
        
        if #available(macOS 11.0, *) {
            titlebarSeparatorStyle = .none
            toolbarStyle = .unified
        }
        
        titlebarAppearsTransparent = true
    }
    
    private func setupContent() {
        let settingsView = SettingsView()
        
        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        self.hostingView = hostingView
        contentView = hostingView
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    func show() {
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        setIsVisible(true)
    }
    
    func hide() {
        orderOut(nil)
        setIsVisible(false)
    }
}
