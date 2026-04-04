import Foundation
import AppKit
import UserNotifications
import ApplicationServices
import Carbon.HIToolbox

class TextInserter {
    static let shared = TextInserter()

    private init() {
        requestNotificationPermission()
    }

    func insertText(_ text: String, targetBundleID: String? = nil, targetPID: pid_t? = nil) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("✅ [TextInserter] 文本已复制到剪贴板")

        guard SettingsManager.shared.autoPasteEnabled else {
            showNotification(title: "文本已复制到剪贴板", body: "请按 ⌘V 粘贴")
            return
        }

        guard AXIsProcessTrusted() else {
            print("⚠️ [TextInserter] 辅助功能权限未授权，降级为手动粘贴")
            showNotification(title: "已复制，未自动粘贴", body: "请在系统设置授予辅助功能权限后重试")
            return
        }

        if let targetBundleID,
           NSWorkspace.shared.frontmostApplication?.bundleIdentifier != targetBundleID {
            print("⚠️ [TextInserter] 前台应用已变化，降级为手动粘贴")
            showNotification(title: "文本已复制到剪贴板", body: "检测到你切换了应用，请手动按 ⌘V")
            return
        }

        if let targetPID,
           let targetApp = NSRunningApplication(processIdentifier: targetPID) {
            _ = targetApp.activate(options: [])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            if self.simulateCommandV() {
                print("✅ [TextInserter] 已自动粘贴到当前输入框")
            } else {
                print("⚠️ [TextInserter] 自动粘贴失败，降级为手动粘贴")
                self.showNotification(title: "文本已复制到剪贴板", body: "自动粘贴失败，请手动按 ⌘V")
            }
        }
    }

    private func simulateCommandV() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("✅ [TextInserter] 通知权限已授予")
            } else if let error = error {
                print("❌ [TextInserter] 通知权限请求失败: \(error.localizedDescription)")
            }
        }
    }

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [TextInserter] 通知显示失败: \(error.localizedDescription)")
            }
        }
    }
}
