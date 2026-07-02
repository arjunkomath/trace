import AppKit
import Carbon
import Foundation

final class TextInsertionService {
    enum InsertionError: LocalizedError {
        case accessibilityNotTrusted
        case secureInputEnabled
        case traceIsFrontmost
        case emptyText
        case pasteboardWriteFailed

        var errorDescription: String? {
            switch self {
            case .accessibilityNotTrusted:
                return "Accessibility permission is required to paste dictation."
            case .secureInputEnabled:
                return "Dictation cannot paste while Secure Input is active."
            case .traceIsFrontmost:
                return "Choose another app or text field before starting dictation."
            case .emptyText:
                return "No speech was detected."
            case .pasteboardWriteFailed:
                return "Trace could not write the transcript to the clipboard."
            }
        }
    }

    func insert(_ text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw InsertionError.emptyText }
        guard AXIsProcessTrusted() else { throw InsertionError.accessibilityNotTrusted }
        guard !IsSecureEventInputEnabled() else { throw InsertionError.secureInputEnabled }

        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
            throw InsertionError.traceIsFrontmost
        }

        let pasteboard = NSPasteboard.general
        let previousItems = Self.snapshotPasteboard(pasteboard)
        pasteboard.clearContents()
        guard pasteboard.setString(trimmed, forType: .string) else {
            Self.restorePasteboard(pasteboard, items: previousItems)
            throw InsertionError.pasteboardWriteFailed
        }

        Self.sendPasteKeystroke()
        try? await Task.sleep(nanoseconds: 450_000_000)
        Self.restorePasteboard(pasteboard, items: previousItems)
    }

    private static func snapshotPasteboard(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        pasteboard.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        } ?? []
    }

    private static func restorePasteboard(_ pasteboard: NSPasteboard, items: [NSPasteboardItem]) {
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    private static func sendPasteKeystroke() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode = CGKeyCode(kVK_ANSI_V)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
