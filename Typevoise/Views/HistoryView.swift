import SwiftUI

struct HistoryView: View {
    @StateObject private var historyManager = HistoryManager.shared
    @State private var selectedRecord: TranscriptionRecord?
    @State private var showDeleteAlert = false
    @State private var showClearAllAlert = false
    @State private var searchText = ""

    var filteredRecords: [TranscriptionRecord] {
        if searchText.isEmpty {
            return historyManager.records
        } else {
            return historyManager.records.filter {
                $0.originalText.localizedCaseInsensitiveContains(searchText) ||
                $0.polishedText.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索历史记录", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .padding()

                Divider()

                // 历史记录列表
                if filteredRecords.isEmpty {
                    emptyView
                } else {
                    List(selection: $selectedRecord) {
                        ForEach(filteredRecords) { record in
                            HistoryRowView(record: record)
                                .tag(record)
                                .contextMenu {
                                    Button("复制原文") {
                                        copyToClipboard(record.originalText)
                                    }
                                    Button("复制润色文本") {
                                        copyToClipboard(record.polishedText)
                                    }
                                    Divider()
                                    Button("删除", role: .destructive) {
                                        selectedRecord = record
                                        showDeleteAlert = true
                                    }
                                }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle("历史记录")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    HStack {
                        Text("\(filteredRecords.count) 条记录")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if !historyManager.records.isEmpty {
                            Button(action: { showClearAllAlert = true }) {
                                Label("清空", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            // 详情视图
            if let record = selectedRecord {
                DetailView(record: record)
            } else {
                Text("选择一条记录查看详情")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .alert("删除记录", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let record = selectedRecord {
                    historyManager.deleteRecord(record)
                    selectedRecord = nil
                }
            }
        } message: {
            Text("确定要删除这条记录吗？")
        }
        .alert("清空所有记录", isPresented: $showClearAllAlert) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                historyManager.deleteAllRecords()
                selectedRecord = nil
            }
        } message: {
            Text("确定要清空所有历史记录吗？此操作不可恢复。")
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(searchText.isEmpty ? "暂无历史记录" : "未找到匹配的记录")
                .font(.headline)
                .foregroundColor(.secondary)

            if searchText.isEmpty {
                Text("使用快捷键录音后，记录会自动保存在这里")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct HistoryRowView: View {
    let record: TranscriptionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.timeAgo)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(record.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(record.polishedText)
                .font(.body)
                .lineLimit(2)
                .foregroundColor(.primary)

            if record.originalText != record.polishedText {
                Text(record.originalText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DetailView: View {
    let record: TranscriptionRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 时间信息
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text(record.formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Divider()

                // 润色后的文本
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("润色文本")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            copyToClipboard(record.polishedText)
                        }) {
                            Label("复制", systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }

                    Text(record.polishedText)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }

                Divider()

                // 原始文本
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("原始文本")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            copyToClipboard(record.originalText)
                        }) {
                            Label("复制", systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }

                    Text(record.originalText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }

                Spacer()
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

#Preview {
    HistoryView()
}
