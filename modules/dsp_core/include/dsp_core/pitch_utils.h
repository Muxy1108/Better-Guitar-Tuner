#ifndef DSP_CORE_PITCH_UTILS_H
#define DSP_CORE_PITCH_UTILS_H

#include <string>

namespace dsp_core {

int frequency_to_midi(float frequency_hz);
std::string midi_to_note_name(int midi_note);
float calculate_cents_offset(float frequency_hz, int midi_note);

}  // namespace dsp_core

#endif
