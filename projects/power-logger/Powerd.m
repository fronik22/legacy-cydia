#import <Foundation/Foundation.h>
#include <sys/file.h>
#include <sys/statvfs.h>
#include <signal.h>
#include <grp.h>
#include "Metrics.m"
#include "LogStore.h"
#define LP_DIR @"/var/mobile/Library/Logs/LegacyPower"
#define LP_PREF @"/var/mobile/Library/Preferences/com.local.legacypower.plist"
#define LP_NOTIFY CFSTR("com.local.legacypower.changed")
static const char*LogPath="/var/mobile/Library/Logs/LegacyPower/samples.jsonl";
static BOOL enabled;static int interval=15;static NSString*segment;static NSString*session;static NSTimer*timer;static NSDictionary*lastSample;static NSString*lastError;static volatile sig_atomic_t quitting;
static NSArray*Segments(void){return[NSArray arrayWithObjects:@"unlabelled",@"video-vpn-on",@"video-vpn-off",@"idle-vpn-on",@"idle-vpn-off",nil];}
static void Status(void){
 NSMutableDictionary*d=[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:enabled],@"enabled",@"1.1.0",@"version",[NSNumber numberWithInt:getpid()],@"pid",[NSNumber numberWithInt:interval],@"interval",[NSNumber numberWithDouble:[[NSDate date]timeIntervalSince1970]],@"updated_epoch",session?:@"",@"session",segment?:@"unlabelled",@"segment",lastError?:@"",@"error",nil];
 if(lastSample){for(NSString*k in [NSArray arrayWithObjects:@"epoch",@"battery",@"cpu_cores_percent",@"gpu3d_percent",@"amnezia",@"display",@"collection_cpu_ms",@"collection_wall_ms",nil])if([lastSample objectForKey:k])[d setObject:[lastSample objectForKey:k]forKey:k];}
 NSData*data=[NSJSONSerialization dataWithJSONObject:d options:0 error:NULL];NSString*path=[LP_DIR stringByAppendingPathComponent:@"status.json"];[data writeToFile:path atomically:YES];chmod(path.fileSystemRepresentation,0640);
}
static BOOL Write(NSDictionary*row){
 NSData*d=[NSJSONSerialization dataWithJSONObject:row options:0 error:NULL];if(!d||d.length>262143)return NO;
 NSMutableData*line=[NSMutableData dataWithData:d];[line appendBytes:"\n"length:1];
 if(LPAppend(LogPath,line.bytes,line.length,4*1024*1024,8)){
  [lastError release];lastError=[[NSString stringWithFormat:@"log write: %s",strerror(errno)]copy];return NO;
 }return YES;
}
static void Event(NSString*kind){
 Write([NSDictionary dictionaryWithObjectsAndKeys:kind,@"type",[NSNumber numberWithDouble:[[NSDate date]timeIntervalSince1970]],@"epoch",session?:@"",@"session",segment?:@"unlabelled",@"segment",nil]);
}
@interface LPPowerRecorder:NSObject
+(void)tick:(NSTimer*)t;
@end
@implementation LPPowerRecorder
+(void)tick:(NSTimer*)t{
 if(!enabled)return;NSAutoreleasePool*pool=[NSAutoreleasePool new];struct statvfs fs;
 if(statvfs(LogPath,&fs)==0&&fs.f_bavail*(uint64_t)fs.f_frsize<20*1024*1024){[lastError release];lastError=[@"Less than20MiB free; no sample written"copy];Status();[pool drain];return;}
 struct rusage before,after;getrusage(RUSAGE_SELF,&before);uint64_t start=mach_absolute_time();
 NSMutableDictionary*r=[NSMutableDictionary dictionaryWithDictionary:Sample()];
 getrusage(RUSAGE_SELF,&after);mach_timebase_info_data_t tb;mach_timebase_info(&tb);
 double work=((after.ru_utime.tv_sec-before.ru_utime.tv_sec)+(after.ru_stime.tv_sec-before.ru_stime.tv_sec))*1000.0+((after.ru_utime.tv_usec-before.ru_utime.tv_usec)+(after.ru_stime.tv_usec-before.ru_stime.tv_usec))/1000.0;
 [r setObject:Num(work)forKey:@"collection_cpu_ms"];[r setObject:Num((mach_absolute_time()-start)*(double)tb.numer/tb.denom/1e6)forKey:@"collection_wall_ms"];
 [r setObject:[NSNumber numberWithInt:interval]forKey:@"interval_seconds"];[r setObject:session forKey:@"session"];[r setObject:segment forKey:@"segment"];[r setObject:@"1.1.0"forKey:@"logger_version"];
 if(Write(r)){[lastError release];lastError=nil;}
 [lastSample release];lastSample=[r copy];Status();[pool drain];
}
@end
static void Configure(void){
 NSDictionary*d=[NSDictionary dictionaryWithContentsOfFile:LP_PREF];BOOL on=Number(d,@"Enabled").boolValue;
 NSNumber*n=Number(d,@"Interval");int seconds=n.intValue;if(seconds!=15&&seconds!=30&&seconds!=60)seconds=15;
 NSString*label=[d objectForKey:@"Segment"];if(![Segments()containsObject:label?:@""])label=@"unlabelled";
 BOOL changed=![segment isEqual:label];BOOL was=enabled;
 if(was&&(!on||changed))Event(on?@"segment_end":@"stop");
 BOOL restart=was!=on||seconds!=interval||changed;
 enabled=on;interval=seconds;[segment release];segment=[label copy];
 if(restart){[timer invalidate];[timer release];timer=nil;ResetBaseline();}
 if(on&&(!was||changed)){[session release];session=[[[NSProcessInfo processInfo]globallyUniqueString]copy];Event(@"start");}
 if(on&&!timer){timer=[[NSTimer scheduledTimerWithTimeInterval:interval target:[LPPowerRecorder class]selector:@selector(tick:)userInfo:nil repeats:YES]retain];[LPPowerRecorder tick:nil];}
 Status();
}
static void Changed(CFNotificationCenterRef c,void*o,CFStringRef n,const void*x,CFDictionaryRef info){NSAutoreleasePool*p=[NSAutoreleasePool new];Configure();[p drain];}

