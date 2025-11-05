#include <platform.h>
#include "i2s_task.h"
#include "stdio.h"
#include "xk_audio_316_mc_ab/board.h"
#include "i2c.h"
#include "dsd_to_pcm_task.h"

// I2S slave resources
on tile[1]: in buffered port:32 p_i2s_slave_din[1] = {PORT_I2S_DAC3};
on tile[1]: in port p_i2s_slave_bclk = PORT_I2S_DAC2;
on tile[1]: in buffered port:32 p_i2s_slave_lrclk = PORT_I2S_DAC1;
on tile[1]: clock i2s_slave_bclk = XS1_CLKBLK_1;

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

/* Working around not being able to extend an unsafe interface (Bugzilla #18670)*/
static i2c_regop_res_t i2c_reg_write(client i2c_master_if i2c, uint8_t device_addr, uint8_t reg, uint8_t data)
{
    uint8_t a_data[2] = {reg, data};
    size_t n;

    unsafe
    {
        i2c.write(device_addr, a_data, 2, n, 1);
    }

    if (n == 0)
    {
        return I2C_REGOP_DEVICE_NACK;
    }
    if (n < 2)
    {
        return I2C_REGOP_INCOMPLETE;
    }

    return I2C_REGOP_SUCCESS;
}

static void I2CWriteRegs(client i2c_master_if i2c, int deviceAddr, int numDevices, int regAddr, int regData)
{
    i2c_regop_res_t result;

    for(int i = deviceAddr; i < (deviceAddr + numDevices); i++)
    {
        unsafe
        {
            result = i2c_reg_write(i2c, i, regAddr, regData);
        }
        printf("r%d\n", result);
        assert(result == I2C_REGOP_SUCCESS && msg("I2C write reg failed"));
    }
}

int main(void)
{
    streaming chan c_dsd_in;
    streaming chan c_pcm_out;
    interface i2c_master_if i_i2c;

    par {
        on tile[0]: xk_audio_316_mc_ab_i2c_master(&i_i2c);
        on tile[0]: {
            board_setup();
            AudioHwInit(i_i2c);
            AudioHwConfig(i_i2c, I2S_SAMPLE_FREQUENCY,MCLK_FREQUENCY,0,I2S_DATA_BITS,I2S_DATA_BITS);
            I2CWriteRegs(i_i2c, (0x4A), 2, (0x70), 0x77);  // Sets ADCs into powerdown.
        };
        on tile[1]: dsd_to_pcm(c_dsd_in, c_pcm_out);
        on tile[1]: i2s_slave_task(c_dsd_in, NULL, 0, p_i2s_slave_din, 1, I2S_DATA_BITS, p_i2s_slave_bclk, p_i2s_slave_lrclk, i2s_slave_bclk);
        on tile[1]: i2s_master_task(c_pcm_out, p_i2s_master_dout, 1, NULL, 0, I2S_DATA_BITS, p_i2s_master_bclk, p_i2s_master_lrclk, p_i2s_master_mclk, i2s_master_bclk);
    }

    return 0;
}