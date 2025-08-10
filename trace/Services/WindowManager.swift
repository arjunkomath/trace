//
//  WindowManager.swift
//  trace
//
//  Created by Claude on 8/8/2025.
//

import AppKit
import CoreGraphics
import SwiftUI
import os.log
import Carbon

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
    case fullScreen = "full-screen"
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
        case .fullScreen: return "Full Screen"
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
        case .fullScreen: return "Enter native macOS full screen mode"
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
    private let permissionManager = PermissionManager.shared
    
    private init() {}
    
    // MARK: - Window Management
    
    /// Simplified window tracking - no longer needed with new permission system
    func trackCurrentActiveWindow() {
        // This method is kept for compatibility but is no longer needed
        // The new permission system tests capabilities on-demand
        logger.debug("Window tracking called - using on-demand capability testing instead")
    }
    
    func applyWindowPosition(_ position: WindowPosition) {
        logger.info("Applying window position: \(position.rawValue)")
        
        permissionManager.performWindowOperation(
            { window in
                if position == .fullScreen {
                    return self.toggleFullScreen(window)
                } else {
                    return self.repositionWindow(window, to: position)
                }
            },
            onSuccess: {
                self.logger.info("Successfully applied window position: \(position.displayName)")
            },
            onFailure: { error in
                self.permissionManager.showWindowManagementError(error)
            }
        )
    }
    
    private func repositionWindow(_ window: AXUIElement, to position: WindowPosition) -> Bool {
        guard let screen = NSScreen.main else {
            logger.error("Could not get main screen")
            return false
        }
        
        let screenFrame = screen.visibleFrame
        let newFrame = calculateFrame(for: position, screenFrame: screenFrame, window: window)
        
        return setWindowFrame(window, frame: newFrame)
    }
    
    private func calculateFrame(for position: WindowPosition, screenFrame: CGRect, window: AXUIElement) -> CGRect {
        let _: CGFloat = 20 // For almost-maximize
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
            
        case .fullScreen:
            // This case is handled separately in applyWindowPosition, but we need this case for exhaustiveness
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
    
    private func toggleFullScreen(_ window: AXUIElement) -> Bool {
        // Method 1: Try the fullscreen attribute directly (most reliable)
        var isFullScreen: CFTypeRef?
        let fullScreenResult = AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &isFullScreen)
        
        if fullScreenResult == .success {
            let currentValue = isFullScreen as? Bool ?? false
            let newValue = !currentValue
            let fullScreenValue = newValue as CFBoolean
            let result = AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, fullScreenValue)
            if result == .success {
                logger.info("Successfully toggled fullscreen: \(currentValue) -> \(newValue)")
                return true
            } else {
                logger.warning("Failed to set AXFullScreen attribute. Error: \(result.rawValue)")
            }
        } else {
            logger.debug("Window does not support AXFullScreen attribute. Error: \(fullScreenResult.rawValue)")
        }
        
        // Method 2: Use the zoom button (fallback)
        var zoomButton: CFTypeRef?
        let zoomButtonResult = AXUIElementCopyAttributeValue(window, kAXZoomButtonAttribute as CFString, &zoomButton)
        
        if zoomButtonResult == .success, let button = zoomButton {
            let zoomResult = AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
            if zoomResult == .success {
                logger.info("Successfully toggled fullscreen using zoom button")
                return true
            } else {
                logger.warning("Failed to press zoom button. Error: \(zoomResult.rawValue)")
            }
        } else {
            logger.debug("Window does not have zoom button. Error: \(zoomButtonResult.rawValue)")
        }
        
        // Method 3: Fallback - try using keyboard shortcut simulation
        logger.info("Attempting fullscreen toggle via keyboard shortcut")
        
        // Get the application element to send the keyboard shortcut to
        var appPid: pid_t = 0
        let pidResult = AXUIElementGetPid(window, &appPid)
        
        if pidResult == .success {
            // Send Cmd+Ctrl+F (common fullscreen toggle shortcut)
            let source = CGEventSource(stateID: .hidSystemState)
            let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x03, keyDown: true) // F key
            let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x03, keyDown: false)
            
            keyDownEvent?.flags = [.maskCommand, .maskControl]
            keyUpEvent?.flags = [.maskCommand, .maskControl]
            
            keyDownEvent?.postToPid(appPid)
            keyUpEvent?.postToPid(appPid)
            
            logger.info("Sent Cmd+Ctrl+F to toggle fullscreen")
            return true
        }
        
        logger.warning("All fullscreen toggle methods failed")
        return false
    }
    
    // MARK: - System Appearance Toggle
    
    func toggleSystemAppearance() {
        let script = """
            tell application "System Events"
                tell appearance preferences
                    set dark mode to not dark mode
                end tell
            end tell
        """
        
        permissionManager.executeAppleScript(script,
            onSuccess: { _ in
                self.logger.info("Successfully toggled system appearance")
            },
            onFailure: { error in
                self.logger.error("Failed to toggle system appearance: \(error)")
                self.permissionManager.showNotification(
                    title: "System Appearance Error", 
                    body: error
                )
            }
        )
    }
}

