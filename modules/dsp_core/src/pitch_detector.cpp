#include "dsp_core/pitch_detector.h"

#include "dsp_core/pitch_utils.h"

#include <algorithm>
#include <cmath>
#include <limits>
#include <vector>

namespace dsp_core {
namespace {

constexpr double kPi = 3.14159265358979323846;

enum class CandidateStatus {
  kNoCandidate,
  kPoorPeriodicity,
  kOk,
};

struct SignalMetrics {
  float rms = 0.0f;
  float peak = 0.0f;
};

struct PitchCandidate {
  CandidateStatus status = CandidateStatus::kNoCandidate;
  int lag = -1;
  double refined_lag = 0.0;
  double yin_score = 1.0;
  double autocorrelation = 0.0;
  double confidence = 0.0;
  float detected_frequency_hz = 0.0f;
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

void ApplyRaisedCosineTaper(std::vector<float>* samples) {
  if (samples->size() < 32U) {
    return;
  }

  const std::size_t taper_size =
      std::max<std::size_t>(16U, samples->size() / 8U);
  for (std::size_t i = 0; i < taper_size; ++i) {
    const double phase = (static_cast<double>(i) + 0.5) /
                         static_cast<double>(taper_size);
    const float gain =
        static_cast<float>(0.5 - (0.5 * std::cos(kPi * phase)));
    (*samples)[i] *= gain;
    (*samples)[samples->size() - 1U - i] *= gain;
  }
}

void ApplyFundamentalSmoothing(std::vector<float>* samples) {
  if (samples->size() < 5U) {
    return;
  }

  std::vector<float> filtered = *samples;
  for (std::size_t i = 2; i + 2 < samples->size(); ++i) {
    filtered[i] = ((*samples)[i - 2] + (4.0f * (*samples)[i - 1]) +
                   (6.0f * (*samples)[i]) + (4.0f * (*samples)[i + 1]) +
                   (*samples)[i + 2]) /
                  16.0f;
  }

  *samples = std::move(filtered);
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

bool IsLocalMinimum(const std::vector<double>& cmndf, int lag, int max_lag) {
  if (lag <= 0 || lag >= max_lag) {
    return false;
  }

  return cmndf[static_cast<std::size_t>(lag)] <=
             cmndf[static_cast<std::size_t>(lag - 1)] &&
         cmndf[static_cast<std::size_t>(lag)] <=
             cmndf[static_cast<std::size_t>(lag + 1)];
}

int FindBestLag(const std::vector<double>& cmndf, int min_lag, int max_lag,
                double max_yin_threshold, double* best_score) {
  // Prefer the first acceptable valley rather than the absolute global minimum.
  // This tracks the original YIN behavior more closely and is less likely to
  // jump to later subharmonic multiples on harmonic-rich or noisy input.
  for (int lag = min_lag + 1; lag < max_lag; ++lag) {
    if (cmndf[static_cast<std::size_t>(lag)] > max_yin_threshold) {
      continue;
    }

    int valley_lag = lag;
    while (valley_lag + 1 <= max_lag &&
           cmndf[static_cast<std::size_t>(valley_lag + 1)] <=
               cmndf[static_cast<std::size_t>(valley_lag)]) {
      ++valley_lag;
    }

    *best_score = cmndf[static_cast<std::size_t>(valley_lag)];
    return valley_lag;
  }

  *best_score = std::numeric_limits<double>::max();
  int best_lag = -1;
  bool found_local_minimum = false;

  for (int lag = min_lag; lag <= max_lag; ++lag) {
    const double score = cmndf[static_cast<std::size_t>(lag)];
    if (!IsLocalMinimum(cmndf, lag, max_lag)) {
      continue;
    }

    if (!found_local_minimum || score < *best_score) {
      *best_score = score;
      best_lag = lag;
      found_local_minimum = true;
    }
  }

  if (found_local_minimum) {
    return best_lag;
  }

  for (int lag = min_lag; lag <= max_lag; ++lag) {
    const double score = cmndf[static_cast<std::size_t>(lag)];
    if (score < *best_score) {
      *best_score = score;
      best_lag = lag;
    }
  }

  return best_lag;
}

int FindBestLagNearTarget(const std::vector<double>& cmndf, int target_lag,
                          int max_lag, double* best_score) {
  const int search_radius = std::max(2, target_lag / 32);
  const int start_lag = std::max(1, target_lag - search_radius);
  const int end_lag = std::min(max_lag, target_lag + search_radius);

  *best_score = std::numeric_limits<double>::max();
  int best_lag = -1;
  for (int lag = start_lag; lag <= end_lag; ++lag) {
    const double score = cmndf[static_cast<std::size_t>(lag)];
    if (IsLocalMinimum(cmndf, lag, max_lag) && score < *best_score) {
      *best_score = score;
      best_lag = lag;
    }
  }

  if (best_lag >= 0) {
    return best_lag;
  }

  for (int lag = start_lag; lag <= end_lag; ++lag) {
    const double score = cmndf[static_cast<std::size_t>(lag)];
    if (score < *best_score) {
      *best_score = score;
      best_lag = lag;
    }
  }

  return best_lag;
}

int PromoteLowerOctaveCandidate(const std::vector<double>& cmndf, int best_lag,
                                int max_lag, double max_yin_threshold,
                                double* best_score) {
  int promoted_lag = best_lag;
  double promoted_score = *best_score;

  while (promoted_lag > 0 && promoted_lag * 2 <= max_lag) {
    double doubled_score = 0.0;
    const int doubled_lag =
        FindBestLagNearTarget(cmndf, promoted_lag * 2, max_lag, &doubled_score);
    if (doubled_lag < 0 || doubled_score > max_yin_threshold) {
      break;
    }

    // Only walk down an octave when the longer period is materially more
    // periodic. This fixes strong-even-harmonic octave errors without broadly
    // biasing every estimate toward lower subharmonics.
    if (!(doubled_score + 0.02 < promoted_score &&
          doubled_score <= promoted_score * 0.75)) {
      break;
    }

    promoted_lag = doubled_lag;
    promoted_score = doubled_score;
  }

  *best_score = promoted_score;
  return promoted_lag;
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

double ComputeNormalizedAutocorrelation(const std::vector<float>& samples,
                                        int lag) {
  const int sample_count = static_cast<int>(samples.size());
  if (lag <= 0 || lag >= sample_count) {
    return 0.0;
  }

  double numerator = 0.0;
  double left_energy = 0.0;
  double right_energy = 0.0;
  for (int i = 0; i + lag < sample_count; ++i) {
    const double left = static_cast<double>(samples[static_cast<std::size_t>(i)]);
    const double right =
        static_cast<double>(samples[static_cast<std::size_t>(i + lag)]);
    numerator += left * right;
    left_energy += left * left;
    right_energy += right * right;
  }

  const double denominator = std::sqrt(left_energy * right_energy);
  if (denominator <= 1e-12) {
    return 0.0;
  }

  return std::clamp(numerator / denominator, 0.0, 1.0);
}

PitchCandidate AnalyzePitchCandidate(const std::vector<float>& samples,
                                     int sample_rate, int min_lag, int max_lag,
                                     const PitchDetectionConfig& config) {
  PitchCandidate candidate{};

  std::vector<double> difference;
  ComputeDifferenceFunction(samples, max_lag, &difference);

  std::vector<double> cmndf;
  ComputeCumulativeMeanNormalizedDifference(difference, &cmndf);

  double best_score = 0.0;
  const int best_lag =
      FindBestLag(cmndf, min_lag, max_lag, config.max_yin_threshold, &best_score);
  const int promoted_lag = PromoteLowerOctaveCandidate(
      cmndf, best_lag, max_lag, config.max_yin_threshold, &best_score);
  candidate.lag = promoted_lag;
  candidate.yin_score = best_score;
  if (promoted_lag < 0) {
    candidate.status = CandidateStatus::kNoCandidate;
    return candidate;
  }

  if (best_score > config.max_yin_threshold) {
    candidate.status = CandidateStatus::kPoorPeriodicity;
    return candidate;
  }

  const double refined_lag =
      RefineLagParabolically(cmndf, promoted_lag, min_lag, max_lag);
  if (refined_lag <= 0.0) {
    candidate.status = CandidateStatus::kNoCandidate;
    return candidate;
  }

  candidate.refined_lag = refined_lag;
  candidate.detected_frequency_hz =
      static_cast<float>(static_cast<double>(sample_rate) / refined_lag);
  candidate.autocorrelation =
      ComputeNormalizedAutocorrelation(samples, promoted_lag);
  candidate.confidence = std::clamp((1.0 - best_score) * candidate.autocorrelation,
                                    0.0, 1.0);
  candidate.status = CandidateStatus::kOk;
  return candidate;
}

PitchCandidate SelectPreferredCandidate(const PitchCandidate& primary,
                                        const PitchCandidate& secondary) {
  if (secondary.status != CandidateStatus::kOk) {
    return primary;
  }
  if (primary.status != CandidateStatus::kOk) {
    return secondary;
  }

  // Prefer the steadier trailing-window estimate when it is meaningfully more
  // periodic or confident. This reduces fresh-attack bias without adding any
  // cross-frame state to the public API.
  if (secondary.confidence > primary.confidence + 0.03 ||
      secondary.autocorrelation > primary.autocorrelation + 0.05 ||
      secondary.yin_score + 0.03 < primary.yin_score) {
    return secondary;
  }

  return primary;
}

PitchCandidate SelectFundamentalCandidate(const PitchCandidate& primary,
                                          const PitchCandidate& smoothed) {
  if (smoothed.status != CandidateStatus::kOk) {
    return primary;
  }
  if (primary.status != CandidateStatus::kOk) {
    return smoothed;
  }

  const double primary_frequency = static_cast<double>(primary.detected_frequency_hz);
  const double smoothed_frequency =
      static_cast<double>(smoothed.detected_frequency_hz);
  if (smoothed_frequency <= 0.0) {
    return primary;
  }

  const double octave_ratio = primary_frequency / smoothed_frequency;
  if (octave_ratio > 1.85 && octave_ratio < 2.15 &&
      smoothed.confidence + 0.08 >= primary.confidence &&
      smoothed.autocorrelation + 0.05 >= primary.autocorrelation) {
    return smoothed;
  }

  return SelectPreferredCandidate(primary, smoothed);
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

  std::vector<float> tapered_samples = centered_samples;
  ApplyRaisedCosineTaper(&tapered_samples);

  PitchCandidate candidate =
      AnalyzePitchCandidate(tapered_samples, sample_rate, min_lag, max_lag, config);
  if (candidate.status == CandidateStatus::kNoCandidate) {
    result.decision_reason = PitchDecisionReason::kNoCandidate;
    return result;
  }
  if (candidate.status == CandidateStatus::kPoorPeriodicity) {
    result.decision_reason = PitchDecisionReason::kPoorPeriodicity;
    return result;
  }

  std::vector<float> smoothed_samples = tapered_samples;
  ApplyFundamentalSmoothing(&smoothed_samples);
  ApplyFundamentalSmoothing(&smoothed_samples);
  const PitchCandidate smoothed_candidate = AnalyzePitchCandidate(
      smoothed_samples, sample_rate, min_lag, max_lag, config);
  candidate = SelectFundamentalCandidate(candidate, smoothed_candidate);

  const int transient_trim = sample_count / 5;
  const int trailing_sample_count = sample_count - transient_trim;
  if (transient_trim > 0 &&
      trailing_sample_count >= (max_lag * config.minimum_periods_required)) {
    std::vector<float> trailing_samples(
        centered_samples.begin() + transient_trim, centered_samples.end());
    ApplyRaisedCosineTaper(&trailing_samples);

    const int trailing_max_lag =
        std::min(trailing_sample_count / config.minimum_periods_required, max_lag);
    if (trailing_max_lag > min_lag + 1) {
      const PitchCandidate trailing_candidate = AnalyzePitchCandidate(
          trailing_samples, sample_rate, min_lag, trailing_max_lag, config);
      candidate = SelectPreferredCandidate(candidate, trailing_candidate);
    }
  }

  result.yin_score = static_cast<float>(candidate.yin_score);
  result.detected_frequency_hz = candidate.detected_frequency_hz;
  result.confidence = static_cast<float>(candidate.confidence);

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
