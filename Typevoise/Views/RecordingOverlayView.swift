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
        VStack(spacing: 8) {
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
            Text(bottomText)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.92))
                .lineLimit(1)
                .frame(maxWidth: 220)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.88))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
    }

    // 录音状态视图
    private var recordingView: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.gray.opacity(0.45))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            AudioWaveformView(level: state.level, isActive: true)
                .frame(width: 86, height: 24)

            Button(action: onConfirm) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 34, height: 34)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // 处理中状态视图
    private var processingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)

            Text("Thinking...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(height: 34)
    }

    // 完成状态视图
    private var completedView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.green)

            Text("完成")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(height: 34)
    }

    // 底部文本
    private var bottomText: String {
        switch state.state {
        case .recording:
            return state.transcript.isEmpty ? "正在聆听..." : state.transcript
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

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<9, id: \.self) { idx in
                let base: CGFloat = 4
                let dynamic = max(0, level * 18 - abs(CGFloat(idx - 4)) * 1.2)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 3, height: isActive ? base + dynamic : 4)
                    .animation(.easeOut(duration: 0.12), value: level)
            }
        }
    }
}
