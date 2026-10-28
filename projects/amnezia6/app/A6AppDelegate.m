#import "A6AppDelegate.h"
#import "A6RootController.h"
#import "A6ProfilesController.h"

@implementation A6AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _root = [[A6RootController alloc] initWithStyle:UITableViewStyleGrouped];
    _navigation = [[UINavigationController alloc] initWithRootViewController:_root];
    if ([_navigation.navigationBar respondsToSelector:@selector(setTranslucent:)])
        _navigation.navigationBar.translucent = NO;
    _window.rootViewController = _navigation;
    [_window makeKeyAndVisible];
    return YES;
}

- (void)dealloc {
    [_navigation release];
    [_root release];
    [_window release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
    sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    if (![url isFileURL] && ![[[url scheme] lowercaseString] isEqualToString:@"vpn"]) return NO;
    if (_navigation.modalViewController) [_navigation dismissModalViewControllerAnimated:NO];
    A6ProfilesController *controller = [[A6ProfilesController alloc] init];
    [_navigation pushViewController:controller animated:NO];
    [controller importURL:url];
    [controller release];
    return YES;
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    return [self application:application openURL:url sourceApplication:nil annotation:[NSNull null]];
}

@end
