import SwiftUI

struct MicrophonePickerView: View {
    @StateObject private var microphoneManager = MicrophoneManager.shared
    @StateObject private var microphoneMonitor = MicrophoneMonitor()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: String?

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("麦克风")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            Divider()

            // 说明文字
            VStack(alignment: .leading, spacing: 8) {
                Text("选择能捕捉到您声音的麦克风。如果显示没有移动，请尝试其他麦克风。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            // 麦克风列表
            ScrollView {
                VStack(spacing: 12) {
                    if microphoneManager.availableDevices.isEmpty {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("正在扫描麦克风设备...")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        // 自动检测选项
                        microphoneRow(
                            name: "自动检测 (MacBook Pro麦克风)",
                            subtitle: "使用系统默认麦克风",
                            isSelected: selectedID == nil,
                            isRecommended: true
                        ) {
                            selectedID = nil
                        }

                        // 其他麦克风设备
                        ForEach(microphoneManager.availableDevices) { device in
                            microphoneRow(
                                name: device.name,
                                subtitle: device.isDefault ? "系统默认" : nil,
                                isSelected: selectedID == device.id,
                                isRecommended: device.isDefault && selectedID != nil
                            ) {
                                selectedID = device.id
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }

            Divider()

            // 底部按钮
            HStack(spacing: 12) {
                Button("刷新设备列表") {
                    microphoneManager.refreshDevices()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("确定") {
                    microphoneManager.selectDevice(selectedID)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 520, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            selectedID = microphoneManager.selectedDeviceID
            if microphoneManager.availableDevices.isEmpty {
                microphoneManager.refreshDevices()
            }
            // 延迟启动监听，避免与其他音频引擎冲突
            Task {
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 秒
                await microphoneMonitor.startMonitoring(deviceID: selectedID)
            }
        }
        .onDisappear {
            Task {
                await microphoneMonitor.stopMonitoring()
            }
        }
        .onChange(of: selectedID) { _, newID in
            // 切换麦克风时重新开始监听
            Task {
                await microphoneMonitor.stopMonitoring()
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 秒
                await microphoneMonitor.startMonitoring(deviceID: newID)
            }
        }
    }

    private func microphoneRow(
        name: String,
        subtitle: String?,
        isSelected: Bool,
        isRecommended: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 选中指示器
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 10, height: 10)
                    }
                }

                // 麦克风信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                        if isRecommended {
                            Text("推荐")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.blue.opacity(0.1))
                                )
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // 音量指示器
                AudioLevelIndicator(level: isSelected ? microphoneMonitor.audioLevel : 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 音量指示器

struct AudioLevelIndicator: View {
    let level: Float
    private let barCount = 8
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 2
    private let maxHeight: CGFloat = 20

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(barColor(for: index))
                    .frame(width: barWidth, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: level)
            }
        }
        .frame(height: maxHeight)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let threshold = Float(index) / Float(barCount)
        if level > threshold {
            // 根据音量动态调整高度
            let intensity = min((level - threshold) * Float(barCount), 1.0)
            return maxHeight * CGFloat(0.3 + intensity * 0.7)
        }
        return maxHeight * 0.3 // 最小高度
    }

    private func barColor(for index: Int) -> Color {
        let threshold = Float(index) / Float(barCount)
        if level > threshold {
            // 根据位置渐变颜色
            if index < barCount * 2 / 3 {
                return Color.accentColor
            } else if index < barCount * 5 / 6 {
                return Color.orange
            } else {
                return Color.red
            }
        }
        return Color.gray.opacity(0.2)
    }
}

#Preview {
    MicrophonePickerView()
}
