#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <dlfcn.h>
static id App;
static NSMutableDictionary *Report;
static NSString *Docs,*Phase;
static IMP OriginalAnnouncement;
static NSUInteger Calls;
static BOOL OldIdle;
static void Check(BOOL ok,NSString *message){if(!ok)[NSException raise:@"DiscoverySwitchTest" format:@"%@",message];}
static void Invoke(SEL selector){((void(*)(id,SEL))objc_msgSend)(App,selector);}
static BOOL TimerValid(void){return [[App valueForKey:@"discoveryTimer"]isValid];}
static void CountAnnouncement(id app,SEL cmd){Calls++;((void(*)(id,SEL))OriginalAnnouncement)(app,cmd);}
static void Save(void){[Report writeToFile:[Docs stringByAppendingPathComponent:[NSString stringWithFormat:@".codex-discovery-switch-%@.plist",Phase]] atomically:YES];}
static void Fail(NSException *e){[Report setObject:e.reason forKey:@"error"];[UIApplication sharedApplication].idleTimerDisabled=OldIdle;Save();}
static void Done(void){[Report setObject:@YES forKey:@"passed"];[Report setObject:@(Calls) forKey:@"announcementCalls"];[Report setObject:@(TimerValid()) forKey:@"timerValid"];[Report setObject:[App valueForKey:@"automaticDiscovery"] forKey:@"automaticDiscovery"];[UIApplication sharedApplication].idleTimerDisabled=OldIdle;Save();}
static UIControl *Switch(void){return [[App valueForKey:@"settingsPanel"]viewWithTag:35];}
static void Toggle(BOOL on){UIControl *toggle=Switch();Check(toggle!=nil,@"Settings switch missing");((void(*)(id,SEL,BOOL))objc_msgSend)(toggle,@selector(setOn:),on);[toggle sendActionsForControlEvents:UIControlEventValueChanged];Check([[App valueForKey:@"automaticDiscovery"]boolValue]==on,@"Switch did not update app state");Check([[NSUserDefaults standardUserDefaults]boolForKey:@"automaticDiscovery"]==on,@"Preference not persisted");}
static void LayoutChecks(void){
 UIView *root=[UIApplication sharedApplication].keyWindow.rootViewController.view;CGRect saved=root.bounds;
 for(NSString *language in @[@"ru",@"en",@"uk"]){NSString *path=[[[NSBundle mainBundle]pathForResource:language ofType:@"lproj"]stringByAppendingPathComponent:@"Translations.plist"];NSDictionary *catalog=[NSDictionary dictionaryWithContentsOfFile:path];Check([catalog objectForKey:@"Автопоиск"]!=nil,@"Missing localized switch");
  for(NSValue *size in @[[NSValue valueWithCGSize:CGSizeMake(320,460)],[NSValue valueWithCGSize:CGSizeMake(768,1004)],[NSValue valueWithCGSize:CGSizeMake(1024,748)]]){
   CGSize bounds=[size CGSizeValue];root.bounds=CGRectMake(0,0,bounds.width,bounds.height);Invoke(@selector(layoutInterface));UIView *general=[[App valueForKey:@"settingsPanel"]viewWithTag:21];UILabel *label=(id)[general viewWithTag:144],*hint=(id)[general viewWithTag:145];label.text=[catalog objectForKey:@"Автопоиск"];hint.text=[catalog objectForKey:@"Повторять поиск каждые 10 с, пока приложение открыто."];
   Check(CGRectContainsRect(general.bounds,Switch().frame)&&CGRectContainsRect(general.bounds,hint.frame),@"Switch/hint outside settings card");
   CGSize text=[label.text sizeWithFont:label.font constrainedToSize:CGSizeMake(label.bounds.size.width,CGFLOAT_MAX) lineBreakMode:label.lineBreakMode];Check(text.height<=label.bounds.size.height,@"Switch title clipped");
   text=[hint.text sizeWithFont:hint.font constrainedToSize:CGSizeMake(hint.bounds.size.width,CGFLOAT_MAX) lineBreakMode:hint.lineBreakMode];Check(text.height<=hint.bounds.size.height,@"Switch explanation clipped");
  }
 }
 root.bounds=saved;Invoke(@selector(buildInterface));[Report setObject:@9 forKey:@"localizedLayoutChecks"];
}
static void Screenshot(void){UIWindow *window=[UIApplication sharedApplication].keyWindow;UIGraphicsBeginImageContextWithOptions(window.bounds.size,NO,[[UIScreen mainScreen]scale]);[window.layer renderInContext:UIGraphicsGetCurrentContext()];UIImage *image=UIGraphicsGetImageFromCurrentImageContext();[UIImagePNGRepresentation(image)writeToFile:[Docs stringByAppendingPathComponent:@".codex-discovery-switch.png"]atomically:YES];UIGraphicsEndImageContext();}
__attribute__((constructor)) static void Start(void){Dl_info image;if(!dladdr((void*)&Start,&image)||!dlopen(image.dli_fname,RTLD_NOW|RTLD_LOCAL|RTLD_NODELETE))return;dispatch_async(dispatch_get_main_queue(),^{@try{
 App=[UIApplication sharedApplication].delegate;Docs=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES)[0]copy];NSDictionary *request=[NSDictionary dictionaryWithContentsOfFile:[Docs stringByAppendingPathComponent:@".codex-discovery-switch-request.plist"]];Phase=[[request objectForKey:@"phase"]copy];Check([@[@"A",@"B",@"C"]containsObject:Phase],@"Invalid test phase");Report=[[NSMutableDictionary alloc]initWithObjectsAndKeys:Phase,@"phase",nil];OldIdle=[UIApplication sharedApplication].idleTimerDisabled;[UIApplication sharedApplication].idleTimerDisabled=YES;
 Check([UIApplication sharedApplication].applicationState==UIApplicationStateActive,@"App must be foreground");Check([[[App valueForKey:@"receiver"]valueForKey:@"ready"]boolValue],@"Receiver not ready");Check([[App valueForKey:@"discoverySocket"]intValue]>=0,@"Passive UDP socket missing");[Report setObject:@YES forKey:@"receiverAndPassiveDiscoveryReady"];
 [App setValue:@2 forKey:@"activeTab"];Invoke(@selector(layoutInterface));
 Method method=class_getInstanceMethod([App class],@selector(announceDiscovery));OriginalAnnouncement=method_setImplementation(method,(IMP)CountAnnouncement);
 if([Phase isEqual:@"A"]){
  Check(![[App valueForKey:@"automaticDiscovery"]boolValue]&&!TimerValid(),@"New setting must default OFF without a timer");Check(![[Switch() valueForKey:@"on"]boolValue],@"New switch must show OFF");LayoutChecks();Screenshot();
  Invoke(@selector(scanAgain));Check(Calls==1&&!TimerValid(),@"Manual scan must announce once without creating a timer");((void(*)(id,SEL,id))objc_msgSend)(App,@selector(applicationDidBecomeActive:),[UIApplication sharedApplication]);Check(Calls==1&&!TimerValid(),@"Foreground OFF must not rescan");
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,12*NSEC_PER_SEC),dispatch_get_main_queue(),^{@try{Check(Calls==1&&!TimerValid(),@"OFF repeated a scan");[Report setObject:@YES forKey:@"defaultOffNoRepeat12s"];Toggle(YES);Check(TimerValid()&&Calls==2,@"ON must scan immediately and create timer");dispatch_after(dispatch_time(DISPATCH_TIME_NOW,12*NSEC_PER_SEC),dispatch_get_main_queue(),^{@try{Check(Calls>=3&&TimerValid(),@"ON did not repeat scan");[Report setObject:@YES forKey:@"enabledPeriodicScan12s"];Done();}@catch(NSException *e){Fail(e);}});}@catch(NSException *e){Fail(e);}});
 }else if([Phase isEqual:@"B"]){
  Check([[App valueForKey:@"automaticDiscovery"]boolValue]&&TimerValid()&&[[Switch()valueForKey:@"on"]boolValue],@"ON did not survive relaunch");[Report setObject:@YES forKey:@"onSurvivedRelaunch"];
  ((void(*)(id,SEL,id))objc_msgSend)(App,@selector(applicationWillResignActive:),[UIApplication sharedApplication]);Check(!TimerValid(),@"Resign-active callback did not stop timer");((void(*)(id,SEL,id))objc_msgSend)(App,@selector(applicationDidBecomeActive:),[UIApplication sharedApplication]);Check(TimerValid(),@"Become-active callback did not restart ON timer");[Report setObject:@YES forKey:@"lifecycleTimerCallbacks"];
  Toggle(NO);Check(!TimerValid(),@"OFF did not invalidate timer");NSUInteger before=Calls;Invoke(@selector(resumeDiscovery));Check(Calls==before&&!TimerValid(),@"OFF resumed automatic search");Invoke(@selector(scanAgain));Check(Calls==before+1&&!TimerValid(),@"Manual scan broken after disabling");NSUInteger expected=Calls;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,12*NSEC_PER_SEC),dispatch_get_main_queue(),^{@try{Check(Calls==expected&&!TimerValid(),@"Disabled timer still fired");[Report setObject:@YES forKey:@"disabledNoRepeat12s"];Screenshot();Done();}@catch(NSException *e){Fail(e);}});
 }else{
  Check(![[App valueForKey:@"automaticDiscovery"]boolValue]&&!TimerValid()&&![[Switch()valueForKey:@"on"]boolValue],@"OFF did not survive relaunch");[Report setObject:@YES forKey:@"offSurvivedRelaunch"];Screenshot();Done();
 }
 }@catch(NSException *e){Fail(e);}});}
