import AVFAudio
import Foundation
import OSLog
import ScreenCaptureKit

/// An object that wraps an instance of `SCStream`, and returns its results as an `AsyncThrowingStream`.
public class CaptureEngine: NSObject {
    private let logger = Logger()

    private var isCaptureing = false
    private var stream: SCStream?
    private var streamOutput: CaptureEngineStreamOutput?
    private let bufferQueue = DispatchQueue(
        label: "AudioBridge.AudioSampleBufferQueue")

    public func startCapture(configuration: SCStreamConfiguration, filter: SCContentFilter)
        async throws
    {
        streamOutput = CaptureEngineStreamOutput()
        streamOutput?.pcmBufferHandler = {
            let arraySize = Int($0.frameLength)
            let data = [Float](
                UnsafeBufferPointer(start: $0.floatChannelData![0], count: arraySize))
            print(data)
        }

        stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream?.addStreamOutput(
            streamOutput!, type: .audio, sampleHandlerQueue: bufferQueue)
        try await stream?.startCapture()
        isCaptureing = true
    }

    public func stopCapture() async throws {
        try await stream?.stopCapture()
        isCaptureing = false
    }

    /// - Tag: UpdateStreamConfiguration
    public func update(configuration: SCStreamConfiguration, filter: SCContentFilter) async {
        do {
            try await stream?.updateConfiguration(configuration)
            try await stream?.updateContentFilter(filter)
        } catch {
            logger.error("Failed to update the stream session: \(String(describing: error))")
        }
    }
}

private class CaptureEngineStreamOutput: NSObject, SCStreamOutput {
    var pcmBufferHandler: ((AVAudioPCMBuffer) -> Void)?

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        // Return early if the sample buffer is invalid.
        guard sampleBuffer.isValid else { return }

        // Determine which type of data the sample buffer contains.
        switch outputType {
        case .screen:
            // Create a CapturedFrame structure for a video sample buffer.
            // guard let frame = createFrame(for: sampleBuffer) else { return }
            break
        case .audio:
            // Create an AVAudioPCMBuffer from an audio sample buffer.
            guard let buffer = createPCMBuffer(for: sampleBuffer) else { return }
            pcmBufferHandler?(buffer)
        @unknown default:
            fatalError("Encountered unknown stream output type: \(outputType)")
        }
    }

    private func createPCMBuffer(for sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        return try? sampleBuffer.withAudioBufferList { audioBufferList, blockBuffer in
            guard
                let absd = sampleBuffer.formatDescription?.audioStreamBasicDescription,
                let format = AVAudioFormat(
                    standardFormatWithSampleRate: absd.mSampleRate, channels: absd.mChannelsPerFrame
                ),
                let buffer = AVAudioPCMBuffer(
                    pcmFormat: format, bufferListNoCopy: audioBufferList.unsafePointer
                )
            else { return nil }
            return buffer
        }
    }
}
