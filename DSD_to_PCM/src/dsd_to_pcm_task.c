#include "dsd_to_pcm_task.h"
#include <xcore/chanend.h>
#include <xcore/channel_streaming.h>
#include <string.h>
#include <xcore/port.h>
#include <platform.h>
#include <xscope.h>
#include "pdm.h"

#include "signal.h"

inline void dop_to_dsd(int* dop, int* dsd) {
    // repack data
    dsd[0] = ((dop[0] & 0x00FFFF00) << 8) | ((dop[1] & 0x00FFFF00) >> 8);
    dsd[1] = ((dop[2] & 0x00FFFF00) << 8) | ((dop[3] & 0x00FFFF00) >> 8);
    dsd[2] = ((dop[4] & 0x00FFFF00) << 8) | ((dop[5] & 0x00FFFF00) >> 8);
    dsd[3] = ((dop[6] & 0x00FFFF00) << 8) | ((dop[7] & 0x00FFFF00) >> 8);
}

void dsd_to_pcm_task(chanend_t c_dsd_in, chanend_t c_pcm_out) {
    uint32_t* dsd_data;
    pdm_pcm_t pdm;
    uint32_t in_dsd[4];
    int32_t out_pcm[2];
    int* ring_buffer;
    size_t ring_buffer_size;
    int ring_buffer_idx = 16;

    // Initialize i2s ring buffer
    ring_buffer = s_chan_in_word(c_pcm_out);
    ring_buffer_size = s_chan_in_word(c_pcm_out);

    pdm_pcm_init(&pdm);

    while (1) {
        dsd_data = s_chan_in_word(c_dsd_in);

        if (DSD_IN_MODE == 1) {
            dop_to_dsd(dsd_data, in_dsd);
            dsd_data = in_dsd;
        }
        pdm_pcm_x1_64_i128_o2(out_pcm, dsd_data, &pdm);
        ring_buffer[ring_buffer_idx++] = out_pcm[0];
        ring_buffer[ring_buffer_idx++] = out_pcm[1];
        ring_buffer_idx %= ring_buffer_size;
    }
}