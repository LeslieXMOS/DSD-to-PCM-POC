#ifndef DSD_TASK_H
#define DSD_TASK_H

// #include "xccompat.h"

#if defined(__cplusplus) || defined(__XC__)
extern "C" {
#endif

#ifdef __XC__
    #pragma unsafe arrays
    void dsd_slave_task(
        streaming chanend c_dsd,
        in buffered port:32 (&?p_din)[num_in],
        size_t num_in,
        in port p_bclk,
        clock clkblk);
#else //__XC__
    void dsd_slave_task(
        chanend_t c_dsd,
        port_t *p_din,
        size_t num_in,
        port_t p_bclk,
        xclock_t clkblk);
#endif //__XC__

#if defined(__cplusplus) || defined(__XC__)
}
#endif

#endif  // DSD_TASK_H