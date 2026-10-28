#include <assert.h>
#include <stdint.h>
#include <stdlib.h>
#include "TelemetryMath.h"
#include "LogStore.h"
int main(void){
 assert(LPCPU(100,150,50,1)==100);assert(LPCPU(100,200,50,1)==200);assert(isnan(LPCPU(100,50,50,1)));assert(isnan(LPCPU(100,200,50,0)));assert(isnan(LPCPU(100,200,0,1)));
 int64_t value;assert(LPCurrent(-1234,&value)&&value== -1234);assert(LPCurrent(4294966062LL,&value)&&value== -1234);assert(LPCurrent(64302,&value)&&value== -1234);assert(!LPCurrent(1000000,&value));assert(LPDischargeW(4000,-1000,0)==4);assert(isnan(LPDischargeW(4000,-1000,1)));assert(isnan(LPDischargeW(4000,1000,0)));assert(LPRate(UINT32_MAX-9,10,2,1)==10);assert(isnan(LPRate(1,2,1,0)));
 char dir[]="/tmp/legacy-power-test-XXXXXX";assert(mkdtemp(dir));char base[1024];snprintf(base,sizeof base,"%s/log",dir);
 for(int i=0;i<30;i++){char b[16];int n=snprintf(b,sizeof b,"%02d\n",i);assert(!LPAppend(base,b,n,12,3));}
 struct stat st;assert(!stat(base,&st)&&st.st_size<=12);char p[1030];snprintf(p,sizeof p,"%s.1",base);assert(!stat(p,&st)&&st.st_size<=12);unlink(p);snprintf(p,sizeof p,"%s.2",base);assert(!stat(p,&st)&&st.st_size<=12);unlink(p);snprintf(p,sizeof p,"%s.3",base);assert(stat(p,&st)<0&&errno==ENOENT);unlink(base);
 assert(!symlink("/dev/null",base));assert(LPAppend(base,"x",1,12,3)<0);unlink(base);rmdir(dir);
 puts("CPU/PID baselines, signed current, charging exclusion, counter wrap, bounded log rotation and symlink rejection passed");
}
