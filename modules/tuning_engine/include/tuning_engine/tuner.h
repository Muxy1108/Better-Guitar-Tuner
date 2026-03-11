#ifndef TUNING_ENGINE_TUNER_H
#define TUNING_ENGINE_TUNER_H

#include "dsp_core/pitch_detector.h"
#include "tuning_engine/tuning_types.h"

namespace tuning_engine {

TuningStatus classify_tuning_status(float cents_offset,
                                    const TuningThresholds& thresholds =
                                        kDefaultTuningThresholds);

TuningResult evaluate_tuning(const dsp_core::PitchResult& pitch_result,
                             const TuningPreset& preset, TuningMode mode,
                             int manual_target_string_index = -1,
                             const TuningThresholds& thresholds =
                                 kDefaultTuningThresholds);

}  // namespace tuning_engine

#endif
