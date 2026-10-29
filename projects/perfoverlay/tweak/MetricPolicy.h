#ifndef PERF_METRIC_POLICY_H
#define PERF_METRIC_POLICY_H
#include <math.h>
#include <stdint.h>
static int PerfMetricPercent(double value){return isfinite(value)&&value>=0&&value<=100?(int)value:-1;}
static int PerfLegacyNCSupported(int major){return major==5||major==6;}
static uint64_t PerfMetricPageSize(uint64_t kernel,uint64_t task){uint64_t page=kernel?kernel:task;return page>=4096&&page<=65536&&!(page&(page-1))?page:0;}
static int PerfMetricMemory(uint64_t active,uint64_t inactive,uint64_t wired,uint64_t page,uint64_t total,uint64_t*used){if(!page||!total)return 0;if(active>UINT64_MAX-inactive||active+inactive>UINT64_MAX-wired)return 0;uint64_t pages=active+inactive+wired;if(pages>UINT64_MAX/page)return 0;uint64_t bytes=pages*page;if(bytes>total)return 0;*used=bytes;return 1;}
#endif
