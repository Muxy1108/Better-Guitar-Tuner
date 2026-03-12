#import "NativeTuningProcessorBridge.h"

#include "dsp_core/pitch_detector.h"
#include "dsp_core/pitch_utils.h"
#include "tuning_engine/tuner.h"

#include <cmath>
#include <deque>
#include <string>
#include <utility>
#include <vector>

namespace {

constexpr float kWeakSignalConfidenceThreshold = 0.75f;
constexpr float kWeakSignalCentsThreshold = 80.0f;
constexpr float kPreciseConfidenceFloor = 0.54f;
constexpr float kBalancedConfidenceFloor = 0.58f;
constexpr float kRelaxedConfidenceFloor = 0.68f;
constexpr float kPreciseWeakSignalThreshold = 0.66f;
constexpr float kBalancedWeakSignalThreshold = 0.72f;
constexpr float kRelaxedWeakSignalThreshold = 0.76f;
constexpr float kPreciseWeakSignalCents = 65.0f;
constexpr float kBalancedWeakSignalCents = 55.0f;
constexpr float kRelaxedWeakSignalCents = 45.0f;

NSString* ToNSString(const std::string& value) {
  return [NSString stringWithUTF8String:value.c_str()];
}

tuning_engine::TuningMode ParseMode(NSString* mode) {
  if ([mode isEqualToString:@"manual"]) {
    return tuning_engine::TuningMode::kManual;
  }

  return tuning_engine::TuningMode::kAuto;
}

NSString* ModeString(tuning_engine::TuningMode mode) {
  return mode == tuning_engine::TuningMode::kManual ? @"manual" : @"auto";
}

NSString* StatusString(tuning_engine::TuningStatus status) {
  switch (status) {
    case tuning_engine::TuningStatus::kTooLow:
      return @"too_low";
    case tuning_engine::TuningStatus::kInTune:
      return @"in_tune";
    case tuning_engine::TuningStatus::kTooHigh:
      return @"too_high";
    case tuning_engine::TuningStatus::kNoPitch:
    default:
      return @"no_pitch";
  }
}

bool IsWeakSignal(const dsp_core::PitchResult& pitch,
                  float weakSignalConfidenceThreshold,
                  float weakSignalCentsThreshold) {
  if (!pitch.has_pitch) {
    return false;
  }

  if (pitch.confidence < weakSignalConfidenceThreshold) {
    return true;
  }

  if (pitch.nearest_midi < 0 || pitch.nearest_note.empty()) {
    return true;
  }

  return std::abs(pitch.cents_offset) > weakSignalCentsThreshold;
}

NSString* SignalStateString(const dsp_core::PitchResult& pitch,
                            float weakSignalConfidenceThreshold,
                            float weakSignalCentsThreshold) {
  if (!pitch.has_pitch) {
    return @"no_pitch";
  }

  if (IsWeakSignal(pitch, weakSignalConfidenceThreshold, weakSignalCentsThreshold)) {
    return @"weak_signal";
  }

  return @"pitched";
}

dsp_core::PitchDetectionConfig DetectionConfigForSensitivity(NSString* sensitivity) {
  dsp_core::PitchDetectionConfig config;
  if ([sensitivity isEqualToString:@"relaxed"]) {
    config.min_signal_rms = 0.010f;
    config.min_signal_peak = 0.032f;
    config.max_yin_threshold = 0.20f;
    config.min_acceptable_confidence = kRelaxedConfidenceFloor;
    return config;
  }

  if ([sensitivity isEqualToString:@"precise"]) {
    config.min_signal_rms = 0.007f;
    config.min_signal_peak = 0.022f;
    config.max_yin_threshold = 0.27f;
    config.min_acceptable_confidence = kPreciseConfidenceFloor;
    return config;
  }

  config.min_signal_rms = 0.008f;
  config.min_signal_peak = 0.025f;
  config.max_yin_threshold = 0.24f;
  config.min_acceptable_confidence = kBalancedConfidenceFloor;
  return config;
}

float WeakSignalConfidenceForSensitivity(NSString* sensitivity) {
  if ([sensitivity isEqualToString:@"relaxed"]) {
    return kRelaxedWeakSignalThreshold;
  }
  if ([sensitivity isEqualToString:@"precise"]) {
    return kPreciseWeakSignalThreshold;
  }
  return kBalancedWeakSignalThreshold;
}

float WeakSignalCentsForSensitivity(NSString* sensitivity) {
  if ([sensitivity isEqualToString:@"relaxed"]) {
    return kRelaxedWeakSignalCents;
  }
  if ([sensitivity isEqualToString:@"precise"]) {
    return kPreciseWeakSignalCents;
  }
  return kBalancedWeakSignalCents;
}

NSDictionary<NSString*, id>* BuildEventPayload(
    const dsp_core::PitchResult& pitch,
    const tuning_engine::TuningResult& result,
    NSString* protocolVersion,
    float weakSignalConfidenceThreshold,
    float weakSignalCentsThreshold) {
  NSMutableDictionary<NSString*, id>* payload = [NSMutableDictionary dictionary];
  payload[@"protocol_version"] = protocolVersion;
  payload[@"stream_kind"] = @"tuning_frame";
  payload[@"tuning_id"] = ToNSString(result.tuning_id);
  payload[@"mode"] = ModeString(result.mode);
  payload[@"target_string_index"] = @(result.target_string_index);
  payload[@"target_note"] = ToNSString(result.target_note);
  payload[@"target_frequency_hz"] = @(result.target_frequency_hz);
  payload[@"detected_frequency_hz"] = @(pitch.detected_frequency_hz);
  payload[@"cents_offset"] = @(result.cents_offset);
  payload[@"status"] = StatusString(result.status);
  payload[@"has_detected_pitch"] = @(pitch.has_pitch);
  payload[@"has_target"] = @(result.has_target);
  payload[@"pitch_confidence"] = @(pitch.confidence);
  payload[@"pitch_note"] = ToNSString(pitch.nearest_note);
  payload[@"pitch_midi"] = @(pitch.nearest_midi);
  payload[@"signal_state"] = SignalStateString(
      pitch, weakSignalConfidenceThreshold, weakSignalCentsThreshold);
  payload[@"signal_rms"] = @(pitch.signal_rms);
  payload[@"signal_peak"] = @(pitch.signal_peak);
  payload[@"pitch_yin_score"] = @(pitch.yin_score);
  payload[@"analysis_reason"] = ToNSString(std::string(dsp_core::to_string(pitch.decision_reason)));

  if (!result.error_message.empty()) {
    payload[@"error_message"] = ToNSString(result.error_message);
  }

  return payload;
}

tuning_engine::TuningPreset BuildPreset(NSString* presetId,
                                        NSString* presetName,
                                        NSString* instrument,
                                        NSArray<NSString*>* notes) {
  tuning_engine::TuningPreset preset;
  preset.id = [presetId UTF8String];
  preset.name = [presetName UTF8String];
  preset.instrument = [instrument UTF8String];
  preset.strings.reserve(notes.count);

  for (NSString* note in notes) {
    tuning_engine::TuningString tuningString;
    tuningString.note = [note UTF8String];
    tuningString.midi_note = dsp_core::note_name_to_midi(tuningString.note);
    tuningString.frequency_hz = tuningString.midi_note >= 0
                                    ? dsp_core::midi_to_frequency_hz(
                                          tuningString.midi_note)
                                    : 0.0f;
    preset.strings.push_back(std::move(tuningString));
  }

  return preset;
}

}  // namespace

