// One-shot screenshot payload; inject into SpringBoard with cynject.
#import <UIKit/UIKit.h>
#import <unistd.h>
#include <stdio.h>

extern CGImageRef UIGetScreenImage(void);

static void SLog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *line = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    FILE *f = fopen("/tmp/snap.log", "a");
    if (f) { fprintf(f, "%s\n", [line UTF8String]); fclose(f); }
    [line release];
}

@interface PerfSnapshot : NSObject
+ (void)take;
@end

@implementation PerfSnapshot
+ (void)take {
    @autoreleasepool {
        SLog(@"take start thread=%d", (int)[NSThread isMainThread]);
        CGImageRef image = UIGetScreenImage();
        SLog(@"image=%p", image);
        if (!image) return;
        UIImage *ui = [UIImage imageWithCGImage:image];
        NSData *png = UIImagePNGRepresentation(ui);
        BOOL ok = [png writeToFile:@"/tmp/perf-shot.png" atomically:YES];
        SLog(@"wrote=%d bytes=%lu size=%@", ok, (unsigned long)[png length], NSStringFromCGSize(ui.size));
        CGImageRelease(image);
    }
}
@end

__attribute__((constructor)) static void PerfSnapshotInit(void) {
    SLog(@"ctor thread=%d", (int)[NSThread isMainThread]);
    [PerfSnapshot performSelectorOnMainThread:@selector(take) withObject:nil waitUntilDone:NO];
}
