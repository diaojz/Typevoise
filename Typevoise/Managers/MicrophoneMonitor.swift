import Foundation
import AVFoundation
import CoreAudio
import Combine

@MainActor
class MicrophoneMonitor: ObservableObject {
    @Published var audioLevel: Float = 0.0

    private var audioEngine: AVAudioEngine?
    private var isMonitoring = false
    private var hasTap = false

    func startMonitoring(deviceID: String?) {
        // 先停止之前的监听
        stopMonitoring()

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        // 设置指定的麦克风设备
        if let deviceID = deviceID,
           let deviceIDValue = AudioDeviceID(deviceID) {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var deviceIDVar = deviceIDValue
            let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
            let status = AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                0,
                nil,
                propertySize,
                &deviceIDVar
            )
            if status != kAudioHardwareNoError {
                print("⚠️  [Monitor] 设置设备失败: \(status)")
            }
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // 检查格式是否有效
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            print("❌ [Monitor] 无效的音频格式")
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)

            guard let channelData = channelData, frameLength > 0 else { return }

            var sum: Float = 0
            for i in 0..<frameLength {
                let sample = channelData[i]
                sum += sample * sample
            }

            let rms = sqrt(sum / Float(frameLength))
            let level = min(max(rms * 20, 0), 1) // 放大并限制在 0-1

            Task { @MainActor in
                self.audioLevel = level
            }
        }
        hasTap = true

        do {
            try audioEngine.start()
            isMonitoring = true
            print("✅ [Monitor] 监听已启动")
        } catch {
            print("❌ [Monitor] 启动音频引擎失败: \(error.localizedDescription)")
            // 清理 tap
            if hasTap {
                inputNode.removeTap(onBus: 0)
                hasTap = false
            }
        }
    }

    func stopMonitoring() {
        guard isMonitoring || hasTap else { return }

        // 先停止引擎
        if isMonitoring {
            audioEngine?.stop()
            isMonitoring = false
        }

        // 再移除 tap
        if hasTap {
            audioEngine?.inputNode.removeTap(onBus: 0)
            hasTap = false
        }

        audioEngine = nil
        audioLevel = 0

        print("🛑 [Monitor] 监听已停止")
    }

    deinit {
        // 在 deinit 中直接清理，不使用 Task
        if isMonitoring {
            audioEngine?.stop()
        }
        if hasTap {
            audioEngine?.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
    }
}

