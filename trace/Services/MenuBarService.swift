//
//  MenuBarService.swift
//  trace
//
//  Created by Codex on 8/7/2026.
//

import AppKit
import ApplicationServices
import Foundation
import os.log

struct MenuItem {
    let id: String
    let pathTitles: [String]
    let title: String
    let menuPath: String
    let shortcut: KeyboardShortcut?
    let enabled: Bool
    let element: AXUIElement
}

enum MenuBarServiceError: Error {
    case permissionDenied
    case menuBarUnavailable
}

class MenuBarService {
    private struct CacheEntry {
        let createdAt: CFAbsoluteTime
        let items: [MenuItem]
    }

    private let logger = AppLogger.menuBarService
    private let cacheLock = NSLock()
    private var cache: [pid_t: CacheEntry] = [:]

    private let cacheTTL: CFTimeInterval = 2.0
    private let maxDepth = 6
    private let maxItems = 500
    private let menuAttribute = "AXMenu"
    private let menuBarRole = "AXMenuBar"
    private let menuBarItemRole = "AXMenuBarItem"
    private let menuRole = "AXMenu"
    private let menuItemRole = "AXMenuItem"

    func menuItems(for app: NSRunningApplication) throws -> [MenuItem] {
        guard AXIsProcessTrusted() else {
            throw MenuBarServiceError.permissionDenied
        }

        let pid = app.processIdentifier
        let now = CFAbsoluteTimeGetCurrent()

        cacheLock.lock()
        if let cached = cache[pid], now - cached.createdAt < cacheTTL {
            cacheLock.unlock()
            return cached.items
        }
        cacheLock.unlock()

        let appElement = AXUIElementCreateApplication(pid)
        guard let menuBar = elementAttribute(appElement, kAXMenuBarAttribute) else {
            throw MenuBarServiceError.menuBarUnavailable
        }

        var collectedItems: [MenuItem] = []
        var collectedCount = 0

        collectItems(
            from: menuBar,
            path: [],
            depth: 0,
            count: &collectedCount,
            output: &collectedItems
        )

        cacheLock.lock()
        cache = cache.filter { $0.key == pid }
        cache[pid] = CacheEntry(createdAt: now, items: collectedItems)
        cacheLock.unlock()

        logger.debug(
            "Enumerated \(collectedItems.count) menu items for \(app.localizedName ?? app.bundleIdentifier ?? "Unknown", privacy: .public)"
        )
        return collectedItems
    }

    func press(_ item: MenuItem, in app: NSRunningApplication) -> Bool {
        activate(app)
        waitForActivation(of: app)

        let result = AXUIElementPerformAction(item.element, kAXPressAction as CFString)
        if result != .success {
            logger.warning("Menu item press failed result=\(result.rawValue) item=\(item.title, privacy: .public)")
        }

        return result == .success
    }

    private func activate(_ app: NSRunningApplication) {
        if Thread.isMainThread {
            _ = app.activate()
        } else {
            _ = DispatchQueue.main.sync {
                app.activate()
            }
        }
    }

    private func waitForActivation(of app: NSRunningApplication) {
        let deadline = Date().addingTimeInterval(0.25)
        while !app.isActive && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
    }

    func invalidateCache(for app: NSRunningApplication? = nil) {
        cacheLock.lock()
        if let app {
            cache.removeValue(forKey: app.processIdentifier)
        } else {
            cache.removeAll()
        }
        cacheLock.unlock()
    }