int main(int argc,char**argv){
 NSAutoreleasePool*p=[NSAutoreleasePool new];NSDictionary*os=[NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];NSString*v=[os objectForKey:@"ProductVersion"];
 if(!LPOSAllowed(v.intValue)){fprintf(stderr,"Only iOS6-7 armv7/arm64 is supported\n");return 2;}
 if(argc==2&&!strcmp(argv[1],"--once")){NSData*d=[NSJSONSerialization dataWithJSONObject:Sample()options:0 error:NULL];fwrite(d.bytes,1,d.length,stdout);puts("");return d?0:1;}
 if(argc==2&&!strcmp(argv[1],"--self-cpu-test")){
  int(*info)(int,int,uint64_t,void*,int)=dlsym(RTLD_DEFAULT,"proc_pidinfo");struct LPTask a={0},b={0};if(!info||info(getpid(),4,0,&a,sizeof a)!=sizeof a)return 3;
  uint64_t t=mach_absolute_time();mach_timebase_info_data_t tb;mach_timebase_info(&tb);volatile uint64_t x=1;while((mach_absolute_time()-t)*(double)tb.numer/tb.denom/1e9<.5)x=x*1664525+1013904223;
  if(info(getpid(),4,0,&b,sizeof b)!=sizeof b)return 5;double cpu=LPCPU(a.user_ticks+a.system_ticks,b.user_ticks+b.system_ticks,mach_absolute_time()-t,1);printf("self_busy_one_core_percent=%.2f\n",cpu);return cpu>=60&&cpu<=110?0:4;
 }
 if(argc==2&&!strcmp(argv[1],"--running")){int fd=open("/var/run/legacypowerd.lock",O_RDONLY|O_NOFOLLOW);if(fd<0)return 1;int active=flock(fd,LOCK_EX|LOCK_NB)<0&&(errno==EWOULDBLOCK||errno==EAGAIN);close(fd);return active?0:1;}
 if(argc>2||(argc==2&&strcmp(argv[1],"--daemonize"))){fprintf(stderr,"usage: legacypowerd [--daemonize|--once|--self-cpu-test]\n");return 64;}
 if(geteuid()!=0)return 77;
 if(argc==2){pid_t child=fork();if(child<0)return 1;if(child>0)return 0;if(setsid()<0)return 1;int fd=open("/dev/null",O_RDWR);if(fd<0)return 1;for(int i=0;i<3;i++)dup2(fd,i);if(fd>2)close(fd);}
 struct group*mobile=getgrnam("mobile");if(!mobile||setgid(mobile->gr_gid))return 1;
 umask(0027);int lock=open("/var/run/legacypowerd.lock",O_CREAT|O_RDWR|O_NOFOLLOW,0600);if(lock<0||flock(lock,LOCK_EX|LOCK_NB))return 1;char pid[32];int len=snprintf(pid,sizeof pid,"%d\n",getpid());ftruncate(lock,0);write(lock,pid,len);
 struct stat st;if(lstat(LP_DIR.fileSystemRepresentation,&st)||!S_ISDIR(st.st_mode)||st.st_uid!=0||(st.st_mode&0022))return 1;
 segment=[@"unlabelled"copy];signal(SIGPIPE,SIG_IGN);
 for(int i=0;i<2;i++){int sig=i?SIGINT:SIGTERM;signal(sig,SIG_IGN);dispatch_source_t source=dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL,sig,0,dispatch_get_main_queue());if(!source)return 1;dispatch_source_set_event_handler(source,^{quitting=1;CFRunLoopStop(CFRunLoopGetMain());});dispatch_resume(source);}
 CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,Changed,LP_NOTIFY,NULL,CFNotificationSuspensionBehaviorDeliverImmediately);Configure();
 while(!quitting){NSAutoreleasePool*cycle=[NSAutoreleasePool new];CFRunLoopRunInMode(kCFRunLoopDefaultMode,3600,false);[cycle drain];}
 if(enabled)Event(@"daemon_exit");[timer invalidate];enabled=NO;Status();close(lock);[p drain];return 0;
}
