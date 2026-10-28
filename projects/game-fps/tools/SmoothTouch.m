#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <mach/mach_time.h>
#import <unistd.h>
#import <math.h>
typedef void *Event;
int main(int argc,char **argv) {
 if((argc!=3&&argc!=5&&argc!=6)||getuid()!=0)return 64;
 float x=atof(argv[1]),y=atof(argv[2]);if(!isfinite(x)||!isfinite(y)||x<0||x>=768||y<0||y>=1024)return 64;
 float endX=argc>=5?atof(argv[3]):x,endY=argc>=5?atof(argv[4]):y;
 if(!isfinite(endX)||!isfinite(endY)||endX<0||endX>=768||endY<0||endY>=1024)return 64;
 float seconds=argc==6?atof(argv[5]):0;if(argc==6&&(!isfinite(seconds)||seconds<1||seconds>20))return 64;
 NSAutoreleasePool *pool=[NSAutoreleasePool new];
 void *lib=dlopen("/System/Library/Frameworks/IOKit.framework/IOKit",RTLD_LAZY);
 Event(*clientCreate)(CFAllocatorRef)=dlsym(lib,"IOHIDEventSystemClientCreate");
 Event(*handCreate)(CFAllocatorRef,uint64_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,float,float,float,float,float,Boolean,Boolean,uint32_t)=dlsym(lib,"IOHIDEventCreateDigitizerEvent");
 Event(*fingerCreate)(CFAllocatorRef,uint64_t,uint32_t,uint32_t,uint32_t,float,float,float,float,float,float,float,float,float,float,Boolean,Boolean,uint32_t)=dlsym(lib,"IOHIDEventCreateDigitizerFingerEventWithQuality");
 void(*setInt)(Event,uint32_t,CFIndex,uint32_t)=dlsym(lib,"IOHIDEventSetIntegerValueWithOptions");
 void(*append)(Event,Event)=dlsym(lib,"IOHIDEventAppendEvent");
 void(*sender)(Event,uint64_t)=dlsym(lib,"IOHIDEventSetSenderID");
 void(*send)(Event,Event)=dlsym(lib,"IOHIDEventSystemClientDispatchEvent");
 if(!clientCreate||!handCreate||!fingerCreate||!setInt||!append||!sender||!send)return 127;
 Event client=clientCreate(kCFAllocatorDefault);if(!client)return 2;
 int count=argc==6?(int)(seconds*20)+2:argc==5?22:2;
 for(int i=0;i<count;i++){
  int down=i<count-1;BOOL moving=argc>=5&&i>0&&i<count-1;
  float progress=argc==6?fminf(i/5.0f,1):argc==5?(float)i/(count-1):(float)i;float px=x+(endX-x)*progress,py=y+(endY-y)*progress;uint64_t t=mach_absolute_time();
  Event hand=handCreate(kCFAllocatorDefault,t,35,0,1,0,0,0,0,0,0,0,0,0,0);
  Event finger=fingerCreate(kCFAllocatorDefault,t,1,2,moving?4:3,px/768,py/1024,0,0,0,0,0,0,0,0,down,down,0);
  if(!hand||!finger)return 3;
  append(hand,finger);CFRelease(finger);
  setInt(hand,(11<<16)+7,moving?4:(down?35:39),0xf0000000);
  setInt(hand,(11<<16)+8,down,0xf0000000);setInt(hand,(11<<16)+9,down,0xf0000000);
  sender(hand,0xDEFACEDBEEFFECE5ULL);send(client,hand);CFRelease(hand);usleep(argc>=5?50000:120000);
 }
 CFRelease(client);[pool drain];return 0;
}
