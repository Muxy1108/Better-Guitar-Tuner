#include "dsp_core/pitch_detector.h"

#include "dsp_core/pitch_utils.h"

#include <algorithm>
#include <cmath>
#include <limits>
#include <vector>

namespace dsp_core {
namespace {

constexpr float kMinDetectableFrequencyHz = 70.0f;
constexpr float kMaxDetectableFrequencyHz = 1'000.0f;
constexpr float kMinSignalRms = 0.01f;
constexpr float kMinSignalPeak = 0.03f;
constexpr float kMaxYinThreshold = 0.20f;
constexpr float kMinAcceptableConfidence = 0.60f;
constexpr int kMinimumPeriodsRequired = 2;

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
                double* best_score) {
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

  if (*best_score <= kMaxYinThreshold) {
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

PitchResult detect_pitch(const float* samples, int sample_count, int sample_rate) {
  PitchResult result{};

  if (samples == nullptr || sample_count <= 0 || sample_rate <= 0) {
    return result;
  }

  const int min_lag =
      std::max(1, static_cast<int>(sample_rate / kMaxDetectableFrequencyHz));
  const int max_lag = std::min(
      sample_count / kMinimumPeriodsRequired,
      static_cast<int>(sample_rate / kMinDetectableFrequencyHz));
  if (sample_count < (max_lag * kMinimumPeriodsRequired) || max_lag <= min_lag + 1) {
    return result;
  }

  std::vector<float> centered_samples;
  const SignalMetrics metrics =
      RemoveDcOffset(samples, sample_count, &centered_samples);
  if (metrics.rms < kMinSignalRms || metrics.peak < kMinSignalPeak) {
    return result;
  }

  std::vector<double> difference;
  ComputeDifferenceFunction(centered_samples, max_lag, &difference);

  std::vector<double> cmndf;
  ComputeCumulativeMeanNormalizedDifference(difference, &cmndf);

  double best_score = 0.0;
  const int best_lag = FindBestLag(cmndf, min_lag, max_lag, &best_score);
  if (best_lag < 0 || best_score > kMaxYinThreshold) {
    return result;
  }

  const double refined_lag =
      RefineLagParabolically(cmndf, best_lag, min_lag, max_lag);
  if (refined_lag <= 0.0) {
    return result;
  }

  result.detected_frequency_hz =
      static_cast<float>(static_cast<double>(sample_rate) / refined_lag);
  result.confidence =
      static_cast<float>(std::clamp(1.0 - best_score, 0.0, 1.0));

  if (result.detected_frequency_hz < kMinDetectableFrequencyHz ||
      result.detected_frequency_hz > kMaxDetectableFrequencyHz ||
      result.confidence < kMinAcceptableConfidence) {
    return result;
  }

  result.nearest_midi = frequency_to_midi(result.detected_frequency_hz);
  if (result.nearest_midi < 0) {
    return result;
  }

  result.nearest_note = midi_to_note_name(result.nearest_midi);
  result.cents_offset =
      calculate_cents_offset(result.detected_frequency_hz, result.nearest_midi);
  result.has_pitch = true;
  return result;
}

}  // namespace dsp_core
