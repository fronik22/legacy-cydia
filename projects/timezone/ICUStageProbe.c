/* Tests an offline ICU pack without replacing system data or changing the clock. */
#include <assert.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
int main(int argc,char **argv){
 assert(argc==2);FILE *f=fopen(argv[1],"rb");assert(f);assert(!fseek(f,0,SEEK_END));long size=ftell(f);assert(size>0);rewind(f);void *bytes=malloc(size);assert(bytes&&fread(bytes,1,size,f)==(size_t)size);fclose(f);
 void *lib=dlopen("/usr/lib/libicucore.A.dylib",RTLD_NOW);assert(lib);
 void (*common)(const void*,int*)=dlsym(lib,"udata_setCommonData");
 const char *(*version)(int*)=dlsym(lib,"ucal_getTZDataVersion");
 void *(*open)(const uint16_t*,int,const char*,int,int*)=dlsym(lib,"ucal_open");
 void (*millis)(void*,double,int*)=dlsym(lib,"ucal_setMillis");
 int (*get)(const void*,int,int*)=dlsym(lib,"ucal_get");void (*close)(void*)=dlsym(lib,"ucal_close");
 assert(common&&version&&open&&millis&&get&&close);int error=0;common(bytes,&error);assert(error<=0);printf("tzdata=%s\n",version(&error));assert(error<=0);
 const char *zones[]={"Europe/Moscow","Europe/Samara","Asia/Novosibirsk","Asia/Irkutsk","Asia/Vladivostok","America/New_York"};
 double dates[]={1262304000000.,1404172800000.,1767225600000.,1782864000000.};
 for(unsigned n=0;n<sizeof zones/sizeof zones[0];n++){
  uint16_t zone[128];int length=0;while(zones[n][length]){zone[length]=(unsigned char)zones[n][length];length++;}zone[length]=0;
  void *calendar=open(zone,length,"en_US_POSIX",1,&error);assert(calendar&&error<=0);
  for(unsigned i=0;i<sizeof dates/sizeof dates[0];i++){millis(calendar,dates[i],&error);int offset=get(calendar,15,&error)+get(calendar,16,&error);assert(error<=0);printf("zone=%s epoch=%.0f offset=%d\n",zones[n],dates[i]/1000.,offset/1000);}
  close(calendar);
 }
 /* ICU retains the supplied common-data pointer until process termination. */
 return 0;
}
