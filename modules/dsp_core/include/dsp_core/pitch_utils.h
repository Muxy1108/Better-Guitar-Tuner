#ifndef DSP_CORE_PITCH_UTILS_H
#define DSP_CORE_PITCH_UTILS_H

#include <string>

namespace dsp_core {

int frequency_to_midi(float frequency_hz);
int note_name_to_midi(const std::string& note_name);
std::string midi_to_note_name(int midi_note);
float midi_to_frequency_hz(int midi_note);
float calculate_cents_offset(float frequency_hz, int midi_note);

}  // namespace dsp_core

#endif
