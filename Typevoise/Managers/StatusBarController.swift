import AppKit
import SwiftUI

class StatusBarController {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    init() {
        setupStatusBar()
        setupNotifications()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateIcon(state: .idle)
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }

        setupMenu()
    }

    private func setupMenu() {
        menu = NSMenu()

        menu?.addItem(NSMenuItem(title: "Typevoise", action: nil, keyEquivalent: ""))
        menu?.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu?.addItem(settingsItem)

        menu?.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu?.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(recordingStarted), name: .voiceRecordingStarted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(recordingStopped), name: .voiceRecordingStopped, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(processingStarted), name: .voiceProcessingStarted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(processingCompleted), name: .voiceProcessingCompleted, object: nil)
    }

    @objc private func statusBarButtonClicked() {
        // 点击状态栏图标时显示菜单
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func recordingStarted() {
        updateIcon(state: .recording)
    }

    @objc private func recordingStopped() {
        updateIcon(state: .idle)
    }

    @objc private func processingStarted() {
        updateIcon(state: .processing)
    }

    @objc private func processingCompleted() {
        updateIcon(state: .idle)
    }

    private func updateIcon(state: IconState) {
        guard let button = statusItem?.button else { return }

        switch state {
        case .idle:
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "待机")
            button.image?.isTemplate = true
        case .recording:
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "录音中")
            button.image?.isTemplate = false
            button.contentTintColor = .systemRed
        case .processing:
            button.image = NSImage(systemSymbolName: "waveform.badge.magnifyingglass", accessibilityDescription: "处理中")
            button.image?.isTemplate = false
            button.contentTintColor = .systemBlue
        }
    }

    enum IconState {
        case idle
        case recording
        case processing
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
