#define PERF_GPU_TIME_POLICY_ONLY
#include "../tweak/GPUTime.h"
#include <assert.h>
#include <stdio.h>
int main(void){
    uint64_t a[7]={100,20,0,0,0,0,0},b[7]={200,20,0,0,0,0,0};double p=-7;
    assert(PerfGPUTimeDelta(a,b,100,&p)&&p==0);
    b[0]=150;b[1]=70;assert(PerfGPUTimeDelta(a,b,100,&p)&&p==50);
    b[0]=100;b[1]=120;assert(PerfGPUTimeDelta(a,b,100,&p)&&p==100);
    b[0]=99;p=-7;assert(!PerfGPUTimeDelta(a,b,100,&p)&&p==-7);
    b[0]=150;b[1]=70;assert(!PerfGPUTimeDelta(a,b,0,&p));
    assert(!PerfGPUTimeDelta(a,b,200,&p));
    assert(PerfGPUTimeDelta(a,b,104,&p)&&p==50);
    assert(!PerfGPUTimeDelta(NULL,b,100,&p));assert(!PerfGPUTimeDelta(a,b,100,NULL));
    uint64_t zero[7]={0},overflow[7]={UINT64_MAX-1,2,0,0,0,0,0};
    assert(!PerfGPUTimeDelta(zero,overflow,100,&p));
    b[3]=UINT64_MAX;assert(!PerfGPUTimeDelta(a,b,100,&p));
    assert(!PerfGPUTimeDelta(a,a,100,&p));
    puts("PASS GPU powered-residency idle/partial/full, monotonic/reset, overflow/sentinel, unit calibration and invalid inputs");
}
