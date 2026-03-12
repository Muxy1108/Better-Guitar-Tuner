#include "dsp_core/pitch_detector.h"

#include "dsp_core/pitch_utils.h"

#include <algorithm>
#include <cmath>
#include <limits>
#include <vector>

namespace dsp_core {
namespace {

struct SignalMetrics {
  float rms = 0.0f;
  float peak = 0.0f;
};

SignalMetrics RemoveDcOffset(const float* samples, int sample_count,
                             std::vector<float>* centered_samples) {
  SignalMetrics metrics{};
  centered_samples->assign(static_cast<std::size_t>(sample_count), 0.0f);

  double mean = 0.0;
  for (int i = 0; i < sample_count; ++i) {
    mean += samples[i];
  }
  mean /= static_cast<double>(sample_count);

  double energy = 0.0;
  float peak = 0.0f;
  for (int i = 0; i < sample_count; ++i) {
    const float centered_sample =
        static_cast<float>(static_cast<double>(samples[i]) - mean);
    (*centered_samples)[static_cast<std::size_t>(i)] = centered_sample;
    energy += static_cast<double>(centered_sample) *
              static_cast<double>(centered_sample);
    peak = std::max(peak, std::abs(centered_sample));
  }

  metrics.rms =
      static_cast<float>(std::sqrt(energy / static_cast<double>(sample_count)));
  metrics.peak = peak;
  return metrics;
}

void ComputeDifferenceFunction(const std::vector<float>& samples, int max_lag,
                               std::vector<double>* difference) {
  difference->assign(static_cast<std::size_t>(max_lag + 1), 0.0);

  const int sample_count = static_cast<int>(samples.size());
  for (int lag = 1; lag <= max_lag; ++lag) {
    double sum = 0.0;
    for (int i = 0; i + lag < sample_count; ++i) {
      const double delta = static_cast<double>(samples[static_cast<std::size_t>(i)]) -
                           static_cast<double>(samples[static_cast<std::size_t>(i + lag)]);
      sum += delta * delta;
    }
    (*difference)[static_cast<std::size_t>(lag)] = sum;
  }
}

void ComputeCumulativeMeanNormalizedDifference(
    const std::vector<double>& difference, std::vector<double>* cmndf) {
  cmndf->assign(difference.size(), 1.0);

  double running_sum = 0.0;
  for (std::size_t lag = 1; lag < difference.size(); ++lag) {
    running_sum += difference[lag];
    if (running_sum > 0.0) {
      (*cmndf)[lag] =
          difference[lag] * static_cast<double>(lag) / running_sum;
    }
  }
}

int FindBestLag(const std::vector<double>& cmndf, int min_lag, int max_lag,
                double max_yin_threshold, double* best_score) {
  *best_score = std::numeric_limits<double>::max();
  int best_lag = -1;

  for (int lag = min_lag; lag <= max_lag; ++lag) {
    const double score = cmndf[static_cast<std::size_t>(lag)];
    if (score < *best_score) {
      *best_score = score;
      best_lag = lag;
    }
  }

  if (best_lag < 0) {
    return -1;
  }

  if (*best_score <= max_yin_threshold) {
    int lag = best_lag;
    while (lag + 1 <= max_lag &&
           cmndf[static_cast<std::size_t>(lag + 1)] <= *best_score) {
      ++lag;
      *best_score = cmndf[static_cast<std::size_t>(lag)];
      best_lag = lag;
    }
  }

  return best_lag;
}

double RefineLagParabolically(const std::vector<double>& cmndf, int lag,
                              int min_lag, int max_lag) {
  double refined_lag = static_cast<double>(lag);
  if (lag <= min_lag || lag >= max_lag) {
    return refined_lag;
  }

  const double left = cmndf[static_cast<std::size_t>(lag - 1)];
  const double center = cmndf[static_cast<std::size_t>(lag)];
  const double right = cmndf[static_cast<std::size_t>(lag + 1)];
  const double denominator = left - (2.0 * center) + right;
  if (std::abs(denominator) <= 1e-12) {
    return refined_lag;
  }

  refined_lag += 0.5 * (left - right) / denominator;
  return refined_lag;
}

}  // namespace

std::string_view to_string(PitchDecisionReason reason) {
  switch (reason) {
    case PitchDecisionReason::kNone:
      return "none";
    case PitchDecisionReason::kInvalidInput:
      return "invalid_input";
    case PitchDecisionReason::kInsufficientWindow:
      return "insufficient_window";
    case PitchDecisionReason::kSignalTooWeakRms:
      return "signal_too_weak_rms";
    case PitchDecisionReason::kSignalTooWeakPeak:
      return "signal_too_weak_peak";
    case PitchDecisionReason::kNoCandidate:
      return "no_candidate";
    case PitchDecisionReason::kPoorPeriodicity:
      return "poor_periodicity";
    case PitchDecisionReason::kLowConfidence:
      return "low_confidence";
    case PitchDecisionReason::kFrequencyOutOfRange:
      return "frequency_out_of_range";
    case PitchDecisionReason::kNoMidiMatch:
      return "no_midi_match";
  }

  return "none";
}

PitchResult detect_pitch(const float* samples, int sample_count, int sample_rate) {
  return detect_pitch(samples, sample_count, sample_rate, PitchDetectionConfig{});
}

PitchResult detect_pitch(const float* samples, int sample_count, int sample_rate,
                         const PitchDetectionConfig& config) {
  PitchResult result{};

  if (samples == nullptr || sample_count <= 0 || sample_rate <= 0) {
    result.decision_reason = PitchDecisionReason::kInvalidInput;
    return result;
  }

  const int min_lag =
      std::max(1, static_cast<int>(sample_rate / config.max_detectable_frequency_hz));
  const int max_lag = std::min(
      sample_count / config.minimum_periods_required,
      static_cast<int>(sample_rate / config.min_detectable_frequency_hz));
  if (sample_count < (max_lag * config.minimum_periods_required) ||
      max_lag <= min_lag + 1) {
    result.decision_reason = PitchDecisionReason::kInsufficientWindow;
    return result;
  }

  std::vector<float> centered_samples;
  const SignalMetrics metrics =
      RemoveDcOffset(samples, sample_count, &centered_samples);
  result.signal_rms = metrics.rms;
  result.signal_peak = metrics.peak;
  if (metrics.rms < config.min_signal_rms) {
    result.decision_reason = PitchDecisionReason::kSignalTooWeakRms;
    return result;
  }

  if (metrics.peak < config.min_signal_peak) {
    result.decision_reason = PitchDecisionReason::kSignalTooWeakPeak;
    return result;
  }

  std::vector<double> difference;
  ComputeDifferenceFunction(centered_samples, max_lag, &difference);

  std::vector<double> cmndf;
  ComputeCumulativeMeanNormalizedDifference(difference, &cmndf);

  double best_score = 0.0;
  const int best_lag = FindBestLag(cmndf, min_lag, max_lag,
                                   config.max_yin_threshold, &best_score);
  result.yin_score = static_cast<float>(best_score);
  if (best_lag < 0) {
    result.decision_reason = PitchDecisionReason::kNoCandidate;
    return result;
  }

  if (best_score > config.max_yin_threshold) {
    result.decision_reason = PitchDecisionReason::kPoorPeriodicity;
    return result;
  }

  const double refined_lag =
      RefineLagParabolically(cmndf, best_lag, min_lag, max_lag);
  if (refined_lag <= 0.0) {
    result.decision_reason = PitchDecisionReason::kNoCandidate;
    return result;
  }

  result.detected_frequency_hz =
      static_cast<float>(static_cast<double>(sample_rate) / refined_lag);
  result.confidence =
      static_cast<float>(std::clamp(1.0 - best_score, 0.0, 1.0));

  if (result.detected_frequency_hz < config.min_detectable_frequency_hz ||
      result.detected_frequency_hz > config.max_detectable_frequency_hz) {
    result.decision_reason = PitchDecisionReason::kFrequencyOutOfRange;
    return result;
  }

  if (result.confidence < config.min_acceptable_confidence) {
    result.decision_reason = PitchDecisionReason::kLowConfidence;
    return result;
  }

  result.nearest_midi = frequency_to_midi(result.detected_frequency_hz);
  if (result.nearest_midi < 0) {
    result.decision_reason = PitchDecisionReason::kNoMidiMatch;
    return result;
  }

  result.nearest_note = midi_to_note_name(result.nearest_midi);
  result.cents_offset =
      calculate_cents_offset(result.detected_frequency_hz, result.nearest_midi);
  result.has_pitch = true;
  result.decision_reason = PitchDecisionReason::kNone;
  return result;
}

}  // namespace dsp_core
