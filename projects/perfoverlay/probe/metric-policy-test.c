#include "../tweak/MetricPolicy.h"
#include <assert.h>
int main(void){assert(PerfMetricPercent(0)==0&&PerfMetricPercent(100)==100);assert(PerfMetricPercent(-1)<0&&PerfMetricPercent(101)<0&&PerfMetricPercent(NAN)<0);assert(PerfLegacyNCSupported(5)&&PerfLegacyNCSupported(6));assert(!PerfLegacyNCSupported(4)&&!PerfLegacyNCSupported(7)&&!PerfLegacyNCSupported(9));return 0;}
