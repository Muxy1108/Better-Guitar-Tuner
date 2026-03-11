#include "dsp_core/pitch_utils.h"

#include <array>
#include <cmath>
#include <cctype>
#include <cstdlib>

namespace dsp_core {
namespace {

constexpr std::array<const char*, 12> kNoteNames = {
    "C",  "C#", "D",  "D#", "E", "F",
    "F#", "G",  "G#", "A",  "A#", "B",
};

float midi_to_frequency(int midi_note) {
  return 440.0f * std::pow(2.0f, static_cast<float>(midi_note - 69) / 12.0f);
}

int note_name_to_index(const std::string& note_name) {
  if (note_name == "C") {
    return 0;
  }
  if (note_name == "C#" || note_name == "Db") {
    return 1;
  }
  if (note_name == "D") {
    return 2;
  }
  if (note_name == "D#" || note_name == "Eb") {
    return 3;
  }
  if (note_name == "E") {
    return 4;
  }
  if (note_name == "F") {
    return 5;
  }
  if (note_name == "F#" || note_name == "Gb") {
    return 6;
  }
  if (note_name == "G") {
    return 7;
  }
  if (note_name == "G#" || note_name == "Ab") {
    return 8;
  }
  if (note_name == "A") {
    return 9;
  }
  if (note_name == "A#" || note_name == "Bb") {
    return 10;
  }
  if (note_name == "B") {
    return 11;
  }
  return -1;
}

}  // namespace

int frequency_to_midi(float frequency_hz) {
  if (frequency_hz <= 0.0f) {
    return -1;
  }

  const float midi =
      69.0f + (12.0f * std::log2(frequency_hz / 440.0f));
  return static_cast<int>(std::lround(midi));
}

int note_name_to_midi(const std::string& note_name) {
  if (note_name.size() < 2) {
    return -1;
  }

  std::size_t octave_start = 1;
  if (note_name.size() >= 3 && (note_name[1] == '#' || note_name[1] == 'b')) {
    octave_start = 2;
  }

  const std::string pitch_class = note_name.substr(0, octave_start);
  const int note_index = note_name_to_index(pitch_class);
  if (note_index < 0 || octave_start >= note_name.size()) {
    return -1;
  }

  for (std::size_t i = octave_start; i < note_name.size(); ++i) {
    if (i == octave_start && (note_name[i] == '-' || note_name[i] == '+')) {
      continue;
    }
    if (!std::isdigit(static_cast<unsigned char>(note_name[i]))) {
      return -1;
    }
  }

  char* end = nullptr;
  const long octave = std::strtol(note_name.c_str() + octave_start, &end, 10);
  if (end == nullptr || *end != '\0') {
    return -1;
  }

  return static_cast<int>((octave + 1) * 12L) + note_index;
}

std::string midi_to_note_name(int midi_note) {
  if (midi_note < 0) {
    return {};
  }

  const int note_index = midi_note % static_cast<int>(kNoteNames.size());
  const int octave = (midi_note / static_cast<int>(kNoteNames.size())) - 1;
  return std::string(kNoteNames[static_cast<std::size_t>(note_index)]) +
         std::to_string(octave);
}

float midi_to_frequency_hz(int midi_note) { return midi_to_frequency(midi_note); }

float calculate_cents_offset(float frequency_hz, int midi_note) {
  if (frequency_hz <= 0.0f || midi_note < 0) {
    return 0.0f;
  }

  const float reference_frequency = midi_to_frequency(midi_note);
  if (reference_frequency <= 0.0f) {
    return 0.0f;
  }

  return 1200.0f * std::log2(frequency_hz / reference_frequency);
}

}  // namespace dsp_core
