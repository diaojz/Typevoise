import SwiftUI
import AppKit

struct SettingsView: View {
    @State private var claudeAPIKey = ""
    @State private var claudeBaseURL = ""
    @State private var hotkeyDescription = "未设置"
    @State private var autoPasteEnabled = true
    @State private var saveMessage = ""
    @StateObject private var microphoneManager = MicrophoneManager.shared
    @StateObject private var serviceManager = WhisperServiceManager.shared
    @State private var showMicrophonePicker = false
    @State private var recognitionEngine = "native"

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

                settingsCard(title: "麦克风设备", description: "选择用于语音识别的麦克风。如果识别不到声音，可能是距离太远或选错了设备。") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("当前麦克风")
                                    .font(.headline)
                                if let device = microphoneManager.getSelectedDevice() {
                                    Text(device.displayName)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("系统默认")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("选择麦克风...") {
                                showMicrophonePicker = true
                            }
                            .buttonStyle(.bordered)
                        }

                        Text("如果识别不到声音，请确保：\n• 麦克风距离嘴巴 10-30cm\n• 选择了正确的麦克风设备\n• 系统设置中已授予麦克风权限")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                settingsCard(title: "识别引擎", description: "选择语音识别引擎。Whisper 对远距离、弱信号的识别效果更好。") {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("识别引擎", selection: $recognitionEngine) {
                            Text("系统原生（快速、免费）").tag("native")
                            Text("Whisper 本地（更准确）").tag("whisper")
                        }
                        .pickerStyle(.radioGroup)

                        if recognitionEngine == "whisper" {
                            Divider()

                            // 服务状态显示
                            HStack {
                                Text("服务状态")
                                    .font(.headline)
                                Spacer()
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(serviceStatusColor)
                                        .frame(width: 8, height: 8)
                                    Text(serviceManager.serviceStatus.description)
                                        .foregroundColor(serviceStatusColor)
                                }
                            }

                            // 服务控制按钮
                            HStack(spacing: 12) {
                                if serviceManager.isRunning {
                                    Button("停止服务") {
                                        Task {
                                            await serviceManager.stopService()
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                } else {
                                    Button("启动服务") {
                                        Task {
                                            do {
                                                try await serviceManager.startService()
                                            } catch {
                                                print("❌ 启动服务失败: \(error)")
                                            }
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }

                                Button("检测服务") {
                                    Task {
                                        await serviceManager.checkServiceStatus()
                                    }
                                }
                                .buttonStyle(.bordered)
                            }

                            if !serviceManager.isRunning {
                                Text("提示：使用 Whisper 引擎前需要先启动服务")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Text("• 系统原生：使用 macOS 内置识别，速度快但准确率约 90%\n• Whisper 本地：准确率 95%+，对远距离和噪音环境识别更好")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
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
        .sheet(isPresented: $showMicrophonePicker) {
            MicrophonePickerView()
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
        recognitionEngine = SettingsManager.shared.recognitionEngine
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
        SettingsManager.shared.recognitionEngine = recognitionEngine
        saveMessage = "已保存"
    }

    private var serviceStatusColor: Color {
        switch serviceManager.serviceStatus {
        case .running: return .green
        case .stopped: return .gray
        case .starting, .stopping: return .orange
        case .error: return .red
        }
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
