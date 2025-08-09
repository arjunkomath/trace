//
//  FolderShortcut.swift
//  trace
//
//  Created by Assistant on 8/10/2025.
//

import Foundation

struct FolderShortcut: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var path: String
    var isDefault: Bool
    var hotkey: String? // Store as formatted string like "⌘⌥D"
    
    init(id: String = UUID().uuidString, name: String, path: String, isDefault: Bool = false, hotkey: String? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.isDefault = isDefault
        self.hotkey = hotkey
    }
    
    // Default system folders
    static let defaultFolders: [FolderShortcut] = [
        FolderShortcut(id: "home", name: "Home", path: NSHomeDirectory(), isDefault: true),
        FolderShortcut(id: "desktop", name: "Desktop", path: "~/Desktop", isDefault: true),
        FolderShortcut(id: "documents", name: "Documents", path: "~/Documents", isDefault: true),
        FolderShortcut(id: "downloads", name: "Downloads", path: "~/Downloads", isDefault: true),
        FolderShortcut(id: "pictures", name: "Pictures", path: "~/Pictures", isDefault: true),
        FolderShortcut(id: "movies", name: "Movies", path: "~/Movies", isDefault: true),
        FolderShortcut(id: "music", name: "Music", path: "~/Music", isDefault: true),
        FolderShortcut(id: "applications", name: "Applications", path: "/Applications", isDefault: true),
        FolderShortcut(id: "library", name: "Library", path: "~/Library", isDefault: true),
    ]
    
    // Get the actual URL for the folder
    var url: URL? {
        let expandedPath = NSString(string: path).expandingTildeInPath
        return URL(fileURLWithPath: expandedPath)
    }
    
    // Check if folder exists
    var exists: Bool {
        guard let url = url else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    // Get icon name for the folder
    var iconName: String {
        switch id {
        case "home": return "house"
        case "desktop": return "menubar.dock.rectangle"
        case "documents": return "doc.text"
        case "downloads": return "arrow.down.circle"
        case "pictures": return "photo"
        case "movies": return "film"
        case "music": return "music.note"
        case "applications": return "app.badge"
        case "library": return "building.columns"
        default: return "folder"
        }
    }
}