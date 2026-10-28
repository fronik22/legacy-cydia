#import "../app/A6Daemon.h"
#include <assert.h>
#include <sys/stat.h>
#include <unistd.h>

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    char directory[] = "/tmp/amnezia6-save.XXXXXX";
    assert(mkdtemp(directory));
    NSString *dir = [NSString stringWithUTF8String:directory];
    A6Daemon *client = [[A6Daemon alloc] init];
    client.configPath = [dir stringByAppendingPathComponent:@"profile.conf"];
    NSString *error = nil;
    assert([client saveConfig:@"original" error:&error]);
    assert([[client configContents] isEqualToString:@"original"]);
    assert([client saveConfig:@"replacement" error:&error]);
    assert([[client configContents] isEqualToString:@"replacement"]);
    assert([client configuredEndpoint] == nil);
    assert([client saveConfig:@"[Interface]\nEndpoint = wrong:1\nPrivateKey = secret\n[Peer]\n # Endpoint = commented:2\n; Endpoint = ignored:3\n enDPoint = vpn.example:443 \r\n" error:&error]);
    assert([[client configuredEndpoint] isEqualToString:@"vpn.example:443"]);
    assert([client saveConfig:@"[Peer]\nEndpoint=192.0.2.1:443\n[Unknown]\nEndpoint=wrong:4\n" error:&error]);
    assert([[client configuredEndpoint] isEqualToString:@"192.0.2.1:443"]);
    struct stat st;
    assert(stat([client.configPath fileSystemRepresentation], &st) == 0);
    assert((st.st_mode & 0777) == 0600);
    assert([[[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:NULL] count] == 1);
    client.configPath = [dir stringByAppendingPathComponent:@"missing/profile.conf"];
    assert(![client saveConfig:@"failed" error:&error]);
    assert(error != nil);
    [[NSFileManager defaultManager] removeItemAtPath:dir error:NULL];
    [client release];
    [pool drain];
    puts("Atomic configuration save and permissions passed");
    return 0;
}
