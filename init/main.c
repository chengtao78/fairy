#include <fairy.h>
#include <fairy/stdint.h>

int start_kernel()
{
    uint8_t     *vmem = (uint8_t*)0xC00B8000;
    int         i;
    uint8_t     mem[24] = "HHEELLLLOO\n\n";

    for (i = 0; i < 12; i++) {
        vmem[i] = mem[i];
    }

    while (1);
}
