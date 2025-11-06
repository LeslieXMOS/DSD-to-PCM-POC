#include <xcore/port.h>
#include <xcore/clock.h>
#include <xcore/channel_streaming.h>
#include "dsd_task.h"

#define RING_BUFF_SIZE  (512)

void dsd_slave_task(
    chanend_t c_dsd,
    port_t *p_din,
    size_t num_in,
    port_t p_bclk,
    xclock_t clkblk)
{
    int ring_buffer[2][RING_BUFF_SIZE];
    int ring_buffer_idx = 0;

    clock_enable(clkblk);
    clock_set_source_port(clkblk, p_bclk);
    clock_set_divide(clkblk, 0);

    for (size_t i = 0; i < num_in; i++) {
        port_start_buffered(p_din[i], 32);
        port_set_clock(p_din[i], clkblk);
        port_clear_buffer(p_din[i]);
    }

    clock_start(clkblk);
    while (1) {
        for (size_t i = 0; i < num_in; i++) {
            unsigned data = port_in(p_din[i]);
            asm volatile("bitrev %0, %1" : "=r"(ring_buffer[i][ring_buffer_idx]) : "r"(data));
        }
        // Handle a received sample
        ring_buffer_idx += 1;
        if (ring_buffer_idx % 4 == 0) {
            if (ring_buffer_idx == 0) {
                s_chan_out_word(c_dsd, (unsigned)(&(ring_buffer[0][RING_BUFF_SIZE-4])));
                s_chan_out_word(c_dsd, (unsigned)(&(ring_buffer[1][RING_BUFF_SIZE-4])));
            } else {
                s_chan_out_word(c_dsd, (unsigned)(&(ring_buffer[0][ring_buffer_idx-4])));
                s_chan_out_word(c_dsd, (unsigned)(&(ring_buffer[1][ring_buffer_idx-4])));
            }
        }
        ring_buffer_idx %= RING_BUFF_SIZE;
    }
}