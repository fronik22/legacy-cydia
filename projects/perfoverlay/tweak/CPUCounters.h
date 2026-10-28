#ifndef PERF_CPU_COUNTERS_H
#define PERF_CPU_COUNTERS_H
#include <stdint.h>
typedef struct { uint32_t user,system,nice,idle; } PerfCPUTicks;
static inline double PerfCPUPercent(PerfCPUTicks before,PerfCPUTicks after,uint64_t *busy,uint64_t *total) {
    *busy=(uint64_t)(uint32_t)(after.user-before.user)+(uint32_t)(after.system-before.system)+(uint32_t)(after.nice-before.nice);
    *total=*busy+(uint32_t)(after.idle-before.idle);
    return *total?100.0*(double)*busy/(double)*total:-1;
}
#endif
