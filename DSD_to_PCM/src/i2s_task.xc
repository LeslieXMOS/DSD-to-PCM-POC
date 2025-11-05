// Copyright 2018-2025 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

/* A simple application example used for code snippets in the library
 * documentation.
 */
#include <platform.h>
#include <xs1.h>
#include "i2s.h"

#define SAMPLE_FREQUENCY (I2S_SAMPLE_FREQUENCY)
#define MASTER_CLOCK_FREQUENCY (MCLK_FREQUENCY)
#define DATA_BITS (32)
#define RING_BUFF_SIZE (512)

[[distributable]]
void i2s_master_application(server i2s_frame_callback_if i_i2s, streaming chanend c_i2s) {
    int ring_buffer[2][RING_BUFF_SIZE];
    int ring_buffer_send_idx = 0;
    c_i2s <: (unsigned)ring_buffer[0];
    c_i2s <: (unsigned)ring_buffer[1];
    c_i2s <: RING_BUFF_SIZE;
    while (1) {
        select {
        case i_i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
            i2s_config.mclk_bclk_ratio = (MASTER_CLOCK_FREQUENCY / (SAMPLE_FREQUENCY*2*DATA_BITS));
            i2s_config.mode = I2S_MODE_I2S;
            // Complete setup
            break;
        case i_i2s.restart_check() -> i2s_restart_t restart:
            // Inform the I2S slave whether it should restart or exit
            restart = I2S_NO_RESTART;
            break;
        case i_i2s.receive(size_t num_in, int32_t samples[num_in]):
            // Handle a received sample
            break;
        case i_i2s.send(size_t num_out, int32_t samples[num_out]):
            // Provide a sample to send
            samples[0] = ring_buffer[0][ring_buffer_send_idx];
            samples[1] = ring_buffer[1][ring_buffer_send_idx++];
            ring_buffer_send_idx %= RING_BUFF_SIZE;
            break;
        }
    }
}


int i2s_master_task(
    streaming chanend c_i2s,
    out buffered port:32 (&?p_dout)[num_out],
    static const size_t num_out,
    in buffered port:32 (&?p_din)[num_in],
    static const size_t num_in,
    static const size_t num_data_bits,
    out port p_bclk,
    out buffered port:32 p_lrclk,
    in port p_mclk,
    clock bclk)
{
    interface i2s_frame_callback_if i_i2s;

    par {
        i2s_frame_master(i_i2s, p_dout, num_out, p_din, num_in, num_data_bits, p_bclk, p_lrclk, p_mclk, bclk);
        i2s_master_application(i_i2s, c_i2s);
    }
    return 0;
}

[[distributable]]
void i2s_slave_application(server i2s_frame_callback_if i_i2s, streaming chanend c_i2s) {
    int ring_buffer[2][RING_BUFF_SIZE];
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
            ring_buffer[0][ring_buffer_idx] = samples[0];
            ring_buffer[1][ring_buffer_idx++] = samples[1];
            if (ring_buffer_idx % 8 == 0) {
                if (ring_buffer_idx == 0) {
                    c_i2s <: (unsigned)(&(ring_buffer[0][RING_BUFF_SIZE-8]));
                    c_i2s <: (unsigned)(&(ring_buffer[1][RING_BUFF_SIZE-8]));
                } else {
                    c_i2s <: (unsigned)(&(ring_buffer[0][ring_buffer_idx-8]));
                    c_i2s <: (unsigned)(&(ring_buffer[1][ring_buffer_idx-8]));
                }
            }
            ring_buffer_idx %= RING_BUFF_SIZE;
            break;
        case i_i2s.send(size_t num_out, int32_t samples[num_out]):
            // Provide a sample to send
            break;
        }
    }
}

int i2s_slave_task(
    streaming chanend c_i2s,
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
