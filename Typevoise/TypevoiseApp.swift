import SwiftUI

@main
struct TypevoiseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var voiceController: VoiceController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 应用启动")

        // 初始化状态栏控制器
        statusBarController = StatusBarController()
        print("✅ 状态栏控制器已初始化")

        // 初始化语音控制器
        voiceController = VoiceController()
        print("✅ 语音控制器已初始化")

        // 检查是否首次启动
        let hasCompleted = SettingsManager.shared.hasCompletedSetup
        print("📋 hasCompletedSetup = \(hasCompleted)")

        if !hasCompleted {
            print("🎉 首次启动，显示欢迎界面")
            showWelcomeWindow()
        } else {
            print("✅ 已完成设置，应用就绪")
        }
    }

    private func showWelcomeWindow() {
        print("🪟 创建欢迎窗口")
        let welcomeView = WelcomeView()
        let hostingController = NSHostingController(rootView: welcomeView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "欢迎使用 Typevoise"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 600, height: 500))
        window.level = .floating  // 设置窗口层级为浮动，始终在最前面
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("✅ 欢迎窗口已显示")
    }
}
