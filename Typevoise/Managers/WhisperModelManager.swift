import Foundation
import Combine

/// Whisper 模型管理器 - 管理模型的下载、删除和切换
@MainActor
class WhisperModelManager: ObservableObject {
    static let shared = WhisperModelManager()

    @Published var availableModels: [WhisperModel] = []
    @Published var currentModel: String = "base"
    @Published var downloadProgress: [String: Double] = [:] // 模型名 -> 下载进度

    private let modelsDirectory: URL
    private let userDefaults = UserDefaults.standard

    // 模型信息
    struct WhisperModel: Identifiable {
        let id: String
        let name: String
        let size: String
        let accuracy: String
        let speed: String
        let description: String
        var isDownloaded: Bool
        var isDownloading: Bool = false

        static let allModels = [
            WhisperModel(
                id: "tiny",
                name: "Tiny",
                size: "39 MB",
                accuracy: "较低",
                speed: "最快",
                description: "最小模型，速度最快但准确率较低",
                isDownloaded: false
            ),
            WhisperModel(
                id: "base",
                name: "Base",
                size: "74 MB",
                accuracy: "中等",
                speed: "快",
                description: "平衡速度和准确率，推荐日常使用",
                isDownloaded: false
            ),
            WhisperModel(
                id: "small",
                name: "Small",
                size: "244 MB",
                accuracy: "良好",
                speed: "中等",
                description: "更高准确率，适合重要场景",
                isDownloaded: false
            ),
            WhisperModel(
                id: "medium",
                name: "Medium",
                size: "769 MB",
                accuracy: "很好",
                speed: "较慢",
                description: "高准确率，需要更多时间",
                isDownloaded: false
            ),
            WhisperModel(
                id: "large",
                name: "Large",
                size: "1.5 GB",
                accuracy: "最高",
                speed: "最慢",
                description: "最高准确率，适合专业场景",
                isDownloaded: false
            )
        ]
    }

    private init() {
        // 模型存储路径：~/Library/Application Support/Typevoise/whisper-models/
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let typevoiseDir = appSupport.appendingPathComponent("Typevoise")
        modelsDirectory = typevoiseDir.appendingPathComponent("whisper-models")

        // 创建目录
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        // 加载当前模型设置
        currentModel = userDefaults.string(forKey: "whisperModel") ?? "base"

        // 扫描已下载的模型
        refreshModels()
    }

    // MARK: - 模型管理

    /// 刷新模型列表
    func refreshModels() {
        availableModels = WhisperModel.allModels.map { model in
            var updatedModel = model
            updatedModel.isDownloaded = isModelDownloaded(model.id)
            updatedModel.isDownloading = downloadProgress[model.id] != nil
            return updatedModel
        }
    }

