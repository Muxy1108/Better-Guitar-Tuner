#include "tuning_engine/preset_loader.h"

#include "dsp_core/pitch_utils.h"

#include <cctype>
#include <cstdlib>
#include <fstream>
#include <map>
#include <sstream>
#include <utility>

namespace tuning_engine {
namespace {

struct JsonValue {
  enum class Type {
    kObject,
    kArray,
    kString,
  };

  Type type = Type::kString;
  std::map<std::string, JsonValue> object_value;
  std::vector<JsonValue> array_value;
  std::string string_value;
};

class JsonParser {
 public:
  explicit JsonParser(const std::string& text) : text_(text) {}

  bool Parse(JsonValue* value, std::string* error_message) {
    SkipWhitespace();
    if (!ParseValue(value, error_message)) {
      return false;
    }

    SkipWhitespace();
    if (position_ != text_.size()) {
      *error_message = "unexpected trailing characters in JSON";
      return false;
    }

    return true;
  }

 private:
  bool ParseValue(JsonValue* value, std::string* error_message) {
    SkipWhitespace();
    if (position_ >= text_.size()) {
      *error_message = "unexpected end of JSON";
      return false;
    }

    const char ch = text_[position_];
    if (ch == '{') {
      return ParseObject(value, error_message);
    }
    if (ch == '[') {
      return ParseArray(value, error_message);
    }
    if (ch == '"') {
      value->type = JsonValue::Type::kString;
      return ParseString(&value->string_value, error_message);
    }

    *error_message = "unsupported JSON value type";
    return false;
  }

  bool ParseObject(JsonValue* value, std::string* error_message) {
    value->type = JsonValue::Type::kObject;
    value->object_value.clear();
    ++position_;
    SkipWhitespace();

    if (ConsumeIf('}')) {
      return true;
    }

    while (position_ < text_.size()) {
      std::string key;
      if (!ParseString(&key, error_message)) {
        return false;
      }

      SkipWhitespace();
      if (!ConsumeIf(':')) {
        *error_message = "expected ':' after object key";
        return false;
      }

      JsonValue member;
      if (!ParseValue(&member, error_message)) {
        return false;
      }
      value->object_value.emplace(std::move(key), std::move(member));

      SkipWhitespace();
      if (ConsumeIf('}')) {
        return true;
      }
      if (!ConsumeIf(',')) {
        *error_message = "expected ',' or '}' in object";
        return false;
      }
      SkipWhitespace();
    }

    *error_message = "unterminated object";
    return false;
  }

  bool ParseArray(JsonValue* value, std::string* error_message) {
    value->type = JsonValue::Type::kArray;
    value->array_value.clear();
    ++position_;
    SkipWhitespace();

    if (ConsumeIf(']')) {
      return true;
    }

    while (position_ < text_.size()) {
      JsonValue element;
      if (!ParseValue(&element, error_message)) {
        return false;
      }
      value->array_value.push_back(std::move(element));

      SkipWhitespace();
      if (ConsumeIf(']')) {
        return true;
      }
      if (!ConsumeIf(',')) {
        *error_message = "expected ',' or ']' in array";
        return false;
      }
      SkipWhitespace();
    }

    *error_message = "unterminated array";
    return false;
  }

  bool ParseString(std::string* value, std::string* error_message) {
    if (!ConsumeIf('"')) {
      *error_message = "expected string";
      return false;
    }

    std::string parsed;
    while (position_ < text_.size()) {
      const char ch = text_[position_++];
      if (ch == '"') {
        *value = std::move(parsed);
        return true;
      }

      if (ch == '\\') {
        if (position_ >= text_.size()) {
          *error_message = "unterminated escape sequence";
          return false;
        }

        const char escaped = text_[position_++];
        switch (escaped) {
          case '"':
          case '\\':
          case '/':
            parsed.push_back(escaped);
            break;
          case 'b':
            parsed.push_back('\b');
            break;
          case 'f':
            parsed.push_back('\f');
            break;
          case 'n':
            parsed.push_back('\n');
            break;
          case 'r':
            parsed.push_back('\r');
            break;
          case 't':
            parsed.push_back('\t');
            break;
          case 'u':
            if (!ParseUnicodeEscape(&parsed, error_message)) {
              return false;
            }
            break;
          default:
            *error_message = "unsupported escape sequence";
            return false;
        }
        continue;
      }

      parsed.push_back(ch);
    }

    *error_message = "unterminated string";
    return false;
  }

  bool ParseUnicodeEscape(std::string* value, std::string* error_message) {
    if (position_ + 4 > text_.size()) {
      *error_message = "invalid unicode escape";
      return false;
    }

    int code_point = 0;
    for (int i = 0; i < 4; ++i) {
      const char ch = text_[position_++];
      code_point *= 16;
      if (ch >= '0' && ch <= '9') {
        code_point += ch - '0';
      } else if (ch >= 'a' && ch <= 'f') {
        code_point += 10 + (ch - 'a');
      } else if (ch >= 'A' && ch <= 'F') {
        code_point += 10 + (ch - 'A');
      } else {
        *error_message = "invalid unicode escape";
        return false;
      }
    }

    if (code_point < 0 || code_point > 0x7F) {
      *error_message = "only ASCII unicode escapes are supported";
      return false;
    }

    value->push_back(static_cast<char>(code_point));
    return true;
  }

