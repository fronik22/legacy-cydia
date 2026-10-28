#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import "VersionPolicy.h"

static UIView *Part(id object, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    return [object respondsToSelector:selector] ? [object performSelector:selector] : nil;
}
static void (*OriginalCell)(id, SEL);
static void Cell(id self, SEL cmd) {
    OriginalCell(self, cmd);
    UIView *content = [(UITableViewCell *)self contentView];
    CGFloat width = content.bounds.size.width;
    if (width < 600) return;
    Part(self, @"backgroundImageView").frame = content.bounds;
    Part(self, @"getLabel").frame = CGRectMake(width - 68, 29, 50, 19);
    Part(self, @"appNameLabel").frame = CGRectMake(78, 18, width - 160, 42);
    Part(self, @"developerNameLabel").frame = CGRectMake(78, 8, width - 160, 12);
    Part(self, @"versionLabel").frame = CGRectMake(78, 58, width - 160, 12);
}
static void (*OriginalHome)(id, SEL);
static void (*OriginalList)(id, SEL);
static void List(id self, SEL cmd) {
    OriginalList(self, cmd);
    CGFloat width = [(UITableViewCell *)self contentView].bounds.size.width;
    if (width < 600) return;
    for (NSString *name in [NSArray arrayWithObjects:@"appNameLabel", @"developerNameLabel", @"versionLabel", nil]) {
        UIView *label = Part(self, name);
        CGRect frame = label.frame;
        frame.size.width = MAX(0, width - frame.origin.x - 12);
        label.frame = frame;
    }
}
static void (*OriginalQueue)(id, SEL);
static void Queue(id self, SEL cmd) {
    OriginalQueue(self, cmd);
    UIView *content = [(UITableViewCell *)self contentView];
    CGFloat width = content.bounds.size.width;
    if (width < 600) return;
    UIView *background = [content.subviews count] ? [content.subviews objectAtIndex:0] : nil;
    if ([background isKindOfClass:[UIImageView class]] && background != Part(self, @"appImageView")) background.frame = content.bounds;
    for (NSString *name in [NSArray arrayWithObjects:@"appNameLabel", @"appDeveloperLabel", @"appVersionLabel", nil]) {
        UIView *label = Part(self, name);
        CGRect frame = label.frame;
        frame.size.width = MAX(0, width - frame.origin.x - 140);
        label.frame = frame;
    }
    Part(self, @"appActivityIndicator").frame = CGRectMake(width - 36, 29, 20, 20);
    Part(self, @"appDownloadActivityIndicator").frame = CGRectMake(width - 36, 29, 20, 20);
    Part(self, @"appProgressView").frame = CGRectMake(width - 128, 35, 112, 20);
    Part(self, @"appSpeedLabel").frame = CGRectMake(width - 128, 16, 112, 14);
    Part(self, @"appProgressLabel").frame = CGRectMake(width - 128, 47, 112, 14);
}
static void Home(id self, SEL cmd) {
    OriginalHome(self, cmd);
    UIView *view = [(UIViewController *)self view];
    CGFloat width = view.bounds.size.width, height = view.bounds.size.height;
    if (width < 600) return;
    Part(self, @"appIconImageView").frame = CGRectMake((width - 201) / 2, 20, 201, 251);
    Part(self, @"badgeImageView").frame = CGRectMake((width - 201) / 2 + 96, 21, 75, 64);
    Part(self, @"welcomeLabel").frame = CGRectMake(24, 278, width - 48, 34);
    Part(self, @"tableView").frame = CGRectMake(24, 330, width - 48, MAX(0, height - 354));
    Part(self, @"backgroundImage").frame = CGRectMake(0, 0, width, 310);
    Part(self, @"backgroundView").frame = CGRectMake(0, 310, width, MAX(0, height - 310));
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (CALayer *layer in view.layer.sublayers) if ([layer isKindOfClass:[CAGradientLayer class]]) layer.frame = CGRectMake(0, 0, width, 310);
    UIView *bottom = Part(self, @"backgroundView");
    for (CALayer *layer in bottom.layer.sublayers) if ([layer isKindOfClass:[CAGradientLayer class]]) layer.frame = bottom.bounds;
    [CATransaction commit];
}

__attribute__((constructor)) static void Start(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSDictionary *info = [NSBundle mainBundle].infoDictionary;
    if ([[info objectForKey:@"CFBundleIdentifier"] isEqual:@"com.victorlobe.veteris"] && [[info objectForKey:@"CFBundleVersion"] isEqual:@"4"]) {
        // Only the verified iOS 6 SGX path needs this; iOS 7 has different graphics drivers.
        NSInteger major = [[[UIDevice currentDevice] systemVersion] integerValue];
        if (!VeterisLayoutSupported((int)major)) { [pool drain]; return; }
        if (VeterisNeedsSGXCacheWorkaround((int)major)) setenv("SGX_MAX_SHADER_CACHE_SIZE", "0", 1);
        void *substrate = dlopen("/usr/lib/libsubstrate.dylib", RTLD_LAZY | RTLD_LOCAL);
        void (*hook)(Class, SEL, IMP, IMP *) = substrate ? dlsym(substrate, "MSHookMessageEx") : NULL;
        Class cell = NSClassFromString(@"SearchTableViewCell"), home = NSClassFromString(@"HomeViewController");
        if (hook && class_getInstanceMethod(cell, @selector(layoutSubviews)) && class_getInstanceMethod(home, @selector(viewDidLayoutSubviews))) {
            hook(cell, @selector(layoutSubviews), (IMP)Cell, (IMP *)&OriginalCell);
            hook(home, @selector(viewDidLayoutSubviews), (IMP)Home, (IMP *)&OriginalHome);
            Class list = NSClassFromString(@"AppListTableViewCell"), queue = NSClassFromString(@"QueueTableViewCell");
            if (class_getInstanceMethod(list, @selector(layoutSubviews))) hook(list, @selector(layoutSubviews), (IMP)List, (IMP *)&OriginalList);
            if (class_getInstanceMethod(queue, @selector(layoutSubviews))) hook(queue, @selector(layoutSubviews), (IMP)Queue, (IMP *)&OriginalQueue);
        }
    }
    [pool drain];
}
