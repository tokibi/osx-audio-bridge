import AVFoundation
import ArgumentParser
import CaptureEngine
import Foundation
import ScreenCaptureKit

@main
struct OSXAudioBridge: AsyncParsableCommand {
    mutating func run() async throws {
        try await start()
    }

    func filterChromeWindows(content: SCShareableContent) async throws -> [SCWindow] {
        let windows = content.windows.filter {
            // guard $0.isOnScreen else { return false }
            guard let app = $0.owningApplication else { return false }
            return app.applicationName == "Google Chrome"
        }

        return windows
    }

    func start() async throws {
        let availableContent = try await SCShareableContent.current
        let display = availableContent.displays.first!
        let windows = try await filterChromeWindows(content: availableContent)

        // Degbug
        print("Target Display: \(display.width)x\(display.height)")
        for window in windows {
            guard let app = window.owningApplication else { continue }
            guard let title = window.title else { continue }
            print("\(app.applicationName): \(title)")
        }

        let filter = SCContentFilter(display: display, including: windows)
        let configuration = SCStreamConfiguration()
        configuration.queueDepth = 6
        configuration.capturesAudio = true
        configuration.sampleRate = 48000
        configuration.channelCount = 1
        configuration.width = display.width
        configuration.height = display.height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.queueDepth = 5

        let captureEngine = try CaptureEngine(configuration: configuration, filter: filter)

        // for await buffer in await captureEngine.listen() {
        //     let arraySize = Int(buffer.frameLength)
        //     let frame = [Float](
        //         UnsafeBufferPointer(start: buffer.floatChannelData![0], count: arraySize))
        //     print(frame)
        // }
        try await writeExample(
            captureEngine: captureEngine, sampleRate: 48000, channelCount: 1, durationSec: 10)
    }

    func writeExample(
        captureEngine: CaptureEngine, sampleRate: Int, channelCount: Int, durationSec: Int
    ) async throws {
        let fileURL = URL(fileURLWithPath: "/tmp/file.pcm")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        var audioFile: AVAudioFile?
        do {
            audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
        } catch {
            print("Error creating audio file: \(error)")
            throw error
        }

        var data: [Float] = []
        for await buffer in await captureEngine.listen() {
            let arraySize = Int(buffer.frameLength)
            let frame = [Float](
                UnsafeBufferPointer(start: buffer.floatChannelData![0], count: arraySize))
            data.append(contentsOf: frame)
            print("current size: \(data.count)")
            if data.count >= sampleRate * durationSec {
                print("stop capture")
                break
            }
        }

        // Convert Float array to PCM data
        let audioFormat = AVAudioFormat(
            standardFormatWithSampleRate: Double(sampleRate),
            channels: AVAudioChannelCount(channelCount))!
        let pcmBuffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(data.count))!
        pcmBuffer.frameLength = pcmBuffer.frameCapacity

        for i in 0..<data.count {
            pcmBuffer.floatChannelData![0][i] = data[i]
            // channelData[i] = data[i]
        }
        do {
            try audioFile?.write(from: pcmBuffer)
        } catch {
            print("Error writing to audio file: \(error)")
        }

        audioFile = nil
    }

}
