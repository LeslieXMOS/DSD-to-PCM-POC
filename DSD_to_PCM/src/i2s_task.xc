// Copyright 2018-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

/* A simple application example used for code snippets in the library
 * documentation.
 */
#include <platform.h>
#include <xs1.h>
#include "i2s.h"
#include "i2s_task.h"

#define SAMPLE_FREQUENCY (I2S_SAMPLE_FREQUENCY)
#define MASTER_CLOCK_FREQUENCY (MCLK_FREQUENCY)
#define DATA_BITS (32)
#define RING_BUFF_SIZE (512)

[[distributable]]
void i2s_master_application(server i2s_frame_callback_if i_i2s, streaming chanend c_i2s[I2S_CHANNEL_CNT], chanend c_ctrl) {
    // Cannot dynamic allocate base on num_in, set a large number instead
    int ring_buffer[32][RING_BUFF_SIZE];
    int ring_buffer_send_idx = 0;
    int sample_rate = SAMPLE_FREQUENCY;
    int mclk_freq = MASTER_CLOCK_FREQUENCY;
    int control_token;
    for (int i = 0; i < I2S_CHANNEL_CNT; ++i) {
        c_i2s[i] <: (unsigned)ring_buffer[i];
        c_i2s[i] <: RING_BUFF_SIZE;
    }
    while (1) {
        select {
        case i_i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
            i2s_config.mclk_bclk_ratio = (mclk_freq / (sample_rate*2*DATA_BITS));
            i2s_config.mode = I2S_MODE_I2S;
            // Complete setup
            break;
        case i_i2s.restart_check() -> i2s_restart_t restart:
            // Inform the I2S slave whether it should restart or exit
            control_token = inct(c_ctrl);
            if (control_token == NEW_SAMPLE_FREQ) {
                c_ctrl :> sample_rate;
                c_ctrl :> mclk_freq;
                restart = I2S_RESTART;
            } else if (control_token == NO_SAMPLE_FREQ) {
                restart = I2S_NO_RESTART;
            } else {
                restart = I2S_SHUTDOWN;
            }
            c_ctrl <: 1;
            break;
        case i_i2s.receive(size_t num_in, int32_t samples[num_in]):
            // Handle a received sample
            break;
        case i_i2s.send(size_t num_out, int32_t samples[num_out]):
            // Provide a sample to send
            for (int i = 0; i < num_out; ++i) {
                samples[i] = ring_buffer[i][ring_buffer_send_idx];
            }
            ring_buffer_send_idx += 1;
            ring_buffer_send_idx %= RING_BUFF_SIZE;
            break;
        }
    }
}


int i2s_master_task(
    streaming chanend c_i2s[I2S_CHANNEL_CNT],
    out buffered port:32 (&?p_dout)[num_out],
    static const size_t num_out,
    in buffered port:32 (&?p_din)[num_in],
    static const size_t num_in,
    static const size_t num_data_bits,
    out port p_bclk,
    out buffered port:32 p_lrclk,
    in port p_mclk,
    clock bclk,
    chanend c_ctrl)
{
    interface i2s_frame_callback_if i_i2s;

    par {
        i2s_frame_master(i_i2s, p_dout, num_out, p_din, num_in, num_data_bits, p_bclk, p_lrclk, p_mclk, bclk);
        i2s_master_application(i_i2s, c_i2s, c_ctrl);
    }
    return 0;
}

[[distributable]]
void i2s_slave_application(server i2s_frame_callback_if i_i2s, streaming chanend c_i2s[I2S_CHANNEL_CNT]) {
    // Cannot dynamic allocate base on num_in, set a large number instead
    int ring_buffer[32][RING_BUFF_SIZE];
    int ring_buffer_idx = 0;
    while (1) {
        select {
        case i_i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
            i2s_config.mode = I2S_MODE_I2S;
            // Complete setup
            break;
        case i_i2s.restart_check() -> i2s_restart_t restart:
            // Inform the I2S slave whether it should restart or exit
            restart = I2S_NO_RESTART;
            break;
        case i_i2s.receive(size_t num_in, int32_t samples[num_in]):
            // Handle a received sample
            for (int i = 0; i < num_in; ++i) {
                ring_buffer[i][ring_buffer_idx] = samples[i];
            }
            ring_buffer_idx += 1;
            if (ring_buffer_idx % 8 == 0) {
                if (ring_buffer_idx == 0) {
                    for (int i = 0; i < num_in; ++i) {
                        c_i2s[i] <: (unsigned)(&(ring_buffer[i][RING_BUFF_SIZE-8]));
                    }
                } else {
                    for (int i = 0; i < num_in; ++i) {
                        c_i2s[i] <: (unsigned)(&(ring_buffer[i][ring_buffer_idx-8]));
                    }
                }
                ring_buffer_idx %= RING_BUFF_SIZE;
            }
            break;
        case i_i2s.send(size_t num_out, int32_t samples[num_out]):
            // Provide a sample to send
            break;
        }
    }
}

int i2s_slave_task(
    streaming chanend c_i2s[I2S_CHANNEL_CNT],
    out buffered port:32 (&?p_dout)[num_out],
    static const size_t num_out,
    in buffered port:32 (&?p_din)[num_in],
    static const size_t num_in,
    static const size_t num_data_bits,
    in port p_bclk,
    in buffered port:32 p_lrclk,
    clock bclk)
{
    interface i2s_frame_callback_if i_i2s;

    par {
        i2s_frame_slave(i_i2s, p_dout, num_out, p_din, num_in, num_data_bits, p_bclk, p_lrclk, bclk);
        i2s_slave_application(i_i2s, c_i2s);
    }
    return 0;
}
