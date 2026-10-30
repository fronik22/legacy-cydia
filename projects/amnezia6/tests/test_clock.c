/* Timer time is monotonic; adjusting wall time must affect only wire timestamps. */
#define a6_now_ms test_now_ms
#define mach_absolute_time mock_ticks
#define mach_timebase_info mock_timebase
#define gettimeofday mock_wall
#include "../src/protocol.c"
#include <assert.h>
static uint64_t ticks;
static int64_t wall_seconds;
static int wall_reads;
uint64_t mock_ticks(void) { return ticks; }
kern_return_t mock_timebase(mach_timebase_info_t info) { info->numer=125;info->denom=3;return KERN_SUCCESS; }
int mock_wall(struct timeval *tv, void *tz) { wall_reads++;tv->tv_sec=wall_seconds;tv->tv_usec=0;return 0; }
int main(void) {
 ticks=24000000;wall_seconds=1700000000;assert(test_now_ms()==1000);
 wall_seconds-=3600;assert(test_now_ms()==1000);
 ticks+=24000000;wall_seconds+=86400;assert(test_now_ms()==2000);
 ticks=24000000ULL*100000000;assert(test_now_ms()==100000000000ULL);
 assert(!wall_reads);
 uint8_t timestamp[12];make_tai64n(timestamp);assert(wall_reads==1); /* Wire TAI64N still uses real wall time. */
 puts("Monotonic timer milliseconds ignore forward/backward wall-clock jumps; TAI64N stays wall-clock based");
 return 0;
}
