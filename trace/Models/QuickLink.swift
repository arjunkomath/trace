//
//  QuickLink.swift
//  trace
//
//  Created by Claude on 13/8/2025.
//

import Foundation

struct QuickLink: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var urlString: String  // Can be file:// or https://
    var iconName: String?  // Optional custom icon
    var keywords: [String] // Additional search keywords
    var hotkey: String?    // Optional keyboard shortcut
    var isSystemDefault: Bool // True for default system folders
    
    init(
        id: String = UUID().uuidString,
        name: String,
        urlString: String,
        iconName: String? = nil,
        keywords: [String] = [],
        hotkey: String? = nil,
        isSystemDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.iconName = iconName
        self.keywords = keywords
        self.hotkey = hotkey
        self.isSystemDefault = isSystemDefault
    }
    
    // MARK: - Computed Properties
    
    /// The URL object for this quick link
    var url: URL? {
        // Handle file paths that might not be proper URLs
        if urlString.hasPrefix("file://") {
            return URL(string: urlString)
        } else if urlString.hasPrefix("http") {
            return URL(string: urlString)
        } else if urlString.hasPrefix("/") || urlString.hasPrefix("~") {
            // Convert file path to file URL
            let expandedPath = NSString(string: urlString).expandingTildeInPath
            return URL(fileURLWithPath: expandedPath)
        } else {
            // Try as-is first, then as web URL with https prefix
            if let url = URL(string: urlString) {
                return url
            } else {
                return URL(string: "https://\(urlString)")
            }
        }
    }
    
    /// Whether this is a file system link
    var isFileLink: Bool {
        return urlString.hasPrefix("file://") || 
               urlString.hasPrefix("/") || 
               urlString.hasPrefix("~")
    }
    
    /// Whether this is a web link
    var isWebLink: Bool {
        return urlString.hasPrefix("http")
    }
    
    /// Check if the file exists (for file links)
    var fileExists: Bool {
        guard isFileLink, let url = url else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Get appropriate system icon name for this quick link
    var systemIconName: String {
        if let customIcon = iconName {
            return customIcon
        }
        
        if isFileLink {
            // Try to determine file type
            if let url = url {
                let pathExtension = url.pathExtension.lowercased()
                switch pathExtension {
                case "pdf": return "doc.richtext"
                case "txt", "md": return "doc.text"
                case "jpg", "jpeg", "png", "gif": return "photo"
                case "mp4", "mov": return "film"
                case "mp3", "m4a": return "music.note"
                default: return "doc"
                }
            }
            return "doc"
        } else if isWebLink {
            // Web link icons based on domain
            if urlString.contains("github.com") {
                return "chevron.left.forwardslash.chevron.right"
            } else if urlString.contains("google.com") {
                return "magnifyingglass"
            } else if urlString.contains("youtube.com") {
                return "play.rectangle"
            } else {
                return "globe"
            }
        } else {
            return "link"
        }
    }
    
    /// Get all searchable terms for this quick link
    var searchableTerms: [String] {
        var terms = [name.lowercased()]
        terms.append(contentsOf: keywords.map { $0.lowercased() })
        
        // Add URL components for search
        if let url = url {
            if isWebLink {
                // Add domain for web links
                if let host = url.host {
                    terms.append(host.lowercased())
                }
            } else if isFileLink {
                // Add filename for file links
                terms.append(url.lastPathComponent.lowercased())
            }
        }
        
        return Array(Set(terms)) // Remove duplicates
    }
}

// MARK: - Default Quick Links

extension QuickLink {
    /// Default system folders and useful web links
    static let defaultQuickLinks: [QuickLink] = [
        // System Folders
        QuickLink(
            id: "home",
            name: "Home",
            urlString: NSHomeDirectory(),
            iconName: "house",
            keywords: ["home", "user"],
            isSystemDefault: true
        ),
        QuickLink(
            id: "desktop",
            name: "Desktop",
            urlString: "~/Desktop",
            iconName: "menubar.dock.rectangle",
            keywords: ["desktop"],
            isSystemDefault: true
        ),
        QuickLink(
            id: "documents",
            name: "Documents",
            urlString: "~/Documents",
            iconName: "doc.text",
            keywords: ["documents", "docs"],
            isSystemDefault: true
        ),
        QuickLink(
            id: "downloads",
            name: "Downloads",
            urlString: "~/Downloads",
            iconName: "arrow.down.circle",
            keywords: ["downloads"],
            isSystemDefault: true
        ),
        QuickLink(
            id: "pictures",
            name: "Pictures",
            urlString: "~/Pictures",
            iconName: "photo",
            keywords: ["pictures", "photos", "images"],
            isSystemDefault: true
        ),
        QuickLink(
            id: "movies",
            name: "Movies",
            urlString: "~/Movies",
            iconName: "film",
            keywords: ["movies", "videos"],
            isSystemDefault: true
        ),
        QuickLink(
            id: "music",
            name: "Music",
            urlString: "~/Music",
            iconName: "music.note",
            keywords: ["music", "audio"],
            isSystemDefault: true
        ),
        QuickLink(
            id: "applications",
            name: "Applications",
            urlString: "/Applications",
            iconName: "app.badge",
            keywords: ["applications", "apps"],
            isSystemDefault: true
        ),
        QuickLink(
            id: "library",
            name: "Library",
            urlString: "~/Library",
            iconName: "building.columns",
            keywords: ["library", "system"],
            isSystemDefault: true
        ),
        
        // Useful Web Links
        QuickLink(
            name: "GitHub",
            urlString: "https://github.com",
            iconName: "chevron.left.forwardslash.chevron.right",
            keywords: ["code", "git", "repository"]
        )
    ]
}
