import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
class SpeechRecognizer: ObservableObject {
    @Published var isRecording = false
    @Published var recognizedText = ""

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var onFinalResult: ((String?, Error?) -> Void)?
    private var latestTranscription = ""
    private var hasInstalledTap = false
    private var lastLevelLogAt = Date.distantPast
    private let verboseAudioLogs = false

    // MARK: - 权限检查

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        let status = SFSpeechRecognizer.authorizationStatus()
        print("🔐 [Speech] 当前语音识别权限状态: \(status.rawValue)")
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                print("🔐 [Speech] 语音识别权限请求结果: \(status.rawValue)")
                completion(status == .authorized)
            }
        }
    }

    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        // 在 Sandbox 环境下,直接尝试访问麦克风
        // 如果没有权限,系统会自动弹出授权对话框
        // 如果已有权限,则直接成功

        // 使用 AVAudioSession 检查权限(更适合 Sandbox)
        #if os(macOS)
        // macOS 上直接返回 true,让系统在实际使用时处理权限
        // 因为 AVCaptureDevice 在 Sandbox 下可能无法正确读取状态
        print("🎙️ [Mic] macOS Sandbox 环境,跳过预检查,让系统处理权限")
        completion(true)
        #else
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        print("🎙️ [Mic] 当前麦克风权限状态: \(status.rawValue)")
        switch status {
        case .authorized:
            print("✅ [Mic] 麦克风已授权")
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    print("🔐 [Mic] 麦克风权限请求结果: \(granted)")
                    completion(granted)
                }
            }
        default:
            print("❌ [Mic] 麦克风未授权")
            completion(false)
        }
        #endif
    }

    // MARK: - 开始录音

    func startRecording(onFinalResult: @escaping (String?, Error?) -> Void) throws {
        print("🎤 [SpeechRecognizer] 开始录音流程")
        self.onFinalResult = onFinalResult
        self.recognizedText = ""
        self.latestTranscription = ""

        // 检查语音识别权限
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            print("❌ [SpeechRecognizer] 语音识别权限未授权")
            throw RecognitionError.notAuthorized
        }

        let recognizer = speechRecognizer ?? SFSpeechRecognizer(locale: Locale.current)
        guard let recognizer else {
            print("❌ [SpeechRecognizer] 语音识别器不可用")
            throw RecognitionError.recognizerUnavailable
        }
        guard recognizer.isAvailable else {
            print("❌ [SpeechRecognizer] 语音识别器当前不可用")
            throw RecognitionError.recognizerUnavailable
        }

        print("✅ [SpeechRecognizer] 权限已授权")

        // 停止之前的任务
        if let task = recognitionTask {
            print("⚠️  [SpeechRecognizer] 停止之前的识别任务")
            task.cancel()
            recognitionTask = nil
        }

        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("❌ [SpeechRecognizer] 无法创建识别请求")
            throw RecognitionError.cannotCreateRequest
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        if #available(macOS 13.0, *) {
            recognitionRequest.addsPunctuation = true
        }
        print("✅ [SpeechRecognizer] 识别请求已创建")

        // 配置音频引擎
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        print("📊 [SpeechRecognizer] 音频格式: \(recordingFormat)")

        // 检查麦克风权限 - 实际访问时系统会自动处理
        // 如果没有权限,audioEngine.start() 会抛出错误

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)

            // 计算输入音量（RMS）用于波形动画
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            if let channelData, frameLength > 0 {
                var sum: Float = 0
                for i in 0..<frameLength {
                    let sample = channelData[i]
                    sum += sample * sample
                }
                let rms = sqrt(sum / Float(frameLength))
                let level = min(max(CGFloat(rms * 12), 0), 1)
                NotificationCenter.default.post(name: .voiceInputLevel, object: level)

                let now = Date()
                if self.verboseAudioLogs, now.timeIntervalSince(self.lastLevelLogAt) > 0.2 {
                    self.lastLevelLogAt = now
                    print(String(format: "🎚️ [Mic] level=%.3f rms=%.5f", Double(level), Double(rms)))
                }
            }
        }
        hasInstalledTap = true

        audioEngine.prepare()

        // 尝试启动音频引擎 - 如果没有麦克风权限,这里会失败
        do {
            try audioEngine.start()
            print("✅ [SpeechRecognizer] 音频引擎已启动")
        } catch {
            print("❌ [SpeechRecognizer] 音频引擎启动失败: \(error.localizedDescription)")
            // 清理已安装的 tap
            if hasInstalledTap {
                inputNode.removeTap(onBus: 0)
                hasInstalledTap = false
            }
            throw RecognitionError.audioEngineStartFailed(underlyingMessage: error.localizedDescription)
        }

        // 开始识别
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                self.latestTranscription = text
                NotificationCenter.default.post(name: .voicePartialTranscription, object: text)
                print("📝 [SpeechRecognizer] 识别中: \(text)")
                DispatchQueue.main.async {
                    self.recognizedText = text
                }

                if result.isFinal {
                    print("✅ [SpeechRecognizer] 识别完成")
                    self.finishRecognition(finalText: text, error: nil)
                }
            }

            if let error = error {
                let currentText = self.latestTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
                if !currentText.isEmpty {
                    print("⚠️  [SpeechRecognizer] 收到错误但已有文本，按成功处理: \(error.localizedDescription)")
                    self.finishRecognition(finalText: currentText, error: nil)
                } else if error.localizedDescription == "No speech detected" {
                    // 用户可能说话很短，给一次宽松提示
                    print("⚠️  [SpeechRecognizer] 未检测到语音")
                    self.finishRecognition(finalText: nil, error: RecognitionError.noSpeechDetected)
                } else {
                    print("❌ [SpeechRecognizer] 识别错误: \(error.localizedDescription)")
                    self.finishRecognition(finalText: nil, error: error)
                }
            }
        }

        isRecording = true
        print("✅ [SpeechRecognizer] 录音已开始")
    }

    // MARK: - 停止录音

    func stopRecording() {
        guard isRecording else { return }
        print("⏹️ [SpeechRecognizer] stopRecording 被调用")

        if audioEngine.isRunning {
            audioEngine.stop()
            print("🛑 [SpeechRecognizer] audioEngine 已停止")
        }
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
            print("🧹 [SpeechRecognizer] input tap 已移除")
        }

        // 关键：结束音频输入，让识别任务输出最终结果；不要立即 cancel
        recognitionRequest?.endAudio()
        print("📦 [SpeechRecognizer] 已 endAudio，等待最终识别结果")

        isRecording = false
    }

    func cancelRecognition() {
        print("⛔️ [SpeechRecognizer] cancelRecognition 被调用")
        if audioEngine.isRunning {
            audioEngine.stop()
            print("🛑 [SpeechRecognizer] audioEngine 已停止")
        }
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
            print("🧹 [SpeechRecognizer] input tap 已移除")
        }
        recognitionRequest?.endAudio()

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        onFinalResult = nil
        latestTranscription = ""
        isRecording = false
        print("✅ [SpeechRecognizer] cancelRecognition 清理完成")
    }

    private func finishRecognition(finalText: String?, error: Error?) {
        print("🏁 [SpeechRecognizer] finishRecognition finalTextLen=\(finalText?.count ?? 0) error=\(error?.localizedDescription ?? "nil")")
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        recognitionRequest?.endAudio()

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        let callback = onFinalResult
        onFinalResult = nil
        isRecording = false

        DispatchQueue.main.async {
            callback?(finalText, error)
        }
    }

    // MARK: - 错误类型

    enum RecognitionError: LocalizedError {
        case notAuthorized
        case cannotCreateRequest
        case recognizerUnavailable
        case noSpeechDetected
        case microphoneAccessDenied
        case audioEngineStartFailed(underlyingMessage: String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "未获得语音识别权限，请在系统设置中允许 Typevoise 使用语音识别。"
            case .cannotCreateRequest:
                return "语音识别暂时无法启动，请关闭后重试。"
            case .recognizerUnavailable:
                return "当前语音识别服务暂时不可用，请稍后再试。"
            case .noSpeechDetected:
                return "没有听清你刚才说的话，请靠近麦克风并连续说 1-2 秒后再试。"
            case .microphoneAccessDenied:
                return "未获得麦克风权限，请在系统设置中允许 Typevoise 访问麦克风。"
            case .audioEngineStartFailed(let underlyingMessage):
                if underlyingMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return "录音启动失败，请检查麦克风权限、输入设备状态后再试一次。"
                }
                return "录音启动失败，请检查麦克风权限、输入设备状态后再试一次。\n\n系统信息：\(underlyingMessage)"
            }
        }
    }
}

extension Notification.Name {
    static let voicePartialTranscription = Notification.Name("voicePartialTranscription")
    static let voiceInputLevel = Notification.Name("voiceInputLevel")
}
