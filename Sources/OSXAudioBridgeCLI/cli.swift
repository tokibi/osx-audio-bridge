import ArgumentParser
import CaptureEngine
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
        configuration.sampleRate = 44100
        configuration.channelCount = 1
        configuration.width = display.width
        configuration.height = display.height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.queueDepth = 5

        let captureEngine = try CaptureEngine(configuration: configuration, filter: filter)
        try await captureEngine.startCapture()
        try await Task.sleep(nanoseconds: 10 * NSEC_PER_SEC)
        try await captureEngine.stopCapture()
    }
}
