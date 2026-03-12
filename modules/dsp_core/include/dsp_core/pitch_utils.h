#ifndef DSP_CORE_PITCH_UTILS_H
#define DSP_CORE_PITCH_UTILS_H

#include <string>

namespace dsp_core {

constexpr float kDefaultA4ReferenceHz = 440.0f;

int frequency_to_midi(float frequency_hz,
                      float a4_reference_hz = kDefaultA4ReferenceHz);
int note_name_to_midi(const std::string& note_name);
std::string midi_to_note_name(int midi_note);
float midi_to_frequency_hz(int midi_note,
                           float a4_reference_hz = kDefaultA4ReferenceHz);
float calculate_cents_offset(float frequency_hz, int midi_note,
                             float a4_reference_hz = kDefaultA4ReferenceHz);

}  // namespace dsp_core

#endif
