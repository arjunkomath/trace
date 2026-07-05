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
    private var initialSection: TraceSettingsSection
    
    init(initialSection: TraceSettingsSection = .general) {
        self.initialSection = initialSection
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
        setupContent(initialSection: initialSection)
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
    
    private func setupContent(initialSection: TraceSettingsSection) {
        let settingsView = SettingsView(initialSection: initialSection)
        
        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        self.hostingView = hostingView
        contentView = hostingView
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    func show() {
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows])

        orderFrontRegardless()
        makeKeyAndOrderFront(nil)
        makeMain()
        setIsVisible(true)

        ensureFocus()
    }

    func show(section: TraceSettingsSection) {
        setupContent(initialSection: section)
        show()
    }

    private func ensureFocus() {
        let delays: [TimeInterval] = [0.05, 0.15, 0.3]

        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.isVisible else { return }

                NSApp.activate(ignoringOtherApps: true)
                NSRunningApplication.current.activate(options: [.activateAllWindows])
                self.orderFrontRegardless()
                self.makeKeyAndOrderFront(nil)
                self.makeMain()
            }
        }
    }
    
    func hide() {
        orderOut(nil)
        setIsVisible(false)
    }
}
