// Developer-only probe: inspect and try to present Notification Center.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <objc/runtime.h>
#include <string.h>

#define NC_LOG "/tmp/ncopen.log"

static void NLog(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *line = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    FILE *f = fopen(NC_LOG, "a");
    if (f) {
        fprintf(f, "%s\n", [line UTF8String]);
        fclose(f);
    }
    [line release];
}

static void DumpMethods(Class cls, BOOL classMethods) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(classMethods ? object_getClass((id)cls) : cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        const char *name = sel_getName(method_getName(methods[i]));
        if (strstr(name, "show") || strstr(name, "present") ||
            strstr(name, "notif") || strstr(name, "bullet") ||
            strstr(name, "center") || strstr(name, "open")) {
            NLog(@"%@ %s", classMethods ? @"+" : @"-", name);
        }
    }
    free(methods);
}

__attribute__((constructor)) static void NCOpenInit(void) {
    @autoreleasepool {
        NLog(@"probe loaded");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            Class cls = NSClassFromString(@"SBBulletinListController");
            NLog(@"class=%p", cls);
            if (!cls) return;
            DumpMethods(cls, NO);
            DumpMethods(cls, YES);
            id shared = [cls performSelector:@selector(sharedInstance)];
            NLog(@"shared=%p", shared);
            NSArray *names = @[
                @"showNotificationCenter", @"_showNotificationCenter",
                @"showNotificationCenter:", @"_showNotificationCenter:",
                @"showBulletinList", @"_showBulletinList",
                @"presentNotificationCenter", @"_presentNotificationCenter",
                @"presentNotificationCenter:", @"_presentNotificationCenter:",
                @"showBulletinList:", @"_showBulletinList:"
            ];
            for (NSString *name in names) {
                SEL sel = NSSelectorFromString(name);
                if (shared && [shared respondsToSelector:sel]) {
                    NLog(@"calling %@", name);
                    [shared performSelector:sel];
                    break;
                }
            }
            SEL list = NSSelectorFromString(@"showListViewAnimated:");
            if (shared && [shared respondsToSelector:list]) {
                NLog(@"calling showListViewAnimated:YES");
                void (*fn)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[shared methodForSelector:list];
                fn(shared, list, YES);
            }
        });
    }
}
