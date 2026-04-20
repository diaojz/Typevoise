import Foundation

class ClaudeService {
    static let shared = ClaudeService()

    private init() {}

    func polishText(_ text: String, progressHandler: ((Double) -> Void)? = nil) async throws -> String {
        guard let apiKey = SettingsManager.shared.claudeAPIKey else {
            throw ClaudeError.missingAPIKey
        }

        let baseURL = SettingsManager.shared.claudeBaseURL
        guard let url = URL(string: "\(baseURL)/v1/messages") else {
            throw ClaudeError.invalidURL
        }

        // 初始进度
        progressHandler?(0.1)

        let prompt = """
        你是语音转文字润色助手。用户通过语音输入了以下内容：

        "\(text)"

        请：
        1. 去除口头禅（"嗯"、"那个"、"就是"、"然后"等）
        2. 修正语法错误
        3. 优化表达（保持原意，提升专业度）
        4. 保留用户的语气和风格

        直接输出润色后的文本，不要解释。
        """

        let models = ["claude-opus-4-6", "claude-sonnet-4-6", "claude-3-5-sonnet-latest"]
        let authModes: [AuthMode] = [.bearer, .xApiKey]

        print("🌐 [Claude] 请求地址: \(url.absoluteString)")

        var lastError: Error?

        for model in models {
            for authMode in authModes {
                do {
                    print("🤖 [Claude] 尝试模型: \(model)，鉴权方式: \(authMode.debugName)")
                    progressHandler?(0.3)
                    return try await sendRequest(url: url, apiKey: apiKey, model: model, prompt: prompt, authMode: authMode, progressHandler: progressHandler)
                } catch let error as ClaudeError {
                    lastError = error
                    switch error {
                    case .apiError(_, let message):
                        if message.contains("model_not_found") || message.contains("无可用渠道") {
                            print("⚠️ [Claude] 模型不可用，尝试下一个模型")
                            break
                        }
                        if authMode == .bearer, shouldFallbackToXApiKey(message: message) {
                            print("⚠️ [Claude] Bearer 未通过，回退到 x-api-key")
                            continue
                        }
                        throw error
                    default:
                        throw error
                    }
                } catch {
                    lastError = error
                    throw error
                }
            }
        }

        throw lastError ?? ClaudeError.invalidResponse
    }

    private func sendRequest(url: URL, apiKey: String, model: String, prompt: String, authMode: AuthMode, progressHandler: ((Double) -> Void)? = nil) async throws -> String {
        progressHandler?(0.4)
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        authMode.apply(apiKey: apiKey, to: &request)
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        progressHandler?(0.5)
        let (data, response) = try await URLSession.shared.data(for: request)
        progressHandler?(0.8)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""
        print("📥 [Claude] 响应状态码: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ClaudeError.apiError(
                statusCode: httpResponse.statusCode,
                message: extractErrorMessage(from: data) ?? fallbackText(responseText, defaultValue: "Unknown error")
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeError.apiError(
                statusCode: httpResponse.statusCode,
                message: "无法解析响应内容：\(fallbackText(responseText, defaultValue: "<empty>"))"
            )
        }

        guard let text = extractText(from: json) else {
            let apiMessage = extractErrorMessage(from: data)
            let stopReason = json["stop_reason"] as? String ?? "unknown"
            throw ClaudeError.apiError(
                statusCode: httpResponse.statusCode,
                message: apiMessage ?? "响应成功但未返回可用文本（stop_reason: \(stopReason)）"
            )
        }

        progressHandler?(1.0)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractText(from json: [String: Any]) -> String? {
        if let content = json["content"] as? [[String: Any]] {
            let texts = content.compactMap(extractText(from:))

            let mergedText = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !mergedText.isEmpty {
                return mergedText
            }
        }

        if let text = json["text"] as? String,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }

        if let value = json["value"] as? String,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }

        if let content = json["content"] as? String,
           !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return content
        }

        if let message = json["message"] as? [String: Any],
           let text = extractText(from: message) {
            return text
        }

        if let output = json["output"] as? [[String: Any]] {
            let texts = output.compactMap(extractText(from:))
            let mergedText = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !mergedText.isEmpty {
                return mergedText
            }
        }

        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first {
            if let message = firstChoice["message"] as? [String: Any],
               let text = extractText(from: message) {
                return text
            }

            if let text = firstChoice["text"] as? String,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text
            }
        }

        if let data = json["data"] as? [String: Any] {
            return extractText(from: data)
        }

        return nil
    }

    private func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let error = json["error"] as? [String: Any] {
            if let message = error["message"] as? String {
                return message
            }
            if let details = error["details"] as? String {
                return details
            }
        }

        if let message = json["message"] as? String {
            return message
        }

        if let detail = json["detail"] as? String {
            return detail
        }

        return nil
    }

    private func fallbackText(_ text: String, defaultValue: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultValue : trimmed
    }

    private func shouldFallbackToXApiKey(message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.contains("unauthorized") ||
        lowercased.contains("forbidden") ||
        lowercased.contains("invalid api key") ||
        lowercased.contains("authentication") ||
        lowercased.contains("error code: 1010")
    }

    private enum AuthMode {
        case bearer
        case xApiKey

        var debugName: String {
            switch self {
            case .bearer:
                return "Bearer"
            case .xApiKey:
                return "x-api-key"
            }
        }

        func apply(apiKey: String, to request: inout URLRequest) {
            switch self {
            case .bearer:
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            case .xApiKey:
                request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            }
        }
    }

    enum ClaudeError: LocalizedError {
        case missingAPIKey
        case invalidURL
        case invalidResponse
        case apiError(statusCode: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "未配置 Claude API Key"
            case .invalidURL:
                return "无效的 API URL"
            case .invalidResponse:
                return "无效的 API 响应"
            case .apiError(let statusCode, let message):
                return "API 错误 (\(statusCode)): \(message)"
            }
        }
    }
}
