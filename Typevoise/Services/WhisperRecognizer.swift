import Foundation
import AVFoundation
import Combine

/// Whisper 语音识别器
@MainActor
class WhisperRecognizer: ObservableObject {
    @Published var isRecording = false
    @Published var recognizedText = ""

    private let audioEngine = AVAudioEngine()
    private let whisperService = WhisperService()
    private var onFinalResult: ((String?, Error?) -> Void)?
    private var recordingURL: URL?
    private var audioFile: AVAudioFile?

    // MARK: - 开始录音

    func startRecording(onFinalResult: @escaping (String?, Error?) -> Void) throws {
        print("🎤 [WhisperRecognizer] 开始录音")
        self.onFinalResult = onFinalResult
        self.recognizedText = ""

        // 保存到固定位置方便查看
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsPath.appendingPathComponent("Typevoise_Recordings")

        // 创建目录
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)

        let tempURL = recordingsDir.appendingPathComponent("recording_\(timestamp).wav")
        self.recordingURL = tempURL
        print("📁 [WhisperRecognizer] 录音文件: \(tempURL.path)")

        do {
            // 获取输入节点
            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            print("🎵 [WhisperRecognizer] 输入格式: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch")

            // 直接使用输入格式创建音频文件（不做转换）
            audioFile = try AVAudioFile(forWriting: tempURL, settings: inputFormat.settings)

            // 安装音频 tap
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                guard let self = self, let audioFile = self.audioFile else { return }
                do {
                    try audioFile.write(from: buffer)
                } catch {
                    print("❌ [WhisperRecognizer] 写入音频失败: \(error)")
                }
            }

            // 启动音频引擎
            try audioEngine.start()
            isRecording = true
            print("✅ [WhisperRecognizer] 录音已开始")
        } catch {
            print("❌ [WhisperRecognizer] 录音启动失败: \(error)")
            throw RecognitionError.audioEngineStartFailed(underlyingMessage: error.localizedDescription)
        }
    }

    // MARK: - 停止录音

    func stopRecording() {
        print("⏹️ [WhisperRecognizer] 停止录音 (isRecording=\(isRecording))")

        guard let audioURL = recordingURL else {
            print("⚠️ [WhisperRecognizer] 录音 URL 为空")
            isRecording = false
            return
        }

        // 立即在后台线程停止音频引擎，避免阻塞主线程
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // 在后台线程执行耗时操作
            await Task.detached(priority: .userInitiated) {
                // 停止音频引擎（可能阻塞）
                await MainActor.run {
                    self.audioEngine.stop()
                    self.audioEngine.inputNode.removeTap(onBus: 0)
                    self.audioFile = nil
                }

                print("📦 [WhisperRecognizer] 录音已停止，开始转录")
            }.value

            // 异步转录
            await self.transcribe(audioURL: audioURL)
        }
    }

    func cancelRecognition() {
        print("⛔️ [WhisperRecognizer] 取消识别")
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        audioFile = nil

        if let audioURL = recordingURL {
            try? FileManager.default.removeItem(at: audioURL)
        }

        recordingURL = nil
        onFinalResult = nil
        isRecording = false
    }

    // MARK: - 转录

    private func transcribe(audioURL: URL) async {
        print("🎵 [WhisperRecognizer] 开始转录: \(audioURL.path)")

        do {
            // 添加 30 秒超时保护
            let text = try await withTimeout(seconds: 30) {
                try await self.whisperService.transcribe(audioURL: audioURL)
            }
            print("✅ [WhisperRecognizer] 转录成功: \(text)")
            print("📁 [WhisperRecognizer] 录音文件已保存: \(audioURL.path)")

            recognizedText = text
            isRecording = false  // 转录完成后才设置为 false

            let callback = onFinalResult
            onFinalResult = nil

            DispatchQueue.main.async {
                callback?(text, nil)
            }
        } catch {
            print("❌ [WhisperRecognizer] 转录失败: \(error)")
            print("📁 [WhisperRecognizer] 录音文件已保存: \(audioURL.path)")

            isRecording = false  // 转录失败也要设置为 false

            let callback = onFinalResult
            onFinalResult = nil

            DispatchQueue.main.async {
                callback?(nil, RecognitionError.whisperServiceUnavailable)
            }
        }

        // 不删除录音文件，保留用于分析
        // try? FileManager.default.removeItem(at: audioURL)
    }

    // MARK: - 超时辅助函数

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw RecognitionError.audioEngineStartFailed(underlyingMessage: "转录超时（\(Int(seconds))秒）")
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    // MARK: - 错误类型

    enum RecognitionError: LocalizedError {
        case audioEngineStartFailed(underlyingMessage: String)
        case whisperServiceUnavailable

        var errorDescription: String? {
            switch self {
            case .audioEngineStartFailed(let underlyingMessage):
                if underlyingMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return "录音启动失败，请检查麦克风权限、输入设备状态后再试一次。"
                }
                return "录音启动失败，请检查麦克风权限、输入设备状态后再试一次。\n\n系统信息：\(underlyingMessage)"
            case .whisperServiceUnavailable:
                return "Whisper 服务不可用，已自动切换到系统识别。\n\n请启动 Whisper 服务：\n./app/whisper-service/start.sh"
            }
        }
    }
}
