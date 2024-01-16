import Foundation
import GRPC
import NIOCore
import CaptureEngine
import ScreenCaptureKit

final class AudioService: Audio_V1_AudioServiceAsyncProvider {
    let interceptors: Audio_V1_AudioServiceServerInterceptorFactoryProtocol? = nil

    func filterChromeWindows(content: SCShareableContent) async throws -> [SCWindow] {
        let windows = content.windows.filter {
            // guard $0.isOnScreen else { return false }
            guard let app = $0.owningApplication else { return false }
            return app.applicationName == "Google Chrome"
        }

        return windows
    }

    func streamAudio(
        request: Audio_V1_StreamAudioRequest,
        responseStream: GRPCAsyncResponseStreamWriter<Audio_V1_StreamAudioResponse>,
        context: GRPCAsyncServerCallContext
    ) async throws {
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
        for await buffer in await captureEngine.listen() {
            let arraySize = Int(buffer.frameLength)
            let frame = [Float](
                UnsafeBufferPointer(start: buffer.floatChannelData![0], count: arraySize))

            try await responseStream.send(Audio_V1_StreamAudioResponse.with {
                $0.data = frame
                $0.sampleRate = 48000
            })
        }

        return
    }
}
