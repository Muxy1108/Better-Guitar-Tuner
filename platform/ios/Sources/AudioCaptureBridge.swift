import Foundation

public struct AudioCaptureConfiguration {
    public let sampleRateHz: Int
    public let channelCount: Int

    public init(sampleRateHz: Int = 48_000, channelCount: Int = 1) {
        self.sampleRateHz = sampleRateHz
        self.channelCount = channelCount
    }
}

public final class AudioCaptureBridge {
    public init() {}

    public func start(configuration: AudioCaptureConfiguration) throws {
        _ = configuration
        throw AudioCaptureBridgeError.notImplemented
    }

    public func stop() {}
}

public enum AudioCaptureBridgeError: Error {
    case notImplemented
}
