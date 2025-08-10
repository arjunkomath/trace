# Architecture

This document provides detailed technical information about Trace's architecture and implementation.

## Core Components

### AppDelegate.swift
Main application controller that manages:
- Launcher window lifecycle
- Global hotkey registration (default: ⌥Space)
- Settings window access
- Launch at login functionality

### LauncherWindow/LauncherView
The main search interface:
- Borderless floating window positioned in upper-center of screen
- Uses `.regularMaterial` for translucent background
- Displays search results with app icons and type badges
- Always includes Google search as fallback result

### AppSearchManager
High-performance app discovery and search:
- Singleton pattern for memory efficiency
- Concurrent scanning of /Applications, /System/Applications, ~/Applications
- In-memory caching with lazy icon loading
- Fuzzy search with relevance scoring

### HotkeyManager
Carbon API wrapper for global hotkey:
- Uses EventHotKey for system-wide hotkey registration
- Handles hotkey recording and updating without restart

### SettingsView
Professional settings interface:
- Launch at login toggle (uses ServiceManagement API)
- Hotkey customization with live recording
- About section with GitHub/Twitter links

## Key Technical Decisions

- **No SwiftUI Settings Scene**: Uses custom NSWindow to avoid duplicate settings windows
- **Background Only**: App runs as LSUIElement (no dock or menu bar presence)
- **Carbon for Hotkeys**: Required for global hotkey functionality
- **Concurrent App Discovery**: Background GCD queues for non-blocking startup
- **Search Result Types**: Application, Command, Suggestion (for Google search)
- **Hotkey-Only Access**: Settings and quit commands accessible through search interface

## Data Flow

1. User presses hotkey → HotkeyManager triggers → AppDelegate shows LauncherWindow
2. User types query → LauncherView updates → AppSearchManager.searchApps() returns filtered results
3. User selects result → Action executed (launch app/open URL) → Window hides, search clears

## Important Files

- `trace/Info.plist` - Contains LSUIElement key for background-only app behavior
- `trace/Assets.xcassets/AppIcon.appiconset/` - App icons (generated from app.png using sips)
- Models: `SearchModels.swift` defines Application, SearchResult, SearchResultType

## UI Components

### KeyBindingView
Reusable component for displaying keyboard shortcuts (`trace/Components/KeyBindingView.swift`):
- Displays keys as separate rounded rectangles with proper macOS styling
- Supports both direct key arrays and automatic conversion from keyCode/modifiers
- Used throughout the app for consistent keyboard shortcut display

## State Management

- User preferences: `@AppStorage` for persistence
- Hotkey settings: Stored in UserDefaults with keys "hotkey_keyCode" and "hotkey_modifiers"
- Launch at login: SMAppService.mainApp for macOS 15.5+

## Window Management

- LauncherWindow: 810x360 borderless window with 30px padding for shadow
- SettingsWindow: 450x500 standard window, non-resizable
- Both windows centered on screen, settings window released when closed = false

## Project Structure

```
trace/
├── Core/                # Core application logic
│   ├── AppDelegate.swift
│   ├── Constants.swift
│   ├── FuzzyMatcher.swift
│   ├── HotkeyRegistry.swift
│   ├── Logging.swift
│   ├── ServiceContainer.swift
│   └── traceApp.swift
├── Views/               # SwiftUI views and UI components
│   ├── LauncherView.swift
│   ├── SettingsView.swift
│   └── Settings/        # Settings sub-views
├── Managers/            # Business logic managers
│   ├── AppHotkeyManager.swift
│   ├── AppSearchManager.swift
│   ├── FolderManager.swift
│   ├── HotkeyManager.swift
│   └── WindowHotkeyManager.swift
├── Services/            # System integration services
│   ├── ControlCenterManager.swift
│   ├── NetworkUtilities.swift
│   ├── PermissionManager.swift
│   ├── SettingsExportManager.swift
│   ├── SettingsManager.swift
│   ├── SettingsService.swift
│   ├── UsageTracker.swift
│   └── WindowManager.swift
├── Models/              # Data models
│   ├── FolderShortcut.swift
│   └── SearchModels.swift
├── Components/          # Reusable UI components
│   └── KeyBindingView.swift
└── Windows/             # Window management
    └── LauncherWindow.swift
```

## Key Features

- **Background Operation**: Runs as `LSUIElement` for invisible operation
- **Memory Efficient**: Lazy loading and intelligent caching
- **Concurrent Processing**: Non-blocking app discovery and search
- **Modern Swift**: Uses async/await, structured concurrency, and SwiftUI

## Development Guidelines

### Memory Management & Safety

**NEVER:**
- Use implicitly unwrapped optionals - declare as optional and safely unwrap
- Force unwrap URLs or any external data without validation
- Create retain cycles with strong references in closures - always use `[weak self]`
- Leave event monitors, timers, or observers without proper cleanup in deinit

**ALWAYS:**
```swift
// Use proper optionals and safe unwrapping
private var statusItem: NSStatusItem?
guard let statusItem = self.statusItem else { return }

// Use weak self in closures
hotkeyManager.onHotkeyPressed = { [weak self] in
    self?.toggleLauncher()
}

// Clean up resources in deinit
deinit {
    timer?.invalidate()
    if let monitor = eventMonitor {
        NSEvent.removeMonitor(monitor)
    }
}
```

### Architecture & Design Patterns

**PREFER:**
```swift
// Settings service instead of direct UserDefaults
protocol SettingsService {
    var launchAtLogin: Bool { get set }
    var hotkeyConfig: HotkeyConfig { get set }
}

// Dependency injection instead of singletons
class AppSearchManager {
    init(settingsService: SettingsService, fileManager: FileManager = .default)
}
```

### Threading & Concurrency

- UI updates ONLY on main queue
- Use structured concurrency (async/await) for new code instead of GCD
- Document thread safety requirements in comments
- Avoid nested dispatch queues

### Constants & Configuration

```swift
private enum Constants {
    enum Window {
        static let width: CGFloat = 810
        static let height: CGFloat = 360
        static let cornerRadius: CGFloat = 12
    }
    enum Animation {
        static let duration: TimeInterval = 0.25
    }
}
```