#ifndef TELEMETRY_MATH_H
#define TELEMETRY_MATH_H
#include <stdint.h>
#include <math.h>
static double LPCPU(uint64_t before,uint64_t after,uint64_t elapsed,int sameProcess){
 return !sameProcess||!elapsed||after<before?NAN:100.0*(after-before)/elapsed;
}
static int LPCurrent(int64_t raw,int64_t*out){
 if(raw>INT32_MAX&&raw<=UINT32_MAX)raw=(int32_t)raw;
 else if(raw>INT16_MAX&&raw<=UINT16_MAX)raw=(int16_t)raw;
 if(raw< -20000||raw>20000)return 0;*out=raw;return 1;
}
static double LPDischargeW(double mv,double ma,int external){
 return external||!isfinite(ma)||ma>=0||mv<2000||mv>10000?NAN:-mv*ma/1000000.0;
}
static double LPRate(uint32_t old,uint32_t now,double elapsed,int same){
 return !same||elapsed<=0?NAN:(uint32_t)(now-old)/elapsed;
}
#endif
