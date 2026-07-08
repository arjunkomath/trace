# Trace

**Spotlight alternative and shortcut toolkit for macOS**

<img width="1774" height="1075" alt="CleanShot 2026-05-19 at 22 50 42@2x" src="https://github.com/user-attachments/assets/5249826e-206b-423b-beb0-afa034599c44" />

A SwiftUI-based application launcher that runs as a background service (LSUIElement) with global hotkey access. Features fuzzy search, window management, quick links, push-to-talk dictation, and system integration.

## Features

- **Fast Search**: Fuzzy search across all applications with intelligent ranking
- **Window Management**: Snap windows to halves, thirds, or custom positions instantly
- **Quick Links**: One-key access to your most-used files, folders, and websites
- **Global Hotkeys**: Customizable shortcuts for launching apps and managing windows
- **Push-to-Talk Dictation**: Hold a custom hotkey, speak, and release to paste on-device transcription into the active app
- **Built-in Calculator**: Perform calculations directly without opening a separate app
- **Calendar Integration**: Quick access to your calendar events without leaving the launcher
- **Emoji Picker**: Search and copy from 1550+ emojis with fuzzy search
- **Native Design**: Beautiful interface that respects your system preferences

## System Requirements

- **macOS**: 26.0 or later
- **Architecture**: Apple Silicon or Intel
- **Permissions**: Accessibility API, Apple Events

## Installation

### Homebrew (Recommended)
```bash
brew install --cask arjunkomath/tap/trace
```

### Direct Download
Download the latest release from [GitHub Releases](https://github.com/arjunkomath/trace/releases/latest).

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
- **Microphone**: For optional push-to-talk dictation
- **Speech Recognition**: For optional on-device transcription

## Dictation

Trace includes opt-in push-to-talk dictation. Enable it from Settings → Dictation, set a hotkey, download the on-device speech asset for your system language if prompted, then hold the shortcut to speak and release to paste the transcription into the active app.

Dictation is processed on your Mac using Apple's Speech framework. Trace does not save audio or transcripts.

## Settings Sync

Trace can back up and restore settings through a self-hosted sync server. Open Settings → General → Remote Settings Sync, enter your sync server URL and bearer token, then use Test, Download, or Upload.

For server setup, Docker, Docker Compose, API, and security details, see the [Trace Sync Server README](https://github.com/arjunkomath/trace-sync-server#readme).

## Architecture

- **Language**: Swift 5.9+
- **Framework**: SwiftUI with AppKit integration
- **APIs**: Accessibility (AXUIElement), Carbon (EventHotKey), Core Graphics, EventKit (Calendar), AVFoundation and Speech (Dictation)
- **Dependencies**: Sparkle (auto-updates), SymbolPicker (UI icons)

### Key Components
- `AppDelegate`: Main application controller, hotkey registration
- `LauncherWindow`: 810x360 borderless search interface  
- `AppSearchManager`: Concurrent app discovery with in-memory caching
- `WindowManager`: AXUIElement-based window positioning
- `HotkeyManager`: Carbon EventHotKey wrapper
- `ToastManager`: Non-intrusive notification system
- `CalendarManager`: EventKit integration for calendar access
- `EmojiManager`: Comprehensive emoji database with search functionality
- `DictationCoordinator`: Push-to-talk dictation lifecycle, speech analysis, and text insertion

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
- Dictation opt-in state and push-to-talk hotkey
- Launch at login preference
- Application cache and icons

## Distribution

### DMG Creation

```bash
# brew install create-dmg

create-dmg \
    --volname "Trace" \
    --window-pos 200 120 \
    --window-size 800 400 \
    --icon-size 100 \
    --icon "trace.app" 200 170 \
    --hide-extension "trace.app" \
    --app-drop-link 600 170 \
    --background "background.png" \
    "Trace-1.3.0.dmg" \
    "trace.app"
```

Once the DMG is created, you can distribute it via your website or GitHub releases.

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