@implementation NativeTuningProcessorBridge {
  NSInteger _sampleRate;
  NSInteger _windowSize;
  NSInteger _hopSize;
  NSInteger _samplesSinceLastAnalysis;
  std::deque<float> _sampleBuffer;
  tuning_engine::TuningPreset _preset;
  tuning_engine::TuningMode _mode;
  NSInteger _manualStringIndex;
  BOOL _hasConfiguration;
  NSInteger _previousAutoTargetStringIndex;
  tuning_engine::TuningThresholds _thresholds;
  dsp_core::PitchDetectionConfig _detectionConfig;
  NSString* _protocolVersion;
  float _weakSignalConfidenceThreshold;
  float _weakSignalCentsThreshold;
}

- (instancetype)initWithSampleRate:(NSInteger)sampleRate
                        windowSize:(NSInteger)windowSize
                           hopSize:(NSInteger)hopSize {
  self = [super init];
  if (self == nil) {
    return nil;
  }

  _sampleRate = sampleRate;
  _windowSize = windowSize;
  _hopSize = hopSize;
  _samplesSinceLastAnalysis = 0;
  _mode = tuning_engine::TuningMode::kAuto;
  _manualStringIndex = -1;
  _hasConfiguration = NO;
  _previousAutoTargetStringIndex = -1;
  _thresholds = tuning_engine::kDefaultTuningThresholds;
  _detectionConfig = dsp_core::PitchDetectionConfig{};
  _protocolVersion = @"stage8.v1";
  _weakSignalConfidenceThreshold = kWeakSignalConfidenceThreshold;
  _weakSignalCentsThreshold = kWeakSignalCentsThreshold;
  return self;
}

