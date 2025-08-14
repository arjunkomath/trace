# Trace

**Spotlight alternative and shortcut toolkit for macOS**

<img width="1606" height="995" alt="CleanShot 2025-08-12 at 23 21 19@2x" src="https://github.com/user-attachments/assets/f6fde413-9732-4d76-a639-1e67f615533e" />

A SwiftUI-based application launcher that runs as a background service (LSUIElement) with global hotkey access. Features fuzzy search, window management, quick links, and system integration.

## Features

### Core Functionality
- **Application Search**: Fuzzy search with intelligent ranking across `/Applications`, `/System/Applications`, and `~/Applications`
- **Global Hotkey**: Customizable system-wide shortcuts (default: `⌥Space`)
- **Background Operation**: LSUIElement with no dock/menu bar presence
- **Quick Links**: User-defined shortcuts for files, folders, and URLs with custom hotkeys
- **Mathematical Calculations**: Built-in calculator with expression evaluation

### Window Management
- Position commands: Left/Right Half, Thirds, Center, Maximize, Fullscreen
- Auto-exit fullscreen detection before applying window positions
- Multi-display support with screen-aware positioning
- Application-specific hotkey assignments

### System Integration
- **System Commands**: Dark mode toggle, sleep, restart, shutdown
- **Menu Bar Integration**: Version display and disabled quit option
- **Toast Notifications**: 400x80px notifications with 3-line support
- **Auto-updater**: Sparkle framework integration

## System Requirements

- **macOS**: 15.5 or later
- **Architecture**: Apple Silicon or Intel
- **Permissions**: Accessibility API, Apple Events

## Installation

### Build from Source
```bash
git clone https://github.com/arjunkomath/trace.git
cd trace
xcodebuild -project trace.xcodeproj -scheme trace -configuration Release build
```

### Required Permissions
Grant when prompted:
- **Accessibility**: For window management and app control
- **Apple Events**: For system command execution

## Architecture

- **Language**: Swift 5.9+
- **Framework**: SwiftUI with AppKit integration
- **APIs**: Accessibility (AXUIElement), Carbon (EventHotKey), Core Graphics
- **Dependencies**: Sparkle (auto-updates), SymbolPicker (UI icons)

### Key Components
- `AppDelegate`: Main application controller, hotkey registration
- `LauncherWindow`: 810x360 borderless search interface  
- `AppSearchManager`: Concurrent app discovery with in-memory caching
- `WindowManager`: AXUIElement-based window positioning
- `HotkeyManager`: Carbon EventHotKey wrapper
- `ToastManager`: Non-intrusive notification system

## Development

### Build Commands
```bash
# Debug build
xcodebuild -project trace.xcodeproj -scheme trace -configuration Debug build

# Release build
xcodebuild -project trace.xcodeproj -scheme trace -configuration Release build

# Clean build
xcodebuild -project trace.xcodeproj -scheme trace clean build
```

### Project Structure
```
trace/
├── Core/                 # Application lifecycle, logging
├── Views/               # SwiftUI interface components
├── Services/            # Business logic, managers
├── Models/              # Data structures, search results
├── Search/Providers/    # Pluggable search implementations
└── Windows/            # NSWindow subclasses
```

## Configuration

Settings stored in `UserDefaults` and `~/Library/Application Support/Trace/`:
- Hotkey combinations (keyCode + modifiers)
- Quick links with custom hotkeys
- Launch at login preference
- Application cache and icons

## Distribution

### DMG Creation
```bash
brew install create-dmg
create-dmg \
    --volname "Trace" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "trace.app" 150 185 \
    --hide-extension "trace.app" \
    --app-drop-link 450 185 \
    --hdiutil-quiet \
    "Trace-1.0.0.dmg" \
    "path/to/trace.app"
```

### Appcast Generation
```bash
generate_appcast --download-url-prefix "https://trace.techulus.xyz/downloads/" \
      --full-release-notes-url "https://github.com/arjunkomath/trace/releases" \
      -o docs/appcast.xml \
      docs/downloads
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Follow Swift/SwiftUI conventions in [ARCHITECTURE.md](ARCHITECTURE.md)
4. Submit a pull request

## Links

- **Website**: [trace.techulus.xyz](https://trace.techulus.xyz)
- **Documentation**: [ARCHITECTURE.md](ARCHITECTURE.md)
- **Releases**: [GitHub Releases](https://github.com/arjunkomath/trace/releases)

---

**License**: MIT • **Author**: [@arjunkomath](https://twitter.com/arjunkomath)
