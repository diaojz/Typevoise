import Foundation

class SettingsManager {
    static let shared = SettingsManager()

    private init() {}

    // MARK: - Claude API 配置

    var claudeAPIKey: String? {
        get {
            let key = UserDefaults.standard.string(forKey: "claudeAPIKey")
            if key != nil {
                print("✅ [Settings] 读取 API Key 成功")
            } else {
                print("ℹ️ [Settings] 未找到 API Key")
            }
            return key
        }
        set {
            if let value = newValue {
                UserDefaults.standard.set(value, forKey: "claudeAPIKey")
                print("✅ [Settings] 保存 API Key 成功")
            } else {
                UserDefaults.standard.removeObject(forKey: "claudeAPIKey")
                print("🗑️ [Settings] 删除 API Key")
            }
        }
    }

    var claudeBaseURL: String {
        get { UserDefaults.standard.string(forKey: "claudeBaseURL") ?? "https://api.anthropic.com" }
        set { UserDefaults.standard.set(newValue, forKey: "claudeBaseURL") }
    }

    // MARK: - 快捷键配置

    var hotkeyKeyCode: UInt32 {
        get { UInt32(UserDefaults.standard.integer(forKey: "hotkeyKeyCode")) }
        set { UserDefaults.standard.set(Int(newValue), forKey: "hotkeyKeyCode") }
    }

    var hotkeyModifiers: UInt32 {
        get { UInt32(UserDefaults.standard.integer(forKey: "hotkeyModifiers")) }
        set { UserDefaults.standard.set(Int(newValue), forKey: "hotkeyModifiers") }
    }

    // MARK: - 自动粘贴配置

    var autoPasteEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "autoPasteEnabled") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "autoPasteEnabled")
        }
        set { UserDefaults.standard.set(newValue, forKey: "autoPasteEnabled") }
    }

    // MARK: - 麦克风设备配置

    var selectedMicrophoneID: String? {
        get { UserDefaults.standard.string(forKey: "selectedMicrophoneID") }
        set { UserDefaults.standard.set(newValue, forKey: "selectedMicrophoneID") }
    }

    // MARK: - 识别引擎配置

    var recognitionEngine: String {
        get { UserDefaults.standard.string(forKey: "recognitionEngine") ?? "native" }
        set { UserDefaults.standard.set(newValue, forKey: "recognitionEngine") }
    }

    // MARK: - 首次启动标记

    var hasCompletedSetup: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedSetup") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedSetup") }
    }

    // MARK: - 配置验证

    func isConfigured() -> Bool {
        return claudeAPIKey != nil && hotkeyKeyCode != 0
    }
}
