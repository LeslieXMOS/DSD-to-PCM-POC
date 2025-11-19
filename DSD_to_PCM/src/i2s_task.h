#include <xs1.h>
#include <xclib.h>
#include "i2s.h"
#include <print.h>
#include "limits.h"
#include "xassert.h"
#include <stdlib.h>
#include <stdio.h>

#pragma unsafe arrays
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
    chanend c_ctrl);

#pragma unsafe arrays
int i2s_slave_task(
    streaming chanend c_i2s[I2S_CHANNEL_CNT],
    out buffered port:32 (&?p_dout)[num_out],
    static const size_t num_out,
    in buffered port:32 (&?p_din)[num_in],
    static const size_t num_in,
    static const size_t num_data_bits,
    in port p_bclk,
    in buffered port:32 p_lrclk,
    clock bclk,
    chanend c_ctrl);