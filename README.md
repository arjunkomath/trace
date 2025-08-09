# Trace

A fast, lightweight macOS application launcher and system-wide search tool. Built with SwiftUI, Trace runs silently in the background and provides instant access to applications, settings, and web search through a global hotkey.

## Features

### 🚀 **Lightning Fast App Launching**
- Instant application search and launch
- Fuzzy search with intelligent ranking
- Concurrent app discovery for optimal performance
- Support for all application directories (Applications, System/Applications, ~/Applications)

### ⌨️ **Global Hotkey Access**
- Default hotkey: `⌥Space` (Option + Space)
- Customizable hotkey combinations
- System-wide access from any application
- Live hotkey recording in settings

### 🎨 **Native macOS Design**
- Translucent background with system materials
- Respects system appearance (Light/Dark mode)
- Smooth animations and transitions
- Professional, minimal interface

### 🔍 **Integrated Web Search**
- Google search fallback for non-app queries
- Seamless transition between app and web search
- Smart search result prioritization

### ⚙️ **System Integration**
- Background-only app (no dock or menu bar presence)
- Launch at login support
- Accessibility and Apple Events integration
- System appearance control

### 🪟 **Advanced Window Management**
- App-specific hotkey assignments
- Window management commands through search
- Control Center integration
- Quick access to system settings

## System Requirements

- macOS 15.5 or later
- Apple Silicon or Intel Mac

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/arjunkomath/trace.git
   cd trace
   ```

2. Build the application:
   ```bash
   xcodebuild -project trace.xcodeproj -scheme trace -configuration Release build
   ```

3. The built application will be available in the build directory

### Permissions

Trace requires the following permissions to function properly:
- **Accessibility**: For system appearance control and window management
- **Apple Events**: For controlling system settings
- **Input Monitoring**: For global hotkey functionality (implicit)

Grant these permissions when prompted, or manually enable them in System Preferences > Privacy & Security.

## Usage

### Basic Usage

1. Launch Trace (it runs in the background)
2. Press `⌥Space` (or your configured hotkey) to open the launcher
3. Type to search for applications
4. Press `Return` to launch the selected app, or click on it
5. Press `Escape` or click outside to close

### Search Types

- **Applications**: Type app names for fuzzy matching
- **Commands**: Search for built-in commands like "settings", "quit"
- **Web Search**: If no apps match, Google search is provided as fallback

### Settings Access

Search for "settings" in the launcher to access:
- Hotkey customization
- Launch at login toggle
- App-specific hotkey assignments
- Window management settings
- About information

## Architecture

### Core Components

- **AppDelegate**: Main application controller and window lifecycle management
- **LauncherView**: Primary search interface with SwiftUI
- **AppSearchManager**: High-performance application discovery and search
- **HotkeyManager**: Global hotkey registration using Carbon API
- **ServiceContainer**: Dependency injection and service management

### Key Features

- **Background Operation**: Runs as `LSUIElement` for invisible operation
- **Memory Efficient**: Lazy loading and intelligent caching
- **Concurrent Processing**: Non-blocking app discovery and search
- **Modern Swift**: Uses async/await, structured concurrency, and SwiftUI

## Development

### Build Commands

```bash
# Debug build
xcodebuild -project trace.xcodeproj -scheme trace -configuration Debug build

# Release build
xcodebuild -project trace.xcodeproj -scheme trace -configuration Release build

# Clean build
xcodebuild -project trace.xcodeproj -scheme trace clean
```

### Project Structure

```
trace/
├── Core/                # Core application logic
├── Views/               # SwiftUI views and UI components
├── Managers/            # Business logic managers
├── Services/            # System integration services
├── Models/              # Data models
├── Components/          # Reusable UI components
└── Windows/             # Window management
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Connect

- **GitHub**: [arjunkomath/trace](https://github.com/arjunkomath/trace)
- **Twitter**: [@arjunkomath](https://twitter.com/arjunkomath)

---

Built with ❤️ using SwiftUI and modern macOS APIs.
