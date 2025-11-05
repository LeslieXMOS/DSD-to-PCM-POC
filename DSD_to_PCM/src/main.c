#include "pdm.h"

int test(void) {
    pdm_pcm_t pdm0, pdm1;
    uint32_t in_dsd[4];
    int32_t out_pcm[2];

    pdm_pcm_init(&pdm0);
    pdm_pcm_init(&pdm1);

    while (1) {
        pdm_pcm_x1_64_i128_o2(out_pcm, in_dsd, &pdm0);
    }
}