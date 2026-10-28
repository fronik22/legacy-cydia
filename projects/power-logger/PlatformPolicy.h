#ifndef LEGACY_POWER_PLATFORM_POLICY_H
#define LEGACY_POWER_PLATFORM_POLICY_H
#include <stdint.h>
#include <stddef.h>
static int LPOSAllowed(int major){return major==6||major==7;}
struct LPTask {uint64_t virtual_size,resident_size,user_ticks,system_ticks,threads_user,threads_system;int32_t policy,faults,pageins,cow,messages_sent,messages_received,syscalls_mach,syscalls_unix,csw,threadnum,numrunning,priority;};
typedef char LPTaskSizeCheck[sizeof(struct LPTask)==96?1:-1];
typedef char LPTaskTimeOffsetCheck[offsetof(struct LPTask,user_ticks)==16?1:-1];
#endif
