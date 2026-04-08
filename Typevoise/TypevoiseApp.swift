import SwiftUI
import AppKit

@main
struct TypevoiseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1240, height: 820)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("显示主窗口") {
                    ContentView.openWindow(for: .overview)
                }
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var voiceController: VoiceController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 应用启动")

        statusBarController = StatusBarController()
        print("✅ 状态栏控制器已初始化")

        voiceController = VoiceController()
        print("✅ 语音控制器已初始化")

        let hasCompleted = SettingsManager.shared.hasCompletedSetup
        print("📋 hasCompletedSetup = \(hasCompleted)")

        if !hasCompleted {
            print("🎉 首次启动，打开主窗口欢迎流程")
            DispatchQueue.main.async {
                ContentView.openWindow(for: .welcome)
            }
        } else {
            print("✅ 已完成设置，应用就绪")
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            ContentView.openWindow(for: .overview)
        }
        return true
    }
}
