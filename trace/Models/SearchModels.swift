//
//  SearchModels.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI
import Foundation
import Ifrit

enum ResultsLayout: String, CaseIterable {
    case compact = "compact"
    case normal = "normal"
    
    var displayName: String {
        switch self {
        case .compact:
            return "Compact"
        case .normal:
            return "Normal"
        }
    }
    
    var description: String {
        switch self {
        case .compact:
            return "Single line layout with more results visible"
        case .normal:
            return "Two line layout with subtitles below titles"
        }
    }
}

enum SearchResultType {
    case application
    case command
    case file
    case folder
    case person
    case recent
    case suggestion
    case math
    
    var displayName: String {
        switch self {
        case .application:
            return "Application"
        case .command:
            return "Command"
        case .file:
            return "File"
        case .folder:
            return "Folder"
        case .person:
            return "Person"
        case .recent:
            return "Recent"
        case .suggestion:
            return "Suggestion"
        case .math:
            return "Math"
        }
    }
}

enum ResultCategory {
    case applications
    case network
    case web
    case window
    case customFolder
    case appearance
    case systemSettings
    
    var displayName: String {
        switch self {
        case .applications:
            return "Applications"
        case .network:
            return "Network"
        case .web:
            return "Web"
        case .window:
            return "Window"
        case .customFolder:
            return "Custom Folder"
        case .appearance:
            return "Appearance"
        case .systemSettings:
            return "System Settings"
        }
    }
}

struct SearchResult: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let icon: SearchIcon
    let type: SearchResultType
    let category: ResultCategory?
    let shortcut: KeyboardShortcut?
    let lastUsed: Date?
    let commandId: String? // Semantic identifier for tracking
    var isLoading: Bool = false // Indicates if this result is currently processing
    let accessory: SearchResultAccessory? // Generic accessory indicator
    let commandAction: CommandAction
    
    // Multi-action support
    var hasMultipleActions: Bool {
        if let multiAction = commandAction as? MultiCommandAction {
            return multiAction.hasMultipleActions
        }
        return false
    }
    
    var allActions: [DisplayableCommandAction] {
        if let multiAction = commandAction as? MultiCommandAction {
            return multiAction.allActions
        } else if let displayableAction = commandAction as? DisplayableCommandAction {
            return [displayableAction]
        }
        return []
    }
    
    init(
        title: String,
        subtitle: String?,
        icon: SearchIcon,
        type: SearchResultType,
        category: ResultCategory? = nil,
        shortcut: KeyboardShortcut? = nil,
        lastUsed: Date? = nil,
        commandId: String? = nil,
        isLoading: Bool = false,
        accessory: SearchResultAccessory? = nil,
        commandAction: CommandAction
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.type = type
        self.category = category
        self.shortcut = shortcut
        self.lastUsed = lastUsed
        self.commandId = commandId
        self.isLoading = isLoading
        self.accessory = accessory
        self.commandAction = commandAction
    }
}

enum SearchIcon {
    case system(String)
    case emoji(String)
    case image(NSImage)
    case app(String)
}

enum SearchResultAccessory {
    case runningIndicator // Green dot for running apps
    case badge(String) // Text badge with custom string
    case count(Int) // Number badge
    case status(String, Color) // Status with custom text and color
    
    var displayText: String? {
        switch self {
        case .runningIndicator:
            return nil
        case .badge(let text):
            return text
        case .count(let number):
            return "\(number)"
        case .status(let text, _):
            return text
        }
    }
    
    var color: Color {
        switch self {
        case .runningIndicator:
            return .green
        case .badge:
            return .secondary
        case .count:
            return .accentColor
        case .status(_, let color):
            return color
        }
    }
    
    var isIndicatorDot: Bool {
        switch self {
        case .runningIndicator:
            return true
        default:
            return false
        }
    }
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

struct Application: Identifiable, Hashable, Searchable {
    let id: String // bundle identifier
    let name: String
    let displayName: String
    let url: URL
    let bundleIdentifier: String
    let lastModified: Date
    let description: String?
    let keywords: [String]
    var icon: NSImage?
    
    // Searchable protocol requirement
    var properties: [FuseProp] {
        return [
            FuseProp(displayName, weight: 0.4),  // Display name is most important
            FuseProp(name, weight: 0.35),         // App name is also very important
            FuseProp(keywords.joined(separator: " "), weight: 0.2),  // Keywords are important
            FuseProp(description ?? "", weight: 0.05)  // Description is least important
        ]
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }
    
    static func == (lhs: Application, rhs: Application) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}