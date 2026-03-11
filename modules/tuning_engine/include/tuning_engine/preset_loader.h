#ifndef TUNING_ENGINE_PRESET_LOADER_H
#define TUNING_ENGINE_PRESET_LOADER_H

#include "tuning_engine/tuning_types.h"

#include <string>
#include <vector>

namespace tuning_engine {

struct PresetLoadResult {
  std::vector<TuningPreset> presets;
  std::string error_message;

  bool ok() const { return error_message.empty(); }
};

PresetLoadResult load_presets_from_json(const std::string& json_text);
PresetLoadResult load_presets_from_file(const std::string& file_path);
const TuningPreset* find_preset_by_id(const std::vector<TuningPreset>& presets,
                                      const std::string& tuning_id);

}  // namespace tuning_engine

#endif
