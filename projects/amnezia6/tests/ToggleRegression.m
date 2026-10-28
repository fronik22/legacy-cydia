#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <dispatch/dispatch.h>
#import "../app/A6Daemon.h"
@interface NSObject(A6TestMethods)
-(void)refreshAsync;-(void)applyReport:(A6StatusReport*)report;
@end
@interface A6TrackingSwitch:UISwitch { @public BOOL fakeTracking; }
@end
@implementation A6TrackingSwitch
-(BOOL)isTracking{return fakeTracking||[super isTracking];}
@end
@interface A6HeldGesture:UIGestureRecognizer
@end
@implementation A6HeldGesture
-(NSUInteger)numberOfTouches{return 1;}
@end
static id root;static A6TrackingSwitch*toggle;static NSMutableArray*results;
static IMP oldStatus,oldVersion,oldStart,oldStop;
static volatile int state,starts,stops,captured,blockNext;
static dispatch_semaphore_t gate;
static A6StatusReport* Report(id self,SEL cmd){A6StatusReport*r=[[[NSClassFromString(@"A6StatusReport")alloc]init]autorelease];r.status=state?A6StatusConnected:A6StatusIdle;if(__sync_bool_compare_and_swap(&blockNext,1,0)){captured=1;dispatch_semaphore_wait(gate,DISPATCH_TIME_FOREVER);}return r;}
static NSString*Version(id self,SEL cmd){return @"test";}
static BOOL Start(id self,SEL cmd,NSString**error){__sync_add_and_fetch(&starts,1);state=1;return YES;}
static BOOL Stop(id self,SEL cmd,NSString**error){__sync_add_and_fetch(&stops,1);state=0;return YES;}
static void Save(void){[[NSJSONSerialization dataWithJSONObject:results options:NSJSONWritingPrettyPrinted error:NULL]writeToFile:@"/var/mobile/Library/Caches/a6-toggle-regression.json" atomically:YES];}
static IMP reloadIMP; static int reloads;
static void Reload(id self, SEL cmd){reloads++;((void(*)(id,SEL))reloadIMP)(self,cmd);}
static void StableCellCase(void){
 state=1;[root applyReport:Report(nil,NULL)];
 Method method=class_getInstanceMethod([UITableView class],@selector(reloadData));reloadIMP=method_setImplementation(method,(IMP)Reload);reloads=0;
 [toggle setOn:NO animated:NO];[root applyReport:Report(nil,NULL)];[root applyReport:Report(nil,NULL)];
 [results addObject:@{@"case":@"unchanged_poll_preserves_gesture_and_cell",@"pass":@(!toggle.on&&!reloads),@"reloads":@(reloads),@"switchOn":@(toggle.on)}];Save();
 method_setImplementation(method,reloadIMP);[toggle setOn:YES animated:NO];
}
static void TrackingCase(BOOL child){
 state=1;starts=stops=0;A6StatusReport*r=Report(nil,NULL);[root applyReport:r];
 UIView*v=[[[UIView alloc]initWithFrame:CGRectZero]autorelease];
 if(child){[v addGestureRecognizer:[[[A6HeldGesture alloc]initWithTarget:nil action:NULL]autorelease]];[toggle addSubview:v];}
 [toggle setOn:NO animated:NO];toggle->fakeTracking=!child;[root applyReport:r];toggle->fakeTracking=NO;[v removeFromSuperview];
 [toggle sendActionsForControlEvents:UIControlEventValueChanged];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,700*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
  [results addObject:@{@"case":child?@"poll_during_child_gesture":@"poll_during_touch",@"pass":@(!state&&!toggle.on&&stops==1&&starts==0),@"switchOn":@(toggle.on),@"daemonOn":@(state),@"starts":@(starts),@"stops":@(stops)}];Save();
  if(!child){TrackingCase(YES);return;}
  StableCellCase();
  Class c=NSClassFromString(@"A6Daemon");method_setImplementation(class_getInstanceMethod(c,@selector(statusReport)),oldStatus);method_setImplementation(class_getInstanceMethod(c,@selector(versionString)),oldVersion);method_setImplementation(class_getInstanceMethod(c,@selector(startWithError:)),oldStart);method_setImplementation(class_getInstanceMethod(c,@selector(stopWithError:)),oldStop);
  [root viewDidAppear:NO];
 });
}
static void RaceCase(int initial);
static void AwaitCapture(int initial,int tries){
 if(!captured){if(tries<100)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_MSEC),dispatch_get_main_queue(),^{AwaitCapture(initial,tries+1);});return;}
 [toggle setOn:!initial animated:NO];[toggle sendActionsForControlEvents:UIControlEventValueChanged];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,200*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
  dispatch_semaphore_signal(gate);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,700*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
   BOOL pass=state==!initial&&toggle.on==!initial&&starts==!initial&&stops==initial;
   [results addObject:@{@"case":initial?@"old_poll_after_stop":@"old_poll_after_start",@"pass":@(pass),@"switchOn":@(toggle.on),@"daemonOn":@(state),@"starts":@(starts),@"stops":@(stops)}];Save();
   if(initial)RaceCase(0);else TrackingCase(NO);
  });
 });
}
static void RaceCase(int initial){state=initial;starts=stops=0;[root applyReport:Report(nil,NULL)];captured=0;blockNext=1;[root refreshAsync];AwaitCapture(initial,0);}
__attribute__((constructor))static void Load(void){
 if(![[NSBundle mainBundle].bundleIdentifier isEqual:@"com.mak.amnezia6"])return;
 Dl_info im;if(!dladdr((void*)&Load,&im)||!dlopen(im.dli_fname,RTLD_LAZY|RTLD_LOCAL|RTLD_NODELETE))return;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{
  UINavigationController*n=(id)[UIApplication sharedApplication].keyWindow.rootViewController;[n popToRootViewControllerAnimated:NO];root=[n.topViewController retain];[root viewWillDisappear:NO];
  gate=dispatch_semaphore_create(0);results=[NSMutableArray new];
  Class c=NSClassFromString(@"A6Daemon");oldStatus=method_setImplementation(class_getInstanceMethod(c,@selector(statusReport)),(IMP)Report);oldVersion=method_setImplementation(class_getInstanceMethod(c,@selector(versionString)),(IMP)Version);oldStart=method_setImplementation(class_getInstanceMethod(c,@selector(startWithError:)),(IMP)Start);oldStop=method_setImplementation(class_getInstanceMethod(c,@selector(stopWithError:)),(IMP)Stop);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,1*NSEC_PER_SEC),dispatch_get_main_queue(),^{
   toggle=[[A6TrackingSwitch alloc]initWithFrame:CGRectZero];[toggle addTarget:root action:NSSelectorFromString(@"toggleChanged:")forControlEvents:UIControlEventValueChanged];[root setValue:toggle forKey:@"toggle"];[root setValue:@YES forKey:@"reachable"];RaceCase(1);
  });
 });
}
