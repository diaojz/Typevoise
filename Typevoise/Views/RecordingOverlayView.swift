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
    @Published var progress: Double = 0.0 // 处理进度 0.0 ~ 1.0
}

struct RecordingOverlayView: View {
    @ObservedObject var state: RecordingOverlayState
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        Group {
            // 根据状态显示不同的内容
            switch state.state {
            case .recording:
                recordingContentView
            case .processing:
                processingContentView
            case .completed:
                completedContentView
            }
        }
    }

    // 录音状态的完整视图（带背景）
    private var recordingContentView: some View {
        VStack(spacing: 10) {
            recordingView

            // 底部文本
            if !state.transcript.isEmpty {
                Text(state.transcript)
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

    // 处理中状态的完整视图（带进度条背景）
    private var processingContentView: some View {
        ShimmerProgressView(
            progress: state.progress,
            text: "正在润色文本..."
        )
        .frame(minWidth: 300, maxWidth: .infinity)
    }

    // 完成状态的完整视图（带背景）
    private var completedContentView: some View {
        VStack(spacing: 10) {
            completedView

            Text("已插入到光标位置")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.92))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
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

    // 处理中状态视图（内容部分）
    private var processingView: some View {
        HStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.0)
                .frame(width: 18, height: 18)

            Text("处理中")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            Color.clear
                .frame(width: 18, height: 18)
        }
        .frame(height: 40)
    }

    // 完成状态视图（内容部分）
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

        // 增加频率差异，让每根柱子的波动更独立
        let frequency = 2.2 + Double(index) * 0.35
        let phase = time * frequency + Double(index) * 0.8
        let wave = (sin(phase) + 1) / 2

        // 添加第二层波形，增加复杂度
        let secondWave = (sin(time * 1.5 + Double(index) * 0.3) + 1) / 2
        let combinedWave = (wave * 0.7 + secondWave * 0.3)

        // 中间柱子更高，两侧递减
        let centerIndex = Double(barCount) / 2
        let distanceFromCenter = abs(Double(index) - centerIndex)
        let centerBoost = 1.0 - (distanceFromCenter / centerIndex) * 0.4

        let idleHeight = minHeight + combinedWave * (minHeight * 1.2) * centerBoost
        let activeHeight = minHeight + normalizedLevel * (maxBarHeight - minHeight) * (0.6 + combinedWave * 0.4) * centerBoost

        return normalizedLevel < 0.05 ? idleHeight : activeHeight
    }
}

// MARK: - 五彩渐变进度条视图
private struct ShimmerProgressView: View {
    let progress: Double // 0.0 ~ 1.0，真实进度
    let text: String

    private let rainbowColors: [Color] = [
        Color(red: 1.0, green: 0.3, blue: 0.3),   // 红
        Color(red: 1.0, green: 0.6, blue: 0.2),   // 橙
        Color(red: 1.0, green: 0.9, blue: 0.2),   // 黄
        Color(red: 0.3, green: 1.0, blue: 0.5),   // 绿
        Color(red: 0.2, green: 0.6, blue: 1.0),   // 蓝
        Color(red: 0.6, green: 0.3, blue: 1.0),   // 紫
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 底层背景（深色胶囊）
                Capsule()
                    .fill(Color.black.opacity(0.88))
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )

                // 进度条：从左到右填充的彩虹渐变背景
                HStack(spacing: 0) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: rainbowColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress * 2)
                        .animation(.easeOut(duration: 0.3), value: progress)

                    Spacer(minLength: 0)
                }

                // 文字层（始终居中显示）
                Text(text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
            }
        }
        .frame(height: 60)
    }
}
