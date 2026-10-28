#import "YTStreams.h"
#import "YTSabr.h"
#import "YTUmp.h"
#import "YTUtil.h"
#import "YTSettings.h"
#import "YTProto.h"
#import "YTPlayerViewController.h"
#import "YTHlsProxy.h"
#import <objc/runtime.h>
#import <assert.h>
#import <sys/socket.h>
#import <unistd.h>
#import <AVFoundation/AVFoundation.h>

@interface YTStreams (SelectionCheck)
+ (void)giveUpOnSabr:(YTSabr *)sabr;
@end
@interface YTSabr (SelectionCheck)
- (void)handlePart:(YTUmpPart *)part;
- (void)parseFormatInit:(NSData *)body;
- (YTProtoWriter *)clientState:(int64_t)startMs;
@end
@interface YTPlayerViewController (SelectionCheck)
- (void)pickHeight:(NSInteger)height;
- (void)pickHeight:(NSInteger)height force:(BOOL)force;
- (void)hideMenu;
- (void)teardownPlayer;
- (void)startPlayer:(NSString *)url generation:(NSInteger)generation;
- (NSTimeInterval)currentSeconds;
- (void)seekTo:(NSTimeInterval)seconds;
- (void)watchStall;
- (void)sabrLost:(NSNotification *)notification;
- (void)sabrRefusedPick:(NSNotification *)notification;
- (void)seekFinished:(BOOL)finished after:(NSTimeInterval)seconds token:(NSInteger)token;
@end

static uint64_t advertisedFrames(YTSabr *sabr) {
    NSData *data = [[sabr clientState:0] data];
    for (NSNumber *field in @[@38, @1]) {
        YTProtoReader *reader = [YTProtoReader readerWithData:data];
        data = nil;
        while ([reader next]) if ([reader field] == [field unsignedIntegerValue]) {
            data = [reader takeData]; break;
        }
        assert(data != nil);
    }
    YTProtoReader *reader = [YTProtoReader readerWithData:data];
    while ([reader next]) if ([reader field] == 11) return [reader takeVarint];
    assert(0); return 0;
}

static void deliver(YTSabr *sabr, NSInteger itag, BOOL init, NSInteger sequence) {
    id header = [[NSClassFromString(@"YTSabrHeader") alloc] init];
    [header setValue:@(itag) forKey:@"itag"];
    [header setValue:@(init) forKey:@"isInit"];
    [header setValue:@(sequence) forKey:@"sequence"];
    [[sabr valueForKey:@"openHeaders"] setObject:header forKey:@1];
    [[sabr valueForKey:@"openBodies"] setObject:[NSData dataWithBytes:"test" length:4] forKey:@1];
    YTUmpPart *end = [[YTUmpPart alloc] init];
    end.type = YTUmpMediaEnd;
    const char key = 1;
    end.body = [NSData dataWithBytes:&key length:1];
    [sabr handlePart:end];
}

@interface YTHlsProxy (SelectionCheck)
- (void)handlePath:(NSString *)path client:(int)client request:(NSString *)request;
- (NSData *)buildSegment:(id)plan index:(NSInteger)index video:(id)video audio:(id)voice videoInit:(id)head audioInit:(id)audioHead;
@end
@interface YTSessionProxy : YTHlsProxy @end
@implementation YTSessionProxy
- (NSData *)buildSegment:(id)plan index:(NSInteger)index video:(id)video audio:(id)voice videoInit:(id)head audioInit:(id)audioHead {
    // Simulate replacement while an old segment download is finishing.
    [self close];
    return [@"old session" dataUsingEncoding:NSUTF8StringEncoding];
}
@end

static YTFormat *audio(NSString *track, BOOL original, NSInteger bitrate) {
    YTFormat *format = [[YTFormat alloc] init];
    format.mimeType = @"audio/mp4; codecs=\"mp4a.40.2\"";
    format.hasAudio = YES;
    format.audioTrackId = track;
    format.audioIsOriginal = original;
    format.bitrate = bitrate;
    return format;
}

