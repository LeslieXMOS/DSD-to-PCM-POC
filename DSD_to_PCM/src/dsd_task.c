#include <xcore/port.h>
#include <xcore/clock.h>
#include <xcore/channel.h>
#include <xcore/channel_streaming.h>
#include "dsd_task.h"
#include <xcore/select.h>
#include <xcore/parallel.h>

#define RING_BUFF_SIZE  (512)

// DSD format lookup table, {lower bound, upper bound, base, multiple}
unsigned format_lut[8][4] = {
    {140, 144, 44100, 512},
    {128, 132, 48000, 512},
    {281, 285, 44100, 256},
    {258, 262, 48000, 256},
    {565, 569, 44100, 128},
    {518, 522, 48000, 128},
    {1132, 1136, 44100, 64},
    {1040, 1044, 48000, 64},
};

void dsd_slave_task(
    chanend_t* c_dsd,
    port_t *p_din,
    size_t num_in,
    port_t p_bclk,
    xclock_t clkblk,
    chanend_t c_ctrl)
{
    // Cannot dynamic allocate base on num_in, set a large number instead
    int ring_buffer[32][RING_BUFF_SIZE];
    int ring_buffer_idx = 0;
    volatile unsigned t0, t1;
    unsigned format = 0;
    unsigned can_update_format = 0;

    clock_enable(clkblk);
    clock_set_source_port(clkblk, p_bclk);
    clock_set_divide(clkblk, 0);

    for (size_t i = 0; i < num_in; i++) {
        port_start_buffered(p_din[i], 32);
        port_set_clock(p_din[i], clkblk);
        port_clear_buffer(p_din[i]);
    }

    clock_start(clkblk);

    SELECT_RES(
        CASE_THEN(c_ctrl, format_handler),
        DEFAULT_THEN(dsd_handler)
    ) {
        format_handler: {
            chan_in_word(c_ctrl);
            can_update_format = 1;
            continue;
        }
        dsd_handler: {
            for (size_t i = 0; i < num_in; ++i) {
                unsigned data = port_in(p_din[i]);
                asm volatile("bitrev %0, %1" : "=r"(ring_buffer[i][ring_buffer_idx]) : "r"(data));
            }
            // Format detection
            asm volatile("gettime %0" : "=r"(t1));
            unsigned delta = t1-t0;
            if (can_update_format) {
                if (delta < format_lut[format][0] || delta > format_lut[format][1]) {
                    // Incorrect format
                    for (int i = 0; i < 8; ++i) {
                        if (delta >= format_lut[i][0] && delta <= format_lut[i][1]) {
                            format = i;
                            chan_out_word(c_ctrl, format_lut[format][2]);
                            chan_out_word(c_ctrl, format_lut[format][3]);
                            break;
                        }
                    }
                }
            }
            t0 = t1;
            // Format detection ended
            // Handle a received sample
            ring_buffer_idx += 1;
            if (ring_buffer_idx % 4 == 0) {
                if (ring_buffer_idx == 0) {
                    for (size_t i = 0; i < num_in; ++i) {
                        s_chan_out_word(c_dsd[i], (unsigned)(&(ring_buffer[i][RING_BUFF_SIZE-4])));
                    }
                } else {
                    for (size_t i = 0; i < num_in; ++i) {
                        s_chan_out_word(c_dsd[i], (unsigned)(&(ring_buffer[i][ring_buffer_idx-4])));
                    }
                }
            }
            ring_buffer_idx %= RING_BUFF_SIZE;
            continue;
        }
    }
}