    private func collectItems(
        from element: AXUIElement,
        path: [String],
        depth: Int,
        count: inout Int,
        output: inout [MenuItem]
    ) {
        guard depth <= maxDepth, count < maxItems else { return }

        let role = role(of: element)
        let title = title(of: element)

        switch role {
        case menuBarRole, menuRole:
            for child in children(of: element) where count < maxItems {
                collectItems(
                    from: child,
                    path: path,
                    depth: depth + 1,
                    count: &count,
                    output: &output
                )
            }

        case menuBarItemRole:
            let nextPath = title.isEmpty ? path : path + [title]
            let menus = menuContainers(of: element)
            if menus.isEmpty {
                for child in children(of: element) where count < maxItems {
                    collectItems(
                        from: child,
                        path: nextPath,
                        depth: depth + 1,
                        count: &count,
                        output: &output
                    )
                }
            } else {
                for menu in menus where count < maxItems {
                    collectItems(
                        from: menu,
                        path: nextPath,
                        depth: depth + 1,
                        count: &count,
                        output: &output
                    )
                }
            }

        case menuItemRole:
            guard !title.isEmpty else { return }
            let nextPath = path + [title]
            let menus = menuContainers(of: element)

            if !menus.isEmpty {
                for menu in menus where count < maxItems {
                    collectItems(
                        from: menu,
                        path: nextPath,
                        depth: depth + 1,
                        count: &count,
                        output: &output
                    )
                }
                return
            }

            let enabled = boolAttribute(element, kAXEnabledAttribute, defaultValue: true)
            guard enabled else { return }

            let item = MenuItem(
                id: makeItemID(pathTitles: nextPath),
                pathTitles: nextPath,
                title: title,
                menuPath: path.joined(separator: " > "),
                shortcut: keyboardShortcut(for: element),
                enabled: enabled,
                element: element
            )

            output.append(item)
            count += 1

        default:
            for child in children(of: element) where count < maxItems {
                collectItems(
                    from: child,
                    path: path,
                    depth: depth + 1,
                    count: &count,
                    output: &output
                )
            }
        }
    }

    private func menuContainers(of element: AXUIElement) -> [AXUIElement] {
        var menus: [AXUIElement] = []

        if let menu = elementAttribute(element, menuAttribute) {
            menus.append(menu)
        }

        for child in children(of: element) where role(of: child) == menuRole {
            if !menus.contains(where: { CFEqual($0, child) }) {
                menus.append(child)
            }
        }

        return menus
    }

    private func makeItemID(pathTitles: [String]) -> String {
        pathTitles
            .map { sanitizeIdentifierComponent($0) }
            .filter { !$0.isEmpty }
            .joined(separator: ".")
    }

    private func sanitizeIdentifierComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return value
            .lowercased()
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "_" }
            .reduce(into: "") { $0.append($1) }
            .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    private func keyboardShortcut(for element: AXUIElement) -> KeyboardShortcut? {
        let key = stringAttribute(element, kAXMenuItemCmdCharAttribute)
            ?? keyName(forVirtualKey: intAttribute(element, kAXMenuItemCmdVirtualKeyAttribute))

        guard let key, !key.isEmpty else {
            return nil
        }

        return KeyboardShortcut(
            key: key.uppercased(),
            modifiers: modifiers(from: intAttribute(element, kAXMenuItemCmdModifiersAttribute))
        )
    }

    private func modifiers(from mask: Int?) -> [String] {
        guard let mask else {
            return ["⌘"]
        }

        var modifiers: [String] = []
        if mask & 4 != 0 { modifiers.append("⌃") }
        if mask & 2 != 0 { modifiers.append("⌥") }
        if mask & 1 != 0 { modifiers.append("⇧") }
        if mask & 8 == 0 { modifiers.append("⌘") }

        return modifiers.isEmpty ? ["⌘"] : modifiers
    }

    private func keyName(forVirtualKey value: Int?) -> String? {
        guard let value else { return nil }

        switch value {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 53: return "⎋"
        case 115: return "Home"
        case 116: return "Page Up"
        case 117: return "⌦"
        case 119: return "End"
        case 121: return "Page Down"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return nil
        }
    }

    private func title(of element: AXUIElement, fallback: String = "") -> String {
        (stringAttribute(element, kAXTitleAttribute) ?? fallback)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func role(of element: AXUIElement) -> String {
        stringAttribute(element, kAXRoleAttribute) ?? ""
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        arrayAttribute(element, kAXChildrenAttribute)
    }

    private func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func intAttribute(_ element: AXUIElement, _ attribute: String) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        if let intValue = value as? Int {
            return intValue
        }
        return (value as? NSNumber)?.intValue
    }

    private func boolAttribute(_ element: AXUIElement, _ attribute: String, defaultValue: Bool) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return defaultValue
        }
        if let boolValue = value as? Bool {
            return boolValue
        }
        return (value as? NSNumber)?.boolValue ?? defaultValue
    }

    private func elementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private func arrayAttribute(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return []
        }
        return value as? [AXUIElement] ?? []
    }
}
