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
    case centerThreeFourths = "center-three-fourths"
    case maximize = "maximize"
    case fullScreen = "full-screen"
    case almostMaximize = "almost-maximize"
    case maximizeHeight = "maximize-height"
    case smaller = "smaller"
    case larger = "larger"
    case center = "center"
    case centerProminently = "center-prominently"
    case moveToLeftDisplay = "move-to-left-display"
    case moveToRightDisplay = "move-to-right-display"
    
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
        case .centerThreeFourths: return "Center Three Fourths"
        case .maximize: return "Maximize"
        case .fullScreen: return "Full Screen"
        case .almostMaximize: return "Almost Maximize"
        case .maximizeHeight: return "Maximize Height"
        case .smaller: return "Smaller"
        case .larger: return "Larger"
        case .center: return "Center"
        case .centerProminently: return "Center Prominently"
        case .moveToLeftDisplay: return "Move to Left Display"
        case .moveToRightDisplay: return "Move to Right Display"
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
        case .centerThreeFourths: return "Center window at three fourths of screen"
        case .maximize: return "Maximize window to full screen"
        case .fullScreen: return "Enter native macOS full screen mode"
        case .almostMaximize: return "Maximize with small margins"
        case .maximizeHeight: return "Maximize window height only"
        case .smaller: return "Make window smaller"
        case .larger: return "Make window larger"
        case .center: return "Center window on screen"
        case .centerProminently: return "Center and resize prominently"
        case .moveToLeftDisplay: return "Move window to the display on the left, scaling size and position"
        case .moveToRightDisplay: return "Move window to the display on the right, scaling size and position"
        }
    }

    var icon: String {
        switch self {
        case .leftHalf, .rightHalf: return "rectangle.split.2x1"
        case .centerHalf: return "rectangle.center.inset.filled"
        case .topHalf, .bottomHalf: return "rectangle.split.1x2"
        case .topLeft, .topRight, .bottomLeft, .bottomRight: return "rectangle.split.2x2"
        case .firstThird, .centerThird, .lastThird: return "rectangle.split.3x1"
        case .firstTwoThirds, .lastTwoThirds, .centerThreeFourths: return "rectangle.split.3x1"
        case .maximize: return "arrow.up.left.and.arrow.down.right"
        case .fullScreen: return "rectangle.fill"
        case .almostMaximize: return "macwindow"
        case .maximizeHeight: return "arrow.up.and.down"
        case .smaller: return "minus.rectangle"
        case .larger: return "plus.rectangle"
        case .center: return "target"
        case .centerProminently: return "viewfinder"
        case .moveToLeftDisplay: return "arrow.left.to.line"
        case .moveToRightDisplay: return "arrow.right.to.line"
        }
    }
}

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    private let logger = AppLogger.windowManager
    private let permissionManager = PermissionManager.shared
    private var horizontalHalfCycleState: HorizontalHalfCycleState?
    
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
        let axWindowFrame = getCurrentWindowFrame(window)
        let appKitWindowFrame = axWindowFrame.map(convertAXFrameToAppKit)
        
        // Left/right half cycle across adjacent monitors (Rectangle-style).
        if position == .leftHalf || position == .rightHalf {
            let windowFrame = appKitWindowFrame
                ?? screenContainingWindow(nil)?.visibleFrame
                ?? .zero
            
            guard windowFrame != .zero else {
                logger.error("Could not determine window frame for horizontal half positioning")
                return false
            }
            
            let targetAppKitFrame = calculateHorizontalHalfFrame(
                direction: position == .leftHalf ? .left : .right,
                windowFrame: windowFrame,
                window: window
            )
            logger.debug(
                "Horizontal half \(position.rawValue): appKit \(NSStringFromRect(targetAppKitFrame))"
            )
            let updateResult = setWindowFrame(
                window,
                frame: convertAppKitFrameToAX(targetAppKitFrame)
            )

            if updateResult.positionSucceeded {
                let resultingFrame = getCurrentWindowFrame(window)
                    .map(convertAXFrameToAppKit)
                    ?? targetAppKitFrame
                horizontalHalfCycleState = HorizontalHalfCycleState(
                    window: window,
                    requestedFrame: targetAppKitFrame,
                    resultingFrame: resultingFrame
                )
            } else {
                horizontalHalfCycleState = nil
            }

            return updateResult.atLeastOneSucceeded
        }

        horizontalHalfCycleState = nil
        
        // Move to adjacent display, preserving size and relative position.
        if position == .moveToLeftDisplay || position == .moveToRightDisplay {
            let windowFrame = appKitWindowFrame
                ?? screenContainingWindow(nil)?.visibleFrame
                ?? .zero
            
            guard windowFrame != .zero else {
                logger.error("Could not determine window frame for display move")
                return false
            }
            
            let direction: HorizontalDirection = position == .moveToLeftDisplay ? .left : .right
            let moveResult = moveWindowFrameToAdjacentDisplay(
                windowFrame: windowFrame,
                direction: direction
            )

            switch moveResult {
            case .noAdjacentDisplay:
                logger.info("No display to the \(direction.label); keeping window on current display")
                ToastManager.shared.showInfo("No display to the \(direction.label)")
                return true
            case .unavailable:
                logger.error("Could not determine the adjacent display")
                return false
            case .target(let targetAppKitFrame):
                logger.debug(
                    "Move to \(position.rawValue): appKit \(NSStringFromRect(targetAppKitFrame))"
                )
                let updateResult = setWindowFrame(
                    window,
                    frame: convertAppKitFrameToAX(targetAppKitFrame)
                )

                guard updateResult.positionSucceeded else {
                    logger.warning("Window resize may have succeeded, but moving to the adjacent display failed")
                    return false
                }

                return true
            }
        }
        
        guard let screen = screenContainingWindow(appKitWindowFrame) else {
            logger.error("Could not determine screen for window")
            return false
        }
        
        let screenFrame = screen.visibleFrame
        let currentFrame = appKitWindowFrame
            ?? CGRect(x: screenFrame.midX - 300, y: screenFrame.midY - 200, width: 600, height: 400)
        let newAppKitFrame = calculateFrame(
            for: position,
            screenFrame: screenFrame,
            currentFrame: currentFrame
        )
        
        logger.debug(
            "Reposition \(position.rawValue) on screen \(screen.localizedName): appKit \(NSStringFromRect(newAppKitFrame))"
        )
        return setWindowFrame(
            window,
            frame: convertAppKitFrameToAX(newAppKitFrame)
        ).atLeastOneSucceeded
    }
    
    // MARK: - Multi-monitor helpers
    
    private enum HorizontalDirection {
        case left
        case right

        var label: String {
            switch self {
            case .left: return "left"
            case .right: return "right"
            }
        }
    }

    private enum AdjacentDisplayMoveResult {
        case target(CGRect)
        case noAdjacentDisplay
        case unavailable
    }

    private struct HorizontalHalfCycleState {
        let window: AXUIElement
        let requestedFrame: CGRect
        let resultingFrame: CGRect
    }

    private struct WindowFrameUpdateResult {
        let positionSucceeded: Bool
        let sizeSucceeded: Bool

        var atLeastOneSucceeded: Bool {
            positionSucceeded || sizeSucceeded
        }
    }
    
    /// Ordered left→right half slots across all displays:
    /// left mon1, right mon1, left mon2, right mon2, ...
    private struct HorizontalHalfSlot {
        let screen: NSScreen
        let isLeftHalf: Bool
        
        var frame: CGRect {
            let visible = screen.visibleFrame
            let width = visible.width / 2
            return CGRect(
                x: isLeftHalf ? visible.minX : visible.minX + width,
                y: visible.minY,
                width: width,
                height: visible.height
            )
        }
    }
    
    private func screensLeftToRight() -> [NSScreen] {
        NSScreen.screens.sorted {
            if $0.frame.minX == $1.frame.minX {
                return $0.frame.minY < $1.frame.minY
            }
            return $0.frame.minX < $1.frame.minX
        }
    }
    
    private func horizontalHalfSlots() -> [HorizontalHalfSlot] {
        screensLeftToRight().flatMap { screen in
            [
                HorizontalHalfSlot(screen: screen, isLeftHalf: true),
                HorizontalHalfSlot(screen: screen, isLeftHalf: false)
            ]
        }
    }
    
    /// Move the window to the neighboring display on the left or right.
    /// Remaps both origin and size proportionally to the destination visible frame,
    /// so e.g. right-half on a 2560×1440 display becomes right-half on a 1512×982 display.
    /// Returns an explicit no-adjacent-display result when already at the edge.
    private func moveWindowFrameToAdjacentDisplay(
        windowFrame: CGRect,
        direction: HorizontalDirection
    ) -> AdjacentDisplayMoveResult {
        let screens = screensLeftToRight()
        guard !screens.isEmpty else { return .unavailable }
        
        guard let currentScreen = screenContainingWindow(windowFrame),
              let currentIndex = screens.firstIndex(where: {
                  $0.frame.equalTo(currentScreen.frame)
              }) else {
            return .unavailable
        }
        
        let targetIndex: Int
        switch direction {
        case .left:
            targetIndex = currentIndex - 1
        case .right:
            targetIndex = currentIndex + 1
        }
        
        guard screens.indices.contains(targetIndex) else {
            return .noAdjacentDisplay
        }
        
        let source = currentScreen.visibleFrame
        let destination = screens[targetIndex].visibleFrame
        
        guard source.width > 0, source.height > 0 else {
            return .unavailable
        }
        
        // Normalize the window rect against the source display (0…1 in each axis),
        // then scale onto the destination display's visible area.
        let relativeX = (windowFrame.minX - source.minX) / source.width
        let relativeY = (windowFrame.minY - source.minY) / source.height
        let relativeWidth = windowFrame.width / source.width
        let relativeHeight = windowFrame.height / source.height
        
        var width = relativeWidth * destination.width
        var height = relativeHeight * destination.height
        var x = destination.minX + relativeX * destination.width
        var y = destination.minY + relativeY * destination.height
        
        // Keep fully on destination (handles floating-point edge cases / slightly oversize windows).
        width = min(max(width, 1), destination.width)
        height = min(max(height, 1), destination.height)
        x = min(max(x, destination.minX), destination.maxX - width)
        y = min(max(y, destination.minY), destination.maxY - height)
        
        return .target(CGRect(x: x, y: y, width: width, height: height))
    }
    
    /// Cycle half positions across monitors.
    /// Left:  right mon2 → left mon2 → right mon1 → left mon1
    /// Right: left mon1 → right mon1 → left mon2 → right mon2
    private func calculateHorizontalHalfFrame(
        direction: HorizontalDirection,
        windowFrame: CGRect,
        window: AXUIElement
    ) -> CGRect {
        let slots = horizontalHalfSlots()
        guard !slots.isEmpty else {
            return windowFrame
        }
        
        let exactSlotIndex = slots.firstIndex {
            framesApproximatelyEqual($0.frame, windowFrame)
        }
        let rememberedSlotIndex: Int? = {
            guard exactSlotIndex == nil,
                  let state = horizontalHalfCycleState,
                  CFEqual(state.window, window),
                  framesApproximatelyEqual(state.resultingFrame, windowFrame) else {
                return nil
            }

            return slots.firstIndex {
                framesApproximatelyEqual($0.frame, state.requestedFrame)
            }
        }()

        if let currentIndex = exactSlotIndex ?? rememberedSlotIndex {
            switch direction {
            case .left:
                let nextIndex = max(0, currentIndex - 1)
                return slots[nextIndex].frame
            case .right:
                let nextIndex = min(slots.count - 1, currentIndex + 1)
                return slots[nextIndex].frame
            }
        }
        
        // Not currently snapped to a half: snap on the window's current screen.
        guard let screen = screenContainingWindow(windowFrame) else {
            return windowFrame
        }
        let isLeft = direction == .left
        return HorizontalHalfSlot(screen: screen, isLeftHalf: isLeft).frame
    }
    
    private func framesApproximatelyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 12) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }
    
    /// Screen with the largest intersection area with the window (by center fallback).
    private func screenContainingWindow(_ windowFrame: CGRect?) -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        
        guard let windowFrame else {
            return NSScreen.main ?? screens.first
        }
        
        var bestScreen: NSScreen?
        var bestArea: CGFloat = 0
        
        for screen in screens {
            let intersection = screen.frame.intersection(windowFrame)
            let area = intersection.isNull ? 0 : intersection.width * intersection.height
            if area > bestArea {
                bestArea = area
                bestScreen = screen
            }
        }
        
        if let bestScreen, bestArea > 0 {
            return bestScreen
        }
        
        // Fallback: screen whose frame contains the window center.
        let center = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        return screens.first { $0.frame.contains(center) } ?? NSScreen.main ?? screens.first
    }
    
    /// Primary display used as the origin for global coordinate conversion.
    private func primaryScreen() -> NSScreen? {
        NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.screens.first
    }
    
    /// Accessibility / CoreGraphics use top-left origin; AppKit uses bottom-left.
    private func convertAXFrameToAppKit(_ axFrame: CGRect) -> CGRect {
        guard let primary = primaryScreen() else { return axFrame }
        let appKitY = primary.frame.maxY - axFrame.origin.y - axFrame.height
        return CGRect(
            x: axFrame.origin.x,
            y: appKitY,
            width: axFrame.width,
            height: axFrame.height
        )
    }
    
    private func convertAppKitFrameToAX(_ appKitFrame: CGRect) -> CGRect {
        guard let primary = primaryScreen() else { return appKitFrame }
        let axY = primary.frame.maxY - appKitFrame.origin.y - appKitFrame.height
        return CGRect(
            x: appKitFrame.origin.x,
            y: axY,
            width: appKitFrame.width,
            height: appKitFrame.height
        )
    }
    
    /// All frames here are in AppKit coordinates (bottom-left origin).
    private func calculateFrame(
        for position: WindowPosition,
        screenFrame: CGRect,
        currentFrame: CGRect
    ) -> CGRect {
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
                y: screenFrame.origin.y + screenFrame.height / 2,
                width: screenFrame.width,
                height: screenFrame.height / 2
            )
            
        case .bottomHalf:
            return CGRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y,
                width: screenFrame.width,
                height: screenFrame.height / 2
            )
            
        case .topLeft:
            return CGRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y + screenFrame.height / 2,
                width: screenFrame.width / 2,
                height: screenFrame.height / 2
            )
            
        case .topRight:
            return CGRect(
                x: screenFrame.origin.x + screenFrame.width / 2,
                y: screenFrame.origin.y + screenFrame.height / 2,
                width: screenFrame.width / 2,
                height: screenFrame.height / 2
            )
            
        case .bottomLeft:
            return CGRect(
                x: screenFrame.origin.x,
                y: screenFrame.origin.y,
                width: screenFrame.width / 2,
                height: screenFrame.height / 2
            )
            
        case .bottomRight:
            return CGRect(
                x: screenFrame.origin.x + screenFrame.width / 2,
                y: screenFrame.origin.y,
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

        case .centerThreeFourths:
            let width = screenFrame.width * 3 / 4
            return CGRect(
                x: screenFrame.origin.x + (screenFrame.width - width) / 2,
                y: screenFrame.origin.y,
                width: width,
                height: screenFrame.height
            )

        case .maximize:
            return screenFrame
            
        case .fullScreen:
            // This case is handled separately in applyWindowPosition, but we need this case for exhaustiveness
            return screenFrame
            
        case .almostMaximize:
            let width = screenFrame.width * 0.90
            let height = screenFrame.height * 0.90
            return CGRect(
                x: screenFrame.origin.x + (screenFrame.width - width) / 2,
                y: screenFrame.origin.y + (screenFrame.height - height) / 2 + 25,
                width: width,
                height: height
            )
            
        case .maximizeHeight:
            return CGRect(
                x: currentFrame.origin.x,
                y: screenFrame.origin.y,
                width: currentFrame.width,
                height: screenFrame.height
            )
            
        case .smaller:
            let newWidth = max(300, currentFrame.width - resizeStep)
            let newHeight = max(200, currentFrame.height - resizeStep)
            return CGRect(
                x: currentFrame.origin.x + (currentFrame.width - newWidth) / 2,
                y: currentFrame.origin.y + (currentFrame.height - newHeight) / 2,
                width: newWidth,
                height: newHeight
            )
            
        case .larger:
            let newWidth = min(screenFrame.width, currentFrame.width + resizeStep)
            let newHeight = min(screenFrame.height, currentFrame.height + resizeStep)
            return CGRect(
                x: max(screenFrame.origin.x, currentFrame.origin.x - resizeStep / 2),
                y: max(screenFrame.origin.y, currentFrame.origin.y - resizeStep / 2),
                width: newWidth,
                height: newHeight
            )
            
        case .center:
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
            
        case .moveToLeftDisplay, .moveToRightDisplay:
            // Handled separately in repositionWindow.
            return currentFrame
        }
    }
    
    /// Returns the window frame in Accessibility (top-left origin) coordinates.
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
    
    /// `frame` must be in Accessibility (top-left origin) coordinates.
    private func setWindowFrame(
        _ window: AXUIElement,
        frame: CGRect
    ) -> WindowFrameUpdateResult {
        // Set size first, then position — some apps clamp position based on current size.
        // Then set size again so apps that clamp size after a move still end up correct.
        var origin = frame.origin
        var size = frame.size
        
        guard let positionValue = AXValueCreate(.cgPoint, &origin),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            logger.error("Failed to create AXValue for position or size")
            return WindowFrameUpdateResult(
                positionSucceeded: false,
                sizeSucceeded: false
            )
        }
        
        let sizeResult1 = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        let positionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        let sizeResult2 = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        
        let sizeResult = (sizeResult1 == .success || sizeResult2 == .success) ? AXError.success : sizeResult1
        
        // Log individual operation results for debugging
        if positionResult != .success {
            logger.debug("Position setting failed with result: \(positionResult.rawValue)")
        } else {
            logger.debug("Position set successfully to (\(origin.x), \(origin.y))")
        }
        
        if sizeResult != .success {
            logger.debug("Size setting failed with result: \(sizeResult.rawValue)")
        } else {
            logger.debug("Size set successfully to \(size.width)x\(size.height)")
        }
        
        let result = WindowFrameUpdateResult(
            positionSucceeded: positionResult == .success,
            sizeSucceeded: sizeResult == .success
        )
        
        if !result.atLeastOneSucceeded {
            logger.warning("Both position and size setting failed")
        }
        
        return result
    }
    
    private func toggleFullScreen(_ window: AXUIElement) -> Bool {
        // Method 1: Try the fullscreen attribute directly
        var isFullScreen: CFTypeRef?
        let fullScreenResult = AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &isFullScreen)
        
        if fullScreenResult == .success {
            let currentValue = isFullScreen as? Bool ?? false
            let newValue = !currentValue
            let fullScreenValue = newValue as CFBoolean
            let result = AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, fullScreenValue)
            if result == .success {
                logger.info("Successfully toggled fullscreen using AXFullScreen attribute")
                return true
            }
        }
        
        // Method 2: Use the zoom button (fallback)
        var zoomButton: CFTypeRef?
        let zoomButtonResult = AXUIElementCopyAttributeValue(window, kAXZoomButtonAttribute as CFString, &zoomButton)
        
        if zoomButtonResult == .success, let button = zoomButton {
            let zoomResult = AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
            if zoomResult == .success {
                logger.info("Successfully toggled fullscreen using zoom button")
                return true
            }
        }
        
        // Method 3: Keyboard shortcut (most reliable)
        var appPid: pid_t = 0
        let pidResult = AXUIElementGetPid(window, &appPid)
        
        if pidResult == .success {
            // Activate the target application to ensure it receives the keyboard shortcut
            if let targetApp = NSRunningApplication(processIdentifier: appPid) {
                targetApp.activate(options: [])
                usleep(50000) // 50ms delay to ensure activation completes
            }
            
            // Send Control+Command+F (standard fullscreen toggle shortcut)
            let source = CGEventSource(stateID: .hidSystemState)
            let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x03, keyDown: true) // F key
            let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x03, keyDown: false)
            
            keyDownEvent?.flags = [.maskCommand, .maskControl]
            keyUpEvent?.flags = [.maskCommand, .maskControl]
            
            keyDownEvent?.postToPid(appPid)
            usleep(1000) // 1ms delay between key down and up
            keyUpEvent?.postToPid(appPid)
            
            logger.info("Successfully sent fullscreen toggle shortcut")
            return true
        }
        
        logger.warning("Unable to toggle fullscreen")
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
                ToastManager.shared.showError("System Appearance Error: \(error)")
            }
        )
    }
}
