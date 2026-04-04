import SwiftUI

struct WelcomeView: View {
    @State private var currentStep = 0
    @State private var claudeAPIKey = ""
    @State private var claudeBaseURL = "https://api.anthropic.com"
    @State private var hotkeyDescription = "未设置"

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("欢迎使用 Typevoise")
                .font(.largeTitle)
                .fontWeight(.bold)

            // 步骤指示器
            HStack(spacing: 10) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.bottom, 20)

            // 内容区域
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 按钮区域
            HStack {
                if currentStep > 0 {
                    Button("上一步") {
                        currentStep -= 1
                    }
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
            .padding(.top, 20)
        }
        .padding(40)
        .frame(width: 600, height: 500)
    }

    // MARK: - 步骤 1：欢迎

    private var step1Welcome: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            Text("简单易用的语音输入工具")
                .font(.title2)

            VStack(alignment: .leading, spacing: 10) {
                FeatureRow(icon: "mic.fill", text: "系统语音识别，完全免费")
                FeatureRow(icon: "sparkles", text: "AI 智能润色，提升表达")
                FeatureRow(icon: "keyboard", text: "快捷键触发，即说即得")
            }
            .padding(.top, 20)
        }
    }

    // MARK: - 步骤 2：配置 API Key

    private var step2APIKey: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("配置 Claude API")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 10) {
                Text("API Key *")
                    .font(.headline)

                SecureField("sk-ant-...", text: $claudeAPIKey)
                    .textFieldStyle(.roundedBorder)

                Text("Base URL（可选）")
                    .font(.headline)
                    .padding(.top, 10)

                TextField("https://api.anthropic.com", text: $claudeBaseURL)
                    .textFieldStyle(.roundedBorder)

                Link("如何获取 API Key？", destination: URL(string: "https://console.anthropic.com/")!)
                    .font(.caption)
                    .padding(.top, 5)
            }
        }
    }

    // MARK: - 步骤 3：设置快捷键

    private var step3Hotkey: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("设置快捷键")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 15) {
                HStack {
                    Text("当前快捷键:")
                    Text(hotkeyDescription)
                        .foregroundColor(hotkeyDescription == "未设置" ? .red : .green)
                        .fontWeight(.semibold)
                }

                Button("录制快捷键") {
                    recordHotkey()
                }
                .buttonStyle(.bordered)

                Text("建议使用：⌘ ⇧ V 或 ⌘ ⌥ V")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("按一次开始录音，再按一次停止")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 辅助视图

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
                    .font(.body)
            }
        }
    }

    // MARK: - 方法

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
        window.level = .floating  // 设置窗口层级为浮动
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func formatHotkey(keyCode: UInt32, modifiers: UInt32) -> String {
        return KeyCodeMapper.formatHotkey(keyCode: keyCode, carbonModifiers: modifiers)
    }

    private func completeSetup() {
        // 保存配置
        SettingsManager.shared.claudeAPIKey = claudeAPIKey
        SettingsManager.shared.claudeBaseURL = claudeBaseURL
        SettingsManager.shared.hasCompletedSetup = true

        // 关闭窗口
        NSApplication.shared.keyWindow?.close()

        // 显示完成提示
        let alert = NSAlert()
        alert.messageText = "设置完成"
        alert.informativeText = "按 \(hotkeyDescription) 开始使用 Typevoise！"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
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
