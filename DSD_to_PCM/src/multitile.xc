#include <platform.h>
#include "i2s_task.h"
#include "stdio.h"
#include "xk_audio_316_mc_ab/board.h"
#include "i2c.h"
#include "dsd_to_pcm_task.h"
#include "dsd_task.h"
#include <xs1.h>

#if defined(DSD_IN_MODE) && DSD_IN_MODE == 0    // DSD interface
// DSD slave resources
on tile[1]: in buffered port:32 p_dsd_slave_din[2] = {PORT_I2S_DAC1, PORT_I2S_DAC3};
on tile[1]: in port p_dsd_slave_bclk = PORT_I2S_DAC2;
on tile[1]: clock dsd_slave_clkblk = XS1_CLKBLK_1;

#elif defined(DSD_IN_MODE) && DSD_IN_MODE == 1  // DOP I2S interface
// I2S slave resources
on tile[1]: in buffered port:32 p_i2s_slave_din[1] = {PORT_I2S_DAC3};
on tile[1]: in port p_i2s_slave_bclk = PORT_I2S_DAC2;
on tile[1]: in buffered port:32 p_i2s_slave_lrclk = PORT_I2S_DAC1;
on tile[1]: clock i2s_slave_bclk = XS1_CLKBLK_1;

#else
#error "unsupport DSD in mode"
#endif

// I2S master resources
on tile[1]: out buffered port:32 p_i2s_master_dout[1] = {PORT_I2S_DAC0};
on tile[1]: out port p_i2s_master_bclk = PORT_I2S_BCLK;
on tile[1]: out buffered port:32 p_i2s_master_lrclk = PORT_I2S_LRCLK;
on tile[1]: in port p_i2s_master_mclk = PORT_MCLK_IN;
on tile[1]: clock i2s_master_bclk = XS1_CLKBLK_2;


// Board configuration from lib_board_support
static const xk_audio_316_mc_ab_config_t config = {
        CLK_FIXED,              // clk_mode. Drive a fixed MCLK output
        0,                      // 1 = dac_is_clock_master
        MCLK_FREQUENCY,
        0,                      // pll_sync_freq (unused when driving fixed clock)
        0,                      // 0 for I2S 1 for TDM
        I2S_DATA_BITS,
        2
};

unsafe client interface i2c_master_if i_i2c_client;

/* Board setup for XU316 MC Audio (1v1) */
void board_setup()
{
    xk_audio_316_mc_ab_board_setup(config);
}

/* Configures the external audio hardware at startup */
void AudioHwInit(client i2c_master_if i_i2c)
{
    unsafe
    {
        xk_audio_316_mc_ab_AudioHwInit(i_i2c, config);
    }
}

/* Configures the external audio hardware for the required sample frequency */
void AudioHwConfig(client i2c_master_if i_i2c, unsigned samFreq, unsigned mClk, unsigned dsdMode, unsigned sampRes_DAC, unsigned sampRes_ADC)
{
    unsafe {xk_audio_316_mc_ab_AudioHwConfig(i_i2c, config, samFreq, mClk, dsdMode, sampRes_DAC, sampRes_ADC);}
}

void audio_format_task(client i2c_master_if i_i2c, chanend c_ctrl, chanend c_i2s_ctrl) {
    unsigned samFreq = I2S_SAMPLE_FREQUENCY;
    unsigned mClk = MCLK_FREQUENCY;
    unsigned dsdMode = 0;
    unsigned sampRes_DAC = I2S_DATA_BITS;
    unsigned sampRes_ADC = I2S_DATA_BITS;
    unsigned format_updated = 0;
    unsafe {
        xk_audio_316_mc_ab_AudioHwConfig(i_i2c, config, samFreq, mClk, dsdMode, sampRes_DAC, sampRes_ADC);
        c_ctrl <: 1;
        outct(c_i2s_ctrl, NO_SAMPLE_FREQ);
        while (1) {
            select {
                case c_ctrl :> unsigned base : {
                    unsigned mult;
                    c_ctrl :> mult;
                    samFreq = base * mult / 64; // lib_pdm support 128-bit in 2*32-bit out
                    mClk = base * 512;
                    printf("Detected DSD%d with base %dHz, changing configuration to MCLK: %dHz I2S:%dHz\n", mult, base, mClk, samFreq);
                    xk_audio_316_mc_ab_AudioHwConfig(i_i2c, config, samFreq, mClk, dsdMode, sampRes_DAC, sampRes_ADC);
                    format_updated = 1;
                    c_ctrl <: 1;
                    break;
                }
                case c_i2s_ctrl :> int dummy : {
                    if (format_updated) {
                        outct(c_i2s_ctrl, NEW_SAMPLE_FREQ);
                        c_i2s_ctrl <: samFreq;
                        c_i2s_ctrl <: mClk;
                        format_updated = 0;
                    } else {
                        outct(c_i2s_ctrl, NO_SAMPLE_FREQ);
                    }
                    break;
                }
            }
        }
    }
}

int main(void)
{
    streaming chan c_dsd_in[2];
    streaming chan c_pcm_out[2];
    chan c_ctrl[2];
    interface i2c_master_if i_i2c[1];

    par {
        on tile[0]: xk_audio_316_mc_ab_i2c_master(i_i2c);
        on tile[0]: {
            board_setup();
            AudioHwInit(i_i2c[0]);
            audio_format_task(i_i2c[0], c_ctrl[0], c_ctrl[1]);
        };
        on tile[1]: dsd_to_pcm_task(c_dsd_in[0], c_pcm_out[0]);
        on tile[1]: dsd_to_pcm_task(c_dsd_in[1], c_pcm_out[1]);
#if DSD_IN_MODE == 0
        on tile[1]: dsd_slave_task(c_dsd_in, p_dsd_slave_din, 2, p_dsd_slave_bclk, dsd_slave_clkblk, c_ctrl[0]);
#elif DSD_IN_MODE == 1
        on tile[1]: i2s_slave_task(c_dsd_in, NULL, 0, p_i2s_slave_din, 1, I2S_DATA_BITS, p_i2s_slave_bclk, p_i2s_slave_lrclk, i2s_slave_bclk);
#endif
        on tile[1]: i2s_master_task(c_pcm_out, p_i2s_master_dout, 1, NULL, 0, I2S_DATA_BITS, p_i2s_master_bclk, p_i2s_master_lrclk, p_i2s_master_mclk, i2s_master_bclk, c_ctrl[1]);
    }

    return 0;
}