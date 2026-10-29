#include "PlatformPolicy.h"
#include <assert.h>
int main(void){assert(sizeof(struct LPTask)==96);assert(offsetof(struct LPTask,user_ticks)==16);assert(offsetof(struct LPTask,resident_size)==8);assert(LPOSAllowed(6)&&LPOSAllowed(7));assert(!LPOSAllowed(5)&&!LPOSAllowed(8));return 0;}