    /// 检查模型是否已下载
    func isModelDownloaded(_ modelId: String) -> Bool {
        // faster-whisper 使用 Hugging Face 格式：Systran/faster-whisper-{model}
        let huggingfaceCache = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
        let modelName = "models--Systran--faster-whisper-\(modelId)"
        let modelPath = huggingfaceCache.appendingPathComponent(modelName)

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: modelPath.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    /// 下载模型
    func downloadModel(_ modelId: String) async throws {
        guard let model = availableModels.first(where: { $0.id == modelId }) else {
            throw ModelError.modelNotFound
        }

        guard !model.isDownloaded else {
            print("⚠️ [WhisperModelManager] 模型已存在: \(modelId)")
            return
        }

        print("📥 [WhisperModelManager] 开始下载模型: \(modelId)")

        // 设置下载状态
        downloadProgress[modelId] = 0.0
        refreshModels()

        // 使用 faster-whisper 的下载机制
        // 实际上，faster-whisper 会在首次使用时自动下载模型
        // 我们这里模拟下载过程，实际下载由 Python 服务完成

        do {
            // 方案：通过 Python 脚本预下载模型
            try await downloadModelViaPython(modelId)

            // 下载完成
            downloadProgress.removeValue(forKey: modelId)
            refreshModels()

            print("✅ [WhisperModelManager] 模型下载完成: \(modelId)")
        } catch {
            downloadProgress.removeValue(forKey: modelId)
            refreshModels()
            throw error
        }
    }

    /// 通过 Python 脚本下载模型
    private func downloadModelViaPython(_ modelId: String) async throws {
        let script = """
        import sys
        import os
        from faster_whisper import WhisperModel
        from huggingface_hub import snapshot_download
        from tqdm import tqdm

        model_name = sys.argv[1]
        repo_id = f"Systran/faster-whisper-{model_name}"

        print("PROGRESS:0")
        sys.stdout.flush()

        try:
            # 使用 huggingface_hub 下载，可以获取进度
            print(f"开始下载模型: {model_name}")
            sys.stdout.flush()

            # 下载模型文件
            cache_dir = snapshot_download(
                repo_id=repo_id,
                cache_dir=None,  # 使用默认缓存
                resume_download=True
            )

            print("PROGRESS:80")
            sys.stdout.flush()

            # 加载模型验证
            print(f"验证模型: {model_name}")
            sys.stdout.flush()
            model = WhisperModel(model_name, device="cpu", compute_type="int8")

            print("PROGRESS:100")
            sys.stdout.flush()
            print(f"模型下载完成: {model_name}")

        except Exception as e:
            print(f"ERROR: {str(e)}", file=sys.stderr)
            sys.exit(1)
        """

        // 创建临时脚本文件
        let tempScript = FileManager.default.temporaryDirectory.appendingPathComponent("download_model.py")
        try script.write(to: tempScript, atomically: true, encoding: .utf8)

        // 使用 bash 激活虚拟环境并执行
        let venvPath = "/Users/diaoye/Documents/BD/App Store/app/whisper-service/venv"
        let bashScript = """
        source "\(venvPath)/bin/activate"
        python3 "\(tempScript.path)" "\(modelId)"
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", bashScript]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // 监控输出更新进度
        let outputHandle = outputPipe.fileHandleForReading
        outputHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                let lines = output.components(separatedBy: .newlines)
                for line in lines where !line.isEmpty {
                    print("📦 [Download] \(line)")

                    // 解析进度
                    if line.hasPrefix("PROGRESS:") {
                        if let progressStr = line.components(separatedBy: ":").last,
                           let progress = Double(progressStr) {
                            Task { @MainActor in
                                self?.downloadProgress[modelId] = progress / 100.0
                            }
                        }
                    }
                }
            }
        }

        try process.run()
        process.waitUntilExit()

        outputHandle.readabilityHandler = nil

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            print("❌ [WhisperModelManager] 下载失败: \(errorOutput)")
            throw ModelError.downloadFailed(errorOutput)
        }

        // 清理临时文件
        try? FileManager.default.removeItem(at: tempScript)
    }

    /// 删除模型
    func deleteModel(_ modelId: String) throws {
        guard modelId != currentModel else {
            throw ModelError.cannotDeleteCurrentModel
        }

        // 删除 Hugging Face cache 中的模型
        let huggingfaceCache = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
        let modelName = "models--Systran--faster-whisper-\(modelId)"
        let modelPath = huggingfaceCache.appendingPathComponent(modelName)

        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw ModelError.modelNotFound
        }

        try FileManager.default.removeItem(at: modelPath)
        print("✅ [WhisperModelManager] 模型已删除: \(modelId)")

        refreshModels()
    }

    /// 切换模型
    func switchModel(_ modelId: String) throws {
        guard let model = availableModels.first(where: { $0.id == modelId }) else {
            throw ModelError.modelNotFound
        }

        guard model.isDownloaded else {
            throw ModelError.modelNotDownloaded
        }

        currentModel = modelId
        userDefaults.set(modelId, forKey: "whisperModel")

        print("✅ [WhisperModelManager] 已切换到模型: \(modelId)")

        // 通知需要重启服务
        NotificationCenter.default.post(name: .whisperModelChanged, object: modelId)
    }

    /// 获取模型存储路径（已废弃，faster-whisper 使用 Hugging Face cache）
    func getModelPath(_ modelId: String) -> String {
        // 返回 Hugging Face cache 路径
        let huggingfaceCache = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
        let modelName = "models--Systran--faster-whisper-\(modelId)"
        return huggingfaceCache.appendingPathComponent(modelName).path
    }

    // MARK: - 辅助方法

    private func findPython() -> String {
        // 优先使用 whisper-service 的虚拟环境（使用绝对路径避免符号链接问题）
        let venvPython = "/Users/diaoye/Documents/BD/App Store/app/whisper-service/venv/bin/python3"
        if FileManager.default.fileExists(atPath: venvPython) {
            // 解析符号链接到实际路径
            if let resolvedPath = try? FileManager.default.destinationOfSymbolicLink(atPath: venvPython) {
                // 如果是相对路径，转换为绝对路径
                if resolvedPath.hasPrefix("/") {
                    return resolvedPath
                } else {
                    let venvDir = "/Users/diaoye/Documents/BD/App Store/app/whisper-service/venv/bin"
                    return (venvDir as NSString).appendingPathComponent(resolvedPath)
                }
            }
            return venvPython
        }

        // 使用 Homebrew Python
        let brewPython = "/opt/homebrew/bin/python3"
        if FileManager.default.fileExists(atPath: brewPython) {
            return brewPython
        }

        // 使用系统 Python
        return "/usr/bin/python3"
    }

    // MARK: - 错误类型

    enum ModelError: LocalizedError {
        case modelNotFound
        case modelNotDownloaded
        case downloadFailed(String)
        case cannotDeleteCurrentModel

        var errorDescription: String? {
            switch self {
            case .modelNotFound:
                return "模型不存在"
            case .modelNotDownloaded:
                return "模型未下载"
            case .downloadFailed(let message):
                return "下载失败: \(message)"
            case .cannotDeleteCurrentModel:
                return "无法删除当前使用的模型"
            }
        }
    }
}

// MARK: - 通知

extension Notification.Name {
    static let whisperModelChanged = Notification.Name("whisperModelChanged")
}
