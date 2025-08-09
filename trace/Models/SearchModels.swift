//
//  SearchModels.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI
import Foundation

enum SearchResultType {
    case application
    case command
    case file
    case person
    case recent
    case suggestion
    
    var displayName: String {
        switch self {
        case .application:
            return "Application"
        case .command:
            return "Command"
        case .file:
            return "File"
        case .person:
            return "Person"
        case .recent:
            return "Recent"
        case .suggestion:
            return "Suggestion"
        }
    }
}

struct SearchResult: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let icon: SearchIcon
    let type: SearchResultType
    let category: String?
    let shortcut: KeyboardShortcut?
    let lastUsed: Date?
    let action: () -> Void
}

enum SearchIcon {
    case system(String)
    case emoji(String)
    case image(NSImage)
    case app(String)
}

struct KeyboardShortcut {
    let key: String
    let modifiers: [String]
    
    var displayString: String {
        (modifiers + [key]).joined(separator: "")
    }
    
    init(key: String, modifiers: [String]) {
        self.key = key
        self.modifiers = modifiers
    }
    
    init(keyCombo: String) {
        // Parse a key combo string like "⌘⌥A" into modifiers and key
        let keys = KeyBindingView.parseKeyCombo(keyCombo)
        
        var modifiers: [String] = []
        var key = ""
        
        for keyString in keys {
            switch keyString {
            case "⌘", "⌃", "⌥", "⇧":
                modifiers.append(keyString)
            default:
                key = keyString
            }
        }
        
        self.key = key
        self.modifiers = modifiers
    }
}

struct SearchCategory {
    let name: String?
    let results: [SearchResult]
}

// MARK: - Application Model

struct Application: Identifiable, Hashable, Sendable {
    let id: String // bundle identifier
    let name: String
    let displayName: String
    let url: URL
    let bundleIdentifier: String
    let lastModified: Date
    var icon: NSImage?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }
    
    static func == (lhs: Application, rhs: Application) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}