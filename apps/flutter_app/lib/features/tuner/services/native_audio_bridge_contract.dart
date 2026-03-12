class NativeAudioBridgeContract {
  const NativeAudioBridgeContract._();

  static const String methodChannelName =
      'better_guitar_tuner/audio_bridge/methods';
  static const String eventChannelName =
      'better_guitar_tuner/audio_bridge/events';

  static const String protocolVersion = 'stage8.v1';

  static const String getMicrophonePermissionStatus =
      'getMicrophonePermissionStatus';
  static const String requestMicrophonePermission =
      'requestMicrophonePermission';
  static const String startListening = 'startListening';
  static const String stopListening = 'stopListening';
  static const String updateConfiguration = 'updateConfiguration';

  static const String presetIdKey = 'presetId';
  static const String presetNameKey = 'presetName';
  static const String instrumentKey = 'instrument';
  static const String notesKey = 'notes';
  static const String modeKey = 'mode';
  static const String manualStringIndexKey = 'manualStringIndex';
  static const String a4ReferenceHzKey = 'a4ReferenceHz';
  static const String tuningToleranceCentsKey = 'tuningToleranceCents';
  static const String sensitivityKey = 'sensitivity';
  static const String protocolVersionKey = 'protocolVersion';
  static const String streamKindKey = 'streamKind';

  static const String tuningFrameStreamKind = 'tuning_frame';
}
