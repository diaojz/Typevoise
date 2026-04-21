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

        let autoPasteEnabled = SettingsManager.shared.autoPasteEnabled
        print("🔍 [TextInserter] autoPasteEnabled = \(autoPasteEnabled)")

        guard autoPasteEnabled else {
            print("⚠️ [TextInserter] 自动粘贴已关闭")
            RecordingOverlayController.shared.hide()
            return
        }

        let isTrusted = AXIsProcessTrusted()
        print("🔍 [TextInserter] AXIsProcessTrusted = \(isTrusted)")

        guard isTrusted else {
            print("⚠️ [TextInserter] 辅助功能权限未授权")
            RecordingOverlayController.shared.hide()
            return
        }

        // 直接执行自动粘贴
        print("🔍 [TextInserter] 准备执行自动粘贴...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            self.simulateCommandV()
            print("✅ [TextInserter] 已执行自动粘贴")
            RecordingOverlayController.shared.hide()
        }
    }

    private func simulateCommandV() {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
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
