#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <dlfcn.h>

@interface YTLegacyTLS : NSObject
@end
@implementation YTLegacyTLS
+ (void)load {
    @autoreleasepool {
        if ([[[UIDevice currentDevice] systemVersion] integerValue]<5 &&
            !dlopen("/Library/MobileSubstrate/DynamicLibraries/tlsfix.dylib",RTLD_NOW))
            NSLog(@"[Troubadour] Install TLSFix 1.1 and modern root certificates for HTTPS: %s",dlerror());
    }
}
@end
