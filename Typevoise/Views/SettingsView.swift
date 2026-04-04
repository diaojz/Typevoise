import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var claudeAPIKey = ""
    @State private var claudeBaseURL = ""
    @State private var hotkeyDescription = "未设置"
    @State private var autoPasteEnabled = true

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                Text("设置")
                    .font(.headline)
                    .padding(.leading)

                Spacer()

                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .padding(.trailing)
            }
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // 设置表单
            Form {
                Section("Claude API 配置") {
                    SecureField("API Key", text: $claudeAPIKey)
                        .textFieldStyle(.roundedBorder)

                    TextField("Base URL", text: $claudeBaseURL)
                        .textFieldStyle(.roundedBorder)

                    Text("默认: https://api.anthropic.com")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("快捷键") {
                    HStack {
                        Text("当前快捷键:")
                        Text(hotkeyDescription)
                            .foregroundColor(.secondary)
                    }

                    Button("录制新快捷键...") {
                        recordHotkey()
                    }

                    Text("按一次开始录音，再按一次停止")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("输入行为") {
                    Toggle("识别完成后自动粘贴到当前光标", isOn: $autoPasteEnabled)

                    Text("关闭后仅复制到剪贴板，需要手动按 ⌘V")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Spacer()

                    Button("保存") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .onAppear {
            load()
        }
    }

    private func load() {
        claudeAPIKey = SettingsManager.shared.claudeAPIKey ?? ""
        claudeBaseURL = SettingsManager.shared.claudeBaseURL
        autoPasteEnabled = SettingsManager.shared.autoPasteEnabled
        hotkeyDescription = KeyCodeMapper.formatHotkey(
            keyCode: SettingsManager.shared.hotkeyKeyCode,
            carbonModifiers: SettingsManager.shared.hotkeyModifiers
        )
    }

    private func save() {
        SettingsManager.shared.claudeAPIKey = claudeAPIKey.isEmpty ? nil : claudeAPIKey
        SettingsManager.shared.claudeBaseURL = claudeBaseURL
        SettingsManager.shared.autoPasteEnabled = autoPasteEnabled

        // 直接关闭设置窗口
        dismiss()
    }

    private func recordHotkey() {
        let recorderVC = HotkeyRecorderViewController()
        recorderVC.onHotkeyRecorded = { [self] keyCode, modifiers in
            SettingsManager.shared.hotkeyKeyCode = keyCode
            SettingsManager.shared.hotkeyModifiers = modifiers
            hotkeyDescription = KeyCodeMapper.formatHotkey(keyCode: keyCode, carbonModifiers: modifiers)

            let alert = NSAlert()
            alert.messageText = "快捷键已更新"
            alert.informativeText = "新快捷键：\(hotkeyDescription)\n\n请重启应用以使新快捷键生效。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }

        let window = NSWindow(contentViewController: recorderVC)
        window.title = "录制快捷键"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 400, height: 200))
        window.level = .floating  // 设置窗口层级为浮动
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func formatHotkey(keyCode: UInt32, modifiers: UInt32) -> String {
        return KeyCodeMapper.formatHotkey(keyCode: keyCode, carbonModifiers: modifiers)
    }
}
