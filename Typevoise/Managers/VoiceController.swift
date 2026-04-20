import Foundation
import AppKit
import Speech

class VoiceController {
    private let speechRecognizer = SpeechRecognizer()
    private let whisperRecognizer = WhisperRecognizer()
    private let hotkeyManager = HotkeyManager.shared
    private var isProcessing = false
    private var pendingInsertTargetBundleID: String?
    private var pendingInsertTargetPID: pid_t?
    private var partialObserver: NSObjectProtocol?
    private var levelObserver: NSObjectProtocol?
    private let verbosePartialLogs = false

    // 当前使用的识别引擎
    private var currentEngine: String {
        SettingsManager.shared.recognitionEngine
    }

    private var isRecording: Bool {
        if currentEngine == "whisper" {
            return whisperRecognizer.isRecording
        } else {
            return speechRecognizer.isRecording
        }
    }

    init() {
        setupHotkey()
        setupObservers()
    }

    deinit {
        if let partialObserver {
            NotificationCenter.default.removeObserver(partialObserver)
        }
        if let levelObserver {
            NotificationCenter.default.removeObserver(levelObserver)
        }
    }

    private func setupObservers() {
        partialObserver = NotificationCenter.default.addObserver(
            forName: .voicePartialTranscription,
            object: nil,
            queue: .main
        ) { notification in
            guard let text = notification.object as? String else { return }
            RecordingOverlayController.shared.update(transcript: text)
            if self.verbosePartialLogs {
                print("📡 [Overlay] 实时转写更新: \(text)")
            }
        }

        levelObserver = NotificationCenter.default.addObserver(
            forName: .voiceInputLevel,
            object: nil,
            queue: .main
        ) { notification in
            guard let level = notification.object as? CGFloat else { return }
            RecordingOverlayController.shared.update(level: level)
        }
    }

    private func setupHotkey() {
        let keyCode = SettingsManager.shared.hotkeyKeyCode
        let modifiers = SettingsManager.shared.hotkeyModifiers

        guard keyCode != 0 else {
            print("⚠️  快捷键未设置")
            return
        }

        hotkeyManager.register(keyCode: keyCode, modifiers: modifiers) { [weak self] in
            self?.handleHotkeyPressed()
        }
    }

    private func handleHotkeyPressed() {
        print("🎯 快捷键回调被调用")
        print("   当前状态: isRecording=\(isRecording), isProcessing=\(isProcessing), engine=\(currentEngine)")

        if isRecording {
            print("   → 停止录音")
            stopRecording()
        } else {
            print("   → 开始录音")
            startRecording()
        }
    }

    private func startRecording() {
        guard !isProcessing else { return }

        // 如果已经在录音，先停止
        if speechRecognizer.isRecording {
            print("⚠️  [VoiceController] 检测到正在录音，先停止")
            speechRecognizer.cancelRecognition()
        }

        // 记录开始录音时的前台应用，用于后续自动粘贴目标校验
        pendingInsertTargetBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        pendingInsertTargetPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        // 发送录音状态通知
        NotificationCenter.default.post(
            name: NSNotification.Name("RecordingStateChanged"),
            object: nil,
            userInfo: ["isRecording": true]
        )

        // 根据引擎选择不同的录音方式
        if currentEngine == "whisper" {
            startWhisperRecording()
        } else {
            startNativeRecording()
        }
    }

