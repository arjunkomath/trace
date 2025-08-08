//
//  KeyBindingView.swift
//  trace
//
//  Created by Arjun on 8/8/2025.
//

import SwiftUI
import Carbon

struct KeyBindingView: View {
    let keys: [String]
    let isSelected: Bool
    let size: KeyBindingSize
    
    @Environment(\.colorScheme) var colorScheme
    
    enum KeyBindingSize {
        case small
        case normal
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 10
            case .normal: return 11
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 4
            case .normal: return 6
            }
        }
        
        var verticalPadding: CGFloat {
            return 2
        }
    }
    
    init(keys: [String], isSelected: Bool = false, size: KeyBindingSize = .normal) {
        self.keys = keys
        self.isSelected = isSelected
        self.size = size
    }
    
    init(keyCode: UInt32, modifiers: UInt32, isSelected: Bool = false, size: KeyBindingSize = .normal) {
        var keyArray: [String] = []
        
        if modifiers & UInt32(controlKey) != 0 { keyArray.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { keyArray.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { keyArray.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { keyArray.append("⌘") }
        
        keyArray.append(KeyBindingView.keyCodeToString(keyCode))
        
        self.keys = keyArray
        self.isSelected = isSelected
        self.size = size
    }
    
    init(keyCombo: String, isSelected: Bool = false, size: KeyBindingSize = .normal) {
        self.keys = KeyBindingView.parseKeyCombo(keyCombo)
        self.isSelected = isSelected
        self.size = size
    }
    
    init(shortcut: KeyboardShortcut, isSelected: Bool = false, size: KeyBindingSize = .normal) {
        self.keys = shortcut.modifiers + [shortcut.key]
        self.isSelected = isSelected
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(keys.indices, id: \.self) { index in
                Text(keys[index])
                    .font(.system(size: size.fontSize, weight: .medium, design: .monospaced))
                    .foregroundColor(foregroundColor)
                    .padding(.horizontal, size.horizontalPadding)
                    .padding(.vertical, size.verticalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(backgroundColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(borderColor, lineWidth: 0.5)
                    )
            }
        }
    }
    
    private var foregroundColor: Color {
        if isSelected {
            return .white.opacity(0.7)
        } else {
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.white.opacity(0.2)
        } else {
            return colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color.white.opacity(0.3)
        } else {
            return colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.15)
        }
    }
    
    static func parseKeyCombo(_ keyCombo: String) -> [String] {
        var keys: [String] = []
        var currentKey = ""
        
        for char in keyCombo {
            let charStr = String(char)
            
            if charStr == "⌃" || charStr == "⌥" || charStr == "⇧" || charStr == "⌘" {
                if !currentKey.isEmpty {
                    keys.append(currentKey)
                    currentKey = ""
                }
                keys.append(charStr)
            } else {
                currentKey += charStr
            }
        }
        
        if !currentKey.isEmpty {
            keys.append(currentKey)
        }
        
        return keys
    }
    
    static func keyCodeToString(_ keyCode: UInt32) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 53: return "Escape"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 0: return "A"
        case 11: return "B"
        case 8: return "C"
        case 2: return "D"
        case 14: return "E"
        case 3: return "F"
        case 5: return "G"
        case 4: return "H"
        case 34: return "I"
        case 38: return "J"
        case 40: return "K"
        case 37: return "L"
        case 46: return "M"
        case 45: return "N"
        case 31: return "O"
        case 35: return "P"
        case 12: return "Q"
        case 15: return "R"
        case 1: return "S"
        case 17: return "T"
        case 32: return "U"
        case 9: return "V"
        case 13: return "W"
        case 7: return "X"
        case 16: return "Y"
        case 6: return "Z"
        case 18...29: return String(keyCode - 18 + 1)
        case 29: return "0"
        default: return "Key\(keyCode)"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        KeyBindingView(keyCombo: "⌥Space")
        KeyBindingView(keyCombo: "⌘⇧A")
        KeyBindingView(keys: ["⌃", "⌥", "⌘", "Space"])
        KeyBindingView(keyCombo: "⌘,", isSelected: true, size: .small)
        KeyBindingView(keyCombo: "⌘Q", isSelected: false, size: .small)
    }
    .padding()
}