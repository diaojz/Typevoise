import SwiftUI
import AppKit

struct SettingsView: View {
    @State private var claudeAPIKey = ""
    @State private var claudeBaseURL = ""
    @State private var hotkeyDescription = "未设置"
    @State private var autoPasteEnabled = true
    @State private var saveMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("设置")
                        .font(.system(size: 38, weight: .bold))
                    Text("统一管理 Claude API、快捷键和输入行为。修改会保存在本机，并在后续使用中持续生效。")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                settingsCard(title: "Claude API 配置", description: "配置润色所需的 API Key 与可选 Base URL。") {
                    VStack(alignment: .leading, spacing: 16) {
                        labeledField("API Key") {
                            SecureField("sk-ant-...", text: $claudeAPIKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        labeledField("Base URL") {
                            TextField("https://api.anthropic.com", text: $claudeBaseURL)
                                .textFieldStyle(.roundedBorder)
                        }

                        Text("默认地址：https://api.anthropic.com")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                settingsCard(title: "快捷键", description: "设置全局快捷键，按一次开始录音，再按一次停止。") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("当前快捷键")
                                .font(.headline)
                            Text(hotkeyDescription)
                                .foregroundStyle(.secondary)
                        }

                        Button("录制新快捷键...") {
                            recordHotkey()
                        }
                        .buttonStyle(.bordered)

                        Text("录制完成后会立即保存。如需让全局监听切换到新快捷键，请重启应用。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                settingsCard(title: "输入行为", description: "决定识别完成后是自动插入，还是仅复制到剪贴板。") {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("识别完成后自动粘贴到当前光标", isOn: $autoPasteEnabled)
                            .toggleStyle(.switch)

                        Text("关闭后仅复制到剪贴板，需要手动按 ⌘V。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 14) {
                    Button("保存设置") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)

                    if !saveMessage.isEmpty {
                        Text(saveMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            load()
        }
    }

    private func settingsCard<Content: View>(title: String, description: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                Text(description)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content()
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
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
        saveMessage = ""
    }

    private func save() {
        SettingsManager.shared.claudeAPIKey = claudeAPIKey.isEmpty ? nil : claudeAPIKey
        SettingsManager.shared.claudeBaseURL = claudeBaseURL
        SettingsManager.shared.autoPasteEnabled = autoPasteEnabled
        saveMessage = "已保存"
    }

    private func recordHotkey() {
        let recorderVC = HotkeyRecorderViewController()
        recorderVC.onHotkeyRecorded = { keyCode, modifiers in
            SettingsManager.shared.hotkeyKeyCode = keyCode
            SettingsManager.shared.hotkeyModifiers = modifiers
            hotkeyDescription = KeyCodeMapper.formatHotkey(keyCode: keyCode, carbonModifiers: modifiers)
            saveMessage = "快捷键已保存"
        }

        let window = NSWindow(contentViewController: recorderVC)
        window.title = "录制快捷键"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 400, height: 200))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
