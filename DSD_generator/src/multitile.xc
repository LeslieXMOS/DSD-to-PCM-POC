#include <platform.h>
#include "stdio.h"

extern "C" {
    void dsd_generator(void);
}

int main(void)
{
    par {
        on tile[1]: dsd_generator();
    }

    return 0;
}