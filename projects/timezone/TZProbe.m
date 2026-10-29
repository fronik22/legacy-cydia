#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <time.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>
int main(int argc,char **argv){NSAutoreleasePool *pool=[NSAutoreleasePool new];setbuf(stdout,NULL);NSString *name=argc>1?[NSString stringWithUTF8String:argv[1]]:@"Europe/Moscow";
 void *icu=dlopen("/usr/lib/libicucore.A.dylib",RTLD_LAZY);void(*version)(unsigned char*)=dlsym(icu,"u_getVersion");const char *(*tzversion)(int*)=dlsym(icu,"ucal_getTZDataVersion");unsigned char v[4]={0};int e=0;if(version)version(v);printf("ICU %u.%u.%u.%u tzdata=%s\n",v[0],v[1],v[2],v[3],tzversion?tzversion(&e):"unavailable");
 printf("SYSTEM zone=%s now=%s\n",[[[NSTimeZone systemTimeZone]name]UTF8String],[[[NSDate date]description]UTF8String]);
 const double dates[]={1767225600,1782864000,1792454400,1262304000,1404172800};
 NSTimeZone *zone=[NSTimeZone timeZoneWithName:name];NSDateFormatter *f=[NSDateFormatter new];[f setLocale:[[[NSLocale alloc]initWithLocaleIdentifier:@"en_US_POSIX"]autorelease]];[f setDateFormat:@"yyyy-MM-dd HH:mm:ss Z"];[f setTimeZone:zone];
 NSString *tz=[@":" stringByAppendingString:[@"/usr/share/zoneinfo/" stringByAppendingString:name]];setenv("TZ",tz.UTF8String,1);tzset();
 for(unsigned i=0;i<5;i++){NSDate *date=[NSDate dateWithTimeIntervalSince1970:dates[i]];time_t t=dates[i];struct tm tm;localtime_r(&t,&tm);printf("TEST zone=%s epoch=%.0f NSTimeZone=%ld C=%ld DST=%d formatted=%s\n",name.UTF8String,dates[i],(long)[zone secondsFromGMTForDate:date],(long)tm.tm_gmtoff,tm.tm_isdst,[[f stringFromDate:date]UTF8String]);}
 [f release];[pool drain];return 0;}
