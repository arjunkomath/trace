//
//  WindowManager.swift
//  trace
//
//  Created by Claude on 8/8/2025.
//

import AppKit
import CoreGraphics
import UserNotifications

enum WindowPosition: String, CaseIterable {
    case leftHalf = "left-half"
    case rightHalf = "right-half"
    case centerHalf = "center-half"
    case topHalf = "top-half"
    case bottomHalf = "bottom-half"
    case topLeft = "top-left"
    case topRight = "top-right"
    case bottomLeft = "bottom-left"
    case bottomRight = "bottom-right"
    case firstThird = "first-third"
    case centerThird = "center-third"
    case lastThird = "last-third"
    case firstTwoThirds = "first-two-thirds"
    case lastTwoThirds = "last-two-thirds"
    case maximize = "maximize"
    case almostMaximize = "almost-maximize"
    case maximizeHeight = "maximize-height"
    case smaller = "smaller"
    case larger = "larger"
    case center = "center"
    case centerProminently = "center-prominently"
    
    var displayName: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .centerHalf: return "Center Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        case .firstThird: return "First Third"
        case .centerThird: return "Center Third"
        case .lastThird: return "Last Third"
        case .firstTwoThirds: return "First Two Thirds"
        case .lastTwoThirds: return "Last Two Thirds"
        case .maximize: return "Maximize"
        case .almostMaximize: return "Almost Maximize"
        case .maximizeHeight: return "Maximize Height"
        case .smaller: return "Smaller"
        case .larger: return "Larger"
        case .center: return "Center"
        case .centerProminently: return "Center Prominently"
        }
    }
    
    var subtitle: String {
        switch self {
        case .leftHalf: return "Move window to left half of screen"
        case .rightHalf: return "Move window to right half of screen"
        case .centerHalf: return "Move window to center half of screen"
        case .topHalf: return "Move window to top half of screen"
        case .bottomHalf: return "Move window to bottom half of screen"
        case .topLeft: return "Move window to top left quarter"
        case .topRight: return "Move window to top right quarter"
        case .bottomLeft: return "Move window to bottom left quarter"
        case .bottomRight: return "Move window to bottom right quarter"
        case .firstThird: return "Move window to first third of screen"
        case .centerThird: return "Move window to center third of screen"
        case .lastThird: return "Move window to last third of screen"
        case .firstTwoThirds: return "Move window to first two thirds of screen"
        case .lastTwoThirds: return "Move window to last two thirds of screen"
        case .maximize: return "Maximize window to full screen"
        case .almostMaximize: return "Maximize with small margins"
        case .maximizeHeight: return "Maximize window height only"
        case .smaller: return "Make window smaller"
        case .larger: return "Make window larger"
        case .center: return "Center window on screen"
        case .centerProminently: return "Center and resize prominently"
        }
    }
}

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    private let logger = AppLogger.windowManager
    
    private var previousActiveWindow: AXUIElement?
    private var previousActiveApp: NSRunningApplication?
    
    @Published var showToast = false
    @Published var toastMessage = ""
    @Published var toastType: ToastView.ToastType = .error
    
    private init() {
        requestNotificationPermissions()
    }
    
    // MARK: - Window Tracking
    
    func trackCurrentActiveWindow() {
        // Check accessibility permissions first
        guard hasAccessibilityPermissions() else {
            logger.error("Accessibility permissions required for window management")
            return
        }
        
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            logger.warning("Could not get frontmost application")
            return
        }
        
        logger.info("Frontmost app: \(frontmostApp.localizedName ?? "Unknown") (\(frontmostApp.bundleIdentifier ?? "Unknown ID"))")
        
        // Don't track Trace itself
        guard frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier else {
            logger.info("Skipping Trace app itself")
            return
        }
        
        let appRef = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        
        var frontmostWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &frontmostWindow)
        
        if result == .success, let window = frontmostWindow {
            previousActiveWindow = (window as! AXUIElement)
            previousActiveApp = frontmostApp
            logger.info("Successfully tracked active window for app: \(frontmostApp.localizedName ?? "Unknown")")
        } else {
            logger.warning("Could not get focused window from frontmost app. Result: \(result.rawValue)")
            // Try to get the first window instead
            var windows: CFTypeRef?
            let windowsResult = AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &windows)
            if windowsResult == .success, 
               let windowArray = windows as? [AXUIElement],
               let firstWindow = windowArray.first {
                previousActiveWindow = firstWindow
                previousActiveApp = frontmostApp
                logger.info("Tracked first window for app: \(frontmostApp.localizedName ?? "Unknown")")
            } else {
                logger.error("Could not get any windows from app")
            }
        }
    }
    
    // MARK: - Window Management
    
    func applyWindowPosition(_ position: WindowPosition) {
        logger.info("🪟 applyWindowPosition called with position: \(position.rawValue)")
        
        // Try to get the current active window if we don't have one tracked, or if the tracked one is stale
        var windowToManage = previousActiveWindow
        
        if windowToManage == nil {
            logger.info("🔍 No tracked window, attempting to find current active window...")
            windowToManage = getCurrentActiveWindow()
        } else {
            // Verify the tracked window is still valid
            if !isWindowValid(windowToManage!) {
                logger.warning("⚠️ Tracked window is no longer valid, finding current active window...")
                windowToManage = getCurrentActiveWindow()
                if windowToManage != nil {
                    previousActiveWindow = windowToManage
                }
            }
        }
        
        guard let window = windowToManage else {
            logger.error("❌ No window available to manage")
            showSystemNotification("Window Management Error", "No active window found. Try clicking on a window first.")
            return
        }
        
        logger.info("✅ Window available for management")
        
        guard let screen = NSScreen.main else {
            logger.error("Could not get main screen")
            showSystemNotification("Window Management Error", "Screen not available")
            return
        }
        
        let screenFrame = screen.visibleFrame
        let newFrame = calculateFrame(for: position, screenFrame: screenFrame, window: window)
        
        let success = setWindowFrame(window, frame: newFrame)
        
        if success {
            // Bring the window's app to front
            if let app = previousActiveApp {
                app.activate()
            }
            
            logger.info("Applied window position: \(position.displayName)")
            // No notification for successful operations
        } else {
            showSystemNotification("Window Management Error", "Failed to resize window")
        }
    }
    
    private func calculateFrame(for position: WindowPosition, screenFrame: CGRect, window: AXUIElement) -> CGRect {
        let margin: CGFloat = 20 // For almost-maximize
        let resizeStep: CGFloat = 50 // For smaller/larger
        
        switch position {
        case .leftHalf:
            return CGRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y,
                width: screenFrame.width / 2,
                height: screenFrame.height
            )
            
        case .rightHalf:
            return CGRect(
                x: screenFrame.origin.x + screenFrame.width / 2,
                y: screenFrame.origin.y,
                width: screenFrame.width / 2,
                height: screenFrame.height
            )
            
        case .centerHalf:
            let width = screenFrame.width / 2
            return CGRect(
                x: screenFrame.origin.x + screenFrame.width / 4,
                y: screenFrame.origin.y,
                width: width,
                height: screenFrame.height
            )
            
        case .topHalf:
            return CGRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y,
                width: screenFrame.width,
                height: screenFrame.height / 2
            )
            
        case .bottomHalf:
            return CGRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y + screenFrame.height / 2,
                width: screenFrame.width,
                height: screenFrame.height / 2
            )
            
        case .topLeft:
            return CGRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y,
                width: screenFrame.width / 2,
                height: screenFrame.height / 2
            )
            
        case .topRight:
            return CGRect(
                x: screenFrame.origin.x + screenFrame.width / 2,
                y: screenFrame.origin.y,
                width: screenFrame.width / 2,
                height: screenFrame.height / 2
            )
            
        case .bottomLeft:
            return CGRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y + screenFrame.height / 2,
                width: screenFrame.width / 2,
                height: screenFrame.height / 2
            )
            
        case .bottomRight:
            return CGRect(
                x: screenFrame.origin.x + screenFrame.width / 2,
                y: screenFrame.origin.y + screenFrame.height / 2,
                width: screenFrame.width / 2,
                height: screenFrame.height / 2
            )
            
        case .firstThird:
            return CGRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y,
                width: screenFrame.width / 3,
                height: screenFrame.height
            )
            
        case .centerThird:
            return CGRect(
                x: screenFrame.origin.x + screenFrame.width / 3,
                y: screenFrame.origin.y,
                width: screenFrame.width / 3,
                height: screenFrame.height
            )
            
        case .lastThird:
            return CGRect(
                x: screenFrame.origin.x + (screenFrame.width * 2 / 3),
                y: screenFrame.origin.y,
                width: screenFrame.width / 3,
                height: screenFrame.height
            )
            
        case .firstTwoThirds:
            return CGRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y,
                width: screenFrame.width * 2 / 3,
                height: screenFrame.height
            )
            
        case .lastTwoThirds:
            return CGRect(
                x: screenFrame.origin.x + screenFrame.width / 3,
                y: screenFrame.origin.y,
                width: screenFrame.width * 2 / 3,
                height: screenFrame.height
            )
            
        case .maximize:
            return screenFrame
            
        case .almostMaximize:
            let width = screenFrame.width * 0.9
            let height = screenFrame.height * 0.9
            return CGRect(
                x: screenFrame.origin.x + (screenFrame.width - width) / 2,
                y: screenFrame.origin.y + (screenFrame.height - height) / 2 + 25,
                width: width,
                height: height
            )
            
        case .maximizeHeight:
            let currentFrame = getCurrentWindowFrame(window) ?? CGRect(x: screenFrame.midX - 300, y: screenFrame.origin.y, width: 600, height: screenFrame.height)
            return CGRect(
                x: currentFrame.origin.x,
                y: screenFrame.origin.y,
                width: currentFrame.width,
                height: screenFrame.height
            )
            
        case .smaller:
            let currentFrame = getCurrentWindowFrame(window) ?? CGRect(x: screenFrame.midX - 300, y: screenFrame.midY - 200, width: 600, height: 400)
            let newWidth = max(300, currentFrame.width - resizeStep)
            let newHeight = max(200, currentFrame.height - resizeStep)
            return CGRect(
                x: currentFrame.origin.x + (currentFrame.width - newWidth) / 2,
                y: currentFrame.origin.y + (currentFrame.height - newHeight) / 2,
                width: newWidth,
                height: newHeight
            )
            
        case .larger:
            let currentFrame = getCurrentWindowFrame(window) ?? CGRect(x: screenFrame.midX - 300, y: screenFrame.midY - 200, width: 600, height: 400)
            let newWidth = min(screenFrame.width, currentFrame.width + resizeStep)
            let newHeight = min(screenFrame.height, currentFrame.height + resizeStep)
            return CGRect(
                x: max(screenFrame.origin.x, currentFrame.origin.x - resizeStep / 2),
                y: max(screenFrame.origin.y, currentFrame.origin.y - resizeStep / 2),
                width: newWidth,
                height: newHeight
            )
            
        case .center:
            let currentFrame = getCurrentWindowFrame(window) ?? CGRect(x: 0, y: 0, width: 600, height: 400)
            return CGRect(
                x: screenFrame.origin.x + (screenFrame.width - currentFrame.width) / 2,
                y: screenFrame.origin.y + (screenFrame.height - currentFrame.height) / 2,
                width: currentFrame.width,
                height: currentFrame.height
            )
            
        case .centerProminently:
            let width = screenFrame.width * 0.7
            let height = screenFrame.height * 0.7
            return CGRect(
                x: screenFrame.origin.x + (screenFrame.width - width) / 2,
                y: screenFrame.origin.y + (screenFrame.height - height) / 2,
                width: width,
                height: height
            )
        }
    }
    
    private func getCurrentWindowFrame(_ window: AXUIElement) -> CGRect? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &size) == .success,
              let pos = position,
              let sz = size else {
            return nil
        }
        
        var point: CGPoint = .zero
        var cgSize: CGSize = .zero
        
        guard CFGetTypeID(pos) == AXValueGetTypeID(),
              CFGetTypeID(sz) == AXValueGetTypeID(),
              AXValueGetValue(pos as! AXValue, .cgPoint, &point),
              AXValueGetValue(sz as! AXValue, .cgSize, &cgSize) else {
            return nil
        }
        
        return CGRect(origin: point, size: cgSize)
    }
    
    private func setWindowFrame(_ window: AXUIElement, frame: CGRect) -> Bool {
        var origin = frame.origin
        var size = frame.size
        
        guard let positionValue = AXValueCreate(.cgPoint, &origin),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            return false
        }
        
        let positionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        
        return positionResult == .success && sizeResult == .success
    }
    
    private func showToastMessage(_ message: String, type: ToastView.ToastType) {
        DispatchQueue.main.async { [weak self] in
            self?.toastMessage = message
            self?.toastType = type
            self?.showToast = true
        }
    }
    
    // MARK: - Improved Window Detection
    
    private func getCurrentActiveWindow() -> AXUIElement? {
        logger.info("🔍 Attempting to find current active window...")
        
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            logger.error("No frontmost application found")
            return nil
        }
        
        // Skip Trace itself
        if frontmostApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            logger.debug("Skipping Trace app itself")
            return nil
        }
        
        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        var windows: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows)
        
        guard result == .success, let windowArray = windows as? [AXUIElement], !windowArray.isEmpty else {
            logger.error("No windows found for app: \(frontmostApp.localizedName ?? "Unknown")")
            return nil
        }
        
        // Find the focused window, or use the first window
        for window in windowArray {
            var focused: AnyObject?
            if AXUIElementCopyAttributeValue(window, kAXFocusedAttribute as CFString, &focused) == .success,
               let isFocused = focused as? Bool, isFocused {
                logger.info("✅ Found focused window for \(frontmostApp.localizedName ?? "Unknown")")
                return window
            }
        }
        
        // Fallback to first window
        let window = windowArray[0]
        logger.info("✅ Using first window for \(frontmostApp.localizedName ?? "Unknown")")
        return window
    }
    
    private func isWindowValid(_ window: AXUIElement) -> Bool {
        var role: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &role)
        return result == .success && role != nil
    }
    
    private func showSystemNotification(_ title: String, _ body: String) {
        logger.info("📢 System notification: \(title) - \(body)")
        
        let notification = UNMutableNotificationContent()
        notification.title = title
        notification.body = body
        notification.sound = nil // Silent notifications
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: notification, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Failed to show notification: \(error)")
            }
        }
    }
    
    // MARK: - Accessibility Permissions
    
    func hasAccessibilityPermissions() -> Bool {
        return AXIsProcessTrusted()
    }
    
    func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge]) { granted, error in
            if let error = error {
                self.logger.error("Failed to request notification permissions: \(error)")
            } else if granted {
                self.logger.info("Notification permissions granted")
            } else {
                self.logger.info("Notification permissions denied")
            }
        }
    }
}
