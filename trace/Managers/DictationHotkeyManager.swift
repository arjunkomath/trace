import Foundation

final class DictationHotkeyManager {
    static let shared = DictationHotkeyManager()

    private let logger = AppLogger.dictation
    private let settingsManager = SettingsManager.shared
    private var hotkeyId: UInt32?

    private init() {}

    func reload() {
        unregister()

        let settings = settingsManager.settings
        guard settings.dictationEnabled, settings.dictationHotkeyKeyCode > 0 else { return }

        hotkeyId = HotkeyRegistry.shared.registerHotkey(
            keyCode: UInt32(settings.dictationHotkeyKeyCode),
            modifiers: UInt32(settings.dictationHotkeyModifiers),
            type: .dictation,
            action: {
                Task { @MainActor in
                    DictationCoordinator.shared.handlePress()
                }
            },
            releaseAction: {
                Task { @MainActor in
                    DictationCoordinator.shared.handleRelease()
                }
            }
        )

        if hotkeyId == nil {
            logger.error("Failed to register dictation hotkey")
            ToastManager.shared.showError("Dictation hotkey conflicts with another Trace shortcut.")
        }
    }

    func unregister() {
        if let hotkeyId {
            HotkeyRegistry.shared.unregisterHotkey(id: hotkeyId)
            self.hotkeyId = nil
        }
    }
}
