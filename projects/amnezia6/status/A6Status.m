/* Native iOS 4–7 VPN badge; scoped getter hook adapted from Senko (GPLv2). */
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#include <dlfcn.h>
#include <pthread.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <string.h>
#include "client.h"

static int connected;
static BOOL querying, installed;
static Class itemClass;
static SEL sharedItem;
static pthread_key_t depthKey;
static BOOL (*originalVPN)(id, SEL);
static void (*originalItem)(id, SEL);
static void (*originalWiFi)(id, SEL, BOOL);

static id shared(NSString *name, SEL selector) {
    Class cls = NSClassFromString(name);
    return [cls respondsToSelector:selector] ? [cls performSelector:selector] : nil;
}
static BOOL wifiUp(void) {
    struct ifaddrs *list = NULL;
    BOOL up = NO;
    if (getifaddrs(&list) != 0) return NO;
    for (struct ifaddrs *p = list; p; p = p->ifa_next)
        if (p->ifa_addr && p->ifa_addr->sa_family == AF_INET &&
            !strcmp(p->ifa_name, "en0") && (p->ifa_flags & IFF_UP)) up = YES;
    freeifaddrs(list);
    return up;
}
static BOOL usingVPN(id self, SEL selector) {
    return originalVPN(self, selector) || (__atomic_load_n(&connected, __ATOMIC_RELAXED) && pthread_getspecific(depthKey));
}
static void updateItem(id self, SEL selector) {
    void *previous = pthread_getspecific(depthKey);
    pthread_setspecific(depthKey, (void *)1);
    originalItem(self, selector);
    pthread_setspecific(depthKey, previous);
}
static void primaryChanged(id self, SEL selector, BOOL primary) {
    originalWiFi(self, selector, primary || (__atomic_load_n(&connected, __ATOMIC_RELAXED) && wifiUp()));
}
static BOOL signature(Method method, char result, unsigned arguments) {
    char type[8] = {0};
    if (!method || method_getNumberOfArguments(method) != arguments) return NO;
    method_getReturnType(method, type, sizeof type);
    return type[0] == result || (result == 'c' && type[0] == 'B');
}
static BOOL installHooks(void) {
    if (installed) return YES;
    Method vpn = class_getInstanceMethod(NSClassFromString(@"SBTelephonyManager"),
                                         @selector(isUsingVPNConnection));
    // iOS7 moved this item from DataManager to StateAggregator.
    itemClass = NSClassFromString(@"SBStatusBarStateAggregator");
    sharedItem = @selector(sharedInstance);
    if (!itemClass) { itemClass = NSClassFromString(@"SBStatusBarDataManager"); sharedItem = @selector(sharedDataManager); }
    Method item = class_getInstanceMethod(itemClass, @selector(_updateVPNItem));
    if (!signature(vpn, 'c', 2) || !signature(item, 'v', 2)) return NO;
    if (pthread_key_create(&depthKey, NULL) != 0) return NO;
    originalItem = (void (*)(id, SEL))method_setImplementation(item, (IMP)updateItem);
    originalVPN = (BOOL (*)(id, SEL))method_setImplementation(vpn, (IMP)usingVPN);
    Method wifi = class_getInstanceMethod(NSClassFromString(@"SBWiFiManager"),
                                          @selector(_primaryInterfaceChanged:));
    char arg[8] = {0};
    if (signature(wifi, 'v', 3)) {
        method_getArgumentType(wifi, 2, arg, sizeof arg);
        if (arg[0] == 'c' || arg[0] == 'B')
            originalWiFi = (void (*)(id, SEL, BOOL))method_setImplementation(wifi, (IMP)primaryChanged);
    }
    installed = YES;
    return YES;
}
static void refresh(void) {
    id manager = shared(NSStringFromClass(itemClass), sharedItem);
    if ([manager respondsToSelector:@selector(_updateVPNItem)])
        [manager performSelector:@selector(_updateVPNItem)];
    if (originalWiFi && wifiUp()) {
        id wifi = shared(@"SBWiFiManager", @selector(sharedInstance));
        if (wifi) primaryChanged(wifi, @selector(_primaryInterfaceChanged:), YES);
    }
}
@interface A6StatusBridge : NSObject
+ (void)poll;
@end
@implementation A6StatusBridge
+ (void)poll {
    if (querying) return;
    querying = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        char reply[1024];
        BOOL active = a6_client_command(NULL, "status", reply, sizeof reply) == 0 &&
                      !strncmp(reply, "state=connected\n", 16);
        dispatch_async(dispatch_get_main_queue(), ^{
            querying = NO;
            BOOL wasInstalled = installed;
            if (installHooks() && (!wasInstalled || active != connected)) {
                __atomic_store_n(&connected, active, __ATOMIC_RELAXED);
                refresh();
            }
        });
    });
}
@end
__attribute__((constructor)) static void start(void) {
    if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) return;
    double os = [[[UIDevice currentDevice] systemVersion] doubleValue];
    if (os < 4.3 || os >= 8) return;
    Dl_info info;
    if (dladdr((const void *)&start, &info)) dlopen(info.dli_fname, RTLD_NOW | RTLD_NODELETE);
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:2.0 target:[A6StatusBridge class]
             selector:@selector(poll) userInfo:nil repeats:YES];
        [A6StatusBridge poll];
    });
}
