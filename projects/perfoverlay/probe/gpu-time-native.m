#import "../tweak/GPUTime.h"
#include <unistd.h>
#include <stdio.h>
int main(void){@autoreleasepool{
    for(int cycle=0;cycle<2;cycle++){
        BOOL available=PerfGPUAwakeAvailable();printf("cycle=%d available=%d uid=%u\n",cycle,available,getuid());
        if(!available){PerfGPUAwakeReset();return 2;}
        for(int i=0;i<3;i++){double p=PerfGPUAwakePercent();printf("cycle=%d sample=%d powered_percent=%.6f\n",cycle,i,p);fflush(stdout);if(i==0&&p!=-1){PerfGPUAwakeReset();return 3;}if(i<2)usleep(1000000);}
        PerfGPUAwakeReset();
    }
    return 0;
}}
