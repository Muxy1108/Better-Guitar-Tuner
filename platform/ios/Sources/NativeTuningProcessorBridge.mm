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

bool IsWeakSignal(const dsp_core::PitchResult& pitch) {
  if (!pitch.has_pitch) {
    return false;
  }

  if (pitch.confidence < kWeakSignalConfidenceThreshold) {
    return true;
  }

  if (pitch.nearest_midi < 0 || pitch.nearest_note.empty()) {
    return true;
  }

  return std::abs(pitch.cents_offset) > kWeakSignalCentsThreshold;
}

NSString* SignalStateString(const dsp_core::PitchResult& pitch) {
  if (!pitch.has_pitch) {
    return @"no_pitch";
  }

  if (IsWeakSignal(pitch)) {
    return @"weak_signal";
  }

  return @"pitched";
}

NSDictionary<NSString*, id>* BuildEventPayload(
    const dsp_core::PitchResult& pitch,
    const tuning_engine::TuningResult& result) {
  NSMutableDictionary<NSString*, id>* payload = [NSMutableDictionary dictionary];
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
  payload[@"signal_state"] = SignalStateString(pitch);

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
  return self;
}

- (BOOL)updateConfigurationWithPresetId:(NSString *)presetId
                             presetName:(NSString *)presetName
                             instrument:(NSString *)instrument
                                  notes:(NSArray<NSString *> *)notes
                                   mode:(NSString *)mode
                      manualStringIndex:(NSNumber *)manualStringIndex
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
      static_cast<int>(_sampleRate));
  const tuning_engine::TuningResult result = tuning_engine::evaluate_tuning(
      pitch, _preset, _mode, static_cast<int>(_manualStringIndex));

  [events addObject:BuildEventPayload(pitch, result)];
  return events;
}

- (void)reset {
  _sampleBuffer.clear();
  _samplesSinceLastAnalysis = 0;
}

@end