  void SkipWhitespace() {
    while (position_ < text_.size() &&
           std::isspace(static_cast<unsigned char>(text_[position_])) != 0) {
      ++position_;
    }
  }

  bool ConsumeIf(char expected) {
    if (position_ < text_.size() && text_[position_] == expected) {
      ++position_;
      return true;
    }
    return false;
  }

  const std::string& text_;
  std::size_t position_ = 0;
};

const JsonValue* FindObjectMember(const JsonValue& object,
                                  const std::string& key) {
  if (object.type != JsonValue::Type::kObject) {
    return nullptr;
  }

  const auto it = object.object_value.find(key);
  if (it == object.object_value.end()) {
    return nullptr;
  }

  return &it->second;
}

bool ReadRequiredString(const JsonValue& object, const std::string& key,
                        std::string* value, std::string* error_message) {
  const JsonValue* member = FindObjectMember(object, key);
  if (member == nullptr || member->type != JsonValue::Type::kString) {
    *error_message = "missing or invalid string field: " + key;
    return false;
  }

  *value = member->string_value;
  return true;
}

bool BuildPreset(const JsonValue& preset_value, TuningPreset* preset,
                 std::string* error_message) {
  if (preset_value.type != JsonValue::Type::kObject) {
    *error_message = "preset entry must be an object";
    return false;
  }

  if (!ReadRequiredString(preset_value, "id", &preset->id, error_message) ||
      !ReadRequiredString(preset_value, "name", &preset->name, error_message) ||
      !ReadRequiredString(preset_value, "instrument", &preset->instrument,
                          error_message)) {
    return false;
  }

  const JsonValue* notes_value = FindObjectMember(preset_value, "notes");
  if (notes_value == nullptr || notes_value->type != JsonValue::Type::kArray ||
      notes_value->array_value.empty()) {
    *error_message = "missing or invalid notes array";
    return false;
  }

  preset->strings.clear();
  preset->strings.reserve(notes_value->array_value.size());
  for (const JsonValue& note_value : notes_value->array_value) {
    if (note_value.type != JsonValue::Type::kString) {
      *error_message = "notes must be strings";
      return false;
    }

    const int midi_note = dsp_core::note_name_to_midi(note_value.string_value);
    if (midi_note < 0) {
      *error_message = "invalid note name in preset '" + preset->id + "': " +
                       note_value.string_value;
      return false;
    }

    TuningString string_target;
    string_target.note = note_value.string_value;
    string_target.midi_note = midi_note;
    string_target.frequency_hz = dsp_core::midi_to_frequency_hz(midi_note);
    preset->strings.push_back(std::move(string_target));
  }

  return true;
}

PresetLoadResult BuildPresetLoadResult(const JsonValue& root) {
  PresetLoadResult result;

  std::vector<JsonValue> preset_values;
  if (root.type == JsonValue::Type::kObject) {
    const JsonValue* presets_member = FindObjectMember(root, "presets");
    if (presets_member != nullptr) {
      if (presets_member->type != JsonValue::Type::kArray) {
        result.error_message = "presets field must be an array";
        return result;
      }
      preset_values = presets_member->array_value;
    } else {
      preset_values.push_back(root);
    }
  } else if (root.type == JsonValue::Type::kArray) {
    preset_values = root.array_value;
  } else {
    result.error_message = "root JSON value must be an object or array";
    return result;
  }

  std::map<std::string, bool> seen_ids;
  result.presets.reserve(preset_values.size());
  for (const JsonValue& preset_value : preset_values) {
    TuningPreset preset;
    if (!BuildPreset(preset_value, &preset, &result.error_message)) {
      return result;
    }

    if (seen_ids.find(preset.id) != seen_ids.end()) {
      result.error_message = "duplicate preset id: " + preset.id;
      result.presets.clear();
      return result;
    }

    seen_ids.emplace(preset.id, true);
    result.presets.push_back(std::move(preset));
  }

  return result;
}

}  // namespace

PresetLoadResult load_presets_from_json(const std::string& json_text) {
  PresetLoadResult result;
  JsonValue root;
  JsonParser parser(json_text);
  if (!parser.Parse(&root, &result.error_message)) {
    return result;
  }

  return BuildPresetLoadResult(root);
}

PresetLoadResult load_presets_from_file(const std::string& file_path) {
  PresetLoadResult result;

  std::ifstream input(file_path);
  if (!input.is_open()) {
    result.error_message = "failed to open preset file: " + file_path;
    return result;
  }

  std::ostringstream buffer;
  buffer << input.rdbuf();
  if (!input.good() && !input.eof()) {
    result.error_message = "failed to read preset file: " + file_path;
    return result;
  }

  return load_presets_from_json(buffer.str());
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
