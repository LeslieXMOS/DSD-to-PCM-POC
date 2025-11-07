# cmake
cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(DSD_generator)

# root
set(XMOS_SANDBOX_DIR ${CMAKE_SOURCE_DIR}/../sandbox)

# Dependencies
set(APP_DEPENDENT_MODULES lib_sw_pll)

set(APP_INCLUDES src)

# target
set(APP_HW_TARGET XK_VOICE_SQ66.xn)

set(BASE 44100 48000)
set(MULT 64 128 256 512)
set(FREQ 1000 2000 4000 8000 19997)

set(APP_COMPILER_FLAGS
    -O3 -Wall -mcmodel=large -fxscope -g
    -DDSD_CHANNEL_CNT=2
)

foreach(B ${BASE})
    foreach(M ${MULT})
        foreach(F ${FREQ})
            set(APP_COMPILER_FLAGS_DSD${M}_${B}_${F}
                ${APP_COMPILER_FLAGS}
                -DBASE=${B}
                -DMULT=${M}
                -DTEST_FREQ=${F}
            )
        endforeach()
    endforeach()
endforeach()

XMOS_REGISTER_APP()