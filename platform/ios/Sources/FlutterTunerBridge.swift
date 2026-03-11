import AVFoundation
import Flutter
import Foundation

public final class FlutterTunerBridge: NSObject {
    private enum Channel {
        static let methods = "better_guitar_tuner/audio_bridge/methods"
        static let events = "better_guitar_tuner/audio_bridge/events"
    }

    private let captureBridge = AudioCaptureBridge()
    private let processor = NativeTuningProcessorBridge(
        sampleRate: 48_000,
        windowSize: 4_096,
        hopSize: 1_024
    )
    private let configuration = AudioCaptureConfiguration()

    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    public override init() {
        super.init()
    }

    public func attach(registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let methodChannel = FlutterMethodChannel(
            name: Channel.methods,
            binaryMessenger: messenger
        )
        let eventChannel = FlutterEventChannel(
            name: Channel.events,
            binaryMessenger: messenger
        )

        methodChannel.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
        eventChannel.setStreamHandler(self)

        self.methodChannel = methodChannel
        self.eventChannel = eventChannel
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getMicrophonePermissionStatus":
            result(mapPermissionStatus(AVAudioSession.sharedInstance().recordPermission))
        case "requestMicrophonePermission":
            requestMicrophonePermission(result: result)
        case "startListening":
            startListening(arguments: call.arguments, result: result)
        case "stopListening":
            stopListening()
            result(nil)
        case "updateConfiguration":
            updateConfiguration(arguments: call.arguments, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func requestMicrophonePermission(result: @escaping FlutterResult) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                result(granted ? "granted" : "denied")
            }
        }
    }

    private func startListening(arguments: Any?, result: @escaping FlutterResult) {
        guard AVAudioSession.sharedInstance().recordPermission == .granted else {
            result(
                FlutterError(
                    code: "permission_denied",
                    message: "Microphone permission was not granted.",
                    details: nil
                )
            )
            return
        }

        do {
            try applyConfiguration(arguments: arguments)
            try captureBridge.start(configuration: configuration) { [weak self] samples in
                self?.processSamples(samples)
            }
            result(nil)
        } catch {
            stopListening()
            result(
                FlutterError(
                    code: "start_failed",
                    message: error.localizedDescription,
                    details: nil
                )
            )
        }
    }

    private func stopListening() {
        captureBridge.stop()
        processor.reset()
    }

    private func updateConfiguration(arguments: Any?, result: @escaping FlutterResult) {
        do {
            try applyConfiguration(arguments: arguments)
            result(nil)
        } catch {
            result(
                FlutterError(
                    code: "config_failed",
                    message: error.localizedDescription,
                    details: nil
                )
            )
        }
    }

    private func applyConfiguration(arguments: Any?) throws {
        guard let arguments = arguments as? [String: Any],
              let presetId = arguments["presetId"] as? String,
              let presetName = arguments["presetName"] as? String,
              let instrument = arguments["instrument"] as? String,
              let notes = arguments["notes"] as? [String],
              let mode = arguments["mode"] as? String else {
            throw FlutterTunerBridgeError.invalidArguments
        }

        let manualStringIndex = arguments["manualStringIndex"] as? NSNumber
        var configurationError: NSError?
        let applied = processor.updateConfiguration(
            withPresetId: presetId,
            presetName: presetName,
            instrument: instrument,
            notes: notes,
            mode: mode,
            manualStringIndex: manualStringIndex,
            error: &configurationError
        )

        if !applied {
            throw configurationError ?? FlutterTunerBridgeError.invalidArguments
        }
    }

    private func processSamples(_ samples: [Float]) {
        samples.withUnsafeBufferPointer { [weak self] buffer in
            guard let self else {
                return
            }

            let events = processor.processSamples(buffer.baseAddress, count: buffer.count)
            if events.isEmpty {
                return
            }

            DispatchQueue.main.async {
                events.forEach { event in
                    self.eventSink?(event)
                }
            }
        }
    }

    private func mapPermissionStatus(_ permission: AVAudioSession.RecordPermission) -> String {
        switch permission {
        case .granted:
            return "granted"
        case .denied:
            return "denied"
        case .undetermined:
            return "unknown"
        @unknown default:
            return "unknown"
        }
    }
}

extension FlutterTunerBridge: FlutterStreamHandler {
    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        _ = arguments
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        _ = arguments
        self.eventSink = nil
        return nil
    }
}

private enum FlutterTunerBridgeError: LocalizedError {
    case invalidArguments

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return "Invalid tuner bridge configuration."
        }
    }
}
