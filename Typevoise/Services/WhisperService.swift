import Foundation

/// Whisper 本地服务客户端
class WhisperService {
    private let baseURL = "http://127.0.0.1:5001"

    /// 检查服务是否可用
    func checkHealth() async throws -> Bool {
        let url = URL(string: "\(baseURL)/health")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(HealthResponse.self, from: data)
        return response.status == "ok"
    }

    /// 转录音频文件
    func transcribe(audioURL: URL) async throws -> String {
        let url = URL(string: "\(baseURL)/transcribe")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30

        // 构建 multipart/form-data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)",
                        forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: audioURL)
        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TranscribeResponse.self, from: data)
        return response.text
    }
}

// MARK: - 响应模型

struct HealthResponse: Codable {
    let status: String
    let model: String
}

struct TranscribeResponse: Codable {
    let text: String
    let language: String
}
