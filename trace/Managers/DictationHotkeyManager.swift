import Foundation

final class DictationHotkeyManager {
    static let shared = DictationHotkeyManager()

    private let logger = AppLogger.dictation
    private let settingsManager = SettingsManager.shared
    private var hotkeyId: UInt32?

    private init() {}

    @discardableResult
    func reload() -> Bool {
        unregister()

        let settings = settingsManager.settings
        guard settings.dictationEnabled, settings.dictationHotkeyKeyCode > 0 else { return true }

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
            return false
        }

        return true
    }

    func canRegister(keyCode: UInt32, modifiers: UInt32) -> Bool {
        if let hotkeyId,
           let registration = HotkeyRegistry.shared.getAllRegistrations().first(where: { $0.id == hotkeyId }),
           registration.keyCode == keyCode,
           registration.modifiers == modifiers {
            return true
        }

        guard let temporaryId = HotkeyRegistry.shared.registerHotkey(
            keyCode: keyCode,
            modifiers: modifiers,
            type: .dictation,
            action: {},
            releaseAction: {}
        ) else {
            return false
        }

        HotkeyRegistry.shared.unregisterHotkey(id: temporaryId)
        return true
    }

    func unregister() {
        if let hotkeyId {
            HotkeyRegistry.shared.unregisterHotkey(id: hotkeyId)
            self.hotkeyId = nil
        }
    }
}
