#include "dsd_to_pcm_task.h"
#include <xcore/chanend.h>
#include <xcore/channel_streaming.h>
#include <string.h>
#include <xcore/port.h>
#include <platform.h>
#include "pdm.h"

inline void dop_to_dsd(int* dop, int* dsd) {
    // repack data
    dsd[0] = ((dop[0] & 0x00FFFF00) << 8) | ((dop[1] & 0x00FFFF00) >> 8);
    dsd[1] = ((dop[2] & 0x00FFFF00) << 8) | ((dop[3] & 0x00FFFF00) >> 8);
    dsd[2] = ((dop[4] & 0x00FFFF00) << 8) | ((dop[5] & 0x00FFFF00) >> 8);
    dsd[3] = ((dop[6] & 0x00FFFF00) << 8) | ((dop[7] & 0x00FFFF00) >> 8);
}
// __attribute__((aligned(8)))
void dsd_to_pcm(chanend_t c_dsd_in, chanend_t c_pcm_out) {
    int* dsd_data_ch0;
    int* dsd_data_ch1;
    pdm_pcm_t pdm0, pdm1;
    uint32_t in_dsd[4];
    int32_t out_pcm[2];
    int* ring_buffer0;
    int* ring_buffer1;
    size_t ring_buffer_size;
    int ring_buffer_idx = 16;

    ring_buffer0 = s_chan_in_word(c_pcm_out);
    ring_buffer1 = s_chan_in_word(c_pcm_out);
    ring_buffer_size = s_chan_in_word(c_pcm_out);

    pdm_pcm_init(&pdm0);
    pdm_pcm_init(&pdm1);

    while (1) {
        dsd_data_ch0 = s_chan_in_word(c_dsd_in);
        dsd_data_ch1 = s_chan_in_word(c_dsd_in);

        // CH0
        dop_to_dsd(dsd_data_ch0, in_dsd);
        pdm_pcm_x1_64_i128_o2(out_pcm, in_dsd, &pdm0);
        ring_buffer0[ring_buffer_idx+0] = out_pcm[0];
        ring_buffer0[ring_buffer_idx+1] = out_pcm[1];
        // CH1
        dop_to_dsd(dsd_data_ch1, in_dsd);
        pdm_pcm_x1_64_i128_o2(out_pcm, in_dsd, &pdm1);
        ring_buffer1[ring_buffer_idx+0] = out_pcm[0];
        ring_buffer1[ring_buffer_idx+1] = out_pcm[1];
        ring_buffer_idx += 2;
        ring_buffer_idx %= ring_buffer_size;

        // last_state = (++last_state)%2;
        // port_out(p_test, last_state);
        // delay_milliseconds(10);
        // printf("%x %x %x %x\n", dsd_data_ch0[0], dsd_data_ch0[1], dsd_data_ch0[2], dsd_data_ch0[3]);
        // printf("%x %x %x %x\n", dsd_data_ch1[0], dsd_data_ch1[1], dsd_data_ch1[2], dsd_data_ch1[3]);
    }
}