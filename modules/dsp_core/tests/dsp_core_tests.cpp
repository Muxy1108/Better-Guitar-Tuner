#include "dsp_core/pitch_detector.h"
#include "dsp_core/pitch_utils.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>

namespace {

constexpr int kSampleRate = 48'000;
constexpr int kLongWindowSize = 8'192;
constexpr float kPi = 3.14159265358979323846f;

bool Check(bool condition, const std::string& message) {
  if (!condition) {
    std::cerr << "FAIL: " << message << "\n";
    return false;
  }
  return true;
}

bool CheckNear(float actual, float expected, float tolerance,
               const std::string& message) {
  if (std::abs(actual - expected) > tolerance) {
    std::cerr << "FAIL: " << message << " (expected " << expected
              << ", got " << actual << ", tolerance " << tolerance << ")\n";
    return false;
  }
  return true;
}

std::vector<float> GenerateSineWave(float frequency_hz, int sample_rate,
                                    int sample_count, float amplitude,
                                    float dc_offset = 0.0f) {
  std::vector<float> samples(static_cast<std::size_t>(sample_count), 0.0f);
  for (int i = 0; i < sample_count; ++i) {
    const float phase =
        2.0f * kPi * frequency_hz * static_cast<float>(i) /
        static_cast<float>(sample_rate);
    samples[static_cast<std::size_t>(i)] =
        dc_offset + (amplitude * std::sin(phase));
  }
  return samples;
}

std::vector<float> GeneratePluckedTone(float frequency_hz, int sample_rate,
                                       int sample_count, float amplitude,
                                       float dc_offset = 0.0f) {
  constexpr float kHarmonicWeights[] = {1.0f, 0.32f, 0.14f, 0.07f};
  constexpr float kHarmonicPhases[] = {0.0f, 0.35f, 0.6f, 1.1f};
  constexpr float kWeightSum = 1.53f;

  std::vector<float> samples(static_cast<std::size_t>(sample_count), 0.0f);
  for (int i = 0; i < sample_count; ++i) {
    const float time_s =
        static_cast<float>(i) / static_cast<float>(sample_rate);
    const float attack = std::min(1.0f, time_s * 180.0f);
    const float decay = std::exp(-3.2f * time_s);

    float sample = 0.0f;
    for (int harmonic = 0; harmonic < 4; ++harmonic) {
      const float harmonic_frequency =
          frequency_hz * static_cast<float>(harmonic + 1);
      const float phase =
          (2.0f * kPi * harmonic_frequency * time_s) +
          kHarmonicPhases[harmonic];
      sample += kHarmonicWeights[harmonic] * std::sin(phase);
    }

    samples[static_cast<std::size_t>(i)] =
        dc_offset + ((amplitude * attack * decay * sample) / kWeightSum);
  }
  return samples;
}

std::vector<float> GenerateWeightedHarmonicTone(
    float fundamental_frequency_hz, int sample_rate, int sample_count,
    const std::vector<float>& harmonic_weights, float amplitude,
    float dc_offset = 0.0f) {
  float weight_sum = 0.0f;
  for (float weight : harmonic_weights) {
    weight_sum += std::abs(weight);
  }
  if (weight_sum <= 0.0f) {
    return std::vector<float>(static_cast<std::size_t>(sample_count), dc_offset);
  }

  std::vector<float> samples(static_cast<std::size_t>(sample_count), 0.0f);
  for (int i = 0; i < sample_count; ++i) {
    const float time_s =
        static_cast<float>(i) / static_cast<float>(sample_rate);
    const float attack = std::min(1.0f, time_s * 200.0f);
    const float decay = std::exp(-2.6f * time_s);

    float sample = 0.0f;
    for (std::size_t harmonic = 0; harmonic < harmonic_weights.size();
         ++harmonic) {
      const float harmonic_frequency =
          fundamental_frequency_hz * static_cast<float>(harmonic + 1U);
      const float phase =
          2.0f * kPi * harmonic_frequency * time_s +
          (0.21f * static_cast<float>(harmonic));
      sample += harmonic_weights[harmonic] * std::sin(phase);
    }

    samples[static_cast<std::size_t>(i)] =
        dc_offset + ((amplitude * attack * decay * sample) / weight_sum);
  }
  return samples;
}

std::vector<float> GenerateNoise(int sample_count, float amplitude) {
  std::vector<float> samples(static_cast<std::size_t>(sample_count), 0.0f);
  std::uint32_t state = 0x12345678u;
  for (int i = 0; i < sample_count; ++i) {
    state = (state * 1'664'525u) + 1'013'904'223u;
    const float unit = static_cast<float>((state >> 8) & 0x00FFFFFFu) /
                           static_cast<float>(0x00FFFFFFu) -
                       0.5f;
    samples[static_cast<std::size_t>(i)] = amplitude * 2.0f * unit;
  }
  return samples;
}

std::vector<float> MixSignals(const std::vector<float>& left,
                              const std::vector<float>& right,
                              float right_gain = 1.0f) {
  std::vector<float> mixed = left;
  const std::size_t sample_count = std::min(left.size(), right.size());
  for (std::size_t i = 0; i < sample_count; ++i) {
    mixed[i] += right[i] * right_gain;
  }
  return mixed;
}

std::vector<float> AddLeadingTransient(const std::vector<float>& base_signal,
                                       int transient_samples,
                                       float transient_amplitude) {
  std::vector<float> with_transient = base_signal;
  const int bounded_transient_samples = std::min(
      transient_samples, static_cast<int>(with_transient.size()));
  const std::vector<float> noise =
      GenerateNoise(bounded_transient_samples, transient_amplitude * 0.35f);

  for (int i = 0; i < bounded_transient_samples; ++i) {
    const float decay = std::exp(-8.0f * static_cast<float>(i) /
                                 static_cast<float>(bounded_transient_samples));
    const float click = transient_amplitude * decay * ((i % 2 == 0) ? 1.0f : -1.0f);
    with_transient[static_cast<std::size_t>(i)] +=
        click + noise[static_cast<std::size_t>(i)];
  }

  return with_transient;
}

bool TestPitchUtils() {
  if (!Check(dsp_core::frequency_to_midi(440.0f) == 69,
             "440 Hz should map to MIDI 69") ||
      !Check(dsp_core::note_name_to_midi("A4") == 69,
             "A4 should parse to MIDI 69") ||
      !Check(dsp_core::note_name_to_midi("Bb3") == 58,
             "flat note names should parse") ||
      !Check(dsp_core::note_name_to_midi("C-1") == 0,
             "negative octaves should parse") ||
      !Check(dsp_core::note_name_to_midi("H2") == -1,
             "invalid pitch classes should be rejected") ||
      !Check(dsp_core::note_name_to_midi("A#") == -1,
             "missing octaves should be rejected") ||
      !Check(dsp_core::midi_to_note_name(69) == "A4",
             "MIDI 69 should render as A4") ||
      !Check(dsp_core::midi_to_note_name(-1).empty(),
             "negative MIDI notes should render as empty") ||
      !CheckNear(dsp_core::midi_to_frequency_hz(69), 440.0f, 0.001f,
                 "MIDI 69 should map to 440 Hz") ||
      !CheckNear(dsp_core::midi_to_frequency_hz(69, 442.0f), 442.0f, 0.001f,
                 "alternate A4 references should be supported") ||
      !CheckNear(dsp_core::calculate_cents_offset(440.0f, 69), 0.0f, 0.001f,
                 "exact MIDI frequencies should have zero cents offset") ||
      !CheckNear(dsp_core::calculate_cents_offset(
                     dsp_core::midi_to_frequency_hz(58), 58),
                 0.0f, 0.001f,
                 "converted MIDI frequencies should round-trip to zero cents") ||
      !Check(dsp_core::frequency_to_midi(0.0f) == -1,
             "non-positive frequencies should not map to MIDI") ||
      !CheckNear(dsp_core::midi_to_frequency_hz(69, 0.0f), 0.0f, 0.0f,
                 "non-positive A4 references should return 0 Hz") ||
      !CheckNear(dsp_core::calculate_cents_offset(-10.0f, 69), 0.0f, 0.0f,
                 "non-positive frequencies should report zero cents")) {
    return false;
  }

  return true;
}

bool TestDetectsHarmonicRichGuitarLikeTone() {
  const float target_frequency_hz = 82.4069f;  // E2
  const std::vector<float> samples = GeneratePluckedTone(
      target_frequency_hz, kSampleRate, kLongWindowSize, 0.42f);

  const dsp_core::PitchResult result =
      dsp_core::detect_pitch(samples.data(), static_cast<int>(samples.size()),
                             kSampleRate);

  if (!Check(result.has_pitch, "harmonic-rich plucked E2 should be detected") ||
      !Check(result.decision_reason == dsp_core::PitchDecisionReason::kNone,
             "successful detection should report no rejection reason") ||
      !Check(result.nearest_note == "E2",
             "detected E2 should map to the nearest E2 note") ||
      !Check(result.nearest_midi == 40,
             "detected E2 should map to MIDI 40") ||
      !CheckNear(result.detected_frequency_hz, target_frequency_hz, 0.8f,
                 "detected E2 frequency should stay close to the source") ||
      !Check(std::abs(result.cents_offset) < 10.0f,
             "detected E2 should be close to in tune") ||
      !Check(result.confidence > 0.80f,
             "clean plucked tones should produce strong confidence") ||
      !Check(result.signal_rms > 0.02f,
             "clean plucked tones should exceed the RMS gate") ||
      !Check(result.signal_peak > 0.05f,
             "clean plucked tones should exceed the peak gate")) {
    return false;
  }

  return true;
}

bool TestPrefersFundamentalWhenSecondHarmonicDominates() {
  const float target_frequency_hz = 82.4069f;  // E2
  const std::vector<float> samples = GenerateWeightedHarmonicTone(
      target_frequency_hz, kSampleRate, kLongWindowSize,
      {0.14f, 1.00f, 0.22f, 0.08f}, 0.42f);

  const dsp_core::PitchResult result =
      dsp_core::detect_pitch(samples.data(), static_cast<int>(samples.size()),
                             kSampleRate);

  if (!Check(result.has_pitch,
             "second-harmonic-heavy tones should still produce a pitch") ||
      !Check(result.nearest_note == "E2",
             "second-harmonic-heavy tones should prefer the fundamental note") ||
      !CheckNear(result.detected_frequency_hz, target_frequency_hz, 1.0f,
                 "second-harmonic-heavy tones should stay near the fundamental")) {
    return false;
  }

  return true;
}

bool TestDetunedPitchReportsMeaningfulCentsOffset() {
  const float cents_offset = 18.0f;
  const float target_frequency_hz =
      110.0f * std::pow(2.0f, cents_offset / 1200.0f);
  const std::vector<float> samples = GeneratePluckedTone(
      target_frequency_hz, kSampleRate, kLongWindowSize, 0.38f);

  const dsp_core::PitchResult result =
      dsp_core::detect_pitch(samples.data(), static_cast<int>(samples.size()),
                             kSampleRate);

  if (!Check(result.has_pitch, "detuned plucked A2 should still be detected") ||
      !Check(result.nearest_note == "A2",
             "detuned A2 should still resolve to A2") ||
      !CheckNear(result.cents_offset, cents_offset, 3.0f,
                 "detected cents offset should stay close to the source detune")) {
    return false;
  }

  return true;
}

bool TestLeadingTransientDoesNotDerailSteadyPitch() {
  const float target_frequency_hz = 110.0f;  // A2
  const std::vector<float> base = GeneratePluckedTone(
      target_frequency_hz, kSampleRate, kLongWindowSize, 0.34f);
  const std::vector<float> transient_frame =
      AddLeadingTransient(base, kLongWindowSize / 6, 0.80f);

  const dsp_core::PitchResult result = dsp_core::detect_pitch(
      transient_frame.data(), static_cast<int>(transient_frame.size()),
      kSampleRate);

  if (!Check(result.has_pitch,
             "strong leading transients should not suppress a stable trailing note") ||
      !Check(result.nearest_note == "A2",
             "attack-heavy frames should still resolve to the steady note") ||
      !CheckNear(result.detected_frequency_hz, target_frequency_hz, 1.0f,
                 "attack-heavy frames should stay close to the steady-state pitch")) {
    return false;
  }

  return true;
}

bool TestDcOffsetIsRemovedBeforeAnalysis() {
  const std::vector<float> clean = GeneratePluckedTone(
      110.0f, kSampleRate, kLongWindowSize, 0.35f);
  const std::vector<float> offset = GeneratePluckedTone(
      110.0f, kSampleRate, kLongWindowSize, 0.35f, 0.30f);

  const dsp_core::PitchResult clean_result =
      dsp_core::detect_pitch(clean.data(), static_cast<int>(clean.size()),
                             kSampleRate);
  const dsp_core::PitchResult offset_result =
      dsp_core::detect_pitch(offset.data(), static_cast<int>(offset.size()),
                             kSampleRate);

  if (!Check(clean_result.has_pitch && offset_result.has_pitch,
             "DC offset should not prevent pitch detection") ||
      !CheckNear(offset_result.signal_peak, clean_result.signal_peak, 0.05f,
                 "centered peak should stay close after DC removal") ||
      !CheckNear(offset_result.signal_rms, clean_result.signal_rms, 0.02f,
                 "centered RMS should stay close after DC removal") ||
      !Check(offset_result.nearest_midi == clean_result.nearest_midi,
             "DC offset should not change the nearest MIDI note") ||
      !CheckNear(offset_result.detected_frequency_hz,
                 clean_result.detected_frequency_hz, 0.25f,
                 "DC offset should not materially change the detected frequency")) {
    return false;
  }

  return true;
}

bool TestRejectsInvalidInputAndShortWindows() {
  const dsp_core::PitchResult invalid =
      dsp_core::detect_pitch(nullptr, 128, kSampleRate);

  const std::vector<float> short_window =
      GenerateSineWave(220.0f, kSampleRate, 96, 0.25f);
  const dsp_core::PitchResult short_result =
      dsp_core::detect_pitch(short_window.data(),
                             static_cast<int>(short_window.size()),
                             kSampleRate);

  if (!Check(!invalid.has_pitch,
             "null sample input should be rejected") ||
      !Check(invalid.decision_reason ==
                 dsp_core::PitchDecisionReason::kInvalidInput,
             "null sample input should surface invalid_input") ||
      !Check(!short_result.has_pitch,
             "very short windows should be rejected") ||
      !Check(short_result.decision_reason ==
                 dsp_core::PitchDecisionReason::kInsufficientWindow,
             "very short windows should surface insufficient_window")) {
    return false;
  }

  return true;
}

bool TestRejectsWeakSignalsAtRmsAndPeakGates() {
  const std::vector<float> low_rms =
      GenerateSineWave(220.0f, kSampleRate, kLongWindowSize, 0.0010f);
  const dsp_core::PitchResult low_rms_result =
      dsp_core::detect_pitch(low_rms.data(), static_cast<int>(low_rms.size()),
                             kSampleRate);

  dsp_core::PitchDetectionConfig peak_sensitive_config;
  peak_sensitive_config.min_signal_rms = 0.0020f;
  peak_sensitive_config.min_signal_peak = 0.0200f;
  const std::vector<float> low_peak =
      GenerateSineWave(220.0f, kSampleRate, kLongWindowSize, 0.0100f);
  const dsp_core::PitchResult low_peak_result = dsp_core::detect_pitch(
      low_peak.data(), static_cast<int>(low_peak.size()), kSampleRate,
      peak_sensitive_config);

  if (!Check(!low_rms_result.has_pitch,
             "sub-threshold RMS frames should be rejected") ||
      !Check(low_rms_result.decision_reason ==
                 dsp_core::PitchDecisionReason::kSignalTooWeakRms,
             "sub-threshold RMS frames should report signal_too_weak_rms") ||
      !Check(!low_peak_result.has_pitch,
             "sub-threshold peak frames should be rejected") ||
      !Check(low_peak_result.decision_reason ==
                 dsp_core::PitchDecisionReason::kSignalTooWeakPeak,
             "sub-threshold peak frames should report signal_too_weak_peak")) {
    return false;
  }

  return true;
}

bool TestRejectsUnstableFramesForPeriodicityAndConfidence() {
  const std::vector<float> noise = GenerateNoise(kLongWindowSize, 0.35f);
  const dsp_core::PitchResult noise_result =
      dsp_core::detect_pitch(noise.data(), static_cast<int>(noise.size()),
                             kSampleRate);

  const std::vector<float> tone = GeneratePluckedTone(
      110.0f, kSampleRate, kLongWindowSize, 0.20f);
  const std::vector<float> noisy_tone =
      MixSignals(tone, GenerateNoise(kLongWindowSize, 0.22f));

  dsp_core::PitchDetectionConfig relaxed_config;
  relaxed_config.max_yin_threshold = 0.95f;
  relaxed_config.min_acceptable_confidence = 0.0f;
  const dsp_core::PitchResult baseline = dsp_core::detect_pitch(
      noisy_tone.data(), static_cast<int>(noisy_tone.size()), kSampleRate,
      relaxed_config);

  dsp_core::PitchDetectionConfig strict_config = relaxed_config;
  strict_config.min_acceptable_confidence =
      std::min(1.01f, baseline.confidence + 0.05f);
  const dsp_core::PitchResult strict_result = dsp_core::detect_pitch(
      noisy_tone.data(), static_cast<int>(noisy_tone.size()), kSampleRate,
      strict_config);

  if (!Check(!noise_result.has_pitch,
             "wideband noise should not be reported as pitch") ||
      !Check(noise_result.decision_reason ==
                 dsp_core::PitchDecisionReason::kPoorPeriodicity,
             "wideband noise should fail the periodicity gate") ||
      !Check(baseline.detected_frequency_hz > 0.0f,
             "relaxed analysis should still estimate a candidate frequency") ||
      !Check(!strict_result.has_pitch,
             "raising the confidence gate should reject the same candidate") ||
      !Check(strict_result.decision_reason ==
                 dsp_core::PitchDecisionReason::kLowConfidence,
             "strict confidence requirements should surface low_confidence")) {
    return false;
  }

  return true;
}

bool TestReportsFrequencyOutOfRangeWhenConfigTightens() {
  const std::vector<float> samples =
      GenerateSineWave(995.0f, kSampleRate, kLongWindowSize, 0.22f);

  const dsp_core::PitchResult baseline =
      dsp_core::detect_pitch(samples.data(), static_cast<int>(samples.size()),
                             kSampleRate);
  if (!Check(baseline.has_pitch,
             "a clean 995 Hz sine should detect under the default range")) {
    return false;
  }

  dsp_core::PitchDetectionConfig restricted_config;
  restricted_config.max_detectable_frequency_hz =
      baseline.detected_frequency_hz - 0.25f;
  const dsp_core::PitchResult restricted = dsp_core::detect_pitch(
      samples.data(), static_cast<int>(samples.size()), kSampleRate,
      restricted_config);

  if (!Check(!restricted.has_pitch,
             "tightening the max frequency range should reject the same tone") ||
      !Check(restricted.decision_reason ==
                 dsp_core::PitchDecisionReason::kFrequencyOutOfRange,
             "out-of-range tones should surface frequency_out_of_range")) {
    return false;
  }

  return true;
}

}  // namespace

int main() {
  if (!TestPitchUtils() ||
      !TestDetectsHarmonicRichGuitarLikeTone() ||
      !TestPrefersFundamentalWhenSecondHarmonicDominates() ||
      !TestDetunedPitchReportsMeaningfulCentsOffset() ||
      !TestLeadingTransientDoesNotDerailSteadyPitch() ||
      !TestDcOffsetIsRemovedBeforeAnalysis() ||
      !TestRejectsInvalidInputAndShortWindows() ||
      !TestRejectsWeakSignalsAtRmsAndPeakGates() ||
      !TestRejectsUnstableFramesForPeriodicityAndConfidence() ||
      !TestReportsFrequencyOutOfRangeWhenConfigTightens()) {
    return 1;
  }

  std::cout << "dsp_core_tests passed\n";
  return 0;
}
