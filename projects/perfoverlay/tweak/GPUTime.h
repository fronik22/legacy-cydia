#ifndef PERF_GPU_TIME_H
#define PERF_GPU_TIME_H
#include <stdint.h>
#include <math.h>

// OFF plus the six known A7 performance states; compare cumulative partitions, not read-cleared snapshots.
static inline int PerfGPUTimeDelta(const uint64_t before[7],const uint64_t after[7],uint64_t elapsed,double *percent) {
    if(!before||!after||!percent||!elapsed)return 0;
    uint64_t total=0,off=0;
    for(unsigned i=0;i<7;i++){
        if(before[i]==UINT64_MAX||after[i]==UINT64_MAX||after[i]<before[i])return 0;
        uint64_t delta=after[i]-before[i];
        if(UINT64_MAX-total<delta)return 0;
        total+=delta;if(!i)off=delta;
    }
    if(!total||fabs((double)total/(double)elapsed-1.0)>0.05)return 0;
    double value=100.0*(double)(total-off)/(double)total;
    if(!isfinite(value)||value<0||value>100)return 0;
    *percent=value;return 1;
}

#ifndef PERF_GPU_TIME_POLICY_ONLY
#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <dlfcn.h>

// Original declarations/call flow; ABI and CFRelease ownership checked against Apple's pmset494.30.1.
typedef CFMutableDictionaryRef(*PerfGPUTCopy)(CFDictionaryRef,uint64_t,CFTypeRef);
typedef CFTypeRef(*PerfGPUTSubscribe)(void*,CFMutableDictionaryRef,CFMutableDictionaryRef*,uint64_t,CFTypeRef);
typedef CFDictionaryRef(*PerfGPUTSamples)(CFTypeRef,CFMutableDictionaryRef,CFTypeRef);
typedef int(*PerfGPUTIterate)(CFDictionaryRef,int(^)(CFDictionaryRef));
typedef uint64_t(*PerfGPUTID)(CFDictionaryRef);
typedef uint32_t(*PerfGPUTCount)(CFDictionaryRef);
typedef uint64_t(*PerfGPUTValue)(CFDictionaryRef,uint32_t);
static struct {
    int attempted,baseline;
    void *reportLibrary,*ioLibrary;
    CFMutableDictionaryRef channels;
    CFTypeRef subscription;
    PerfGPUTSamples samples;
    PerfGPUTIterate iterate;
    PerfGPUTID channelID;
    PerfGPUTCount stateCount;
    PerfGPUTValue stateID,residency;
    uint64_t previous[7],lastTicks;
} gPerfGPUTime;

static void PerfGPUAwakeReset(void) {
    if(gPerfGPUTime.subscription)CFRelease(gPerfGPUTime.subscription);
    if(gPerfGPUTime.channels)CFRelease(gPerfGPUTime.channels);
    if(gPerfGPUTime.reportLibrary)dlclose(gPerfGPUTime.reportLibrary);
    if(gPerfGPUTime.ioLibrary)dlclose(gPerfGPUTime.ioLibrary);
    gPerfGPUTime=(__typeof__(gPerfGPUTime)){0};
}

