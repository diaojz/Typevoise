import Foundation
import Combine

class HistoryManager: ObservableObject {
    static let shared = HistoryManager()

    @Published private(set) var records: [TranscriptionRecord] = []

    private let fileURL: URL

    private init() {
        // 获取应用支持目录
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("Typevoise", isDirectory: true)

        // 确保目录存在
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        // 历史记录文件路径
        fileURL = appDirectory.appendingPathComponent("history.json")

        // 加载历史记录
        loadRecords()
    }

    func addRecord(originalText: String, polishedText: String) {
        let record = TranscriptionRecord(originalText: originalText, polishedText: polishedText)
        records.insert(record, at: 0) // 最新的记录放在最前面
        saveRecords()
        print("📝 [HistoryManager] 已保存记录: \(record.id)")
    }

    func deleteRecord(_ record: TranscriptionRecord) {
        records.removeAll { $0.id == record.id }
        saveRecords()
        print("🗑️ [HistoryManager] 已删除记录: \(record.id)")
    }

    func deleteAllRecords() {
        records.removeAll()
        saveRecords()
        print("🗑️ [HistoryManager] 已清空所有记录")
    }

    private func loadRecords() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("📂 [HistoryManager] 历史记录文件不存在，使用空列表")
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            records = try JSONDecoder().decode([TranscriptionRecord].self, from: data)
            print("✅ [HistoryManager] 已加载 \(records.count) 条历史记录")
        } catch {
            print("❌ [HistoryManager] 加载历史记录失败: \(error.localizedDescription)")
        }
    }

    private func saveRecords() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: .atomic)
            print("💾 [HistoryManager] 已保存 \(records.count) 条历史记录")
        } catch {
            print("❌ [HistoryManager] 保存历史记录失败: \(error.localizedDescription)")
        }
    }
}
