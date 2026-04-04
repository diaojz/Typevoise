import SwiftUI
import AppKit

struct ContentView: View {
    @State private var isRecording = false
    @State private var recordingText = "按快捷键开始录音"
    @State private var showSettings = false
    @State private var showHistory = false

    var body: some View {
        VStack(spacing: 30) {
            // 顶部标题
            VStack(spacing: 10) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)

                Text("Typevoise")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("语音转文字助手")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)

            Spacer()

            // 录音状态显示
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 120, height: 120)

                    Image(systemName: isRecording ? "mic.fill" : "mic.slash.fill")
                        .font(.system(size: 50))
                        .foregroundColor(isRecording ? .red : .gray)
                }

                Text(recordingText)
                    .font(.headline)
                    .foregroundColor(isRecording ? .red : .primary)
            }

            Spacer()

            // 快捷键提示
            VStack(spacing: 10) {
                Text("快捷键：\(getHotkeyDescription())")
                    .font(.body)
                    .foregroundColor(.secondary)

                Text("按一次开始录音，再按一次停止")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)

            // 底部按钮
            HStack(spacing: 20) {
                Button(action: {
                    showHistory = true
                }) {
                    Label("历史记录", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.bordered)

                Button(action: {
                    showSettings = true
                }) {
                    Label("设置", systemImage: "gear")
                }
                .buttonStyle(.bordered)

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Label("退出", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, 30)
        }
        .frame(width: 400, height: 600)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showHistory) {
            HistoryView()
        }
        .onAppear {
            setupNotifications()
        }
    }

    private func getHotkeyDescription() -> String {
        let keyCode = SettingsManager.shared.hotkeyKeyCode
        let modifiers = SettingsManager.shared.hotkeyModifiers

        if keyCode == 0 {
            return "未设置"
        }

        return KeyCodeMapper.formatHotkey(keyCode: keyCode, carbonModifiers: modifiers)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RecordingStateChanged"),
            object: nil,
            queue: .main
        ) { notification in
            if let isRecording = notification.userInfo?["isRecording"] as? Bool {
                self.isRecording = isRecording
                self.recordingText = isRecording ? "正在录音..." : "按快捷键开始录音"
            }
        }
    }
}

#Preview {
    ContentView()
}
