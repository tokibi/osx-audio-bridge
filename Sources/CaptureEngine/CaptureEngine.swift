import AVFAudio
import Combine
import Foundation
import OSLog
import ScreenCaptureKit

/// An object that wraps an instance of `SCStream`, and returns its results as an `AsyncThrowingStream`.
public class CaptureEngine: NSObject {
    private let logger = Logger()

    private var isCapturing = false
    private var stream: SCStream
    private var streamOutput: CaptureEngineStreamOutput
    private let bufferQueue = DispatchQueue(
        label: "AudioBridge.AudioSampleBufferQueue")

    private let pcmBufferSubject = CurrentValueSubject<AVAudioPCMBuffer?, Never>(nil)

    public init(configuration: SCStreamConfiguration, filter: SCContentFilter) throws {
        streamOutput = CaptureEngineStreamOutput()
        stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        super.init()

        streamOutput.pcmBufferHandler = { [weak self] in
            guard let self = self else { return }
            self.pcmBufferSubject.send($0)
        }
        try stream.addStreamOutput(streamOutput, type: .audio, sampleHandlerQueue: bufferQueue)
    }

    public func listen() async -> AsyncStream<AVAudioPCMBuffer> {
        if !isCapturing {
            await startCapture()
        }

        return AsyncStream { continuation in
            let cancellable = pcmBufferSubject.sink {
                guard let buffer = $0 else { return }
                continuation.yield(buffer)
            }
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

    public func startCapture() async {
        try? await stream.startCapture()
        isCapturing = true
    }

    public func stopCapture() async {
        try? await stream.stopCapture()
        isCapturing = false
    }

    /// - Tag: UpdateStreamConfiguration
    public func update(configuration: SCStreamConfiguration, filter: SCContentFilter) async {
        do {
            try await stream.updateConfiguration(configuration)
            try await stream.updateContentFilter(filter)
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
