#import <Foundation/Foundation.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <unistd.h>

static NSString *const App = @"/Applications/Veteris.app";
static NSString *const State = @"/var/lib/veteris-ipad/original.plist";
static NSArray *Keys(void) { return [NSArray arrayWithObjects:@"UIDeviceFamily", @"NSMainNibFile~ipad", @"UIMainStoryboardFile~ipad", nil]; }
static NSDictionary *Patched(NSDictionary *original) {
    NSMutableDictionary *d = [[original mutableCopy] autorelease];
    [d setObject:[NSArray arrayWithObjects:@1, @2, nil] forKey:@"UIDeviceFamily"];
    // The shipped iPad nib name has no matching file; reuse the real storyboard.
    [d removeObjectForKey:@"NSMainNibFile~ipad"];
    [d setObject:@"MainStoryboard" forKey:@"UIMainStoryboardFile~ipad"];
    return d;
}
static NSDictionary *Restored(NSDictionary *current, NSDictionary *original) {
    NSMutableDictionary *d = [[current mutableCopy] autorelease];
    for (NSString *key in Keys()) {
        [d removeObjectForKey:key];
        if ([original objectForKey:key]) [d setObject:[original objectForKey:key] forKey:key];
    }
    return d;
}
static void Require(BOOL ok, NSString *reason) {
    if (!ok) @throw [NSException exceptionWithName:@"VeterisIPad" reason:reason userInfo:nil];
}
static int SelfTest(void) {
    NSDictionary *a = [NSDictionary dictionaryWithObjectsAndKeys:@"MainStoryboard-iPad", @"NSMainNibFile~ipad", @"untouched", @"other", nil];
    NSDictionary *b = Patched(a);
    Require([[b objectForKey:@"UIDeviceFamily"] isEqual:[NSArray arrayWithObjects:@1, @2, nil]], @"Family test");
    Require(![b objectForKey:@"NSMainNibFile~ipad"] && [[b objectForKey:@"UIMainStoryboardFile~ipad"] isEqual:@"MainStoryboard"], @"Storyboard test");
    Require([Patched(b) isEqual:b], @"Idempotency test");
    Require([Restored(b, a) isEqual:a], @"Absent-key restore test");
    NSDictionary *c = [NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObject:@1], @"UIDeviceFamily", @"custom", @"UIMainStoryboardFile~ipad", @"untouched", @"other", nil];
    Require([Restored(Patched(c), c) isEqual:c], @"Existing-key restore test");
    puts("PASS: family, storyboard, idempotency, absent/existing-key restoration");
    return 0;
}
int main(int argc, char **argv) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    int status = 1;
    @try {
        Require(argc == 2, @"Use apply, remove or --self-test");
        NSString *action = [NSString stringWithUTF8String:argv[1]];
        if ([action isEqual:@"--self-test"]) { status = SelfTest(); [pool drain]; return status; }
        Require([action isEqual:@"apply"] || [action isEqual:@"remove"], @"Unknown action");
        Require(getuid() == 0, @"Root is required");
        char model[128] = {0}; size_t length = sizeof model;
        Require(!sysctlbyname("hw.machine", model, &length, NULL, 0) && !strncmp(model, "iPad", 4), @"iPad hardware is required");
        NSDictionary *backup = [NSDictionary dictionaryWithContentsOfFile:State];
        if ([action isEqual:@"remove"] && !backup) { puts("Nothing to restore"); [pool drain]; return 0; }
        NSString *path = [App stringByAppendingPathComponent:@"Info.plist"];
        NSDictionary *current = [NSDictionary dictionaryWithContentsOfFile:path];
        Require([[current objectForKey:@"CFBundleIdentifier"] isEqual:@"com.victorlobe.veteris"] && [[current objectForKey:@"CFBundleVersion"] isEqual:@"4"], @"This package supports the original Veteris version 4 only");
        struct stat permissions;
        Require(!lstat(path.fileSystemRepresentation, &permissions) && S_ISREG(permissions.st_mode), @"Expected a regular Info.plist");
        NSDictionary *next = nil;
        if ([action isEqual:@"apply"]) {
            Require([[NSFileManager defaultManager] fileExistsAtPath:[App stringByAppendingPathComponent:@"en.lproj/MainStoryboard.storyboardc/Info.plist"]], @"MainStoryboard is missing");
            if (!backup) {
                NSMutableDictionary *original = [NSMutableDictionary dictionary];
                for (NSString *key in Keys()) if ([current objectForKey:key]) [original setObject:[current objectForKey:key] forKey:key];
                Require([[NSFileManager defaultManager] createDirectoryAtPath:State.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil], @"Cannot create backup directory");
                chmod(State.stringByDeletingLastPathComponent.fileSystemRepresentation, 0700);
                Require([original writeToFile:State atomically:YES], @"Cannot save original metadata");
                chmod(State.fileSystemRepresentation, 0600);
            }
            next = Patched(current);
        } else {
            NSDictionary *expected = Patched(backup);
            for (NSString *key in Keys()) {
                id a = [current objectForKey:key], b = [expected objectForKey:key];
                Require(a == b || [a isEqual:b], @"Metadata changed outside this package; refusing to overwrite it");
            }
            next = Restored(current, backup);
        }
        Require([next writeToFile:path atomically:YES], @"Cannot write metadata");
        Require(!chown(path.fileSystemRepresentation, permissions.st_uid, permissions.st_gid) && !chmod(path.fileSystemRepresentation, permissions.st_mode & 07777), @"Cannot preserve metadata permissions");
        if ([action isEqual:@"remove"]) Require([[NSFileManager defaultManager] removeItemAtPath:State error:nil], @"Cannot remove saved state");
        printf("Veteris iPad metadata: %s\n", argv[1]);
        status = 0;
    } @catch (NSException *e) { fprintf(stderr, "%s\n", e.reason.UTF8String); }
    [pool drain];
    return status;
}
