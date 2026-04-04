import Cocoa

class HotkeyRecorderViewController: NSViewController {
    var onHotkeyRecorded: ((UInt32, UInt32) -> Void)?

    private var keyCodeLabel: NSTextField!
    private var instructionLabel: NSTextField!

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        setupUI()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(view)
    }

    private func setupUI() {
        // 说明文字
        instructionLabel = NSTextField(labelWithString: "请按下你想要使用的快捷键组合")
        instructionLabel.font = .systemFont(ofSize: 14)
        instructionLabel.alignment = .center
        instructionLabel.frame = NSRect(x: 50, y: 140, width: 300, height: 20)
        view.addSubview(instructionLabel)

        // 快捷键显示
        keyCodeLabel = NSTextField(labelWithString: "等待输入...")
        keyCodeLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        keyCodeLabel.alignment = .center
        keyCodeLabel.frame = NSRect(x: 50, y: 80, width: 300, height: 40)
        view.addSubview(keyCodeLabel)

        // 提示文字
        let hintLabel = NSTextField(labelWithString: "建议使用修饰键 + 字母/数字")
        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.alignment = .center
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.frame = NSRect(x: 50, y: 50, width: 300, height: 20)
        view.addSubview(hintLabel)

        // 取消按钮
        let cancelButton = NSButton(frame: NSRect(x: 100, y: 20, width: 80, height: 30))
        cancelButton.title = "取消"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancel)
        view.addSubview(cancelButton)

        // 确定按钮
        let confirmButton = NSButton(frame: NSRect(x: 220, y: 20, width: 80, height: 30))
        confirmButton.title = "确定"
        confirmButton.bezelStyle = .rounded
        confirmButton.keyEquivalent = "\r"
        confirmButton.target = self
        confirmButton.action = #selector(confirm)
        view.addSubview(confirmButton)
    }

    override func keyDown(with event: NSEvent) {
        let keyCode = event.keyCode
        let modifiers = event.modifierFlags

        var parts: [String] = []

        if modifiers.contains(.command) {
            parts.append("⌘")
        }
        if modifiers.contains(.shift) {
            parts.append("⇧")
        }
        if modifiers.contains(.option) {
            parts.append("⌥")
        }
        if modifiers.contains(.control) {
            parts.append("⌃")
        }

        let keyName = KeyCodeMapper.keyCodeToString(UInt32(keyCode))
        parts.append(keyName)
        keyCodeLabel.stringValue = parts.joined(separator: " ")

        // 如果有修饰键，0.3 秒后自动确认
        if !modifiers.intersection([.command, .shift, .option, .control]).isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.recordHotkey(keyCode: UInt16(keyCode), modifiers: modifiers)
            }
        } else {
            // 只按字母，显示为红色提示
            keyCodeLabel.textColor = .systemRed
        }
    }

    private func recordHotkey(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        var carbonModifiers: UInt32 = 0

        if modifiers.contains(.command) {
            carbonModifiers |= UInt32(1 << 8)  // cmdKey
        }
        if modifiers.contains(.shift) {
            carbonModifiers |= UInt32(1 << 9)  // shiftKey
        }
        if modifiers.contains(.option) {
            carbonModifiers |= UInt32(1 << 11) // optionKey
        }
        if modifiers.contains(.control) {
            carbonModifiers |= UInt32(1 << 12) // controlKey
        }

        onHotkeyRecorded?(UInt32(keyCode), carbonModifiers)
        view.window?.close()
    }

    @objc private func cancel() {
        view.window?.close()
    }

    @objc private func confirm() {
        // 手动确认时，需要有已录制的快捷键
        if keyCodeLabel.stringValue != "等待输入..." {
            view.window?.close()
        }
    }
}
