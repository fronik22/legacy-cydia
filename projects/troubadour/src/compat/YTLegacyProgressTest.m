#import "YTPlayerViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <assert.h>

@interface YTPlayerViewController (ProgressCheck)
- (void)startWatchReports;
- (void)reportWatchSegment;
- (void)stopWatchReports:(BOOL)closing;
- (void)teardownPlayer;
- (NSDictionary *)trackingJson;
@end

@interface YTProgressClock : NSObject
@property (nonatomic, assign) NSTimeInterval seconds;
- (CMTime)currentTime;
- (float)rate;
- (void)pause;
@end
@implementation YTProgressClock
- (CMTime)currentTime { return CMTimeMakeWithSeconds(_seconds, 600); }
- (float)rate { return 1.0f; }
- (void)pause {}
@end

@interface YTProgressCheck : YTPlayerViewController
@end
@implementation YTProgressCheck
// No tracking URLs: the regression check cannot send requests or change history.
- (NSDictionary *)trackingJson { return [NSDictionary dictionary]; }
@end

int YTLegacyProgressTest(void) {
    YTProgressCheck *screen = [[YTProgressCheck alloc] init];
    YTProgressClock *clock = [[YTProgressClock alloc] init];
    clock.seconds = 10;
    [screen setValue:clock forKey:@"player"];
    [screen setValue:@YES forKey:@"watchReported"];
    [screen startWatchReports];
    [screen reportWatchSegment];
    assert([[screen valueForKey:@"watchSegmentFrom"] doubleValue] == 10);
    id timer = [screen valueForKey:@"watchTimer"];

    [screen teardownPlayer];
    assert(![[screen valueForKey:@"watchClosed"] boolValue]);
    assert([screen valueForKey:@"watchTimer"] == timer);
    [screen setValue:clock forKey:@"player"];
    clock.seconds = 115;
    [screen reportWatchSegment];
    assert([[screen valueForKey:@"watchSegmentFrom"] doubleValue] == 115);

    [screen stopWatchReports:YES];
    assert([[screen valueForKey:@"watchClosed"] boolValue]);
    assert([screen valueForKey:@"watchTimer"] == nil);
    [screen stopWatchReports:YES];
    [screen teardownPlayer];
    puts("PASS progress advances 10 -> 115 seconds across decoder replacement; closes on exit");
    return 0;
}

#import "YTApi.h"
#import "YTAuth.h"
#import <objc/runtime.h>

