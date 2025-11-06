#include <xcore/port.h>
#include <platform.h>
#include <xcore/clock.h>
#include "sw_pll.h"
#include "stdint.h"
#include "signal.h"

#define MCLK_FREQUENCY  (BASE*512)

void dsd_generator(void) {
    printf("Generating DSD%d signal with %dHz tone\n", MULT, TEST_FREQ);
    port_t p_dsd_out[DSD_CHANNEL_CNT] = {PORT_I2S_DATA0, PORT_I2S_DATA1};
    port_t p_dsd_bclk = PORT_I2S_BCLK;
    port_t p_dsd_mclk = PORT_MCLK_IN_OUT;
    xclock_t dsd_clkblk = XS1_CLKBLK_1;

    sw_pll_fixed_clock(MCLK_FREQUENCY);

    port_enable(p_dsd_bclk);
    port_enable(p_dsd_mclk);

    clock_enable(dsd_clkblk);
    clock_set_source_port(dsd_clkblk, p_dsd_mclk);
    clock_set_divide(dsd_clkblk, (MCLK_FREQUENCY/(BASE*MULT)) >> 1);

    for (size_t i = 0; i < DSD_CHANNEL_CNT; i++) {
        port_start_buffered(p_dsd_out[i], 32);
        port_set_clock(p_dsd_out[i], dsd_clkblk);
        port_clear_buffer(p_dsd_out[i]);
    }

    port_set_clock(p_dsd_bclk, dsd_clkblk);
    port_set_out_clock(p_dsd_bclk);

    size_t signal_len = sizeof(sig) / sizeof(uint32_t);

    for (size_t j = 0; j < DSD_CHANNEL_CNT; j++) {
        port_out(p_dsd_out[j], 0);
    }
    clock_start(dsd_clkblk);
    while (1) {
        for (int i = 0; i < signal_len; ++i) {
            unsigned data;
            asm volatile("bitrev %0, %1" : "=r"(data) : "r"(sig[i]));
            for (size_t j = 0; j < DSD_CHANNEL_CNT; j++) {
                port_out(p_dsd_out[j], data);
            }
        }
    }
}