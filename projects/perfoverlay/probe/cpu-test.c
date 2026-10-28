#include "../tweak/CPUCounters.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
static double sample(PerfCPUTicks a,PerfCPUTicks b,uint64_t *busy,uint64_t *total) {
    return PerfCPUPercent(a,b,busy,total);
}
int main(void) {
    uint64_t b,t,b2,t2;PerfCPUTicks zero={0,0,0,0};
    assert(sample(zero,zero,&b,&t)==-1 && b==0 && t==0);
    assert(sample(zero,(PerfCPUTicks){0,0,0,100},&b,&t)==0);
    assert(sample(zero,(PerfCPUTicks){50,40,10,0},&b,&t)==100 && b==100 && t==100);
    assert(sample((PerfCPUTicks){UINT32_MAX-4,20,30,40},(PerfCPUTicks){5,25,35,60},&b,&t)==50 && b==20 && t==40);
    assert(sample(zero,(PerfCPUTicks){30,10,10,50},&b,&t)==50);
    assert(sample(zero,(PerfCPUTicks){100,0,0,100},&b2,&t2)==50);
    assert(fabs(100.0*(b+b2)/(t+t2)-50)<1e-9);
    sample(zero,(PerfCPUTicks){0,0,0,100},&b,&t);
    sample(zero,(PerfCPUTicks){200,0,0,0},&b2,&t2);
    assert(fabs(100.0*(b+b2)/(t+t2)-66.6666666667)<1e-8);
    puts("PASS: CPU deltas, idle/full, zero interval, 32-bit wrap and weighted core aggregate");
}
