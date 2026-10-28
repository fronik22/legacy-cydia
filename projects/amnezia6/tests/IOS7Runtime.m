#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#include <sys/stat.h>
__attribute__((constructor)) static void inspect(void){
 NSAutoreleasePool *pool=[NSAutoreleasePool new];NSMutableDictionary *out=[NSMutableDictionary dictionary];
 NSArray *names=@[@"SBTelephonyManager",@"SBStatusBarDataManager",@"SBStatusBarStateAggregator",@"SBWiFiManager",@"SBLockScreenManager",@"SBDeviceLockController",@"SBBacklightController",@"SpringBoard"];
 for(NSString *name in names){Class cls=NSClassFromString(name);NSMutableDictionary *row=[NSMutableDictionary dictionary];
  if(cls)for(int meta=0;meta<2;meta++){unsigned count=0;Method *methods=class_copyMethodList(meta?object_getClass(cls):cls,&count);NSMutableDictionary *m=[NSMutableDictionary dictionary];
   for(unsigned i=0;i<count;i++){NSString *sel=NSStringFromSelector(method_getName(methods[i]));if([sel rangeOfString:@"VPN" options:NSCaseInsensitiveSearch].location!=NSNotFound||[sel rangeOfString:@"wifi" options:NSCaseInsensitiveSearch].location!=NSNotFound||[sel rangeOfString:@"lock" options:NSCaseInsensitiveSearch].location!=NSNotFound||[sel rangeOfString:@"backlight" options:NSCaseInsensitiveSearch].location!=NSNotFound||[sel rangeOfString:@"undim" options:NSCaseInsensitiveSearch].location!=NSNotFound||[sel hasPrefix:@"shared"])[m setObject:[NSString stringWithUTF8String:method_getTypeEncoding(methods[i])]forKey:sel];}free(methods);[row setObject:m forKey:meta?@"class":@"instance"];}
  [out setObject:row forKey:name];}
 [out setObject:[[UIDevice currentDevice]systemVersion]forKey:@"os"];[out setObject:[[NSBundle mainBundle]bundleIdentifier]?:@""forKey:@"bundle"];
 [out writeToFile:@"/var/tmp/amnezia7-runtime.plist" atomically:YES];chmod("/var/tmp/amnezia7-runtime.plist",0600);[pool drain];
}
