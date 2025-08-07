//
//  AppDelegate.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import Cocoa
import SwiftUI
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Constants
    private enum Constants {
        static let defaultKeyCode: UInt32 = 49 // Space key
        static let menuOffset = NSPoint(x: 0, y: 5)
    }
    var statusItem: NSStatusItem!
    var launcherWindow: LauncherWindow!
    var hotkeyManager: HotkeyManager!
    var globalEventMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupLauncherWindow()
        setupHotkey()
        requestAccessibilityPermissions()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Trace")
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Trace", action: #selector(showLauncher), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Trace", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    private func setupLauncherWindow() {
        launcherWindow = LauncherWindow()
    }
    
    private func setupHotkey() {
        hotkeyManager = HotkeyManager()
        hotkeyManager.onHotkeyPressed = { [weak self] in
            self?.toggleLauncher()
        }
        
        let savedKeyCode = UserDefaults.standard.integer(forKey: "hotkey_keyCode")
        let savedModifiers = UserDefaults.standard.integer(forKey: "hotkey_modifiers")
        
        let keyCode = savedKeyCode > 0 ? UInt32(savedKeyCode) : Constants.defaultKeyCode
        let modifiers = savedModifiers > 0 ? UInt32(savedModifiers) : UInt32(optionKey)
        
        do {
            try hotkeyManager.registerHotkey(keyCode: keyCode, modifiers: modifiers)
        } catch {
            NSLog("Failed to register hotkey: %@", error.localizedDescription)
        }
    }
    
    private func requestAccessibilityPermissions() {
        let accessEnabled = AXIsProcessTrusted()
        
        if !accessEnabled {
            do {
                let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                let hasPermissions = AXIsProcessTrustedWithOptions(options)
                
                if !hasPermissions {
                    NSLog("Accessibility permissions needed for global hotkey - please check System Preferences > Security & Privacy > Accessibility")
                }
            } catch {
                NSLog("Failed to request accessibility permissions: %@", error.localizedDescription)
            }
        }
    }
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            let menuPosition = NSPoint(x: Constants.menuOffset.x, y: sender.bounds.height + Constants.menuOffset.y)
            statusItem.menu?.popUp(positioning: nil, at: menuPosition, in: sender)
        } else {
            statusItem.menu = nil
            showLauncher()
        }
    }
    
    @objc private func showLauncher() {
        launcherWindow.show()
        startGlobalEventMonitoring()
    }
    
    @objc func showPreferences() {
        if let settingsScene = NSApp.windows.first(where: { $0.title.contains("Settings") || $0.title.contains("Preferences") }) {
            settingsScene.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func toggleLauncher() {
        if launcherWindow.isVisible {
            launcherWindow.hide()
            stopGlobalEventMonitoring()
        } else {
            launcherWindow.show()
            startGlobalEventMonitoring()
        }
    }
    
    private func startGlobalEventMonitoring() {
        guard globalEventMonitor == nil else { return }
        
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.launcherWindow.hide()
            self?.stopGlobalEventMonitoring()
        }
    }
    
    private func stopGlobalEventMonitoring() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregisterHotkey()
        stopGlobalEventMonitoring()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showLauncher()
        return true
    }
}