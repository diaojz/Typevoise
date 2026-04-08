import Foundation
import AVFoundation
import CoreAudio
import Combine

struct MicrophoneDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let isDefault: Bool

    var displayName: String {
        isDefault ? "\(name) (默认)" : name
    }
}

class MicrophoneManager: ObservableObject {
    static let shared = MicrophoneManager()

    @Published var availableDevices: [MicrophoneDevice] = []
    @Published var selectedDeviceID: String?

    private init() {
        refreshDevices()
        selectedDeviceID = SettingsManager.shared.selectedMicrophoneID
    }

    func refreshDevices() {
        var devices: [MicrophoneDevice] = []

        #if os(macOS)
        // 获取所有音频输入设备
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == kAudioHardwareNoError else {
            print("❌ [Mic] 无法获取音频设备列表")
            return
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &audioDevices
        )

        guard status == kAudioHardwareNoError else {
            print("❌ [Mic] 无法读取音频设备数据")
            return
        }

        // 获取默认输入设备
        var defaultInputDeviceID = AudioDeviceID(0)
        var defaultDevicePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var defaultDeviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDevicePropertyAddress,
            0,
            nil,
            &defaultDeviceIDSize,
            &defaultInputDeviceID
        )

        // 遍历设备，筛选输入设备
        for deviceID in audioDevices {
            // 检查是否有输入通道
            var streamPropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            var streamDataSize: UInt32 = 0
            status = AudioObjectGetPropertyDataSize(
                deviceID,
                &streamPropertyAddress,
                0,
                nil,
                &streamDataSize
            )

            guard status == kAudioHardwareNoError, streamDataSize > 0 else {
                continue
            }

            let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            defer { bufferList.deallocate() }

            status = AudioObjectGetPropertyData(
                deviceID,
                &streamPropertyAddress,
                0,
                nil,
                &streamDataSize,
                bufferList
            )

            guard status == kAudioHardwareNoError else {
                continue
            }

            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            var totalChannels = 0
            for buffer in buffers {
                totalChannels += Int(buffer.mNumberChannels)
            }

            guard totalChannels > 0 else {
                continue
            }

            // 获取设备名称
            var namePropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            var deviceName: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            status = AudioObjectGetPropertyData(
                deviceID,
                &namePropertyAddress,
                0,
                nil,
                &nameSize,
                &deviceName
            )

            guard status == kAudioHardwareNoError else {
                continue
            }

            let name = deviceName as String
            let deviceIDString = "\(deviceID)"
            let isDefault = deviceID == defaultInputDeviceID

            devices.append(MicrophoneDevice(
                id: deviceIDString,
                name: name,
                isDefault: isDefault
            ))

            print("🎤 [Mic] 发现输入设备: \(name) (ID: \(deviceIDString), 默认: \(isDefault))")
        }
        #endif

        DispatchQueue.main.async {
            self.availableDevices = devices.sorted { device1, device2 in
                if device1.isDefault != device2.isDefault {
                    return device1.isDefault
                }
                return device1.name < device2.name
            }
            print("✅ [Mic] 共找到 \(devices.count) 个输入设备")
        }
    }

    func selectDevice(_ deviceID: String?) {
        selectedDeviceID = deviceID
        SettingsManager.shared.selectedMicrophoneID = deviceID
        print("🎤 [Mic] 已选择设备: \(deviceID ?? "默认")")
    }

    func getSelectedDevice() -> MicrophoneDevice? {
        guard let deviceID = selectedDeviceID else {
            return availableDevices.first { $0.isDefault }
        }
        return availableDevices.first { $0.id == deviceID }
    }
}
