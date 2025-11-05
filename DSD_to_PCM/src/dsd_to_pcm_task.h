#ifndef DSD_TO_PCM_TASK_H
#define DSD_TO_PCM_TASK_H

#include "xccompat.h"

#if defined(__cplusplus) || defined(__XC__)
extern "C" {
#endif

#ifdef __XC__
    void dsd_to_pcm(streaming chanend c_dsd_in, streaming chanend c_pcm_out);
#else //__XC__
    void dsd_to_pcm(chanend c_dsd_in, chanend c_pcm_out);
#endif //__XC__

#if defined(__cplusplus) || defined(__XC__)
}
#endif

#endif  // DSD_TO_PCM_TASK_H