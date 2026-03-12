import AVFoundation
import Foundation

public struct AudioCaptureConfiguration {
    public let sampleRateHz: Int
    public let channelCount: Int
    public let windowSizeSamples: Int
    public let hopSizeSamples: Int
    public let tapBufferSize: Int
    public let sessionCategory: AVAudioSession.Category
    public let sessionMode: AVAudioSession.Mode
    public let sessionOptions: AVAudioSession.CategoryOptions

    public init(
        sampleRateHz: Int = 48_000,
        channelCount: Int = 1,
        windowSizeSamples: Int = 4_096,
        hopSizeSamples: Int = 1_024,
        tapBufferSize: Int = 1_024,
        sessionCategory: AVAudioSession.Category = .playAndRecord,
        sessionMode: AVAudioSession.Mode = .measurement,
        sessionOptions: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetooth]
    ) {
        self.sampleRateHz = sampleRateHz
        self.channelCount = channelCount
        self.windowSizeSamples = windowSizeSamples
        self.hopSizeSamples = hopSizeSamples
        self.tapBufferSize = tapBufferSize
        self.sessionCategory = sessionCategory
        self.sessionMode = sessionMode
        self.sessionOptions = sessionOptions
    }
}

public final class AudioCaptureBridge {
    private let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()

    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?
    private var sampleHandler: (([Float]) -> Void)?

    public init() {}

    public func start(
        configuration: AudioCaptureConfiguration,
        onSamples: @escaping ([Float]) -> Void
    ) throws {
        stop()

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(configuration.sampleRateHz),
            channels: AVAudioChannelCount(configuration.channelCount),
            interleaved: false
        ) else {
            throw AudioCaptureBridgeError.invalidAudioFormat
        }

        self.targetFormat = targetFormat
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        sampleHandler = onSamples

        try audioSession.setCategory(
            configuration.sessionCategory,
            mode: configuration.sessionMode,
            options: configuration.sessionOptions
        )
        try audioSession.setPreferredSampleRate(Double(configuration.sampleRateHz))
        try audioSession.setPreferredIOBufferDuration(
            Double(configuration.hopSizeSamples) / Double(configuration.sampleRateHz)
        )
        try audioSession.setActive(true, options: [])

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(configuration.tapBufferSize),
            format: inputFormat
        ) { [weak self] buffer, _ in
            self?.handleBuffer(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    public func stop() {
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        converter = nil
        targetFormat = nil
        sampleHandler = nil

        do {
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Stop should remain best-effort so UI cleanup is not blocked.
        }
    }

    private func handleBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let targetFormat, let sampleHandler else {
            return
        }

        let convertedBuffer: AVAudioPCMBuffer
        if formatsMatch(buffer.format, targetFormat) {
            convertedBuffer = buffer
        } else {
            let estimatedFrameCount = max(
                1,
                Int(
                    ceil(
                        Double(buffer.frameLength) * targetFormat.sampleRate /
                            buffer.format.sampleRate
                    )
                )
            )
            guard let converter,
                  let outputBuffer = AVAudioPCMBuffer(
                    pcmFormat: targetFormat,
                    frameCapacity: AVAudioFrameCount(estimatedFrameCount)
                  ) else {
                return
            }

            var conversionError: NSError?
            var consumedBuffer = false
            let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
                if consumedBuffer {
                    outStatus.pointee = .noDataNow
                    return nil
                }

                consumedBuffer = true
                outStatus.pointee = .haveData
                return buffer
            }

            guard conversionError == nil, status != .error else {
                return
            }

            convertedBuffer = outputBuffer
        }

        guard let channelData = convertedBuffer.floatChannelData?.pointee else {
            return
        }

        let frameCount = Int(convertedBuffer.frameLength)
        if frameCount == 0 {
            return
        }

        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        sampleHandler(samples)
    }

    private func formatsMatch(_ lhs: AVAudioFormat, _ rhs: AVAudioFormat) -> Bool {
        lhs.sampleRate == rhs.sampleRate &&
            lhs.channelCount == rhs.channelCount &&
            lhs.commonFormat == rhs.commonFormat &&
            lhs.isInterleaved == rhs.isInterleaved
    }
}

public enum AudioCaptureBridgeError: Error {
    case invalidAudioFormat
}
