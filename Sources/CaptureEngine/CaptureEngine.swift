import AVFAudio
import Combine
import Foundation
import OSLog
import ScreenCaptureKit

/// An object that wraps an instance of `SCStream`, and returns its results as an `AsyncStream`.
public class CaptureEngine: NSObject {
    private let logger = Logger()

    private var isCapturing = false
    private var stream: SCStream
    private var streamOutput: CaptureEngineStreamOutput
    private let bufferQueue = DispatchQueue(label: "AudioBridge.AudioSampleBufferQueue")

    private var subscriberCount = 0
    private let counterQueue = DispatchQueue(label: "AudioBridge.SubscriberCounterQueue")
    private let pcmBufferSubject = PassthroughSubject<AVAudioPCMBuffer, Never>()

    public init(configuration: SCStreamConfiguration, filter: SCContentFilter) throws {
        streamOutput = CaptureEngineStreamOutput()
        stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        super.init()

        streamOutput.pcmBufferHandler = { [weak self] in
            self?.pcmBufferSubject.send($0)
        }
        try stream.addStreamOutput(streamOutput, type: .audio, sampleHandlerQueue: bufferQueue)
    }

    public func listen() async -> AsyncStream<AVAudioPCMBuffer> {
        if !isCapturing {
            await startCapture()
        }

        incrimentSubscriberCount()

        return AsyncStream { continuation in
            let cancellable = pcmBufferSubject.sink {
                continuation.yield($0)
            }
            continuation.onTermination = { [weak self] _ in
                cancellable.cancel()
                self?.handleUnsubscription()
            }
        }
    }

    private func handleUnsubscription() {
        decrimentSubscriberCount()
        counterQueue.sync {
            if self.subscriberCount < 1 {
                Task {
                    await stopCapture()
                }
            }
        }
    }

    private func incrimentSubscriberCount() {
        counterQueue.sync { subscriberCount += 1 }
    }

    private func decrimentSubscriberCount() {
        counterQueue.sync { subscriberCount -= 1 }
    }

    private func startCapture() async {
        do {
            try await stream.startCapture()
            isCapturing = true
        } catch {
            logger.error("Failed to start capture: \(String(describing: error))")
        }
    }

    public func stopCapture() async {
        do {
            try await stream.stopCapture()
            isCapturing = false
        } catch {
            logger.error("Failed to stop capture: \(String(describing: error))")
        }
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
