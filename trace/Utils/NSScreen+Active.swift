//
//  NSScreen+Active.swift
//  trace
//

import AppKit
import CoreGraphics

extension NSScreen {
    /// Screen that contains the focused/frontmost window of the app the user was
    /// working in (before Trace became frontmost). Prefer this over `NSScreen.main`
    /// for UI that should appear where the user is working.
    ///
    /// Resolution order:
    /// 1. Screen containing the active window of `lastActiveApplication` / frontmost app
    /// 2. Screen under the mouse cursor
    /// 3. Main screen / first screen
    static var active: NSScreen? {
        screenContainingActiveWindow()
            ?? screenContainingMouse()
            ?? main
            ?? screens.first
    }

    // MARK: - Active window screen

    /// Screen that contains the frontmost on-screen window of the target app.
    private static func screenContainingActiveWindow() -> NSScreen? {
        guard let targetPID = targetApplicationPID() else { return nil }

        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        // Window list is front-to-back; first layer-0 window of the target app is its active window.
        for info in windowList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == targetPID else {
                continue
            }

            let layer = info[kCGWindowLayer as String] as? Int ?? -1
            guard layer == 0 else { continue }

            guard let boundsDict = info[kCGWindowBounds as String] as? NSDictionary else {
                continue
            }

            var cgFrame = CGRect.zero
            guard CGRectMakeWithDictionaryRepresentation(boundsDict, &cgFrame),
                  cgFrame.width > 1, cgFrame.height > 1 else {
                continue
            }

            let appKitFrame = convertCGFrameToAppKit(cgFrame)
            let center = CGPoint(x: appKitFrame.midX, y: appKitFrame.midY)

            if let screen = screens.first(where: { NSMouseInRect(center, $0.frame, false) }) {
                return screen
            }

            // Fallback: largest intersection with any screen (window straddling monitors)
            return screens.max(by: {
                $0.frame.intersection(appKitFrame).area < $1.frame.intersection(appKitFrame).area
            })
        }

        return nil
    }

    /// App whose window should define the "active" screen — last app before Trace,
    /// or the current frontmost app when it isn't Trace.
    private static func targetApplicationPID() -> pid_t? {
        if let lastApp = PermissionManager.shared.lastActiveApplication {
            return lastApp.processIdentifier
        }

        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
            return frontmost.processIdentifier
        }

        return nil
    }

    // MARK: - Coordinate conversion

    /// Converts a CoreGraphics / window-server frame (origin top-left of main display)
    /// into AppKit coordinates (origin bottom-left of main display).
    private static func convertCGFrameToAppKit(_ cgFrame: CGRect) -> CGRect {
        let mainDisplayHeight = CGDisplayBounds(CGMainDisplayID()).height
        return CGRect(
            x: cgFrame.origin.x,
            y: mainDisplayHeight - cgFrame.origin.y - cgFrame.height,
            width: cgFrame.width,
            height: cgFrame.height
        )
    }

    // MARK: - Cursor fallback

    private static func screenContainingMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }
}

private extension CGRect {
    var area: CGFloat {
        max(0, width) * max(0, height)
    }
}