static BOOL PerfGPUAwakeAvailable(void) {
    if(gPerfGPUTime.attempted)return gPerfGPUTime.subscription!=NULL;
    gPerfGPUTime.attempted=1;
#if !defined(__LP64__)
    return NO; // The private helper ABI is verified only in the A7 arm64 runtime.
#endif
    int major=[[[NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"]objectForKey:@"ProductVersion"]intValue];
    if(major!=7)return NO;
    CFMutableDictionaryRef desired=NULL,match=NULL;
    gPerfGPUTime.reportLibrary=dlopen("/System/Library/PrivateFrameworks/PowerlogCoreLoggers.framework/PowerlogCoreLoggers",RTLD_LAZY|RTLD_LOCAL);
    gPerfGPUTime.ioLibrary=dlopen("/System/Library/Frameworks/IOKit.framework/IOKit",RTLD_LAZY|RTLD_LOCAL);
    if(!gPerfGPUTime.reportLibrary||!gPerfGPUTime.ioLibrary)goto failed;
    PerfGPUTCopy copy=(PerfGPUTCopy)dlsym(gPerfGPUTime.reportLibrary,"IOReportCopyChannelsWithID");
    PerfGPUTSubscribe subscribe=(PerfGPUTSubscribe)dlsym(gPerfGPUTime.reportLibrary,"IOReportCreateSubscription");
    gPerfGPUTime.samples=(PerfGPUTSamples)dlsym(gPerfGPUTime.reportLibrary,"IOReportCreateSamples");
    gPerfGPUTime.iterate=(PerfGPUTIterate)dlsym(gPerfGPUTime.reportLibrary,"IOReportIterate");
    gPerfGPUTime.channelID=(PerfGPUTID)dlsym(gPerfGPUTime.reportLibrary,"IOReportChannelGetChannelID");
    gPerfGPUTime.stateCount=(PerfGPUTCount)dlsym(gPerfGPUTime.reportLibrary,"IOReportStateGetCount");
    gPerfGPUTime.stateID=(PerfGPUTValue)dlsym(gPerfGPUTime.reportLibrary,"IOReportStateGetIDForIndex");
    gPerfGPUTime.residency=(PerfGPUTValue)dlsym(gPerfGPUTime.reportLibrary,"IOReportStateGetResidency");
    CFMutableDictionaryRef(*matching)(const char*)=dlsym(gPerfGPUTime.ioLibrary,"IOServiceMatching");
    if(!copy||!subscribe||!matching||!gPerfGPUTime.samples||!gPerfGPUTime.iterate||!gPerfGPUTime.channelID||!gPerfGPUTime.stateCount||!gPerfGPUTime.stateID||!gPerfGPUTime.residency)goto failed;
    match=matching("AGXAcceleratorG3_B0");if(!match)goto failed;
    desired=copy(match,0x4750555048000000ULL,NULL);CFRelease(match);match=NULL;
    if(!desired)goto failed;
    gPerfGPUTime.subscription=subscribe(NULL,desired,&gPerfGPUTime.channels,0,NULL);
    CFRelease(desired);desired=NULL;
    if(!gPerfGPUTime.subscription||!gPerfGPUTime.channels)goto failed;
    return YES;
failed:
    if(match)CFRelease(match);if(desired)CFRelease(desired);
    PerfGPUAwakeReset();gPerfGPUTime.attempted=1;return NO;
}

static double PerfGPUAwakePercent(void) {
    if(!PerfGPUAwakeAvailable())return -1;
    uint64_t before=mach_absolute_time();
    CFDictionaryRef sample=gPerfGPUTime.samples(gPerfGPUTime.subscription,gPerfGPUTime.channels,NULL);
    uint64_t after=mach_absolute_time();
    if(!sample){gPerfGPUTime.baseline=0;return -1;}
    uint64_t values[7]={0};uint64_t *output=values;
    __block unsigned channels=0;__block int valid=1;
    int result=gPerfGPUTime.iterate(sample,^int(CFDictionaryRef channel){
        static const uint64_t ids[]={0x4f46460000000000ULL,0x564c4f5700000000ULL,0x564e4f4d00000000ULL,0x564d415800000000ULL,0x564c4f57494e5400ULL,0x564e4f4d494e5400ULL,0x564d4158494e5400ULL};
        channels++;
        if(!channel||CFGetTypeID(channel)!=CFDictionaryGetTypeID()||gPerfGPUTime.channelID(channel)!=0x4750555048000000ULL||gPerfGPUTime.stateCount(channel)!=7){valid=0;return 0;}
        unsigned mask=0;
        for(unsigned i=0;i<7;i++){
            uint64_t id=gPerfGPUTime.stateID(channel,i),ticks=gPerfGPUTime.residency(channel,i);unsigned j=0;
            while(j<7&&ids[j]!=id)j++;
            if(j==7||(mask&(1U<<j))||ticks==UINT64_MAX){valid=0;return 0;}
            mask|=1U<<j;output[j]=ticks;
        }
        if(mask!=127)valid=0;return 0;
    });
    CFRelease(sample);
    if(result||!valid||channels!=1||after<before){gPerfGPUTime.baseline=0;return -1;}
    uint64_t now=before+(after-before)/2;double percent=-1;
    if(gPerfGPUTime.baseline&&now>gPerfGPUTime.lastTicks)
        PerfGPUTimeDelta(gPerfGPUTime.previous,values,now-gPerfGPUTime.lastTicks,&percent);
    for(unsigned i=0;i<7;i++)gPerfGPUTime.previous[i]=values[i];
    gPerfGPUTime.lastTicks=now;gPerfGPUTime.baseline=1;
    return percent;
}
#endif
#endif
