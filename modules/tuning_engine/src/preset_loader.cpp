#include "tuning_engine/preset_loader.h"

#include "dsp_core/pitch_utils.h"

#include <nlohmann/json.hpp>

#include <fstream>
#include <cctype>
#include <sstream>
#include <string_view>
#include <unordered_set>
#include <utility>
#include <vector>

namespace tuning_engine {
namespace {

using JsonValue = nlohmann::json;

struct JsonPresetDefinition {
  std::string id;
  std::string name;
  std::string instrument;
  std::vector<std::string> notes;
};

NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(JsonPresetDefinition, id, name, instrument,
                                   notes)

std::string trim_whitespace(std::string_view value) {
  std::size_t start = 0;
  while (start < value.size() &&
         std::isspace(static_cast<unsigned char>(value[start])) != 0) {
    ++start;
  }

  std::size_t end = value.size();
  while (end > start &&
         std::isspace(static_cast<unsigned char>(value[end - 1])) != 0) {
    --end;
  }

  return std::string(value.substr(start, end - start));
}

std::string describe_preset(std::size_t preset_index,
                            std::string_view preset_id) {
  if (!preset_id.empty()) {
    return "preset '" + std::string(preset_id) + "'";
  }

  std::ostringstream description;
  description << "preset at index " << preset_index;
  return description.str();
}

bool NormalizePresetDefinition(const JsonPresetDefinition& preset_definition,
                               std::size_t preset_index,
                               JsonPresetDefinition* normalized_definition,
                               std::string* error_message) {
  normalized_definition->id = trim_whitespace(preset_definition.id);
  normalized_definition->name = trim_whitespace(preset_definition.name);
  normalized_definition->instrument =
      trim_whitespace(preset_definition.instrument);

  if (normalized_definition->id.empty()) {
    *error_message =
        describe_preset(preset_index, std::string_view{}) + " has an empty id";
    return false;
  }

  const std::string preset_label =
      describe_preset(preset_index, normalized_definition->id);
  if (normalized_definition->name.empty()) {
    *error_message = preset_label + " has an empty name";
    return false;
  }

  if (normalized_definition->instrument.empty()) {
    *error_message = preset_label + " has an empty instrument";
    return false;
  }

  if (preset_definition.notes.empty()) {
    *error_message = preset_label + " has no notes";
    return false;
  }

  normalized_definition->notes.clear();
  normalized_definition->notes.reserve(preset_definition.notes.size());
  for (std::size_t note_index = 0; note_index < preset_definition.notes.size();
       ++note_index) {
    const std::string trimmed_note =
        trim_whitespace(preset_definition.notes[note_index]);
    if (trimmed_note.empty()) {
      *error_message = preset_label + " has an empty note at index " +
                       std::to_string(note_index);
      return false;
    }

    normalized_definition->notes.push_back(trimmed_note);
  }

  return true;
}

bool BuildPreset(const JsonPresetDefinition& preset_definition,
                 std::size_t preset_index, TuningPreset* preset,
                 std::string* error_message) {
  JsonPresetDefinition normalized_definition;
  if (!NormalizePresetDefinition(preset_definition, preset_index,
                                 &normalized_definition, error_message)) {
    return false;
  }

  preset->id = normalized_definition.id;
  preset->name = normalized_definition.name;
  preset->instrument = normalized_definition.instrument;
  preset->strings.clear();
  preset->strings.reserve(normalized_definition.notes.size());
  for (const std::string& note_name : normalized_definition.notes) {
    const int midi_note = dsp_core::note_name_to_midi(note_name);
    if (midi_note < 0) {
      *error_message = "invalid note name in preset '" + preset->id + "': " +
                       note_name;
      return false;
    }

    TuningString string_target;
    string_target.note = note_name;
    string_target.midi_note = midi_note;
    string_target.frequency_hz = dsp_core::midi_to_frequency_hz(midi_note);
    preset->strings.push_back(std::move(string_target));
  }

  return true;
}

PresetLoadResult BuildPresetLoadResult(const JsonValue& root) {
  PresetLoadResult result;

  std::vector<JsonPresetDefinition> preset_definitions;
  try {
    if (root.is_object()) {
      const auto presets_it = root.find("presets");
      if (presets_it == root.end()) {
        preset_definitions.push_back(root.get<JsonPresetDefinition>());
      } else {
        preset_definitions =
            presets_it->get<std::vector<JsonPresetDefinition>>();
      }
    } else if (root.is_array()) {
      preset_definitions = root.get<std::vector<JsonPresetDefinition>>();
    } else {
      result.error_message = "root JSON value must be an object or array";
      return result;
    }
  } catch (const JsonValue::exception& error) {
    result.error_message = "invalid preset schema: " + std::string(error.what());
    return result;
  }

  std::unordered_set<std::string> seen_ids;
  if (preset_definitions.empty()) {
    result.error_message = "preset bundle is empty";
    return result;
  }

  result.presets.reserve(preset_definitions.size());
  for (std::size_t preset_index = 0; preset_index < preset_definitions.size();
       ++preset_index) {
    const JsonPresetDefinition& preset_definition =
        preset_definitions[preset_index];
    TuningPreset preset;
    if (!BuildPreset(preset_definition, preset_index, &preset,
                     &result.error_message)) {
      return result;
    }

    if (!seen_ids.insert(preset.id).second) {
      result.error_message = "duplicate preset id: " + preset.id;
      result.presets.clear();
      return result;
    }

    result.presets.push_back(std::move(preset));
  }

  return result;
}

}  // namespace

PresetLoadResult load_presets_from_json(const std::string& json_text) {
  try {
    return BuildPresetLoadResult(JsonValue::parse(json_text));
  } catch (const JsonValue::parse_error& error) {
    PresetLoadResult result;
    result.error_message = "invalid JSON: " + std::string(error.what());
    return result;
  }
}

PresetLoadResult load_presets_from_file(const std::string& file_path) {
  PresetLoadResult result;

  std::ifstream input(file_path);
  if (!input.is_open()) {
    result.error_message = "failed to open preset file: " + file_path;
    return result;
  }
  input.exceptions(std::ifstream::badbit);

  try {
    return BuildPresetLoadResult(JsonValue::parse(input));
  } catch (const JsonValue::parse_error& error) {
    result.error_message = "invalid JSON: " + std::string(error.what());
  } catch (const JsonValue::exception& error) {
    result.error_message = "invalid preset schema: " + std::string(error.what());
  } catch (const std::ios_base::failure&) {
    result.error_message = "failed to read preset file: " + file_path;
    return result;
  }

  return result;
}

const TuningPreset* find_preset_by_id(const std::vector<TuningPreset>& presets,
                                      const std::string& tuning_id) {
  for (const TuningPreset& preset : presets) {
    if (preset.id == tuning_id) {
      return &preset;
    }
  }

  return nullptr;
}

}  // namespace tuning_engine
