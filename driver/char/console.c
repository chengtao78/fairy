#include <fairy.h>

/* Console only for the screen, and maintained by TTY
 */

/*
video_mem_start +----------------+
                |                |
                |                |
                |                |
          origin+----------------+
                | x,y(相对于屏幕)|
                |                |
                +----------------+screen_end
                |                |
                |                |
                |                |
                |                |
                |                |
                +----------------+video_mem_end
*/


