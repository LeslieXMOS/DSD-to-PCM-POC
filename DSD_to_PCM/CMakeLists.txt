# cmake
cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(DSD_to_PCM)

# root
set(XMOS_SANDBOX_DIR ${CMAKE_SOURCE_DIR}/../sandbox)


# Dependencies
set(APP_DEPENDENT_MODULES
    "lib_i2s"
    "lib_sw_pll"
    "lib_xassert"
    "lib_board_support"
    "lib_pdm"
)

# target
set(APP_HW_TARGET xk-audio-316-mc.xn)

set(APP_COMPILER_FLAGS
    -O3 -Wall -mcmodel=large -fxscope -g
    -DI2S_CHANNEL_CNT=2
    -DI2S_SAMPLE_FREQUENCY=44100
    -DI2S_DATA_BITS=32
    -DMCLK_FREQUENCY=22579200
    -DBOARD_SUPPORT_BOARD=XK_AUDIO_316_MC_AB
)

XMOS_REGISTER_APP()