@interface YTApi (ProgressTransportCheck)
+ (void)sendWatched:(NSDictionary *)json position:(double)position from:(double)from elapsed:(double)elapsed final:(BOOL)final nonce:(NSString *)nonce;
+ (BOOL)pingStats:(NSString *)url;
+ (void)sendPendingWatch;
@end
static NSMutableArray *YTCheckedPackets;
static NSMutableArray *YTCheckedURLs;
static dispatch_semaphore_t YTCheckedDone;
static BOOL YTCheckSuccess;
static double YTCheckedTTL;
@interface YTReportQueueCheck : YTApi @end
@implementation YTReportQueueCheck
+ (void)sendWatched:(NSDictionary *)json position:(double)position from:(double)from elapsed:(double)elapsed final:(BOOL)final nonce:(NSString *)nonce {
    if (position == 0) [NSThread sleepForTimeInterval:0.1];
    [YTCheckedPackets addObject:@[@(position), nonce]];
    if (final) dispatch_semaphore_signal(YTCheckedDone);
}
+ (NSDictionary *)post:(NSString *)endpoint body:(NSDictionary *)body client:(NSString *)client authorize:(BOOL)authorize ttl:(NSTimeInterval)ttl {
    YTCheckedTTL = ttl;
    return nil;
}
@end
@interface YTReportTransportCheck : YTApi @end
@implementation YTReportTransportCheck
+ (BOOL)pingStats:(NSString *)url {
    [YTCheckedURLs addObject:url];
    return YTCheckSuccess;
}
@end
static BOOL YTCheckSignedIn(id obj, SEL selector) { return YES; }
int YTLegacyReportTest(void) {
    YTCheckedPackets = [NSMutableArray array];
    YTCheckedURLs = [NSMutableArray array];
    YTCheckedDone = dispatch_semaphore_create(0);
    NSDictionary *json = @{@"videoDetails":@{@"videoId":@"codex-check-a",@"lengthSeconds":@"1000"},
        @"playbackTracking":@{@"videostatsPlaybackUrl":@{@"baseUrl":@"https://example.invalid/playback?x=1"},
                             @"videostatsWatchtimeUrl":@{@"baseUrl":@"https://example.invalid/watchtime?x=1"}}};
    [YTReportQueueCheck reportWatched:json position:0];
    [YTReportQueueCheck reportWatched:json position:10 from:0 elapsed:10 final:NO];
    [YTReportQueueCheck reportWatched:json position:20 from:10 elapsed:10 final:YES];
    NSString *firstNonce = [YTApi playbackNonceForVideo:@"codex-check-a"];
    [YTApi beginPlaybackForVideo:@"codex-check-a"];
    NSString *secondNonce = [YTApi playbackNonceForVideo:@"codex-check-a"];
    assert(![firstNonce isEqualToString:secondNonce]);
    assert([secondNonce isEqualToString:[YTApi playbackNonceForVideo:@"codex-check-a"]]);
    [YTApi playbackNonceForVideo:@"codex-check-b"];
    assert(dispatch_semaphore_wait(YTCheckedDone, dispatch_time(DISPATCH_TIME_NOW, 3*NSEC_PER_SEC)) == 0);
    assert([YTCheckedPackets count] == 3);
    for (NSUInteger i = 0; i < 3; i++) {
        assert([[[YTCheckedPackets objectAtIndex:i] objectAtIndex:0] intValue] == i*10);
        assert([[[YTCheckedPackets objectAtIndex:i] objectAtIndex:1] isEqual:[[YTCheckedPackets objectAtIndex:0] objectAtIndex:1]]);
    }
    Method auth = class_getClassMethod([YTAuth class], @selector(isSignedIn));
    IMP original = method_setImplementation(auth, (IMP)YTCheckSignedIn);
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    id pending = [settings objectForKey:@"YTPendingWatch"];
    @try {
        YTCheckedTTL = -1;
        [YTReportQueueCheck homeFeedWithParams:nil continuation:nil];
        assert(YTCheckedTTL == 0);
        YTCheckSuccess = NO;
        [YTReportTransportCheck sendWatched:json position:115 from:100 elapsed:15 final:YES nonce:@"test-cpn"];
        NSDictionary *record = [settings dictionaryForKey:@"YTPendingWatch"];
        assert([[record objectForKey:@"position"] doubleValue] == 115);
        assert([[record objectForKey:@"reported"] doubleValue] == 100);
        assert([[record objectForKey:@"nonce"] isEqualToString:@"test-cpn"]);
        YTCheckSuccess = YES;
        [YTReportTransportCheck sendPendingWatch];
        assert([settings objectForKey:@"YTPendingWatch"] == nil);
        [YTReportTransportCheck sendWatched:json position:115 from:-1 elapsed:0 final:NO nonce:@"new-cpn"];
        NSString *url = [YTCheckedURLs lastObject];
        assert([url rangeOfString:@"cmt=115.000&st=115.000&et=116.000"].location != NSNotFound);
    } @finally {
        method_setImplementation(auth, original);
        if (pending) [settings setObject:pending forKey:@"YTPendingWatch"];
        else [settings removeObjectForKey:@"YTPendingWatch"];
        [settings synchronize];
    }
    puts("PASS new viewing session renews nonce; ordered reports retain their nonce; fresh feed; failed final retained and retried; opening preserves resume");
    return 0;
}
