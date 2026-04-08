import Foundation
import AVFoundation
import CoreAudio
import Combine

class MicrophoneMonitor: ObservableObject {
    @Published var audioLevel: Float = 0.0

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var isMonitoring = false

    func startMonitoring(deviceID: String?) {
        guard !isMonitoring else { return }

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
            AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                0,
                nil,
                propertySize,
                &deviceIDVar
            )
        }

        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else { return }

        let recordingFormat = inputNode.outputFormat(forBus: 0)

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

            DispatchQueue.main.async {
                self.audioLevel = level
            }
        }

        do {
            try audioEngine.start()
            isMonitoring = true
        } catch {
            print("❌ [Monitor] 启动音频引擎失败: \(error)")
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }

        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        isMonitoring = false

        DispatchQueue.main.async {
            self.audioLevel = 0
        }
    }
}
