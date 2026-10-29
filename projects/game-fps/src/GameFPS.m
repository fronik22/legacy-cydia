#import <UIKit/UIKit.h>
#include "RuntimePolicy.h"
#if !defined(__arm__) || defined(__LP64__)
#error Verified native game profiles require an armv7 process, never reuse their offsets in arm64.
#endif
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <CommonCrypto/CommonDigest.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#include <libkern/OSAtomic.h>
#include <math.h>
#ifdef FPS_DIAGNOSTIC
#include <execinfo.h>
#endif

static NSString *const PreferencePath=@"/var/mobile/Library/Preferences/com.local.legacygamefps.plist";
typedef struct { const char *bundle,*version,*hash,*key; BOOL minigore; } GameProfile;
static const GameProfile Profiles[]={
 {"com.team17.worms2","1.25","bc4e0d74eb67fa2aaa100f36dd5f8368b8c0a198e85257db2935857f95dec940","Worms2Enabled",NO},
 {"com.team17.worms3","1.16","0172a8cf67029eb5f5d19ca355eb82bd3d4b0e03e7b94fd115d260db48346631","Worms3Enabled",NO},
 {"com.chillingo.minigorehd","6.2","a1ad0cb0bf3fa33f57f121c6840a2fb9976b2c2ae1d3e5d8f036d819dd16f179","MinigoreEnabled",YES},
 {"ms.games.minigore2","1.4","0b909e642003ba469d38209574619014db57ff35130d1d5958e6826c3890cd9d","Minigore2Enabled",YES}
};
static const GameProfile *Profile;
static BOOL Enabled;
static Class ViewClass;
static id CurrentView;
static Ivar LinkIvar,TimerIvar;
static SEL DrawSelector;
static NSTimeInterval NativeTimerInterval;
static NSInteger NativeLinkInterval;
static void(*OriginalSetInterval)(id,SEL,NSInteger);
static double SampleStart,DrawSeconds,PresentSeconds;
static unsigned Draws,Presents;
static volatile int32_t LogicCalls,LogicMilliseconds;
static int(*OriginalTargetFPS)(void*);
static float(*OriginalDelta)(void*);
static float Delta(void *engine){return Enabled?1.0f/60:OriginalDelta(engine);}
static int TargetFPS(void *engine){return Enabled?60:OriginalTargetFPS(engine);}
#ifdef FPS_DIAGNOSTIC
static volatile int32_t LogicMicroseconds;
static void(*OriginalSceneUpdate)(void*,float);
static void SceneUpdate(void *engine,float seconds){OSAtomicAdd32Barrier((int32_t)lrintf(seconds*1000000),&LogicMicroseconds);OriginalSceneUpdate(engine,seconds);}
#endif
static void(*OriginalStart)(id,SEL),(*OriginalDraw)(id,SEL),(*OriginalDealloc)(id,SEL),(*OriginalLogic)(id,SEL);
static BOOL(*OriginalPresent)(id,SEL,NSUInteger);
static id(*OriginalSchedule)(id,SEL,NSTimeInterval,id,SEL,id,BOOL);
static const void *ControlledTimerKey=&ControlledTimerKey;

