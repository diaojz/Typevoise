import SwiftUI
import AppKit

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
        HStack(spacing: 24) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("历史记录")
                        .font(.system(size: 38, weight: .bold))
                    Text("查看、搜索、复制和管理所有转录记录。")
                        .font(.title3)
                        .foregroundStyle(.secondary)

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
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    HStack {
                        Text("\(filteredRecords.count) 条记录")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !historyManager.records.isEmpty {
                            Button(role: .destructive, action: { showClearAllAlert = true }) {
                                Label("清空", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(28)

                if filteredRecords.isEmpty {
                    emptyView
                } else {
                    List(selection: $selectedRecord) {
                        ForEach(filteredRecords) { record in
                            HistoryRowView(record: record, isSelected: selectedRecord?.id == record.id)
                                .tag(record)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
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
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                }
            }
            .frame(minWidth: 390, maxWidth: 430, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )

            Group {
                if let record = selectedRecord {
                    DetailView(record: record)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 42))
                            .foregroundStyle(.secondary)
                        Text("选择一条记录查看详情")
                            .font(.title3.weight(.semibold))
                        Text("右侧会显示润色文本与原始文本，你可以随时复制需要的内容。")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            ensureSelection()
        }
        .onChange(of: filteredRecords) { _ in
            ensureSelection()
        }
        .alert("删除记录", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let record = selectedRecord {
                    historyManager.deleteRecord(record)
                    selectedRecord = filteredRecords.first(where: { $0.id != record.id }) ?? filteredRecords.first
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
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text(searchText.isEmpty ? "暂无历史记录" : "未找到匹配的记录")
                .font(.headline)
                .foregroundColor(.secondary)
            if searchText.isEmpty {
                Text("使用快捷键录音后，记录会自动保存在这里。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func ensureSelection() {
        guard selectedRecord == nil else { return }
        selectedRecord = filteredRecords.first
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct HistoryRowView: View {
    let record: TranscriptionRecord
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(record.timeAgo)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : Color(NSColor.secondaryLabelColor))
                Spacer()
                Text(record.formattedDate)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : Color(NSColor.tertiaryLabelColor))
            }

            Text(record.polishedText)
                .font(.headline)
                .lineLimit(2)
                .foregroundColor(isSelected ? .white : Color(NSColor.labelColor))

            if record.originalText != record.polishedText {
                Text(record.originalText)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .white.opacity(0.85) : Color(NSColor.secondaryLabelColor))
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.33, green: 0.42, blue: 0.62),
                                    Color(red: 0.38, green: 0.52, blue: 0.72),
                                    Color(red: 0.45, green: 0.60, blue: 0.74)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.purple.opacity(0.3), radius: 12, x: 0, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                }
            }
        )
    }
}

struct DetailView: View {
    let record: TranscriptionRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Label(record.formattedDate, systemImage: "clock")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                detailSection(title: "润色文本", text: record.polishedText, secondary: false)
                detailSection(title: "原始文本", text: record.originalText, secondary: true)
                Spacer(minLength: 0)
            }
            .padding(28)
        }
    }

    private func detailSection(title: String, text: String, secondary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3.weight(.bold))
                Spacer()
                Button(action: {
                    copyToClipboard(text)
                }) {
                    Label("复制", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }

            Text(text)
                .font(.body)
                .foregroundColor(secondary ? Color(NSColor.secondaryLabelColor) : Color(NSColor.labelColor))
                .textSelection(.enabled)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

#Preview {
    HistoryView()
}