    private func startNativeRecording() {
        speechRecognizer.requestMicrophonePermission { [weak self] (micGranted: Bool) in
            guard let self else { return }
            guard micGranted else {
                self.showMicrophonePermissionAlert()
                return
            }

            // 检查语音识别权限
            if SFSpeechRecognizer.authorizationStatus() != .authorized {
                self.speechRecognizer.requestPermissions { [weak self] (granted: Bool) in
                    if granted {
                        self?.startRecording()
                    } else {
                        self?.showPermissionAlert()
                    }
                }
                return
            }

            do {
                try self.speechRecognizer.startRecording { [weak self] (finalText: String?, error: Error?) in
                    guard let self = self else { return }

                    if let error = error {
                        RecordingOverlayController.shared.hide()
                        self.showError(self.userFacingRecognitionMessage(for: error))
                        NotificationCenter.default.post(name: .voiceRecordingStopped, object: nil)
                        return
                    }

                    let recognizedText = (finalText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    self.handleRecognizedText(recognizedText)
                }

                RecordingOverlayController.shared.show(
                    onCancel: { [weak self] in self?.cancelRecording() },
                    onConfirm: { [weak self] in self?.stopRecording() }
                )
                NotificationCenter.default.post(name: .voiceRecordingStarted, object: nil)
                print("🎤 开始录音（原生引擎）")
            } catch {
                NotificationCenter.default.post(name: .voiceRecordingStopped, object: nil)
                NotificationCenter.default.post(
                    name: NSNotification.Name("RecordingStateChanged"),
                    object: nil,
                    userInfo: ["isRecording": false]
                )
                self.showError("录音失败: \(self.userFacingRecognitionMessage(for: error))")
            }
        }
    }

    private func startWhisperRecording() {
        do {
            try whisperRecognizer.startRecording { [weak self] (finalText: String?, error: Error?) in
                guard let self = self else { return }

                if let error = error {
                    RecordingOverlayController.shared.hide()
                    self.showError(self.userFacingRecognitionMessage(for: error))
                    NotificationCenter.default.post(name: .voiceRecordingStopped, object: nil)

                    // 如果 Whisper 失败，自动降级到原生引擎
                    SettingsManager.shared.recognitionEngine = "native"
                    return
                }

                let recognizedText = (finalText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                self.handleRecognizedText(recognizedText)
            }

            RecordingOverlayController.shared.show(
                onCancel: { [weak self] in self?.cancelRecording() },
                onConfirm: { [weak self] in self?.stopRecording() }
            )
            NotificationCenter.default.post(name: .voiceRecordingStarted, object: nil)
            print("🎤 开始录音（Whisper 引擎）")
        } catch {
            NotificationCenter.default.post(name: .voiceRecordingStopped, object: nil)
            NotificationCenter.default.post(
                name: NSNotification.Name("RecordingStateChanged"),
                object: nil,
                userInfo: ["isRecording": false]
            )
            self.showError("录音失败: \(self.userFacingRecognitionMessage(for: error))")

            // Whisper 启动失败，降级到原生引擎
            SettingsManager.shared.recognitionEngine = "native"
        }
    }

    private func stopRecording() {
        // 立即发送停止通知，更新 UI
        NotificationCenter.default.post(name: .voiceRecordingStopped, object: nil)
        NotificationCenter.default.post(
            name: NSNotification.Name("RecordingStateChanged"),
            object: nil,
            userInfo: ["isRecording": false]
        )

        // 异步停止录音和转录（避免阻塞主线程）
        if currentEngine == "whisper" {
            whisperRecognizer.stopRecording()
        } else {
            speechRecognizer.stopRecording()
        }

        print("⏹️  停止录音")
    }

    private func cancelRecording() {
        if currentEngine == "whisper" {
            whisperRecognizer.cancelRecognition()
        } else {
            speechRecognizer.cancelRecognition()
        }

        RecordingOverlayController.shared.hide()
        NotificationCenter.default.post(name: .voiceRecordingStopped, object: nil)

        // 发送录音状态通知
        NotificationCenter.default.post(
            name: NSNotification.Name("RecordingStateChanged"),
            object: nil,
            userInfo: ["isRecording": false]
        )

        print("⛔️ 取消录音")
    }

    private func handleRecognizedText(_ recognizedText: String) {
        guard !recognizedText.isEmpty else {
            print("⚠️ [VoiceController] 最终识别文本为空")
            RecordingOverlayController.shared.hide()
            showError("未识别到语音，请重试（可尝试多说 1-2 秒）")
            return
        }

        print("📝 识别结果: \(recognizedText)")
        print("🪟 [VoiceController] 准备切换到处理状态")

        // 确保在主线程上更新 UI
        DispatchQueue.main.async {
            // 开始处理 - 切换浮窗到处理状态
            self.isProcessing = true
            RecordingOverlayController.shared.showProcessing()
            NotificationCenter.default.post(name: .voiceProcessingStarted, object: nil)
            print("🔄 [VoiceController] 开始调用 Claude 润色")
        }

        Task {
            do {
                let polishedText = try await ClaudeService.shared.polishText(recognizedText) { progress in
                    // 在主线程更新进度
                    DispatchQueue.main.async {
                        RecordingOverlayController.shared.updateProgress(progress)
                    }
                }
                print("✨ 润色结果: \(polishedText)")

                await MainActor.run {
                    RecordingOverlayController.shared.hide()
                    TextInserter.shared.insertText(
                        polishedText,
                        targetBundleID: self.pendingInsertTargetBundleID,
                        targetPID: self.pendingInsertTargetPID
                    )
                    // 保存到历史记录
                    HistoryManager.shared.addRecord(originalText: recognizedText, polishedText: polishedText)
                    self.pendingInsertTargetBundleID = nil
                    self.pendingInsertTargetPID = nil
                    self.isProcessing = false
                    NotificationCenter.default.post(name: .voiceProcessingCompleted, object: nil)
                    print("✅ [VoiceController] 文本已插入")
                }
            } catch {
                await MainActor.run {
                    RecordingOverlayController.shared.hide()
                    // Claude 调用失败时，降级插入原始识别文本，避免用户内容丢失
                    TextInserter.shared.insertText(
                        recognizedText,
                        targetBundleID: self.pendingInsertTargetBundleID,
                        targetPID: self.pendingInsertTargetPID
                    )
                    // 即使失败也保存到历史记录（原文和润色文本相同）
                    HistoryManager.shared.addRecord(originalText: recognizedText, polishedText: recognizedText)
                    self.pendingInsertTargetBundleID = nil
                    self.pendingInsertTargetPID = nil
                    self.isProcessing = false
                    NotificationCenter.default.post(name: .voiceProcessingCompleted, object: nil)
                    print("❌ [VoiceController] Claude 处理失败: \(error.localizedDescription)")
                    print("↩️ [VoiceController] 已降级插入原始文本")

                    self.showError("Claude 润色失败，已为你插入原始识别文本。\n\n错误：\(error.localizedDescription)")
                }
            }
        }
    }

    private func userFacingRecognitionMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let message = localizedError.errorDescription,
           !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }

        return "语音识别这次没有成功完成，请再试一次。若多次失败，请检查麦克风和语音识别权限是否已开启。"
    }

    private func showMicrophonePermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "需要麦克风权限"
            alert.informativeText = "Typevoise 需要访问麦克风以采集语音。\n\n请在系统设置 → 隐私与安全性 → 麦克风中授权。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "取消")

            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
            }
        }
    }

    private func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "需要语音识别权限"
            alert.informativeText = "Typevoise 需要访问麦克风以进行语音识别。\n\n请在系统设置 → 隐私与安全性 → 语音识别中授权。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "取消")

            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")!)
            }
        }
    }

    private func showError(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "错误"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let voiceRecordingStarted = Notification.Name("voiceRecordingStarted")
    static let voiceRecordingStopped = Notification.Name("voiceRecordingStopped")
    static let voiceProcessingStarted = Notification.Name("voiceProcessingStarted")
    static let voiceProcessingCompleted = Notification.Name("voiceProcessingCompleted")
}