static NSMutableArray *started, *selectedAudio, *resumed;
static dispatch_semaphore_t firstOpen, releaseOpen;
static NSInteger opens;
static BOOL played;
static NSString *fakeOpen(id obj, SEL sel, YTFormat *video, YTFormat *voice) {
    [selectedAudio addObject:voice.audioTrackId];
    if (++opens == 1) {
        dispatch_semaphore_signal(firstOpen);
        assert(dispatch_semaphore_wait(releaseOpen, dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_SEC)) == 0);
    }
    return [NSString stringWithFormat:@"http://127.0.0.1/%ld", (long)video.height];
}
@interface YTReadyItem : NSObject
- (AVPlayerItemStatus)status;
- (CMTime)duration;
@end
@implementation YTReadyItem
- (AVPlayerItemStatus)status { return AVPlayerItemStatusReadyToPlay; }
- (CMTime)duration { return CMTimeMakeWithSeconds(1000, 600); }
@end
@interface YTStoppedPlayer : NSObject
@property(nonatomic, strong) YTReadyItem *item;
@end
@implementation YTStoppedPlayer
- (float)rate { return 0; }
- (id)currentItem { return _item; }
@end
@interface YTLoadingItem : YTReadyItem @end
@implementation YTLoadingItem
- (AVPlayerItemStatus)status { return AVPlayerItemStatusUnknown; }
@end
@interface YTPendingPlayer : YTStoppedPlayer @end
@implementation YTPendingPlayer
- (void)play { played = YES; }
- (void)pause {}
- (CMTime)currentTime { return CMTimeMakeWithSeconds(10, 600); }
- (void)seekToTime:(CMTime)time toleranceBefore:(CMTime)before toleranceAfter:(CMTime)after completionHandler:(void (^)(BOOL))handler {}
@end
@interface YTBufferedItem : YTReadyItem
@property(nonatomic, assign) BOOL empty;
@end
@implementation YTBufferedItem
- (NSArray *)loadedTimeRanges {
    return _empty ? @[] : @[[NSValue valueWithCMTimeRange:CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(100, 600))]];
}
@end
@interface YTSelectionScreen : YTPlayerViewController @end
@implementation YTSelectionScreen
- (void)hideMenu {}
- (void)logPlaybackStats {}
- (void)noteLiveHealth {}
- (void)renewLiveFeedIfStuck {}
- (void)checkBroadcastOver {}
- (void)rescueLiveStall {}
- (void)updateProgress {}
- (void)scheduleHide {}
- (void)resumeAtChosenRate { played = YES; }
- (void)teardownPlayer {}
- (NSTimeInterval)currentSeconds { return 0; }
- (void)startPlayer:(NSString *)url generation:(NSInteger)generation {
    [started addObject:url]; [self setValue:@YES forKey:@"legacyStartPending"];
}
- (void)seekTo:(NSTimeInterval)seconds { [resumed addObject:@(seconds)]; }
@end

static BOOL freshFallback;
@interface YTNoURLsScreen : YTSelectionScreen @end
@implementation YTNoURLsScreen
- (void)sabrRefusedPick:(NSNotification *)notification { freshFallback = YES; }
@end

