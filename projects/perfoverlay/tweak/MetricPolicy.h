#ifndef PERF_METRIC_POLICY_H
#define PERF_METRIC_POLICY_H
#include <math.h>
static int PerfMetricPercent(double value){return isfinite(value)&&value>=0&&value<=100?(int)value:-1;}
static int PerfLegacyNCSupported(int major){return major==5||major==6;}
#endif
