import SwiftUI
import AppKit

struct WelcomeView: View {
    let onComplete: (() -> Void)?

    @State private var currentStep = 0
    @State private var claudeAPIKey = ""
    @State private var claudeBaseURL = "https://api.anthropic.com"
    @State private var hotkeyDescription = "未设置"

    init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("欢迎使用 Typevoise")
                        .font(.system(size: 40, weight: .bold))
                    Text("先完成基础配置。之后你就能在任何应用中，通过全局快捷键开始语音输入。")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                HStack(spacing: 10) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.25))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 12)
            }

            Group {
                switch currentStep {
                case 0:
                    step1Welcome
                case 1:
                    step2APIKey
                case 2:
                    step3Hotkey
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )

            HStack {
                if currentStep > 0 {
                    Button("上一步") {
                        currentStep -= 1
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if currentStep < 2 {
                    Button("下一步") {
                        if currentStep == 1 && claudeAPIKey.isEmpty {
                            showAlert(message: "请输入 Claude API Key")
                            return
                        }
                        currentStep += 1
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("完成") {
                        completeSetup()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(hotkeyDescription == "未设置")
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            claudeAPIKey = SettingsManager.shared.claudeAPIKey ?? ""
            claudeBaseURL = SettingsManager.shared.claudeBaseURL
            if SettingsManager.shared.hotkeyKeyCode != 0 {
                hotkeyDescription = KeyCodeMapper.formatHotkey(
                    keyCode: SettingsManager.shared.hotkeyKeyCode,
                    carbonModifiers: SettingsManager.shared.hotkeyModifiers
                )
            }
        }
    }

    private var step1Welcome: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.accentColor)

            Text("简单易用的语音输入工具")
                .font(.system(size: 32, weight: .bold))

            Text("Typevoise 负责把你的语音转成文本，再润色成更自然的表达，并自动插入到当前光标位置。")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 18) {
                FeatureRow(icon: "mic.fill", text: "系统语音识别，低门槛直接可用")
                FeatureRow(icon: "sparkles", text: "Claude 润色文本，让表达更顺滑")
                FeatureRow(icon: "keyboard", text: "全局快捷键触发，跨应用直接输入")
            }
            .padding(.top, 10)
        }
    }

    private var step2APIKey: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("配置 Claude API")
                .font(.system(size: 30, weight: .bold))

            Text("填入你的 API Key 和可选 Base URL。后续所有润色都将基于这里的配置。")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                Text("API Key *")
                    .font(.headline)
                SecureField("sk-ant-...", text: $claudeAPIKey)
                    .textFieldStyle(.roundedBorder)

                Text("Base URL（可选）")
                    .font(.headline)
                    .padding(.top, 8)
                TextField("https://api.anthropic.com", text: $claudeBaseURL)
                    .textFieldStyle(.roundedBorder)

                Link("如何获取 API Key？", destination: URL(string: "https://console.anthropic.com/")!)
                    .font(.subheadline)
                    .padding(.top, 6)
            }
        }
    }

    private var step3Hotkey: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("设置快捷键")
                .font(.system(size: 30, weight: .bold))

            Text("录制一个你顺手的全局快捷键。按一次开始录音，再按一次停止。")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("当前快捷键")
                        .font(.headline)
                    Text(hotkeyDescription)
                        .foregroundColor(hotkeyDescription == "未设置" ? .red : .green)
                        .fontWeight(.semibold)
                }

                Button("录制快捷键") {
                    recordHotkey()
                }
                .buttonStyle(.bordered)

                Text("建议使用：⌘⇧Space、⌘⇧D 或 ⌘⌥V")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private struct FeatureRow: View {
        let icon: String
        let text: String

        var body: some View {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 30)
                Text(text)
                    .font(.title3)
            }
        }
    }

    private func recordHotkey() {
        let recorderVC = HotkeyRecorderViewController()
        recorderVC.onHotkeyRecorded = { keyCode, modifiers in
            SettingsManager.shared.hotkeyKeyCode = keyCode
            SettingsManager.shared.hotkeyModifiers = modifiers
            hotkeyDescription = KeyCodeMapper.formatHotkey(keyCode: keyCode, carbonModifiers: modifiers)
        }

        let window = NSWindow(contentViewController: recorderVC)
        window.title = "录制快捷键"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 400, height: 200))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func completeSetup() {
        SettingsManager.shared.claudeAPIKey = claudeAPIKey
        SettingsManager.shared.claudeBaseURL = claudeBaseURL
        SettingsManager.shared.hasCompletedSetup = true

        let alert = NSAlert()
        alert.messageText = "设置完成"
        alert.informativeText = "按 \(hotkeyDescription) 开始使用 Typevoise！"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()

        onComplete?()
    }

    private func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "提示"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}
