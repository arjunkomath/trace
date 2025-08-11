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
    let commandId: String? // Semantic identifier for tracking
    var isLoading: Bool = false // Indicates if this result is currently processing
    let accessory: SearchResultAccessory? // Generic accessory indicator
    let action: () -> Void
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