static void Log(NSString *event,NSDictionary *details){
 NSMutableDictionary *row=[NSMutableDictionary dictionaryWithDictionary:details?:@{}];row[@"event"]=event;row[@"ts"]=@([[NSDate date] timeIntervalSince1970]);row[@"pid"]=@([[NSProcessInfo processInfo] processIdentifier]);row[@"enabled"]=@(Enabled);
 NSString *path=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/LegacyGameFPS.jsonl"];
 NSData *data=[NSJSONSerialization dataWithJSONObject:row options:0 error:NULL];if(!data)return;
 NSFileManager *fm=[NSFileManager defaultManager];NSDictionary *attributes=[fm attributesOfItemAtPath:path error:NULL];
 if([attributes fileSize]>262144){[fm removeItemAtPath:[path stringByAppendingString:@".1"] error:NULL];[fm moveItemAtPath:path toPath:[path stringByAppendingString:@".1"] error:NULL];}
 if(![fm fileExistsAtPath:path])[fm createFileAtPath:path contents:nil attributes:nil];
 @try{NSFileHandle *f=[NSFileHandle fileHandleForWritingAtPath:path];[f seekToEndOfFile];[f writeData:data];[f writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];[f closeFile];}
 @catch(NSException *exception){/* Logging must not interrupt gameplay. */}
}
static BOOL Supported(void){
 if(!LegacyFPSOSAllowed([[[UIDevice currentDevice]systemVersion]intValue]))return NO;
 NSBundle *b=[NSBundle mainBundle];
 for(unsigned n=0;n<sizeof(Profiles)/sizeof(Profiles[0]);n++)if([b.bundleIdentifier isEqual:@(Profiles[n].bundle)]&&[b.infoDictionary[@"CFBundleVersion"] isEqual:@(Profiles[n].version)]){Profile=&Profiles[n];break;}
 if(!Profile)return NO;
 NSInputStream *stream=[NSInputStream inputStreamWithFileAtPath:b.executablePath];[stream open];CC_SHA256_CTX ctx;CC_SHA256_Init(&ctx);unsigned char buffer[65536],digest[32];NSInteger size;
 while((size=[stream read:buffer maxLength:sizeof(buffer)])>0)CC_SHA256_Update(&ctx,buffer,(CC_LONG)size);[stream close];if(size<0)return NO;CC_SHA256_Final(digest,&ctx);
 NSMutableString *hash=[NSMutableString string];for(unsigned n=0;n<32;n++)[hash appendFormat:@"%02x",digest[n]];
 return [hash isEqual:@(Profile->hash)];
}
static id Field(id view,Ivar ivar){return view&&ivar?object_getIvar(view,ivar):nil;}
static id Schedule(id cls,SEL cmd,NSTimeInterval interval,id target,SEL selector,id info,BOOL repeats){
 BOOL controlled=[target isKindOfClass:ViewClass]&&selector==DrawSelector&&repeats&&interval>.02&&interval<.04;
 if(controlled)NativeTimerInterval=interval;
 id timer=OriginalSchedule(cls,cmd,controlled&&Enabled?1.0/60:interval,target,selector,info,repeats);
 if(controlled){objc_setAssociatedObject(timer,ControlledTimerKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);Log(@"render_timer",@{@"requested":@(interval),@"effective":@([timer timeInterval])});}
 return timer;
}
static void ResetSample(void){SampleStart=0;Draws=Presents=0;DrawSeconds=PresentSeconds=0;OSAtomicAnd32Barrier(0,(volatile uint32_t*)&LogicCalls);OSAtomicAnd32Barrier(0,(volatile uint32_t*)&LogicMilliseconds);
#ifdef FPS_DIAGNOSTIC
 OSAtomicAnd32Barrier(0,(volatile uint32_t*)&LogicMicroseconds);
#endif
}
static void Apply(id view){
 id link=Field(view,LinkIvar);if([link isKindOfClass:NSClassFromString(@"CADisplayLink")]){
  if(!NativeLinkInterval)NativeLinkInterval=[link frameInterval];[link setFrameInterval:Enabled?1:NativeLinkInterval];
  Log(@"pacing",@{@"kind":@"displayLink",@"nativeInterval":@(NativeLinkInterval),@"effectiveInterval":@([link frameInterval])});return;
 }
 NSTimer *timer=Field(view,TimerIvar);if(![timer isKindOfClass:[NSTimer class]]||!timer.valid||!objc_getAssociatedObject(timer,ControlledTimerKey)||!NativeTimerInterval)return;
 NSTimeInterval desired=Enabled?1.0/60:NativeTimerInterval;
 if(fabs(timer.timeInterval-desired)>1e-8){
  id replacement=OriginalSchedule([NSTimer class],@selector(scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:),desired,view,DrawSelector,timer.userInfo,YES);
  objc_setAssociatedObject(replacement,ControlledTimerKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);[timer invalidate];((void(*)(id,SEL,id))objc_msgSend)(view,NSSelectorFromString(@"setAnimationTimer:"),replacement);
 }
 Log(@"pacing",@{@"kind":@"timer",@"nativeInterval":@(NativeTimerInterval),@"effectiveInterval":@(desired)});
}
static void ReadPreference(void){id value=[[NSDictionary dictionaryWithContentsOfFile:PreferencePath] objectForKey:@(Profile->key)];Enabled=[value isKindOfClass:[NSNumber class]]&&[value intValue]==1;ResetSample();if(CurrentView)Apply(CurrentView);Log(@"policy",nil);}
static void Changed(CFNotificationCenterRef c,void *o,CFStringRef n,const void *obj,CFDictionaryRef info){dispatch_async(dispatch_get_main_queue(),^{ReadPreference();});}
static void Start(id view,SEL cmd){CurrentView=view;OriginalStart(view,cmd);Apply(view);}
static void SetInterval(id view,SEL cmd,NSInteger interval){if(interval>0)NativeLinkInterval=interval;OriginalSetInterval(view,cmd,interval);Apply(view);}
static void Draw(id view,SEL cmd){
#ifdef FPS_DIAGNOSTIC
 static BOOL traced;
 if(!traced&&Profile->minigore){traced=YES;void *frames[20];int count=backtrace(frames,20);NSMutableArray *offsets=[NSMutableArray array];for(int i=0;i<count;i++)[offsets addObject:@((uintptr_t)frames[i]-_dyld_get_image_vmaddr_slide(0))];Log(@"draw_stack",@{@"offsets":offsets,@"caller":@((uintptr_t)__builtin_return_address(0)-_dyld_get_image_vmaddr_slide(0))});}
#endif
 CurrentView=view;double start=CACurrentMediaTime();OriginalDraw(view,cmd);double now=CACurrentMediaTime();Draws++;DrawSeconds+=now-start;
 if(!SampleStart){ResetSample();SampleStart=now;return;}double elapsed=now-SampleStart;if(elapsed<5)return;
 NSMutableDictionary *sample=[NSMutableDictionary dictionaryWithDictionary:@{@"seconds":@(elapsed),@"drawFPS":@(Draws/elapsed),@"presentFPS":@(Presents/elapsed),@"drawMs":@(DrawSeconds*1000/Draws),@"presentMs":@(PresentSeconds*1000/(Presents?:1)),@"logicCalls":@(LogicCalls)}];
#ifdef FPS_DIAGNOSTIC
 sample[@"logicMilliseconds"]=Profile->minigore?@(LogicMicroseconds/1000.0):@(LogicMilliseconds);
#endif
 Log(@"sample",sample);ResetSample();
}
static void Logic(id self,SEL cmd){OSAtomicIncrement32Barrier(&LogicCalls);OriginalLogic(self,cmd);}
static BOOL Present(id self,SEL cmd,NSUInteger target){double start=CACurrentMediaTime();BOOL result=OriginalPresent(self,cmd,target);if(result){Presents++;PresentSeconds+=CACurrentMediaTime()-start;}return result;}
static void Dealloc(id self,SEL cmd){if(CurrentView==self){CurrentView=nil;NativeLinkInterval=0;NativeTimerInterval=0;}OriginalDealloc(self,cmd);}
#ifdef FPS_DIAGNOSTIC
static void(*OriginalNativeLogic)(unsigned);
static void NativeLogic(unsigned milliseconds){OSAtomicAdd32Barrier((int32_t)milliseconds,&LogicMilliseconds);OriginalNativeLogic(milliseconds);}
#endif
static BOOL ValidMethod(Class cls,SEL sel,const char *signature){Method m=class_getInstanceMethod(cls,sel);return m&&strcmp(method_getTypeEncoding(m),signature)==0;}
__attribute__((constructor))static void Initialize(void){
 NSAutoreleasePool *pool=[NSAutoreleasePool new];if(!Supported()){Log(@"unsupported_build",nil);[pool drain];return;}
 ViewClass=NSClassFromString(@"EAGLView");DrawSelector=NSSelectorFromString(Profile->minigore?@"swapBuffers":@"drawView");LinkIvar=class_getInstanceVariable(ViewClass,"displayLink");TimerIvar=class_getInstanceVariable(ViewClass,"animationTimer");
 void *lib=dlopen("/usr/lib/libsubstrate.dylib",RTLD_LAZY|RTLD_LOCAL);void(*hook)(Class,SEL,IMP,IMP*)=lib?dlsym(lib,"MSHookMessageEx"):NULL;
 void(*functionHook)(void*,void*,void**)=lib?dlsym(lib,"MSHookFunction"):NULL;
 BOOL minigoreHD=[@(Profile->bundle) isEqual:@"com.chillingo.minigorehd"];
 BOOL minigore2=[@(Profile->bundle) isEqual:@"ms.games.minigore2"];
 uintptr_t fpsAddress=_dyld_get_image_vmaddr_slide(0)+0x785a0;
 // This getter feeds the native elapsed-time scheduler; retain its normal clock and delta handling.
 const unsigned char fpsBytes[]={0x80,0xb5,0x80,0x68,0x3c,0x21,0x6f,0x46};
 if(minigore2&&(!functionHook||memcmp((void*)fpsAddress,fpsBytes,sizeof(fpsBytes)))){Log(@"unsupported_native_limiter",nil);[pool drain];return;}
 uintptr_t deltaAddress=_dyld_get_image_vmaddr_slide(0)+0x222ac;
 const unsigned char deltaBytes[]={0x80,0xb5,0x46,0xf2,0xde,0x00,0x47,0xf6};
 if(minigoreHD&&(!functionHook||memcmp((void*)deltaAddress,deltaBytes,sizeof(deltaBytes)))){Log(@"unsupported_native_limiter",nil);[pool drain];return;}
 Class timerMeta=object_getClass([NSTimer class]);SEL schedule=@selector(scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:);
 SEL start=NSSelectorFromString(Profile->minigore?@"startAnimation":@"startTimer");
 Class logicClass=Profile->minigore?NSClassFromString(@"AppController"):ViewClass;SEL logic=NSSelectorFromString(Profile->minigore?@"update":@"logicThreadUpdate");
 if(!hook||!ViewClass||!LinkIvar||!TimerIvar||ivar_getTypeEncoding(LinkIvar)[0]!='@'||ivar_getTypeEncoding(TimerIvar)[0]!='@'||!ValidMethod(ViewClass,DrawSelector,"v8@0:4")||!ValidMethod(ViewClass,start,"v8@0:4")||!ValidMethod(logicClass,logic,"v8@0:4")||(Profile->minigore&&!ValidMethod(ViewClass,NSSelectorFromString(@"setAnimationFrameInterval:"),"v12@0:4i8"))||!ValidMethod(ViewClass,NSSelectorFromString(@"setAnimationTimer:"),"v12@0:4@8")){Log(@"unsupported_runtime",nil);[pool drain];return;}
 ReadPreference();
 hook(timerMeta,schedule,(IMP)Schedule,(IMP*)&OriginalSchedule);
 hook(ViewClass,DrawSelector,(IMP)Draw,(IMP*)&OriginalDraw);hook(ViewClass,start,(IMP)Start,(IMP*)&OriginalStart);hook(ViewClass,sel_registerName("dealloc"),(IMP)Dealloc,(IMP*)&OriginalDealloc);
 hook(logicClass,logic,(IMP)Logic,(IMP*)&OriginalLogic);
 if(Profile->minigore)hook(ViewClass,NSSelectorFromString(@"setAnimationFrameInterval:"),(IMP)SetInterval,(IMP*)&OriginalSetInterval);
 if(minigoreHD){functionHook((void*)(deltaAddress|1),(void*)Delta,(void**)&OriginalDelta);Log(@"native_delta",@{@"getterOffset":@0x222ad});
#ifdef FPS_DIAGNOSTIC
  functionHook((void*)(_dyld_get_image_vmaddr_slide(0)+0x24d11),(void*)SceneUpdate,(void**)&OriginalSceneUpdate);
#endif
 }
 if(minigore2){functionHook((void*)(fpsAddress|1),(void*)TargetFPS,(void**)&OriginalTargetFPS);Log(@"native_limiter",@{@"getterOffset":@0x785a1});
#ifdef FPS_DIAGNOSTIC
  functionHook((void*)(_dyld_get_image_vmaddr_slide(0)+0x785dd),(void*)SceneUpdate,(void**)&OriginalSceneUpdate);
#endif
 }
 hook(NSClassFromString(@"EAGLContext"),NSSelectorFromString(@"presentRenderbuffer:"),(IMP)Present,(IMP*)&OriginalPresent);
#ifdef FPS_DIAGNOSTIC
 if(functionHook&&Profile==&Profiles[0])functionHook((void*)(_dyld_get_image_vmaddr_slide(0)+0x1dd541),(void*)NativeLogic,(void**)&OriginalNativeLogic);
#endif
 CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),NULL,Changed,CFSTR("com.local.legacygamefps.changed"),NULL,CFNotificationSuspensionBehaviorDeliverImmediately);
 NSNotificationCenter *center=[NSNotificationCenter defaultCenter];
 [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note){ReadPreference();Log(@"active",nil);}];
 [center addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note){ResetSample();Log(@"inactive",nil);}];
 [center addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil queue:nil usingBlock:^(NSNotification *note){Log(@"memory_warning",nil);}];
 Log(@"started",@{@"version":@"0.2.2",@"bundle":@(Profile->bundle),@"drawSelector":NSStringFromSelector(DrawSelector),@"idleTimerDisabled":@([UIApplication sharedApplication].idleTimerDisabled),@"linkOffset":@(ivar_getOffset(LinkIvar)),@"timerOffset":@(ivar_getOffset(TimerIvar))});[pool drain];
}
