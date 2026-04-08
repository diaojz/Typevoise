import SwiftUI
import AppKit

extension Notification.Name {
    static let appNavigationRequested = Notification.Name("appNavigationRequested")
}

enum AppSection: String, CaseIterable, Hashable {
    case welcome
    case overview
    case history
    case settings

    var title: String {
        switch self {
        case .welcome: return "欢迎使用"
        case .overview: return "概览"
        case .history: return "历史记录"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .welcome: return "sparkles"
        case .overview: return "house"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var isRecording = false
    @State private var selectedSection: AppSection = SettingsManager.shared.hasCompletedSetup ? .overview : .welcome
    @State private var refreshToken = UUID()
    @StateObject private var historyManager = HistoryManager.shared

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            ZStack {
                Color(nsColor: NSColor.windowBackgroundColor)
                    .ignoresSafeArea()

                Group {
                    switch selectedSection {
                    case .welcome:
                        WelcomeView(onComplete: handleWelcomeCompleted)
                    case .overview:
                        OverviewPageView(
                            isRecording: isRecording,
                            hotkeyDescription: getHotkeyDescription(),
                            recentRecords: Array(historyManager.records.prefix(4)),
                            openHistory: { selectedSection = .history },
                            openSettings: { selectedSection = .settings }
                        )
                    case .history:
                        HistoryView()
                            .id(refreshToken)
                    case .settings:
                        SettingsView()
                            .id(refreshToken)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 1180, minHeight: 760)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .onAppear {
            setupNotifications()
            refreshForCurrentState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appNavigationRequested)) { notification in
            if let section = notification.object as? AppSection {
                selectedSection = section
                refreshToken = UUID()
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first { $0.isVisible }?.makeKeyAndOrderFront(nil)
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.9), Color.blue.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 42, height: 42)
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Typevoise")
                            .font(.system(size: 28, weight: .bold))
                        Text("语音输入工作台")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(SettingsManager.shared.hasCompletedSetup ? "在一个窗口里管理录音、历史与配置。" : "先完成基础配置，然后开始你的第一段语音输入。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .padding(.top, 32)
            .padding(.bottom, 24)

            VStack(spacing: 10) {
                sidebarButton(for: .overview)
                sidebarButton(for: .history)
                sidebarButton(for: .settings)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            VStack(alignment: .leading, spacing: 14) {
                Text(isRecording ? "正在录音" : "已就绪")
                    .font(.headline)
                Text(isRecording ? "再次按下快捷键即可停止录音。" : "使用全局快捷键，随时开始语音输入。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    shortcutKey(getHotkeyDescription())
                    if isRecording {
                        Label("录音中", systemImage: "waveform.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(width: 290)
        .background(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.72))
    }

    private func sidebarButton(for section: AppSection) -> some View {
        Button {
            selectedSection = section
            refreshToken = UUID()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: section.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 20)
                Text(section.title)
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(selectedSection == section ? Color.primary : Color.secondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selectedSection == section ? Color.white : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selectedSection == section ? Color.black.opacity(0.06) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func shortcutKey(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
    }

    private func handleWelcomeCompleted() {
        selectedSection = .overview
        refreshForCurrentState()
    }

    private func refreshForCurrentState() {
        if !SettingsManager.shared.hasCompletedSetup {
            selectedSection = .welcome
        } else if selectedSection == .welcome {
            selectedSection = .overview
        }
        refreshToken = UUID()
    }

    private func getHotkeyDescription() -> String {
        let keyCode = SettingsManager.shared.hotkeyKeyCode
        let modifiers = SettingsManager.shared.hotkeyModifiers

        if keyCode == 0 {
            return "未设置"
        }

        return KeyCodeMapper.formatHotkey(keyCode: keyCode, carbonModifiers: modifiers)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RecordingStateChanged"),
            object: nil,
            queue: .main
        ) { notification in
            if let isRecording = notification.userInfo?["isRecording"] as? Bool {
                self.isRecording = isRecording
            }
        }
    }

    static func openWindow(for section: AppSection) {
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first(where: { !$0.isMiniaturized && !$0.isExcludedFromWindowsMenu }) {
            window.makeKeyAndOrderFront(nil)
            NotificationCenter.default.post(name: .appNavigationRequested, object: section)
            return
        }

        if let appDelegate = NSApp.delegate as? AppDelegate {
            let contentView = ContentView()
            let host = NSHostingController(rootView: contentView)
            let window = NSWindow(contentViewController: host)
            window.title = "Typevoise"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.setContentSize(NSSize(width: 1240, height: 820))
            window.center()
            window.makeKeyAndOrderFront(nil)
            NotificationCenter.default.post(name: .appNavigationRequested, object: section)
            _ = appDelegate
            return
        }

        NotificationCenter.default.post(name: .appNavigationRequested, object: section)
    }
}

private struct OverviewPageView: View {
    let isRecording: Bool
    let hotkeyDescription: String
    let recentRecords: [TranscriptionRecord]
    let openHistory: () -> Void
    let openSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                heroSection
                statsSection
                quickAccessSection
                recentHistorySection
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("自然说话，流畅写字，在任何输入框中")
                .font(.system(size: 42, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)

            Text("按下 \(hotkeyDescription) 开始和停止语音输入。Typevoise 会为你完成转写、润色与插入。")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                Button(action: openHistory) {
                    Label("查看历史记录", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.borderedProminent)

                Button(action: openSettings) {
                    Label("调整设置", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var statsSection: some View {
        HStack(spacing: 18) {
            overviewCard(title: "当前状态", value: isRecording ? "录音中" : "待机", symbol: isRecording ? "waveform.circle.fill" : "bolt.circle")
            overviewCard(title: "快捷键", value: hotkeyDescription, symbol: "keyboard")
            overviewCard(title: "历史条数", value: "\(recentRecords.count)+", symbol: "text.badge.checkmark")
        }
    }

    private func overviewCard(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title == "当前状态" ? "随时可通过全局快捷键调用" : "")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .opacity(title == "当前状态" ? 1 : 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var quickAccessSection: some View {
        HStack(spacing: 20) {
            quickPanel(
                title: "语音输入",
                description: "按一次开始录音，再按一次停止。录音结束后会自动插入到当前光标位置。",
                colors: [Color.blue.opacity(0.20), Color.cyan.opacity(0.16)],
                symbol: "mic.fill"
            )
            quickPanel(
                title: "设置中心",
                description: "统一管理 Claude API、快捷键和自动粘贴行为。",
                colors: [Color.orange.opacity(0.18), Color.pink.opacity(0.16)],
                symbol: "gearshape.fill"
            )
        }
    }

    private func quickPanel(title: String, description: String, colors: [Color], symbol: String) -> some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 96, height: 96)
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                Text(description)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
        .background(
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        )
    }

    private var recentHistorySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("最近的转录")
                    .font(.system(size: 30, weight: .bold))
                Spacer()
                Button("查看全部", action: openHistory)
                    .buttonStyle(.bordered)
            }

            VStack(spacing: 14) {
                if recentRecords.isEmpty {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white)
                        .frame(height: 180)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.text.bubble.right")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.secondary)
                                Text("还没有历史记录")
                                    .font(.headline)
                                Text("用一次语音输入后，记录就会出现在这里。")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                        )
                } else {
                    ForEach(recentRecords) { record in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(record.timeAgo)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(record.formattedDate)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(record.polishedText)
                                .font(.title3.weight(.semibold))
                                .lineLimit(2)
                            Text(record.originalText)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
