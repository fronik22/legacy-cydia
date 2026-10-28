#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#include <dlfcn.h>
__attribute__((constructor)) static void snapshot(void) {
    Dl_info info;
    if (dladdr((const void *)&snapshot, &info)) dlopen(info.dli_fname, RTLD_NOW | RTLD_NODELETE);
    dispatch_async(dispatch_get_main_queue(), ^{
        CGImageRef (*capture)(void) = dlsym(RTLD_DEFAULT, "UIGetScreenImage");
        CGImageRef screen = capture ? capture() : NULL;
        if (screen) {
            [UIImagePNGRepresentation([UIImage imageWithCGImage:screen]) writeToFile:@"/var/mobile/a6-status-screen.png" atomically:YES];
            CGImageRelease(screen);
        }
        id telephony = [NSClassFromString(@"SBTelephonyManager") performSelector:@selector(sharedTelephonyManager)];
        id wifi = [NSClassFromString(@"SBWiFiManager") performSelector:@selector(sharedInstance)];
        BOOL (*using)(id,SEL) = (BOOL (*)(id,SEL))[telephony methodForSelector:@selector(isUsingVPNConnection)];
        int (*type)(id,SEL) = (int (*)(id,SEL))[telephony methodForSelector:@selector(dataConnectionType)];
        BOOL (*primary)(id,SEL) = (BOOL (*)(id,SEL))[wifi methodForSelector:@selector(isPrimaryInterface)];
        NSString *result = [NSString stringWithFormat:@"bridge=%d native_vpn_outside_item=%d network_type=%d wifi_primary=%d screenshot=%d\n",
           NSClassFromString(@"A6StatusBridge") != nil, using ? using(telephony,@selector(isUsingVPNConnection)) : -1,
           type ? type(telephony,@selector(dataConnectionType)) : -1,
           primary ? primary(wifi,@selector(isPrimaryInterface)) : -1, screen != NULL];
        [result writeToFile:@"/var/mobile/a6-status-result.txt" atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
}