- (BOOL)updateConfigurationWithPresetId:(NSString *)presetId
                             presetName:(NSString *)presetName
                             instrument:(NSString *)instrument
                                  notes:(NSArray<NSString *> *)notes
                                   mode:(NSString *)mode
                      manualStringIndex:(NSNumber *)manualStringIndex
                           a4ReferenceHz:(double)a4ReferenceHz
                    tuningToleranceCents:(double)tuningToleranceCents
                              sensitivity:(NSString *)sensitivity
                                  error:(NSError * _Nullable __autoreleasing *)error {
  if (notes.count == 0) {
    if (error != nullptr) {
      *error = [NSError errorWithDomain:@"NativeTuningProcessorBridge"
                                   code:1
                               userInfo:@{
                                 NSLocalizedDescriptionKey: @"At least one target note is required."
                               }];
    }
    return NO;
  }

  _preset = BuildPreset(presetId, presetName, instrument, notes);
  _mode = ParseMode(mode);
  _manualStringIndex =
      _mode == tuning_engine::TuningMode::kManual ? manualStringIndex.integerValue : -1;

  if (_mode == tuning_engine::TuningMode::kManual &&
      (_manualStringIndex < 0 ||
       _manualStringIndex >= static_cast<NSInteger>(_preset.strings.size()))) {
    if (error != nullptr) {
      *error = [NSError errorWithDomain:@"NativeTuningProcessorBridge"
                                   code:2
                               userInfo:@{
                                 NSLocalizedDescriptionKey:
                                     @"Manual string index is out of range for the selected preset."
                               }];
    }
    return NO;
  }

  _thresholds = tuning_engine::kDefaultTuningThresholds;
  _thresholds.a4_reference_hz = static_cast<float>(a4ReferenceHz);
  _thresholds.in_tune_cents = static_cast<float>(tuningToleranceCents);
  _detectionConfig = DetectionConfigForSensitivity(sensitivity);
  _weakSignalConfidenceThreshold = WeakSignalConfidenceForSensitivity(sensitivity);
  _weakSignalCentsThreshold = WeakSignalCentsForSensitivity(sensitivity);
  _previousAutoTargetStringIndex = -1;
  _hasConfiguration = YES;
  return YES;
}

- (NSArray<NSDictionary<NSString *,id> *> *)processSamples:(const float *)samples
                                                      count:(NSInteger)count {
  if (!_hasConfiguration || samples == nullptr || count <= 0) {
    return @[];
  }

  NSMutableArray<NSDictionary<NSString*, id>*>* events = [NSMutableArray array];

  for (NSInteger index = 0; index < count; ++index) {
    _sampleBuffer.push_back(samples[index]);
  }
  _samplesSinceLastAnalysis += count;

  while (_sampleBuffer.size() > static_cast<std::size_t>(_windowSize)) {
    _sampleBuffer.pop_front();
  }

  if (_sampleBuffer.size() < static_cast<std::size_t>(_windowSize) ||
      _samplesSinceLastAnalysis < _hopSize) {
    return events;
  }

  _samplesSinceLastAnalysis = 0;
  std::vector<float> analysisWindow(_sampleBuffer.begin(), _sampleBuffer.end());
  const dsp_core::PitchResult pitch = dsp_core::detect_pitch(
      analysisWindow.data(), static_cast<int>(analysisWindow.size()),
      static_cast<int>(_sampleRate), _detectionConfig);
  const tuning_engine::TuningResult result = tuning_engine::evaluate_tuning(
      pitch, _preset, _mode, static_cast<int>(_manualStringIndex),
      static_cast<int>(_previousAutoTargetStringIndex), _thresholds);
  if (_mode == tuning_engine::TuningMode::kAuto && result.target_string_index >= 0) {
    _previousAutoTargetStringIndex = result.target_string_index;
  }

  [events addObject:BuildEventPayload(
      pitch, result, _protocolVersion, _weakSignalConfidenceThreshold,
      _weakSignalCentsThreshold)];
  return events;
}

- (void)reset {
  _sampleBuffer.clear();
  _samplesSinceLastAnalysis = 0;
  _previousAutoTargetStringIndex = -1;
}

@end
