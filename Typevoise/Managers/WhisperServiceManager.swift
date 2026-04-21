import Foundation
import Combine

/// Whisper 服务管理器 - 管理 Python 进程的启动、停止和状态监控
@MainActor
class WhisperServiceManager: ObservableObject {
    static let shared = WhisperServiceManager()

    @Published var isRunning = false
    @Published var serviceStatus: ServiceStatus = .stopped

    private var process: Process?
    private let serviceURL = URL(string: "http://127.0.0.1:5001")!

    enum ServiceStatus {
        case stopped
        case starting
        case running
        case stopping
        case error(String)

        var description: String {
            switch self {
            case .stopped: return "已停止"
            case .starting: return "启动中..."
            case .running: return "运行中"
            case .stopping: return "停止中..."
            case .error(let message): return "错误: \(message)"
            }
        }
    }

    private init() {
        // 启动时检测服务状态
        Task {
            await checkServiceStatus()
        }
    }

    // MARK: - 服务控制

    /// 启动 Whisper 服务
    func startService() async throws {
        guard !isRunning else {
            print("⚠️ [WhisperServiceManager] 服务已在运行")
            return
        }

        serviceStatus = .starting
        print("🚀 [WhisperServiceManager] 启动 Whisper 服务")

        // 获取 whisper-service 路径
        guard let servicePath = getServicePath() else {
            let error = "找不到 whisper-service 目录"
            serviceStatus = .error(error)
            throw ServiceError.serviceNotFound
        }

        print("📁 [WhisperServiceManager] 服务路径: \(servicePath)")

        // 创建进程
        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: servicePath)

        // 查找 Python 可执行文件
        let pythonPath = findPython(in: servicePath)
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["server.py"]

        // 设置环境变量
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"] = "1"
        process.environment = environment

        // 重定向输出到日志文件
        let logPath = servicePath + "/whisper.log"
        let logFile = FileHandle(forWritingAtPath: logPath) ?? FileHandle.nullDevice
        process.standardOutput = logFile
        process.standardError = logFile

