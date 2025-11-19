#include <platform.h>
#include "stdio.h"
#include "xk_audio_316_mc_ab/board.h"
#include "i2c.h"
#include <xs1.h>
#include "i2s_task.h"

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
                    if (mult < 64) {
                        // I2S/DOP
                        samFreq = base * mult;
                        mClk = base * 512;
                        printf("Detected I2S%d with base %dHz, changing configuration to MCLK: %dHz I2S:%dHz\n", mult, base, mClk, samFreq);
                        xk_audio_316_mc_ab_AudioHwConfig(i_i2c, config, samFreq, mClk, dsdMode, sampRes_DAC, sampRes_ADC);
                    } else {
                        // DSD
                        samFreq = base * mult / 64; // lib_pdm support 128-bit in 2*32-bit out
                        mClk = base * 512;
                        printf("Detected DSD%d with base %dHz, changing configuration to MCLK: %dHz I2S:%dHz\n", mult, base, mClk, samFreq);
                        xk_audio_316_mc_ab_AudioHwConfig(i_i2c, config, samFreq, mClk, dsdMode, sampRes_DAC, sampRes_ADC);
                    }
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