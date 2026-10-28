#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
static NSString *const Folder = @"/var/mobile/Library/Caches/veteris-ipad-test";
static NSDictionary *View(UIView *v, unsigned depth) {
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObjectsAndKeys:NSStringFromClass(v.class), @"class", NSStringFromCGRect(v.frame), @"frame", nil];
    if ([v isKindOfClass:[UILabel class]]) [d setObject:((UILabel *)v).text ?: @"" forKey:@"text"];
    if (depth < 12) {
        NSMutableArray *children = [NSMutableArray array];
        for (UIView *child in v.subviews) if (!child.hidden) [children addObject:View(child, depth + 1)];
        [d setObject:children forKey:@"children"];
    }
    return d;
}
__attribute__((constructor)) static void Start(void) {
    if (![[NSBundle mainBundle].bundleIdentifier isEqual:@"com.victorlobe.veteris"]) return;
    Dl_info image;
    if (!dladdr((void *)&Start, &image) || !dlopen(image.dli_fname, RTLD_LAZY | RTLD_LOCAL | RTLD_NODELETE)) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        NSDictionary *command = [NSDictionary dictionaryWithContentsOfFile:[Folder stringByAppendingPathComponent:@"command.plist"]];
        UITabBarController *root = (id)[UIApplication sharedApplication].keyWindow.rootViewController;
        if ([root isKindOfClass:[UITabBarController class]] && [command objectForKey:@"tab"]) root.selectedIndex = [[command objectForKey:@"tab"] unsignedIntegerValue];
        if ([[command objectForKey:@"action"] isEqual:@"settings"]) {
            id home = [(UINavigationController *)[root.viewControllers objectAtIndex:0] topViewController];
            if ([home respondsToSelector:@selector(showSettings)]) [home performSelector:@selector(showSettings)];
        }
        if ([[command objectForKey:@"action"] isEqual:@"detail"]) {
            UINavigationController *nav = [root.viewControllers objectAtIndex:1];
            [nav popToRootViewControllerAnimated:NO];
            UITableViewController *list = (id)nav.topViewController;
            NSIndexPath *row = [NSIndexPath indexPathForRow:0 inSection:0];
            if ([list isKindOfClass:NSClassFromString(@"FeaturedTableViewController")] && [list.tableView numberOfRowsInSection:0]) {
                [list.tableView selectRowAtIndexPath:row animated:NO scrollPosition:UITableViewScrollPositionTop];
                [list performSegueWithIdentifier:@"FeaturedAppInfoPush" sender:[list.tableView cellForRowAtIndexPath:row]];
            }
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            NSAutoreleasePool *p = [NSAutoreleasePool new];
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            UITabBarController *selectedRoot = (id)window.rootViewController;
            if ([selectedRoot isKindOfClass:[UITabBarController class]] && [command objectForKey:@"tab"]) selectedRoot.selectedIndex = [[command objectForKey:@"tab"] unsignedIntegerValue];
            [window layoutIfNeeded];
            NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObjectsAndKeys:NSStringFromCGRect(window.frame), @"window", NSStringFromCGRect([UIScreen mainScreen].bounds), @"screen", [NSNumber numberWithInt:[UIDevice currentDevice].userInterfaceIdiom], @"idiom", [NSNumber numberWithFloat:[UIScreen mainScreen].scale], @"scale", View(window, 0), @"views", nil];
            NSMutableArray *tabs = [NSMutableArray array];
            UITabBarController *r = (id)window.rootViewController;
            if ([r isKindOfClass:[UITabBarController class]]) for (UIViewController *vc in r.viewControllers) [tabs addObject:vc.tabBarItem.title ?: @""];
            [d setObject:tabs forKey:@"tabs"];
            NSMutableArray *cells = [NSMutableArray array];
            Class cellClass = NSClassFromString(@"SearchTableViewCell");
            for (NSNumber *requested in [NSArray arrayWithObjects:@768, @1024, nil]) {
                UITableViewCell *cell = [[[cellClass alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];
                cell.frame = CGRectMake(0, 0, requested.floatValue, 78);
                [cell setNeedsLayout]; [cell layoutIfNeeded];
                UIView *title = [cell valueForKey:@"appNameLabel"], *get = [cell valueForKey:@"getLabel"], *background = [cell valueForKey:@"backgroundImageView"];
                [cells addObject:[NSDictionary dictionaryWithObjectsAndKeys:requested, @"width", NSStringFromCGRect(cell.contentView.bounds), @"content", NSStringFromCGRect(title.frame), @"title", NSStringFromCGRect(get.frame), @"get", NSStringFromCGRect(background.frame), @"background", [NSNumber numberWithBool:CGRectGetMaxX(title.frame) < CGRectGetMinX(get.frame) && CGRectGetMaxX(get.frame) <= requested.floatValue && background.frame.size.width == cell.contentView.bounds.size.width], @"fits", nil]];
            }
            [d setObject:cells forKey:@"cellChecks"];
            NSMutableArray *queues = [NSMutableArray array];
            for (NSNumber *requested in [NSArray arrayWithObjects:@768, @1024, nil]) {
                Class c = NSClassFromString(@"QueueTableViewCell");
                UITableViewCell *cell = [[[c alloc] initWithFrame:CGRectMake(0, 0, 320, 78) reuseIdentifier:nil] autorelease];
                cell.frame = CGRectMake(0, 0, requested.floatValue, 78);
                [cell setNeedsLayout]; [cell layoutIfNeeded];
                UIView *title = [cell valueForKey:@"appNameLabel"], *progress = [cell valueForKey:@"appProgressView"];
                [queues addObject:[NSDictionary dictionaryWithObjectsAndKeys:requested, @"width", NSStringFromCGRect(title.frame), @"title", NSStringFromCGRect(progress.frame), @"progress", [NSNumber numberWithBool:CGRectGetMaxX(title.frame) < CGRectGetMinX(progress.frame) && CGRectGetMaxX(progress.frame) <= requested.floatValue], @"fits", nil]];
            }
            [d setObject:queues forKey:@"queueChecks"];
            NSMutableArray *images = [NSMutableArray array];
            for (uint32_t i = 0; i < _dyld_image_count(); i++) {
                NSString *name = [NSString stringWithUTF8String:_dyld_get_image_name(i)];
                if ([name rangeOfString:@"substrate" options:NSCaseInsensitiveSearch].location != NSNotFound || [name rangeOfString:@"VeterisIPad"].location != NSNotFound) [images addObject:name];
            }
            [d setObject:images forKey:@"images"];
            [d setObject:[NSNumber numberWithUnsignedLong:(unsigned long)dlsym(RTLD_DEFAULT, "MSHookMessageEx")] forKey:@"hookSymbol"];
            [d writeToFile:[Folder stringByAppendingPathComponent:@"result.plist"] atomically:YES];
            UIGraphicsBeginImageContextWithOptions(window.bounds.size, YES, 0);
            [window.layer renderInContext:UIGraphicsGetCurrentContext()];
            [UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext()) writeToFile:[Folder stringByAppendingPathComponent:@"screen.png"] atomically:YES];
            UIGraphicsEndImageContext();
            if ([[command objectForKey:@"render2x"] boolValue]) {
                UIGraphicsBeginImageContextWithOptions(window.bounds.size, YES, 2);
                [window.layer renderInContext:UIGraphicsGetCurrentContext()];
                [UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext()) writeToFile:[Folder stringByAppendingPathComponent:@"screen2x.png"] atomically:YES];
                UIGraphicsEndImageContext();
            }
            [p drain];
        });
        [pool drain];
    });
}