        // 设置终止处理
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                self?.handleProcessTermination(exitCode: process.terminationStatus)
            }
        }

        do {
            try process.run()
            self.process = process
            print("✅ [WhisperServiceManager] 进程已启动 (PID: \(process.processIdentifier))")

            // 等待服务就绪
            try await waitForServiceReady()

            isRunning = true
            serviceStatus = .running
            print("✅ [WhisperServiceManager] 服务启动成功")
        } catch {
            serviceStatus = .error(error.localizedDescription)
            print("❌ [WhisperServiceManager] 启动失败: \(error)")
            throw error
        }
    }

    /// 停止 Whisper 服务
    func stopService() async {
        serviceStatus = .stopping
        print("⏹️ [WhisperServiceManager] 停止 Whisper 服务")

        // 方法 1: 通过 HTTP 请求让服务自己关闭
        let shutdownSuccess = await shutdownViaHTTP()

        if !shutdownSuccess {
            // 方法 2: 如果有进程引用，优雅停止
            if let process = process, process.isRunning {
                print("📍 [WhisperServiceManager] 停止管理的进程 (PID: \(process.processIdentifier))")
                process.terminate()

                // 等待最多 5 秒
                for _ in 0..<50 {
                    if !process.isRunning {
                        break
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
                }

                // 如果还在运行，强制杀死
                if process.isRunning {
                    print("⚠️ [WhisperServiceManager] 优雅停止超时，强制终止")
                    process.interrupt()
                }

                self.process = nil
            }

            // 方法 3: 使用 shell 命令杀死进程
            await killWhisperProcesses()
        }

        // 等待服务真正停止
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 秒

        // 重新检测状态确认是否真的停止了
        let actuallyRunning = await checkServiceStatus()

        if actuallyRunning {
            print("⚠️ [WhisperServiceManager] 服务仍在运行，停止失败")
            serviceStatus = .error("停止失败，服务仍在运行")
        } else {
            print("✅ [WhisperServiceManager] 服务已停止")
        }
    }

    /// 通过 HTTP 请求关闭服务
    private func shutdownViaHTTP() async -> Bool {
        print("🌐 [WhisperServiceManager] 尝试通过 HTTP 关闭服务...")

        do {
            let url = serviceURL.appendingPathComponent("shutdown")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 5

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ [WhisperServiceManager] HTTP 关闭失败")
                return false
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String {
                print("✅ [WhisperServiceManager] 服务响应: \(status)")
                return true
            }

            return false
        } catch {
            print("❌ [WhisperServiceManager] HTTP 关闭请求失败: \(error)")
            return false
        }
    }

    /// 查找并杀死所有 Whisper 服务进程
    private func killWhisperProcesses() async {
        print("🔍 [WhisperServiceManager] 查找 Whisper 进程...")

        // 使用 shell 脚本执行 pkill
        let script = """
        #!/bin/bash
        pkill -f "server.py"
        exit $?
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let exitCode = process.terminationStatus
            print("📍 [WhisperServiceManager] 停止脚本退出码: \(exitCode)")

            if exitCode == 0 {
                print("✅ [WhisperServiceManager] 已杀死 Whisper 进程")
            } else if exitCode == 1 {
                print("⚠️ [WhisperServiceManager] 没有找到匹配的进程")
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                print("❌ [WhisperServiceManager] 停止失败: \(errorOutput)")
            }
        } catch {
            print("❌ [WhisperServiceManager] 执行停止脚本失败: \(error)")
        }

        // 等待一下确保进程被杀死
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
    }

    /// 检查服务状态
    func checkServiceStatus() async -> Bool {
        do {
            let (data, response) = try await URLSession.shared.data(from: serviceURL.appendingPathComponent("health"))

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                isRunning = false
                serviceStatus = .stopped
                return false
            }

            let healthResponse = try JSONDecoder().decode(HealthResponse.self, from: data)
            isRunning = healthResponse.status == "ok"
            serviceStatus = isRunning ? .running : .stopped

            print("✅ [WhisperServiceManager] 服务状态: \(healthResponse.status), 模型: \(healthResponse.model)")
            return isRunning
        } catch {
            isRunning = false
            serviceStatus = .stopped
            return false
        }
    }

    // MARK: - 私有方法

    private func getServicePath() -> String? {
        // 1. 优先查找项目内的 whisper-service（子模块）
        if let bundlePath = Bundle.main.bundlePath as NSString? {
            let projectRoot = (bundlePath.deletingLastPathComponent as NSString).deletingLastPathComponent as NSString
            let servicePath = projectRoot.appendingPathComponent("whisper-service")
            if FileManager.default.fileExists(atPath: servicePath) {
                return servicePath
            }
        }

        // 2. 查找 App Bundle 内的服务（生产环境）
        if let bundlePath = Bundle.main.resourcePath {
            let servicePath = bundlePath + "/whisper-service"
            if FileManager.default.fileExists(atPath: servicePath) {
                return servicePath
            }
        }

        return nil
    }

    private func findPython(in servicePath: String) -> String {
        // 优先使用虚拟环境的 Python
        let venvPython = servicePath + "/venv/bin/python3"
        if FileManager.default.fileExists(atPath: venvPython) {
            return venvPython
        }

        // 使用系统 Python
        return "/usr/bin/python3"
    }

    private func waitForServiceReady() async throws {
        print("⏳ [WhisperServiceManager] 等待服务就绪...")

        for attempt in 1...30 {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 秒

            if await checkServiceStatus() {
                print("✅ [WhisperServiceManager] 服务就绪 (尝试 \(attempt) 次)")
                return
            }

            print("⏳ [WhisperServiceManager] 等待中... (\(attempt)/30)")
        }

        throw ServiceError.startupTimeout
    }

    private func handleProcessTermination(exitCode: Int32) {
        print("⚠️ [WhisperServiceManager] 进程终止 (退出码: \(exitCode))")

        isRunning = false
        process = nil

        if exitCode != 0 {
            serviceStatus = .error("进程异常退出 (退出码: \(exitCode))")
        } else {
            serviceStatus = .stopped
        }
    }

    // MARK: - 错误类型

    enum ServiceError: LocalizedError {
        case serviceNotFound
        case startupTimeout
        case pythonNotFound

        var errorDescription: String? {
            switch self {
            case .serviceNotFound:
                return "找不到 Whisper 服务文件"
            case .startupTimeout:
                return "服务启动超时"
            case .pythonNotFound:
                return "找不到 Python 运行环境"
            }
        }
    }
}
