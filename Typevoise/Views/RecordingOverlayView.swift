import SwiftUI
import Combine

enum OverlayState {
    case recording      // 正在录音
    case processing     // 正在处理（AI 润色中）
    case completed      // 完成
}

final class RecordingOverlayState: ObservableObject {
    @Published var transcript: String = ""
    @Published var level: CGFloat = 0
    @Published var state: OverlayState = .recording
}

struct RecordingOverlayView: View {
    @ObservedObject var state: RecordingOverlayState
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // 根据状态显示不同的内容
            switch state.state {
            case .recording:
                recordingView
            case .processing:
                processingView
            case .completed:
                completedView
            }

            // 底部文本
            if !bottomText.isEmpty {
                Text(bottomText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .frame(minWidth: 300, maxWidth: .infinity)
        .background(Color.black.opacity(0.88))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
    }

    // 录音状态视图
    private var recordingView: some View {
        HStack(spacing: 0) {
            // 左侧取消按钮
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.45))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            // 中间波形
            AudioWaveformView(level: state.level, isActive: true)
                .frame(width: 120, height: 32)

            Spacer()

            // 右侧确认按钮
            Button(action: onConfirm) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // 处理中状态视图
    private var processingView: some View {
        HStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.0)
                .frame(width: 18, height: 18)

            Text("Thinking...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            // 占位，保证文本严格居中（与左侧 loading 等宽）
            Color.clear
                .frame(width: 18, height: 18)
        }
        .frame(height: 40)
    }

    // 完成状态视图
    private var completedView: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.green)

            Text("完成")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(height: 40)
    }

    // 底部文本
    private var bottomText: String {
        switch state.state {
        case .recording:
            return state.transcript.isEmpty ? "" : state.transcript
        case .processing:
            return "正在润色文本..."
        case .completed:
            return "已插入到光标位置"
        }
    }
}

private struct AudioWaveformView: View {
    let level: CGFloat
    let isActive: Bool

    private let barCount = 12
    private let barWidth: CGFloat = 2.5
    private let barSpacing: CGFloat = 3.5
    private let minHeightRatio: CGFloat = 0.15
    private let maxHeightRatio: CGFloat = 0.85
    private let gamma: CGFloat = 0.7

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isActive)) { timeline in
            Canvas { context, size in
                let centerY = size.height / 2
                let time = timeline.date.timeIntervalSinceReferenceDate
                let totalWidth = CGFloat(barCount) * (barWidth + barSpacing) - barSpacing
                let startX = (size.width - totalWidth) / 2

                for i in 0..<barCount {
                    let x = startX + CGFloat(i) * (barWidth + barSpacing)
                    let barHeight = calculateBarHeight(
                        index: i,
                        time: time,
                        maxHeight: size.height
                    )

                    let rect = CGRect(
                        x: x,
                        y: centerY - barHeight / 2,
                        width: barWidth,
                        height: barHeight
                    )

                    let opacity = 0.85 - (abs(CGFloat(i) - CGFloat(barCount) / 2) / CGFloat(barCount)) * 0.3
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
        .drawingGroup()
    }

    private func calculateBarHeight(index: Int, time: TimeInterval, maxHeight: CGFloat) -> CGFloat {
        let clampedLevel = min(max(level, 0), 1)
        let normalizedLevel = pow(clampedLevel, gamma)

        let minHeight = maxHeight * minHeightRatio
        let maxBarHeight = maxHeight * maxHeightRatio

        let frequency = 1.8 + Double(index) * 0.15
        let phase = time * frequency + Double(index) * 0.5
        let wave = (sin(phase) + 1) / 2

        let idleHeight = minHeight + wave * (minHeight * 0.6)
        let activeHeight = minHeight + normalizedLevel * (maxBarHeight - minHeight) * (0.7 + wave * 0.3)

        return normalizedLevel < 0.05 ? idleHeight : activeHeight
    }
}
