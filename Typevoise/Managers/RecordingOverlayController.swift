import AppKit
import SwiftUI

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class RecordingOverlayController {
    static let shared = RecordingOverlayController()

    private var window: NSWindow?
    private var host: NSHostingController<RecordingOverlayView>?
    private let state = RecordingOverlayState()
    private var onCancel: (() -> Void)?
    private var onConfirm: (() -> Void)?
    private var hideTimer: Timer?

    private init() {}

    func show(onCancel: @escaping () -> Void, onConfirm: @escaping () -> Void) {
        // 取消之前的自动隐藏定时器
        hideTimer?.invalidate()
        hideTimer = nil

        self.onCancel = onCancel
        self.onConfirm = onConfirm
        state.state = .recording
        state.transcript = ""
        state.level = 0

        let view = RecordingOverlayView(
            state: state,
            onCancel: { [weak self] in self?.onCancel?() },
            onConfirm: { [weak self] in self?.onConfirm?() }
        )

        let host = NSHostingController(rootView: view)
        self.host = host

        let window = OverlayWindow(contentViewController: host)
        window.styleMask = NSWindow.StyleMask.borderless
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.level = NSWindow.Level.floating
        window.hasShadow = true
        window.ignoresMouseEvents = false

        let initialWidth = preferredWidth(for: "", state: .recording)
        setWindowFrame(window, width: initialWidth)
        window.orderFrontRegardless()

        self.window = window
        print("🪟 [Overlay] 录音浮层显示")
    }

    func update(transcript: String) {
        state.transcript = transcript
        guard let window else { return }
        let width = preferredWidth(for: transcript, state: .recording)
        setWindowFrame(window, width: width)
    }

    func update(level: CGFloat) {
        state.level = max(0, min(1, level))
    }

    // 切换到处理中状态
    func showProcessing() {
        guard let window else {
            print("⚠️ [Overlay] 窗口不存在，无法切换到处理状态")
            return
        }

        // 取消之前的自动隐藏定时器
        hideTimer?.invalidate()
        hideTimer = nil

        // 直接更新状态（调用方已确保在主线程）
        state.state = .processing
        state.level = 0
        setWindowFrame(window, width: preferredWidth(for: "正在润色文本...", state: .processing))
        // 清空按钮回调，处理中状态不需要交互
        onCancel = nil
        onConfirm = nil
        print("🪟 [Overlay] 切换到处理中状态")
    }

    // 显示完成状态（可选，显示后自动隐藏）
    func showCompleted(autoHideAfter delay: TimeInterval = 1.0) {
        guard let window else {
            print("⚠️ [Overlay] 窗口不存在，无法显示完成状态")
            return
        }

        // 取消之前的自动隐藏定时器
        hideTimer?.invalidate()
        hideTimer = nil

        // 直接更新状态（调用方已确保在主线程）
        state.state = .completed
        state.level = 0
        setWindowFrame(window, width: preferredWidth(for: "已插入到光标位置", state: .completed))
        print("🪟 [Overlay] 显示完成状态")

        // 设置自动隐藏定时器
        hideTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    func hide() {
        // 取消自动隐藏定时器
        hideTimer?.invalidate()
        hideTimer = nil

        guard window != nil else { return }
        window?.orderOut(nil)
        window = nil
        host = nil
        state.state = .recording
        state.transcript = ""
        state.level = 0
        onCancel = nil
        onConfirm = nil
        print("🪟 [Overlay] 录音浮层隐藏")
    }

    private func preferredWidth(for text: String, state: OverlayState) -> CGFloat {
        guard let screenFrame = NSScreen.main?.visibleFrame else { return 420 }

        let minWidth: CGFloat = 380
        let maxWidth: CGFloat = min(980, screenFrame.width * 0.82)

        let characterCount = max(text.count, 8)
        let baseWidth: CGFloat
        switch state {
        case .recording:
            baseWidth = 300
        case .processing, .completed:
            baseWidth = 360
        }

        let textWidth = CGFloat(characterCount) * 15
        return min(max(baseWidth + textWidth, minWidth), maxWidth)
    }

    private func setWindowFrame(_ window: NSWindow, width: CGFloat) {
        guard let screenFrame = NSScreen.main?.visibleFrame else { return }
        let height: CGFloat = 100
        let safeWidth = min(width, screenFrame.width * 0.9)
        let origin = NSPoint(
            x: screenFrame.midX - safeWidth / 2,
            y: screenFrame.maxY - height - 24
        )
        window.setFrame(NSRect(origin: origin, size: NSSize(width: safeWidth, height: height)), display: true, animate: false)
    }
}