int YTLegacyStreamTest(void) {
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 5.0)
        assert([YTStreams deviceDislikesSixtyFrames]);
    // A 32-bit length must not wrap past the end of the network response.
    const uint8_t malformed[] = {21, 0xf0, 0xff, 0xff, 0xff, 0xff};
    NSUInteger tail = 0; __block NSInteger parts = 0;
    [YTUmp read:[NSData dataWithBytes:malformed length:sizeof(malformed)] remainder:&tail
        handler:^(YTUmpPart *part) { parts++; }];
    assert(parts == 0 && tail == sizeof(malformed));
    const uint8_t packet[] = {21, 3, 1, 2, 3};
    NSMutableData *source = [NSMutableData dataWithBytes:packet length:sizeof(packet)];
    __block NSData *payload;
    [YTUmp read:source remainder:&tail handler:^(YTUmpPart *part) { payload = part.body; }];
    memset([source mutableBytes], 0, [source length]);
    assert(tail == 0 && [payload length] == 3 && ((const uint8_t *)[payload bytes])[0] == 1);

    YTSessionProxy *proxy = [[YTSessionProxy alloc] init];
    [proxy setValue:@[@1] forKey:@"segments"];
    NSUInteger session = [[proxy valueForKey:@"session"] unsignedIntegerValue];
    int sockets[2]; assert(socketpair(AF_UNIX, SOCK_STREAM, 0, sockets) == 0);
    [proxy handlePath:[NSString stringWithFormat:@"/%lu/s/0.ts", (unsigned long)session]
        client:sockets[0] request:@"GET / HTTP/1.0\r\n\r\n"];
    char reply[1024] = {0}; ssize_t size = read(sockets[1], reply, sizeof(reply)-1);
    assert(size > 0 && strstr(reply, "410 Gone") != NULL);
    assert([proxy valueForKey:@"lastSegment"] == nil);
    close(sockets[0]); close(sockets[1]);

    YTFormat *ru = audio(@"ru.4", YES, 100);
    YTFormat *en = audio(@"en-US.10", NO, 200);
    NSArray *voices = @[en, ru];
    assert([YTStreams chooseAudio:voices preferredTrack:nil] == ru);
    assert([YTStreams chooseAudio:voices preferredTrack:@"en-US.10"] == en);
    assert([YTStreams chooseAudio:voices preferredTrack:@"missing"] == nil);

    YTSabrFormat *chosen = [YTSabrFormat formatWithItag:299 lastModified:0]; chosen.height = 1080; chosen.fps = 60;
    YTSabrFormat *wrong = [YTSabrFormat formatWithItag:135 lastModified:0]; wrong.height = 480;
    YTSabr *sabr = [[YTSabr alloc] initWithUrl:nil config:nil videoId:@"fixture" poToken:nil];
    [sabr setAvailableVideo:@[chosen, wrong] audio:@[]];
    [sabr pinVideo:chosen hard:YES];
    __block NSInteger refusals = 0;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:YTSabrPinRefusedNotification
        object:sabr queue:nil usingBlock:^(NSNotification *note) { refusals++; }];
    deliver(sabr, 299, YES, 0);
    NSData *head = [sabr videoInit];
    deliver(sabr, 135, YES, 0);
    deliver(sabr, 135, NO, 1);
    assert(refusals == 0 && [sabr videoInit] == head);
    assert([sabr videoSegment:1] == nil && [sabr deliveredVideoItag] == 299);
    assert(![sabr takeVideoTrackChanged] && ![sabr stepDownVideo]);
    YTProtoWriter *announced = [YTProtoWriter writer];
    YTProtoWriter *formatID = [YTProtoWriter writer];
    [formatID putVarint:135 field:1]; [announced putMessage:formatID field:2];
    [sabr parseFormatInit:[announced data]];
    assert([sabr playingItag] == 135 && [sabr deliveredVideoItag] == 299);
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    // A filtered-out video response must never replace AAC init/media or acknowledgements.
    YTSabrFormat *aac = [YTSabrFormat formatWithItag:140 lastModified:0];
    [sabr setAvailableVideo:@[chosen, wrong] audio:@[aac]];
    deliver(sabr, 140, YES, 0); deliver(sabr, 140, NO, 1);
    NSData *audioHead = [sabr audioInit], *audioBody = [sabr audioSegment:1];
    for (NSNumber *unlisted in @[@298, @9999]) {
        deliver(sabr, unlisted.integerValue, YES, 0);
        deliver(sabr, unlisted.integerValue, NO, 1);
        assert([sabr audioItag] == 140 && [sabr audioInit] == audioHead);
        assert([sabr audioSegment:1] == audioBody);
        assert([[[sabr valueForKey:@"gotAudio"] valueForKey:@"itag"] integerValue] == 140);
        assert([sabr deliveredVideoItag] == 299);
    }
    YTSabr *neverAccepted = [[YTSabr alloc] initWithUrl:nil config:nil videoId:@"fixture" poToken:nil];
    [neverAccepted setAvailableVideo:@[chosen, wrong] audio:@[]];
    [neverAccepted pinVideo:chosen hard:YES];
    observer = [[NSNotificationCenter defaultCenter] addObserverForName:YTSabrPinRefusedNotification
        object:neverAccepted queue:nil usingBlock:^(NSNotification *note) { refusals++; }];
    deliver(neverAccepted, 135, YES, 0); deliver(neverAccepted, 135, NO, 1);
    assert(refusals == 1);
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    __block NSInteger lost = 0;
    observer = [[NSNotificationCenter defaultCenter] addObserverForName:YTSabrLostNotification
        object:sabr queue:nil usingBlock:^(NSNotification *note) { lost++; }];
    for (NSInteger i=0; i<3; i++) [YTStreams giveUpOnSabr:sabr];
    assert(lost == 1);
    [[NSNotificationCenter defaultCenter] removeObserver:observer];

    started = [NSMutableArray array]; selectedAudio = [NSMutableArray array];
    resumed = [NSMutableArray array]; opens = 0;
    firstOpen = dispatch_semaphore_create(0); releaseOpen = dispatch_semaphore_create(0);
    YTFormat *low = [[YTFormat alloc] init]; low.hasVideo = YES;
    low.mimeType = @"video/mp4; codecs=\"avc1.4d401f\""; low.height = 360; low.width = 640;
    YTFormat *high = [[YTFormat alloc] init]; high.hasVideo = YES;
    high.mimeType = low.mimeType; high.height = 720; high.width = 1280;
    YTFormat *full60 = [[YTFormat alloc] init]; full60.hasVideo = YES;
    full60.mimeType = low.mimeType; full60.width = 1920; full60.height = 1080; full60.fps = 60;
    YTFormat *full30 = [[YTFormat alloc] init]; full30.hasVideo = YES;
    full30.mimeType = low.mimeType; full30.width = 1920; full30.height = 1080; full30.fps = 30;
    NSInteger savedFrames = [[NSUserDefaults standardUserDefaults] integerForKey:@"YTSixtyFrames"];
    [YTSettings setAllowsSixtyFrames:NO];
    assert(advertisedFrames(sabr) == 60);
    [sabr pinVideo:chosen hard:NO];
    assert(advertisedFrames(sabr) == 30);
    [sabr pinVideo:chosen hard:YES];
    assert(([[YTStreams heightsIn:@[high, full60]] containsObject:@1080]));
    assert([YTStreams framesForHeight:1080] == 60);
    assert(([YTStreams chooseVideo:@[high, full60] maxHeight:1080 manual:YES] == full60));
    assert(([YTStreams chooseVideo:@[high, full60] maxHeight:1080] == high));
    assert(([YTStreams chooseVideo:@[full60, full30] maxHeight:1080 manual:YES] == full30));
    assert(([YTStreams chooseVideo:@[full30, full60] maxHeight:1080 manual:YES] == full30));
    assert(([YTStreams chooseVideo:@[low, high] maxHeight:1080 manual:YES] == high));
    [[NSUserDefaults standardUserDefaults] setInteger:savedFrames forKey:@"YTSixtyFrames"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    YTSelectionScreen *screen = [[YTSelectionScreen alloc] init];
    [screen setValue:[[YTGeneration alloc] init] forKey:@"loadGeneration"];
    [screen setValue:@[low, high, en, ru] forKey:@"formats"];
    [screen setValue:@"ru.4" forKey:@"audioTrack"];
    [screen setValue:@YES forKey:@"awaitingSeek"];
    [screen setValue:@203.1 forKey:@"seekTarget"];
    Method method = class_getInstanceMethod([YTHlsProxy class], @selector(openWithVideo:audio:));
    IMP original = method_setImplementation(method, (IMP)fakeOpen);
    NSInteger savedHeight = [YTSettings preferredHeight];
    @try {
        [screen pickHeight:360];
        assert([YTSettings preferredHeight] == 360);
        assert(dispatch_semaphore_wait(firstOpen, dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_SEC)) == 0);
        [screen pickHeight:720];
        assert([YTSettings preferredHeight] == 720);
        assert([[screen valueForKey:@"maxHeight"] integerValue] == 720);
        YTPlayerViewController *next = [[YTPlayerViewController alloc]
            initWithVideoId:@"fixture" title:@"fixture" playlist:nil];
        assert([[next valueForKey:@"pickedHeight"] integerValue] == 720);
        dispatch_semaphore_signal(releaseOpen);
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
        while ([started count] == 0 && [deadline timeIntervalSinceNow] > 0)
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        assert([started isEqualToArray:@[@"http://127.0.0.1/720"]]);
        assert(([selectedAudio isEqualToArray:@[@"ru.4", @"ru.4"]]));
        assert([resumed isEqualToArray:@[@203.1]]);
        [YTSettings setPreferredHeight:360];
        [screen pickHeight:720]; // The same selection still persists immediately.
        assert([YTSettings preferredHeight] == 720);
        [screen pickHeight:360 force:YES]; // Internal rebuild must not save a preference.
        assert([YTSettings preferredHeight] == 720);
        deadline = [NSDate dateWithTimeIntervalSinceNow:5];
        while ([started count] < 2 && [deadline timeIntervalSinceNow] > 0)
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        assert([started count] == 2);
    } @finally {
        method_setImplementation(method, original);
        [YTSettings setPreferredHeight:savedHeight];
    }
    YTSelectionScreen *zero = [[YTSelectionScreen alloc] init];
    YTReadyItem *item = [[YTReadyItem alloc] init];
    [zero setValue:item forKey:@"observedItem"];
    [zero setValue:[[NSObject alloc] init] forKey:@"player"];
    [zero setValue:@YES forKey:@"watchReported"];
    [zero setValue:@YES forKey:@"legacyStartPending"];
    [zero setValue:@YES forKey:@"awaitingSeek"];
    [zero setValue:@YES forKey:@"meantToPlay"];
    played = NO;
    [zero observeValueForKeyPath:@"status" ofObject:item change:nil context:NULL];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2];
    while (!played && [deadline timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    assert(played && ![[zero valueForKey:@"awaitingSeek"] boolValue]);

    YTSelectionScreen *loading = [[YTSelectionScreen alloc] init];
    YTLoadingItem *loadingItem = [[YTLoadingItem alloc] init];
    YTPendingPlayer *loadingPlayer = [[YTPendingPlayer alloc] init]; loadingPlayer.item = loadingItem;
    [loading setValue:loadingPlayer forKey:@"player"];
    [loading setValue:loadingItem forKey:@"observedItem"];
    [loading setValue:@YES forKey:@"meantToPlay"];
    IMP seek = class_getMethodImplementation([YTPlayerViewController class], @selector(seekTo:));
    ((void (*)(id, SEL, double))seek)(loading, @selector(seekTo:), 33.0);
    assert([[loading valueForKey:@"legacyStartPending"] boolValue]);
    assert([[loading valueForKey:@"legacyStartTime"] doubleValue] == 33.0);
    assert([[loading valueForKey:@"awaitingSeek"] boolValue]);
    assert([[loading valueForKey:@"seekWasPlaying"] boolValue]);

    YTNoURLsScreen *noURLs = [[YTNoURLsScreen alloc] init];
    [noURLs setValue:@{} forKey:@"playerJson"];
    [noURLs setValue:@720 forKey:@"pickedHeight"];
    freshFallback = NO;
    [noURLs sabrLost:[NSNotification notificationWithName:YTSabrLostNotification object:[YTStreams lastSabr]]];
    assert(freshFallback);
    [noURLs setValue:@0 forKey:@"pickedHeight"];
    freshFallback = NO;
    [noURLs sabrLost:[NSNotification notificationWithName:YTSabrLostNotification object:[YTStreams lastSabr]]];
    assert(!freshFallback);

    YTSelectionScreen *pending = [[YTSelectionScreen alloc] init];
    YTPendingPlayer *pendingPlayer = [[YTPendingPlayer alloc] init]; pendingPlayer.item = item;
    [pending setValue:pendingPlayer forKey:@"player"];
    [pending setValue:item forKey:@"observedItem"];
    [pending setValue:@YES forKey:@"watchReported"];
    [pending setValue:@YES forKey:@"awaitingSeek"];
    [pending setValue:@YES forKey:@"seekCompletionPending"];
    [pending setValue:@YES forKey:@"seekWasPlaying"];
    [pending setValue:@1 forKey:@"seekToken"];
    [pending observeValueForKeyPath:@"status" ofObject:item change:nil context:NULL];
    assert([[pending valueForKey:@"awaitingSeek"] boolValue]);
    played = NO;
    [pending seekFinished:YES after:0.1 token:1];
    assert(played && ![[pending valueForKey:@"awaitingSeek"] boolValue]);

    YTSelectionScreen *stopped = [[YTSelectionScreen alloc] init];
    YTBufferedItem *buffered = [[YTBufferedItem alloc] init];
    YTStoppedPlayer *paused = [[YTStoppedPlayer alloc] init]; paused.item = buffered;
    [stopped setValue:paused forKey:@"player"];
    [stopped setValue:@0 forKey:@"stallSeen"];
    played = NO;
    [stopped setValue:@1.75 forKey:@"stalledFor"];
    [stopped watchStall];
    assert(!played); // An explicit pause must stay paused.
    [stopped setValue:@YES forKey:@"meantToPlay"];
    buffered.empty = YES;
    [stopped setValue:@1.75 forKey:@"stalledFor"];
    [stopped watchStall]; assert(!played);
    buffered.empty = NO;
    [stopped setValue:@YES forKey:@"awaitingSeek"];
    [stopped watchStall]; assert(!played);
    [stopped setValue:@NO forKey:@"awaitingSeek"];
    [stopped setValue:@1.75 forKey:@"stalledFor"];
    [stopped watchStall];
    assert(played == ([[[UIDevice currentDevice] systemVersion] floatValue] < 5.0));

    puts("PASS parser ownership/lengths; stale session rejected without cache pollution; original/explicit audio; rejected mismatched SABR init/media; single scoped fallback only before any selected media; pre-ready seek is deferred with play intent; missing direct URLs trigger manual recovery; Ready does not cancel seek completion; manual 60-fps-only resolution plays; 30 fps preferred when available; absent resolution uses fixed nearest track; latest quality wins; immediate persistent user selection; internal rebuild does not overwrite preference; new video inherits quality; pending resume preserved; zero start clears seek; buffered legacy stall resumes without overriding pause/seek");
    return 0;
}


// Separate invocations verify the on-disk preference, including Auto, without networking.
int YTLegacyQualityTest(NSInteger expected, BOOL write) {
    if (write) {
        YTSelectionScreen *screen = [[YTSelectionScreen alloc] init];
        [screen setValue:@(expected) forKey:@"pickedHeight"];
        [screen pickHeight:expected];
    }
    assert([YTSettings preferredHeight] == expected);
    YTPlayerViewController *next = [[YTPlayerViewController alloc]
        initWithVideoId:@"fixture" title:@"fixture" playlist:nil];
    assert([[next valueForKey:@"pickedHeight"] integerValue] == expected);
    printf("PASS quality %s: %ld; fresh controller inherits preference\n",
        write ? "written" : "read in new process", (long)expected);
    return 0;
}
