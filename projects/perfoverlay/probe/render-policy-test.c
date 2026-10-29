#include "../tweak/HUDRenderPolicy.h"
#include <assert.h>
#include <stdio.h>
int main(void){
 assert(!PerfHUDRenderDue(10,0,1,1,1,0,0));
 assert(PerfHUDRenderDue(10,0,1,1,1,0,1));
 assert(!PerfHUDRenderDue(10,9,1,1,1,1,1));
 assert(PerfHUDRenderDue(14,9,1,1,1,0,1));
 assert(PerfHUDRenderDue(10,9,1,1,1,60,1));
 assert(PerfHUDRenderDue(10,9,1,0,1,0,1));
 assert(PerfHUDRenderDue(10,9,1,1,0,0,1));
 assert(PerfHUDRenderDue(8,9,1,1,1,0,1));
 assert(!PerfHUDRenderDue(10,9,.5,1,1,2,1));
 assert(PerfHUDRenderDue(10,9,1,1,1,2,1));
 assert(PerfHUDRenderDue(14,9,5,1,1,.2,1));
 puts("PASS idle own-frame threshold, active rendering, changed-only text, first/reset/fallback and user intervals");
}
