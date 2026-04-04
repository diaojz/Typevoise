import Foundation

class ClaudeService {
    static let shared = ClaudeService()

    private init() {}

    func polishText(_ text: String) async throws -> String {
        guard let apiKey = SettingsManager.shared.claudeAPIKey else {
            throw ClaudeError.missingAPIKey
        }

        let baseURL = SettingsManager.shared.claudeBaseURL
        guard let url = URL(string: "\(baseURL)/v1/messages") else {
            throw ClaudeError.invalidURL
        }

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

        // 主模型 + 兼容回退（适配中转 API 的可用渠道）
        let models = ["claude-opus-4-6", "claude-sonnet-4-6", "claude-3-5-sonnet-latest"]

        print("🌐 [Claude] 请求地址: \(url.absoluteString)")

        var lastError: Error?

        for model in models {
            do {
                print("🤖 [Claude] 尝试模型: \(model)")
                return try await sendRequest(url: url, apiKey: apiKey, model: model, prompt: prompt)
            } catch let error as ClaudeError {
                lastError = error
                switch error {
                case .apiError(_, let message):
                    if message.contains("model_not_found") || message.contains("无可用渠道") {
                        print("⚠️ [Claude] 模型不可用，尝试下一个模型")
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

        throw lastError ?? ClaudeError.invalidResponse
    }

    private func sendRequest(url: URL, apiKey: String, model: String, prompt: String) async throws -> String {
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
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw ClaudeError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
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
