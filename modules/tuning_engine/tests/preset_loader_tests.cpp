#include "tuning_engine/preset_loader.h"

#include <iostream>
#include <string>

namespace {

bool Check(bool condition, const std::string& message) {
  if (!condition) {
    std::cerr << "FAIL: " << message << "\n";
    return false;
  }
  return true;
}

}  // namespace

int main() {
  const tuning_engine::PresetLoadResult array_result =
      tuning_engine::load_presets_from_json(R"json(
        [
          {
            "id": "open_g",
            "name": "Open G",
            "instrument": "guitar",
            "notes": ["D2", "G2", "D3", "G3", "B3", "D4"]
          }
        ]
      )json");
  if (!Check(array_result.ok(), "root array should load successfully") ||
      !Check(array_result.presets.size() == 1,
             "root array should produce one preset") ||
      !Check(array_result.presets.front().id == "open_g",
             "root array should preserve preset ids")) {
    return 1;
  }

  const tuning_engine::PresetLoadResult object_result =
      tuning_engine::load_presets_from_json(R"json(
        {
          "id": "drop_d",
          "name": "Drop D",
          "instrument": "guitar",
          "notes": ["D2", "A2", "D3", "G3", "B3", "E4"]
        }
      )json");
  if (!Check(object_result.ok(), "single preset object should load successfully") ||
      !Check(object_result.presets.size() == 1,
             "single preset object should produce one preset") ||
      !Check(object_result.presets.front().strings.size() == 6,
             "single preset object should resolve string targets")) {
    return 1;
  }

  const tuning_engine::PresetLoadResult parse_error_result =
      tuning_engine::load_presets_from_json("{");
  if (!Check(!parse_error_result.ok(), "invalid JSON should fail") ||
      !Check(parse_error_result.error_message.rfind("invalid JSON:", 0) == 0,
             "syntax failures should surface parser context")) {
    return 1;
  }

  const tuning_engine::PresetLoadResult extra_field_result =
      tuning_engine::load_presets_from_json(R"json(
        {
          "id": "standard",
          "name": "Standard",
          "instrument": "guitar",
          "notes": ["E2", "A2", "D3", "G3", "B3", "E4"],
          "version": 1
        }
      )json");
  if (!Check(extra_field_result.ok(),
             "extra metadata fields should be ignored") ||
      !Check(extra_field_result.presets.size() == 1,
             "extra metadata should not block preset loading")) {
    return 1;
  }

  const tuning_engine::PresetLoadResult schema_error_result =
      tuning_engine::load_presets_from_json(R"json(
        {
          "id": "standard",
          "name": "Standard",
          "instrument": "guitar",
          "notes": ["E2", 1, "D3", "G3", "B3", "E4"]
        }
      )json");
  if (!Check(!schema_error_result.ok(), "notes must still be strings") ||
      !Check(schema_error_result.error_message.rfind("invalid preset schema:", 0) ==
                 0,
             "schema failures should surface json parser diagnostics")) {
    return 1;
  }

  const tuning_engine::PresetLoadResult duplicate_id_result =
      tuning_engine::load_presets_from_json(R"json(
        {
          "presets": [
            {
              "id": "standard",
              "name": "Standard",
              "instrument": "guitar",
              "notes": ["E2", "A2", "D3", "G3", "B3", "E4"]
            },
            {
              "id": "standard",
              "name": "Duplicate",
              "instrument": "guitar",
              "notes": ["D2", "A2", "D3", "G3", "B3", "E4"]
            }
          ]
        }
      )json");
  if (!Check(!duplicate_id_result.ok(),
             "duplicate preset ids should fail") ||
      !Check(duplicate_id_result.error_message == "duplicate preset id: standard",
             "duplicate id failures should remain descriptive")) {
    return 1;
  }

  const tuning_engine::PresetLoadResult empty_bundle_result =
      tuning_engine::load_presets_from_json(R"json({"presets":[]})json");
  if (!Check(!empty_bundle_result.ok(), "empty preset bundles should fail") ||
      !Check(empty_bundle_result.error_message == "preset bundle is empty",
             "empty bundles should surface an explicit validation error")) {
    return 1;
  }

  const tuning_engine::PresetLoadResult trimmed_metadata_result =
      tuning_engine::load_presets_from_json(R"json(
        {
          "id": " standard ",
          "name": " Standard ",
          "instrument": " guitar ",
          "notes": [" E2 ", "A2", "D3", "G3", "B3", "E4"]
        }
      )json");
  if (!Check(trimmed_metadata_result.ok(),
             "surrounding whitespace should be normalized") ||
      !Check(trimmed_metadata_result.presets.front().id == "standard",
             "preset ids should be trimmed during loading") ||
      !Check(trimmed_metadata_result.presets.front().strings.front().note ==
                 "E2",
             "note names should be trimmed during loading")) {
    return 1;
  }

  const tuning_engine::PresetLoadResult blank_note_result =
      tuning_engine::load_presets_from_json(R"json(
        {
          "id": "standard",
          "name": "Standard",
          "instrument": "guitar",
          "notes": ["E2", " ", "D3", "G3", "B3", "E4"]
        }
      )json");
  if (!Check(!blank_note_result.ok(), "blank note values should fail") ||
      !Check(blank_note_result.error_message ==
                 "preset 'standard' has an empty note at index 1",
             "blank note failures should identify the broken note index")) {
    return 1;
  }

  const tuning_engine::PresetLoadResult blank_id_result =
      tuning_engine::load_presets_from_json(R"json(
        {
          "id": " ",
          "name": "Standard",
          "instrument": "guitar",
          "notes": ["E2", "A2", "D3", "G3", "B3", "E4"]
        }
      )json");
  if (!Check(!blank_id_result.ok(), "blank preset ids should fail") ||
      !Check(blank_id_result.error_message == "preset at index 0 has an empty id",
             "blank ids should be rejected before preset construction")) {
    return 1;
  }

  std::cout << "preset_loader_tests passed\n";
  return 0;
}
