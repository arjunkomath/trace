# Trace

**Lightning-fast app launcher for macOS**

A beautiful, native macOS application launcher that lives in your background. Press `⌥Space`, type what you need, and launch instantly. Built with SwiftUI for modern macOS.

## ✨ Features

- **🚀 Instant Search** - Fuzzy search across all your applications with intelligent ranking
- **⌨️ Global Hotkey** - Access from anywhere with customizable shortcuts (default: `⌥Space`)  
- **🎨 Native Design** - Translucent UI that respects your system theme and appearance
- **🔍 Smart Results** - Application search with Google fallback for everything else
- **⚙️ Invisible** - Runs silently in background, no dock or menu bar clutter
- **🪟 Advanced** - Custom hotkeys per app, window management, and system integration

## System Requirements

- macOS 15.5 or later
- Apple Silicon or Intel Mac

## 🚀 Installation

### Download & Build

```bash
git clone https://github.com/arjunkomath/trace.git
cd trace
xcodebuild -project trace.xcodeproj -scheme trace -configuration Release build
```

Grant permissions when prompted: **Accessibility** and **Apple Events**.

## 🎯 Usage

1. **Launch Trace** → Runs silently in background
2. **Press `⌥Space`** → Opens the search interface  
3. **Type & Launch** → Search apps, press `Return` or click to launch
4. **Access Settings** → Search "settings" to customize hotkeys and preferences

**Pro tip**: Search for "quit" to exit the app completely.

## 🛠️ Development

Built with modern Swift, SwiftUI, and macOS APIs. See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed technical information.

```bash
# Debug build
xcodebuild -project trace.xcodeproj -scheme trace -configuration Debug build

# Release build  
xcodebuild -project trace.xcodeproj -scheme trace -configuration Release build
```

## 🤝 Contributing

Contributions welcome! Fork, create a feature branch, and submit a PR.

## 🔗 Links

- **Website**: [trace.techulus.xyz](https://trace.techulus.xyz
- **GitHub**: [arjunkomath/trace](https://github.com/arjunkomath/trace)  
- **Twitter**: [@arjunkomath](https://twitter.com/arjunkomath)

---

Built with ❤️ using SwiftUI for macOS
