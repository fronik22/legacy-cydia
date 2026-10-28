#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <unistd.h>
@interface NSObject (VIPTest)
+ (id)sharedInstance;
+ (NSArray *)allReps;
+ (BOOL)hasActiveWork;
+ (BOOL)markRepAsCancelled:(id)rep;
- (void)backgroundTaskExpired;
- (NSString *)bundleID;
- (NSInteger)state;
@end
static NSString *const Folder = @"/var/mobile/Library/Caches/veteris-bg-control";
static NSString *const Bundle = @"local.codex.veteris-background-test";
static NSString *const Target = @"/var/mobile/Library/Caches/veteris-background-test.ipa";
static NSDictionary *Status(id background) {
    NSUInteger paused = 0;
    for (id rep in [NSClassFromString(@"YZQueueManager") allReps]) if ([[rep bundleID] isEqual:Bundle] && [rep state] == 6) paused++;
    return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:[UIApplication sharedApplication].applicationState != UIApplicationStateActive], @"inactive", [background valueForKey:@"expiredInBackground"], @"expired", [NSNumber numberWithBool:[[background valueForKey:@"backgroundTask"] unsignedIntegerValue] != UIBackgroundTaskInvalid], @"taskActive", [background valueForKey:@"helperKeepsAlive"], @"helperKeepsAlive", [NSNumber numberWithUnsignedInteger:paused], @"pausedCount", [NSNumber numberWithBool:[NSClassFromString(@"YZQueueManager") hasActiveWork]], @"hasWork", nil];
}
__attribute__((constructor)) static void Start(void) {
    if (![[NSBundle mainBundle].bundleIdentifier isEqual:@"com.victorlobe.veteris"]) return;
    Dl_info image;
    if (!dladdr((void *)&Start, &image) || !dlopen(image.dli_fname, RTLD_LAZY | RTLD_LOCAL | RTLD_NODELETE)) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        NSDictionary *request = [NSDictionary dictionaryWithContentsOfFile:[Folder stringByAppendingPathComponent:@"request.plist"]];
        NSString *action = [request objectForKey:@"action"];
        Class manager = NSClassFromString(@"YZQueueManager");
        id background = [NSClassFromString(@"YZBackgroundKeeper") sharedInstance];
        NSMutableDictionary *reply = [NSMutableDictionary dictionary];
        @try {
            for (id rep in [manager allReps]) if (![[rep bundleID] isEqual:Bundle] && ([rep state] == 1 || [rep state] == 3 || [rep state] == 4)) @throw [NSException exceptionWithName:@"Busy" reason:@"User queue is busy" userInfo:nil];
            if ([action isEqual:@"start"]) {
                NSString *url = [request objectForKey:@"url"];
                if (![url hasPrefix:@"http://127.0.0.1:18761/"]) @throw [NSException exceptionWithName:@"URL" reason:@"Expected the owned USB test tunnel" userInfo:nil];
                id app = [NSClassFromString(@"YZApplication") new];
                [app setValue:Bundle forKey:@"bundleID"];
                [app setValue:@"Background transfer test" forKey:@"name"];
                [app setValue:@"1.0" forKey:@"version"];
                [app setValue:@"Local test" forKey:@"developer"];
                [app setValue:@"5.0" forKey:@"minimumOS"];
                [app setValue:[request objectForKey:@"size"] forKey:@"sizeBytes"];
                [app setValue:url forKey:@"url"];
                SEL selector = NSSelectorFromString(@"enqueueYZApplicationForDownloadOnly:targetPath:");
                ((void (*)(id, SEL, id, id))objc_msgSend)(manager, selector, app, Target);
                [app release];
            } else if ([action isEqual:@"expire"]) {
                [background backgroundTaskExpired];
            } else if ([action isEqual:@"cleanup"]) {
                NSArray *reps = [[[manager allReps] copy] autorelease];
                for (id rep in reps) if ([[rep bundleID] isEqual:Bundle]) [manager markRepAsCancelled:rep];
                NSFileManager *fm = [NSFileManager defaultManager];
                for (NSString *file in [fm contentsOfDirectoryAtPath:Target.stringByDeletingLastPathComponent error:nil]) if ([file hasPrefix:Target.lastPathComponent]) [fm removeItemAtPath:[Target.stringByDeletingLastPathComponent stringByAppendingPathComponent:file] error:nil];
            } else if (![action isEqual:@"status"]) @throw [NSException exceptionWithName:@"Action" reason:@"Unknown test action" userInfo:nil];
            [reply setObject:Status(background) forKey:@"background"];
            [reply setObject:[NSNumber numberWithInt:[UIApplication sharedApplication].applicationState] forKey:@"applicationState"];
            [reply setObject:[NSNumber numberWithInt:getpid()] forKey:@"pid"];
            NSMutableArray *reps = [NSMutableArray array];
            for (id rep in [manager allReps]) if ([[rep bundleID] isEqual:Bundle]) [reps addObject:[NSNumber numberWithInteger:[rep state]]];
            [reply setObject:reps forKey:@"testStates"];
        } @catch (NSException *e) { [reply setObject:e.reason forKey:@"error"]; }
        [reply setObject:[request objectForKey:@"nonce"] ?: @"" forKey:@"nonce"];
        [reply writeToFile:[Folder stringByAppendingPathComponent:@"reply.plist"] atomically:YES];
        [pool drain];
    });
}
