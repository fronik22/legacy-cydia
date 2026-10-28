// Developer-only probe: invoke NCSettings' own tap handler on the HUD toggle.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <objc/runtime.h>
#include <stdarg.h>

#define TAP_LOG "/tmp/nctap.log"

static void TLog(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *line = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    FILE *f = fopen(TAP_LOG, "a");
    if (f) {
        fprintf(f, "%s\n", [line UTF8String]);
        fclose(f);
    }
    [line release];
}

static IMP gOriginalImageWithContentsOfFile;

static UIImage *LogImageWithContentsOfFile(id self, SEL _cmd, NSString *path) {
    UIImage *image = ((UIImage *(*)(id, SEL, NSString *))gOriginalImageWithContentsOfFile)(self, _cmd, path);
    if ([path rangeOfString:@"NCSettings"].location != NSNotFound) {
        TLog(@"image %@ -> %p size=%@", path, image,
             image ? NSStringFromCGSize(image.size) : @"nil");
    }
    return image;
}

static void InstallImageLog(void) {
    Method method = class_getClassMethod([UIImage class], @selector(imageWithContentsOfFile:));
    if (!method) return;
    gOriginalImageWithContentsOfFile = method_getImplementation(method);
    method_setImplementation(method, (IMP)LogImageWithContentsOfFile);
}

static UIView *FindView(UIView *view, NSString *className) {
    if (!view) return nil;
    if ([NSStringFromClass([view class]) isEqualToString:className]) return view;
    for (UIView *child in view.subviews) {
        UIView *found = FindView(child, className);
        if (found) return found;
    }
    return nil;
}

static void CollectToggleViews(UIView *view, NSMutableArray *out) {
    if (!view) return;
    if ([NSStringFromClass([view class]) isEqualToString:@"NCSToggleView"]) [out addObject:view];
    for (UIView *child in view.subviews) CollectToggleViews(child, out);
}

__attribute__((constructor)) static void NCTapInit(void) {
    @autoreleasepool {
        TLog(@"probe loaded");
        InstallImageLog();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            NSArray *windows = [[UIApplication sharedApplication] windows];
            TLog(@"windows=%lu", (unsigned long)[windows count]);
            UIView *mainView = nil;
            NSMutableArray *toggles = [NSMutableArray array];
            for (UIWindow *window in windows) {
                TLog(@"window %@ frame=%@", NSStringFromClass([window class]), NSStringFromCGRect(window.frame));
                if (!mainView) mainView = FindView(window, @"NCSMainView");
                CollectToggleViews(window, toggles);
            }
            TLog(@"main=%p toggles=%lu", mainView, (unsigned long)[toggles count]);
            UIView *hud = nil;
            for (UIView *toggle in toggles) {
                NSString *name = [toggle valueForKey:@"name"];
                BOOL enabled = [[toggle valueForKey:@"enabled"] boolValue];
                TLog(@"toggle %@ frame=%@ enabled=%d", name, NSStringFromCGRect(toggle.frame), enabled);
                if ([name isEqualToString:@"PerfOverlay"]) hud = toggle;
            }
            if (!hud && [toggles count]) hud = [toggles objectAtIndex:0];
            if (hud) {
                UIImage *image = nil;
                if ([hud respondsToSelector:@selector(image)]) image = [hud performSelector:@selector(image)];
                TLog(@"hud image=%p size=%@ alpha=%.2f hidden=%d class=%@",
                     image, image ? NSStringFromCGSize(image.size) : @"nil",
                     hud.alpha, hud.hidden, NSStringFromClass([hud class]));
                for (UIView *sub in hud.subviews) {
                    TLog(@"hud sub %@ frame=%@ alpha=%.2f", NSStringFromClass([sub class]),
                         NSStringFromCGRect(sub.frame), sub.alpha);
                }
            }
            if (mainView && hud) {
                TLog(@"tapping %@ via %@", [hud valueForKey:@"name"], NSStringFromClass([mainView class]));
                [mainView performSelector:@selector(toggleWasTapped:) withObject:hud];
            } else {
                TLog(@"not tapping: mainView=%p hud=%p", mainView, hud);
            }
        });
    }
}
