import AVFoundation
import Flutter
import Foundation

public final class FlutterTunerBridge: NSObject {
    private enum Channel {
        static let methods = NativeBridgeContract.methodChannelName
        static let events = NativeBridgeContract.eventChannelName
    }

    private enum NativeBridgeContract {
        static let methodChannelName = "better_guitar_tuner/audio_bridge/methods"
        static let eventChannelName = "better_guitar_tuner/audio_bridge/events"
        static let protocolVersion = "stage8.v1"

        static let presetIdKey = "presetId"
        static let presetNameKey = "presetName"
        static let instrumentKey = "instrument"
        static let notesKey = "notes"
        static let modeKey = "mode"
        static let manualStringIndexKey = "manualStringIndex"
        static let a4ReferenceHzKey = "a4ReferenceHz"
        static let tuningToleranceCentsKey = "tuningToleranceCents"
        static let sensitivityKey = "sensitivity"
        static let protocolVersionKey = "protocolVersion"
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
              let presetId = arguments[NativeBridgeContract.presetIdKey] as? String,
              let presetName = arguments[NativeBridgeContract.presetNameKey] as? String,
              let instrument = arguments[NativeBridgeContract.instrumentKey] as? String,
              let notes = arguments[NativeBridgeContract.notesKey] as? [String],
              let mode = arguments[NativeBridgeContract.modeKey] as? String else {
            throw FlutterTunerBridgeError.invalidArguments
        }

        let manualStringIndex = arguments[NativeBridgeContract.manualStringIndexKey] as? NSNumber
        let a4ReferenceHz =
            (arguments[NativeBridgeContract.a4ReferenceHzKey] as? NSNumber)?.doubleValue ?? 440.0
        let tuningToleranceCents =
            (arguments[NativeBridgeContract.tuningToleranceCentsKey] as? NSNumber)?.doubleValue ?? 5.0
        let sensitivity =
            arguments[NativeBridgeContract.sensitivityKey] as? String ?? "balanced"
        let protocolVersion =
            arguments[NativeBridgeContract.protocolVersionKey] as? String ??
            NativeBridgeContract.protocolVersion
        if protocolVersion != NativeBridgeContract.protocolVersion {
            throw FlutterTunerBridgeError.unsupportedProtocolVersion(protocolVersion)
        }
        var configurationError: NSError?
        let applied = processor.updateConfiguration(
            withPresetId: presetId,
            presetName: presetName,
            instrument: instrument,
            notes: notes,
            mode: mode,
            manualStringIndex: manualStringIndex,
            a4ReferenceHz: a4ReferenceHz,
            tuningToleranceCents: tuningToleranceCents,
            sensitivity: sensitivity,
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
    case unsupportedProtocolVersion(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return "Invalid tuner bridge configuration."
        case let .unsupportedProtocolVersion(version):
            return "Unsupported tuner bridge protocol version: \(version)"
        }
    }
}
