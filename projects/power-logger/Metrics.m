#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <mach/processor_info.h>
#include <sys/sysctl.h>
#include <sys/proc.h>
#include <sys/resource.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <net/if.h>
#include <ifaddrs.h>
#include <dlfcn.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include "TelemetryMath.h"
#include "PlatformPolicy.h"
static id Num(double n){return isfinite(n)?[NSNumber numberWithDouble:n]:(id)[NSNull null];}
static NSNumber*Number(NSDictionary*d,NSString*k){id v=[d objectForKey:k];return[v isKindOfClass:[NSNumber class]]?v:nil;}
typedef unsigned LPObject;
static CFMutableDictionaryRef(*IOmatch)(const char*);
static LPObject(*IOservice)(unsigned,CFDictionaryRef);
static int(*IOprops)(unsigned,CFMutableDictionaryRef*,CFAllocatorRef,unsigned);
static int(*IOrelease)(unsigned);
static NSDictionary*Properties(const char*name){
 static BOOL tried=NO;if(!tried){tried=YES;void*h=dlopen("/System/Library/Frameworks/IOKit.framework/IOKit",RTLD_LAZY);IOmatch=dlsym(h,"IOServiceMatching");IOservice=dlsym(h,"IOServiceGetMatchingService");IOprops=dlsym(h,"IORegistryEntryCreateCFProperties");IOrelease=dlsym(h,"IOObjectRelease");}
 if(!IOmatch||!IOservice||!IOprops||!IOrelease)return nil;LPObject s=IOservice(0,IOmatch(name));if(!s)return nil;
 CFMutableDictionaryRef p=NULL;int err=IOprops(s,&p,NULL,0);IOrelease(s);if(err||!p)return nil;return[(NSDictionary*)p autorelease];
}
static NSDictionary*Battery(void){
 NSDictionary*d=Properties("IOPMPowerSource");NSMutableDictionary*b=[NSMutableDictionary dictionary];
 for(NSString*k in [NSArray arrayWithObjects:@"CurrentCapacity",@"MaxCapacity",@"DesignCapacity",@"AppleRawCurrentCapacity",@"AppleRawMaxCapacity",@"InstantAmperage",@"Amperage",@"Voltage",@"Temperature",@"CycleCount",@"ExternalConnected",@"IsCharging",@"FullyCharged",nil]){NSNumber*v=Number(d,k);if(v)[b setObject:v forKey:k];}
 NSNumber*raw=Number(d,@"InstantAmperage");int64_t ma=0;BOOL valid=raw&&LPCurrent(raw.longLongValue,&ma);
 [b setObject:valid?[NSNumber numberWithLongLong:ma]:(id)[NSNull null]forKey:@"net_current_ma"];
 NSNumber*mv=Number(d,@"Voltage");[b setObject:valid&&mv?Num(ma*mv.doubleValue/1e6):(id)[NSNull null]forKey:@"net_battery_w_signed"];
 NSNumber*external=Number(d,@"ExternalConnected");[b setObject:valid&&mv&&external?Num(LPDischargeW(mv.doubleValue,ma,external.boolValue)):(id)[NSNull null]forKey:@"discharge_w"];
 NSNumber*temperature=Number(d,@"Temperature");[b setObject:temperature&&temperature.doubleValue> -4000&&temperature.doubleValue<10000?Num(temperature.doubleValue/100.0):(id)[NSNull null]forKey:@"temperature_c"];
 NSNumber*max=Number(d,@"MaxCapacity"),*current=Number(d,@"CurrentCapacity");[b setObject:max.doubleValue>0&&current?Num(100.0*current.doubleValue/max.doubleValue):(id)[NSNull null]forKey:@"charge_percent"];
 char model[64]={0};size_t modelSize=sizeof(model);sysctlbyname("hw.machine",model,&modelSize,NULL,0);
 [b setObject:!strncmp(model,"iPad2,",6)&&max.doubleValue>100?@"mAh_on_verified_iPad2_PMU":@"raw_unverified"forKey:@"capacity_units"];
 [b setObject:!valid?@"missing_or_invalid_instant_current":!external?@"external_state_unknown":external.boolValue?@"charging_or_externally_powered_not_device_watts":@"battery_net_discharge"forKey:@"power_interpretation"];
 return b;
}
// Public XNU2050 PROC_PIDTASKINFO ABI; CPU times are Mach absolute ticks, not nanoseconds.
static NSMutableDictionary*oldProcesses;
static NSArray*Processes(uint64_t elapsed){
 int(*info)(int,int,uint64_t,void*,int)=dlsym(RTLD_DEFAULT,"proc_pidinfo");
 int mib[]={CTL_KERN,KERN_PROC,KERN_PROC_ALL,0};size_t n=0;if(sysctl(mib,4,NULL,&n,NULL,0))return nil;
 size_t cap=n+32*sizeof(struct kinfo_proc);struct kinfo_proc*p=malloc(cap);if(!p)return nil;n=cap;
 if(sysctl(mib,4,p,&n,NULL,0)){free(p);return nil;}
 if(n%sizeof(*p)){free(p);errno=EPROTO;return nil;}
 NSMutableArray*rows=[NSMutableArray array];NSMutableDictionary*next=[NSMutableDictionary dictionary];
 for(size_t i=0;i<n/sizeof(*p);i++){
  struct extern_proc*k=&p[i].kp_proc;struct LPTask t={0};int got=info?info(k->p_pid,4,0,&t,sizeof t):-1;
  NSString*key=[NSString stringWithFormat:@"%d:%ld:%d",k->p_pid,k->p_starttime.tv_sec,k->p_starttime.tv_usec];
  uint64_t ticks=t.user_ticks+t.system_ticks;NSNumber*old=[oldProcesses objectForKey:key];
  NSString*name=[[[NSString alloc]initWithBytes:k->p_comm length:strnlen(k->p_comm,sizeof k->p_comm) encoding:NSUTF8StringEncoding]autorelease]?:@"?";
  NSMutableDictionary*row=[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:k->p_pid],@"pid",key,@"identity",name,@"name",[NSNumber numberWithInt:got==sizeof t?0:(errno?:-1)],@"read_error",nil];
  [row setObject:got==sizeof t?[NSNumber numberWithUnsignedLongLong:t.resident_size]:(id)[NSNull null]forKey:@"rss_bytes"];
  [row setObject:got==sizeof t&&k->p_pid!=0?Num(LPCPU(old.unsignedLongLongValue,ticks,elapsed,old!=nil)):(id)[NSNull null]forKey:@"cpu_one_core_percent"];
  if(k->p_pid==0)[row setObject:@"kernel_task counters include idle threads; use host CPU totals"forKey:@"cpu_unavailable_reason"];
  if(got==sizeof t){[next setObject:[NSNumber numberWithUnsignedLongLong:ticks]forKey:key];[row setObject:[NSNumber numberWithUnsignedLongLong:ticks]forKey:@"cpu_total_ticks"];[row setObject:[NSNumber numberWithInt:t.threadnum]forKey:@"threads"];[row setObject:[NSNumber numberWithInt:t.csw]forKey:@"context_switches_total"];}
  [rows addObject:row];
 }
 free(p);[oldProcesses release];oldProcesses=[next retain];return rows;
}
static NSMutableDictionary*oldInterfaces;
static NSArray*Interfaces(double elapsed){
 struct ifaddrs*list=NULL;if(getifaddrs(&list))return nil;NSMutableArray*a=[NSMutableArray array];NSMutableDictionary*next=[NSMutableDictionary dictionary];
 for(struct ifaddrs*p=list;p;p=p->ifa_next){if(!p->ifa_addr||p->ifa_addr->sa_family!=AF_LINK||!p->ifa_data||!strcmp(p->ifa_name,"lo0"))continue;
  struct if_data*d=p->ifa_data;NSString*name=[NSString stringWithUTF8String:p->ifa_name];NSArray*old=[oldInterfaces objectForKey:name];
  [next setObject:[NSArray arrayWithObjects:[NSNumber numberWithUnsignedInt:d->ifi_ibytes],[NSNumber numberWithUnsignedInt:d->ifi_obytes],[NSNumber numberWithUnsignedInt:if_nametoindex(p->ifa_name)],nil]forKey:name];
  BOOL same=old&&[[old objectAtIndex:2]unsignedIntValue]==if_nametoindex(p->ifa_name);
  NSMutableDictionary*r=[NSMutableDictionary dictionaryWithObjectsAndKeys:name,@"name",[NSNumber numberWithUnsignedInt:d->ifi_ibytes],@"rx_bytes32",[NSNumber numberWithUnsignedInt:d->ifi_obytes],@"tx_bytes32",[NSNumber numberWithUnsignedInt:d->ifi_ierrors],@"rx_errors32",[NSNumber numberWithUnsignedInt:d->ifi_oerrors],@"tx_errors32",nil];
  double rx=LPRate([[old objectAtIndex:0]unsignedIntValue],d->ifi_ibytes,elapsed,same),tx=LPRate([[old objectAtIndex:1]unsignedIntValue],d->ifi_obytes,elapsed,same);
  // A reset is indistinguishable from wrap; reject physically impossible rates for these devices.
  [r setObject:Num(rx<=100000000?rx:NAN)forKey:@"rx_bytes_per_second"];[r setObject:Num(tx<=100000000?tx:NAN)forKey:@"tx_bytes_per_second"];[a addObject:r];
 }freeifaddrs(list);[oldInterfaces release];oldInterfaces=[next retain];return a;
}
static NSDictionary*VPN(void){
 NSMutableDictionary*r=[NSMutableDictionary dictionary];int fd=socket(AF_UNIX,SOCK_STREAM,0);if(fd<0)return r;
 struct sockaddr_un a={0};a.sun_family=AF_UNIX;strlcpy(a.sun_path,"/var/tmp/amnezia6d.sock",sizeof a.sun_path);fcntl(fd,F_SETFL,O_NONBLOCK);int no=1;setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&no,sizeof no);
 if(connect(fd,(void*)&a,sizeof a)&&errno!=EINPROGRESS){close(fd);return r;}
 fd_set w;FD_ZERO(&w);FD_SET(fd,&w);struct timeval tv={0,100000};
 if(select(fd+1,NULL,&w,NULL,&tv)<=0){close(fd);return r;}
 if(send(fd,"status\n",7,0)!=7){close(fd);return r;}
 char buf[2048];size_t used=0;
 for(int i=0;i<2&&used<sizeof(buf)-1;i++){
  fd_set rd;FD_ZERO(&rd);FD_SET(fd,&rd);tv=(struct timeval){0,100000};if(select(fd+1,&rd,NULL,NULL,&tv)<=0)break;
  ssize_t n=recv(fd,buf+used,sizeof(buf)-1-used,0);if(n<=0)break;used+=n;
 }close(fd);buf[used]=0;NSString*text=[NSString stringWithUTF8String:buf]?:@"";
 for(NSString*line in [text componentsSeparatedByString:@"\n"]){NSRange eq=[line rangeOfString:@"="];if(eq.location==NSNotFound)continue;NSString*k=[line substringToIndex:eq.location];
  if([[NSArray arrayWithObjects:@"state",@"uptime",@"tx",@"rx",@"retry_in",@"handshake_attempts",@"error",nil]containsObject:k])[r setObject:[line substringFromIndex:eq.location+1]forKey:k];}
 return r;
}
static id GPU(void){NSDictionary*p=Properties("SGXDriver543");if(!p)p=Properties("AGXAccelerator");if(!p)p=Properties("IOAccelerator");id stats=[p objectForKey:@"PerformanceStatistics"];NSNumber*v=[stats isKindOfClass:[NSDictionary class]]?Number(stats,@"Device Utilization %"):nil;return v&&v.doubleValue>=0&&v.doubleValue<=100?v:(id)[NSNull null];}
static NSDictionary*Display(void){
 NSMutableDictionary*d=[NSMutableDictionary dictionary];NSDictionary*prefs=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist"];
 for(NSString*k in [NSArray arrayWithObjects:@"SBBacklightLevel2",@"SBBacklightLevel",@"SBUsesNetworkTime",nil])if([k rangeOfString:@"Backlight"].location!=NSNotFound&&Number(prefs,k))[d setObject:[prefs objectForKey:k]forKey:k];
 NSDictionary*power=[Properties("AppleCLCD")objectForKey:@"IOPowerManagement"];if([power isKindOfClass:[NSDictionary class]]&&Number(power,@"CurrentPowerState"))[d setObject:[power objectForKey:@"CurrentPowerState"]forKey:@"display_power_state_raw"];
 static CFStringRef(*front)(void);static BOOL tried=NO;if(!tried){tried=YES;void*h=dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",RTLD_LAZY);front=dlsym(h,"SBSCopyFrontmostApplicationDisplayIdentifier");}
 CFStringRef s=front?front():NULL;if(s){[d setObject:(id)s forKey:@"frontmost_app"];CFRelease(s);}else[d setObject:[NSNull null]forKey:@"frontmost_app"];return d;
}
static uint64_t lastTicks;static processor_cpu_load_info_t oldCPU;static unsigned oldCount;
static NSArray*SystemCPU(void){
 processor_info_array_t raw=NULL;mach_msg_type_number_t n=0;natural_t count=0;
 static mach_port_t host;if(!host)host=mach_host_self();
 if(host_processor_info(host,PROCESSOR_CPU_LOAD_INFO,&count,&raw,&n))return nil;
 processor_cpu_load_info_t cp=(void*)raw;NSMutableArray*a=[NSMutableArray array];
 for(unsigned i=0;i<count;i++){double value=NAN;if(oldCPU&&oldCount==count){uint64_t total=0,idle=0;for(int j=0;j<CPU_STATE_MAX;j++){uint32_t delta=cp[i].cpu_ticks[j]-oldCPU[i].cpu_ticks[j];total+=delta;if(j==CPU_STATE_IDLE)idle=delta;}if(total)value=100.0*(total-idle)/total;}[a addObject:Num(value)];}
 free(oldCPU);oldCPU=malloc(count*sizeof(*oldCPU));if(oldCPU){memcpy(oldCPU,cp,count*sizeof(*oldCPU));oldCount=count;}else oldCount=0;
 vm_deallocate(mach_task_self(),(vm_address_t)raw,n*sizeof(integer_t));return a;
}
static NSDictionary*Sample(void){
 uint64_t now=mach_absolute_time(),elapsed=lastTicks?now-lastTicks:0;mach_timebase_info_data_t tb;mach_timebase_info(&tb);double seconds=(double)elapsed*tb.numer/tb.denom/1e9;
 NSMutableDictionary*r=[NSMutableDictionary dictionaryWithObjectsAndKeys:@"sample",@"type",[NSNumber numberWithDouble:[[NSDate date]timeIntervalSince1970]],@"epoch",[NSNumber numberWithUnsignedLongLong:now],@"monotonic_ticks",[NSNumber numberWithUnsignedInt:tb.numer],@"timebase_numer",[NSNumber numberWithUnsignedInt:tb.denom],@"timebase_denom",Num(lastTicks?seconds:NAN),@"elapsed_seconds",Battery(),@"battery",Display(),@"display",GPU(),@"gpu3d_percent",VPN(),@"amnezia",nil];
 NSArray*p=Processes(elapsed);[r setObject:p?@0:@(errno?:-1)forKey:@"process_read_error"];
 NSDictionary*os=[NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];[r setObject:[os objectForKey:@"ProductVersion"]?:@"unknown"forKey:@"os_version"];[r setObject:@(sizeof(void*)*8)forKey:@"collector_bits"];
 NSArray*net=Interfaces(seconds),*cpu=SystemCPU();[r setObject:p?:[NSArray array]forKey:@"processes"];[r setObject:net?:[NSArray array]forKey:@"interfaces"];[r setObject:cpu?:[NSArray array]forKey:@"cpu_cores_percent"];lastTicks=now;return r;
}
static void ResetBaseline(void){lastTicks=0;[oldProcesses release];oldProcesses=nil;[oldInterfaces release];oldInterfaces=nil;free(oldCPU);oldCPU=NULL;oldCount=0;}
