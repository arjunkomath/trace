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
        
        let keyCode = savedKeyCode > 0 ? UInt32(savedKeyCode) : 49
        let modifiers = savedModifiers > 0 ? UInt32(savedModifiers) : UInt32(optionKey)
        
        hotkeyManager.registerHotkey(keyCode: keyCode, modifiers: modifiers)
    }
    
    private func requestAccessibilityPermissions() {
        // First check if we have permissions
        let accessEnabled = AXIsProcessTrusted()
        
        if !accessEnabled {
            // Request permissions with prompt
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            let _ = AXIsProcessTrustedWithOptions(options)
            print("Accessibility permissions needed for global hotkey - please check System Preferences")
        }
    }
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent {
            if event.type == .rightMouseUp {
                statusItem.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 5), in: sender)
            } else {
                statusItem.menu = nil
                showLauncher()
            }
        }
    }
    
    @objc private func showLauncher() {
        launcherWindow.show()
        startGlobalEventMonitoring()
    }
    
    @objc func showPreferences() {
        print("AppDelegate showPreferences called - DEBUG")
        // Use the proper SwiftUI Settings scene approach
        if let settingsScene = NSApp.windows.first(where: { $0.title.contains("Settings") || $0.title.contains("Preferences") }) {
            settingsScene.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // Trigger the Settings scene to open
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