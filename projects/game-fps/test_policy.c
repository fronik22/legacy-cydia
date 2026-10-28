#include "src/RuntimePolicy.h"
#include <assert.h>
int main(void){assert(!LegacyFPSOSAllowed(5));assert(LegacyFPSOSAllowed(6)&&LegacyFPSOSAllowed(7));assert(!LegacyFPSOSAllowed(8));return 0;}
