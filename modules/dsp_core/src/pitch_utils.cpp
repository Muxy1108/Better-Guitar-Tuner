#include "dsp_core/pitch_utils.h"

#include <array>
#include <cmath>

namespace dsp_core {
namespace {

constexpr std::array<const char*, 12> kNoteNames = {
    "C",  "C#", "D",  "D#", "E", "F",
    "F#", "G",  "G#", "A",  "A#", "B",
};

float midi_to_frequency(int midi_note) {
  return 440.0f * std::pow(2.0f, static_cast<float>(midi_note - 69) / 12.0f);
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

std::string midi_to_note_name(int midi_note) {
  if (midi_note < 0) {
    return {};
  }

  const int note_index = midi_note % static_cast<int>(kNoteNames.size());
  const int octave = (midi_note / static_cast<int>(kNoteNames.size())) - 1;
  return std::string(kNoteNames[static_cast<std::size_t>(note_index)]) +
         std::to_string(octave);
}

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
