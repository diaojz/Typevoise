import Foundation

struct KeyCodeMapper {
    static func keyCodeToString(_ keyCode: UInt32) -> String {
        switch keyCode {
        // 字母键
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 45: return "N"
        case 46: return "M"

        // 数字键
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        case 29: return "0"

        // 特殊键
        case 36: return "Return"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Delete"
        case 53: return "Escape"
        case 117: return "Forward Delete"
        case 115: return "Home"
        case 116: return "Page Up"
        case 119: return "End"
        case 121: return "Page Down"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"

        // 符号键
        case 27: return "-"
        case 24: return "="
        case 33: return "["
        case 30: return "]"
        case 41: return ";"
        case 39: return "'"
        case 42: return "\\"
        case 43: return ","
        case 47: return "."
        case 44: return "/"
        case 50: return "`"

        default: return "Key \(keyCode)"
        }
    }

    // Carbon modifiers 转换为可读字符串
    static func carbonModifiersToString(_ carbonModifiers: UInt32) -> String {
        var parts: [String] = []

        // Carbon 格式的修饰键位掩码
        let cmdKey: UInt32 = 1 << 8      // 256
        let shiftKey: UInt32 = 1 << 9    // 512
        let optionKey: UInt32 = 1 << 11  // 2048
        let controlKey: UInt32 = 1 << 12 // 4096

        if carbonModifiers & cmdKey != 0 {
            parts.append("⌘")
        }
        if carbonModifiers & shiftKey != 0 {
            parts.append("⇧")
        }
        if carbonModifiers & optionKey != 0 {
            parts.append("⌥")
        }
        if carbonModifiers & controlKey != 0 {
            parts.append("⌃")
        }

        return parts.joined(separator: " ")
    }

    // 格式化完整的快捷键字符串
    static func formatHotkey(keyCode: UInt32, carbonModifiers: UInt32) -> String {
        if keyCode == 0 && carbonModifiers == 0 {
            return "未设置"
        }

        let modifierString = carbonModifiersToString(carbonModifiers)
        let keyString = keyCodeToString(keyCode)

        if modifierString.isEmpty {
            return keyString
        } else {
            return "\(modifierString) \(keyString)"
        }
    }
}
