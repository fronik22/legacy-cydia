#import "A6Daemon.h"

#import "client.h"

#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

@implementation A6StatusReport
@synthesize status = _status;
@synthesize stateName = _stateName;
@synthesize uptime = _uptime;
@synthesize txBytes = _txBytes;
@synthesize rxBytes = _rxBytes;
@synthesize txPackets = _txPackets;
@synthesize rxPackets = _rxPackets;
@synthesize endpoint = _endpoint;
@synthesize ifname = _ifname;
@synthesize address = _address;
@synthesize errorText = _errorText;

- (void)dealloc {
    [_stateName release];
    [_endpoint release];
    [_ifname release];
    [_address release];
    [_errorText release];
    [super dealloc];
}
@end

static NSString *value_for_key(NSString *line, NSString *key) {
    if (![line hasPrefix:key]) return nil;
    return [line substringFromIndex:[key length]];
}

@implementation A6Daemon

@synthesize socketPath = _socketPath;
@synthesize configPath = _configPath;
@synthesize logPath = _logPath;

+ (A6Daemon *)shared {
    static A6Daemon *instance = nil;
    if (!instance) instance = [[A6Daemon alloc] init];
    return instance;
}

- (id)init {
    self = [super init];
    if (self) {
        _socketPath = [@A6_CONTROL_DEFAULT_PATH copy];
        _configPath = [@"/var/mobile/Library/Preferences/Amnezia6/amnezia6.conf" copy];
        _logPath = [@"/var/log/amnezia6d.log" copy];
    }
    return self;
}

- (void)dealloc {
    [_socketPath release];
    [_configPath release];
    [_logPath release];
    [super dealloc];
}

- (BOOL)isReachable {
    int fd = a6_client_connect([_socketPath UTF8String]);
    if (fd < 0) return NO;
    close(fd);
    return YES;
}

- (NSString *)runCommand:(NSString *)command {
    char reply[8192];
    if (!command) return nil;
    if (a6_client_command([_socketPath UTF8String], [command UTF8String], reply,
                          sizeof reply) != 0)
        return nil;
    return [NSString stringWithUTF8String:reply];
}

- (A6StatusReport *)statusReport {
    A6StatusReport *report = [[[A6StatusReport alloc] init] autorelease];
    NSString *reply = [self runCommand:@"status"];
    NSArray *lines;
    NSUInteger i;

    report.status = A6StatusUnavailable;
    if (!reply) return report;

    lines = [reply componentsSeparatedByString:@"\n"];
    for (i = 0; i < [lines count]; ++i) {
        NSString *line = [lines objectAtIndex:i];
        NSString *v;
        if ((v = value_for_key(line, @"state="))) {
            report.stateName = v;
            if ([v isEqualToString:@"connected"]) report.status = A6StatusConnected;
            else if ([v isEqualToString:@"connecting"]) report.status = A6StatusConnecting;
            else if ([v isEqualToString:@"idle"]) report.status = A6StatusIdle;
            else report.status = A6StatusError;
        } else if ((v = value_for_key(line, @"uptime="))) {
            report.uptime = strtoull([v UTF8String], NULL, 10);
        } else if ((v = value_for_key(line, @"tx="))) {
            report.txBytes = strtoull([v UTF8String], NULL, 10);
        } else if ((v = value_for_key(line, @"rx="))) {
            report.rxBytes = strtoull([v UTF8String], NULL, 10);
        } else if ((v = value_for_key(line, @"tx_packets="))) {
            report.txPackets = strtoull([v UTF8String], NULL, 10);
        } else if ((v = value_for_key(line, @"rx_packets="))) {
            report.rxPackets = strtoull([v UTF8String], NULL, 10);
        } else if ((v = value_for_key(line, @"endpoint="))) {
            report.endpoint = v;
        } else if ((v = value_for_key(line, @"ifname="))) {
            report.ifname = v;
        } else if ((v = value_for_key(line, @"address="))) {
            report.address = v;
        } else if ((v = value_for_key(line, @"error="))) {
            report.errorText = v;
        }
    }
    return report;
}

- (NSString *)versionString {
    NSString *reply = [self runCommand:@"version"];
    if (!reply) return nil;
    if ([reply hasPrefix:@"OK "]) {
        NSArray *parts = [[reply substringFromIndex:3]
            componentsSeparatedByCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([parts count] > 0) return [parts objectAtIndex:0];
    }
    return nil;
}

- (BOOL)startWithError:(NSString **)error {
    NSString *reply = [self runCommand:@"start"];
    if (!reply) {
        if (error) *error = @"Демон не отвечает. Проверьте, запущен ли amnezia6d.";
        return NO;
    }
    if (![[reply stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@"OK"]) {
        NSString *message = [reply stringByTrimmingCharactersInSet:
                                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (error) *error = [message length] ? message : @"Пустой ответ демона.";
        return NO;
    }
    return YES;
}

- (BOOL)stopWithError:(NSString **)error {
    NSString *reply = [self runCommand:@"stop"];
    if (!reply) {
        if (error) *error = @"Демон не отвечает.";
        return NO;
    }
    if (![[reply stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]] isEqualToString:@"OK"]) {
        NSString *message = [reply stringByTrimmingCharactersInSet:
                                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (error) *error = [message length] ? message : @"Пустой ответ демона.";
        return NO;
    }
    return YES;
}

- (NSString *)logContents {
    NSString *reply = [self runCommand:@"log"];
    if (!reply) return @"";
    return reply;
}

- (BOOL)clearLogWithError:(NSString **)error {
    NSString *reply = [self runCommand:@"logclear"];
    if (!reply || a6_client_reply_is_error([reply UTF8String])) {
        if (error) *error = @"Не удалось очистить журнал.";
        return NO;
    }
    return YES;
}

- (NSString *)configContents {
    NSData *data = [NSData dataWithContentsOfFile:_configPath];
    NSString *text = nil;
    if (data) {
        text = [[[NSString alloc] initWithData:data
                                      encoding:NSUTF8StringEncoding] autorelease];
        if (!text) {
            text = [[[NSString alloc] initWithData:data
                                          encoding:NSISOLatin1StringEncoding] autorelease];
        }
    }
    return text ? text : @"";
}

- (NSString *)configuredEndpoint {
    NSCharacterSet *space = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    BOOL peer = NO;
    NSString *endpoint = nil;
    for (NSString *raw in [[self configContents] componentsSeparatedByString:@"\n"]) {
        NSString *line = [raw stringByTrimmingCharactersInSet:space];
        if (![line length] || [line hasPrefix:@"#"] || [line hasPrefix:@";"]) continue;
        if ([line hasPrefix:@"["]) {
            peer = [line caseInsensitiveCompare:@"[Peer]"] == NSOrderedSame;
            continue;
        }
        NSRange equal = [line rangeOfString:@"="];
        if (!peer || equal.location == NSNotFound) continue;
        NSString *key = [[line substringToIndex:equal.location] stringByTrimmingCharactersInSet:space];
        if ([key caseInsensitiveCompare:@"Endpoint"] == NSOrderedSame)
            endpoint = [[line substringFromIndex:equal.location + 1] stringByTrimmingCharactersInSet:space];
    }
    return [endpoint length] ? endpoint : nil;
}

- (BOOL)saveConfig:(NSString *)text error:(NSString **)error {
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    const char *path = [_configPath UTF8String];
    const char *bytes = (const char *)[data bytes];
    size_t total = (size_t)[data length];
    size_t off = 0;
    int fd;

    if (!data) {
        if (error) *error = @"Не удалось закодировать текст.";
        return NO;
    }
    char *temporary = strdup([[ _configPath stringByAppendingString:@".XXXXXX"] UTF8String]);
    fd = temporary ? mkstemp(temporary) : -1;
    if (fd < 0) {
        if (error)
            *error = [NSString stringWithFormat:@"Не удалось открыть файл: %s",
                                               strerror(errno)];
        free(temporary);
        return NO;
    }
    while (off < total) {
        ssize_t n = write(fd, bytes + off, total - off);
        if (n > 0) { off += (size_t)n; continue; }
        if (n < 0 && errno == EINTR) continue;
        break;
    }
    BOOL saved = off == total && fsync(fd) == 0;
    if (close(fd) != 0) saved = NO;
    if (saved && rename(temporary, path) != 0) saved = NO;
    if (!saved) {
        if (error) *error = @"Не удалось сохранить файл; прежняя конфигурация сохранена.";
        unlink(temporary);
    }
    free(temporary);
    if (!saved) return NO;
    return YES;
}

@end

NSString *A6FormatBytes(unsigned long long bytes) {
    if (bytes < 1024ULL) return [NSString stringWithFormat:@"%llu Б", bytes];
    if (bytes < 1024ULL * 1024ULL)
        return [NSString stringWithFormat:@"%.1f КБ", (double)bytes / 1024.0];
    if (bytes < 1024ULL * 1024ULL * 1024ULL)
        return [NSString stringWithFormat:@"%.1f МБ",
                                          (double)bytes / (1024.0 * 1024.0)];
    return [NSString stringWithFormat:@"%.2f ГБ",
                                      (double)bytes / (1024.0 * 1024.0 * 1024.0)];
}

NSString *A6FormatDuration(unsigned long long seconds) {
    unsigned long long h = seconds / 3600;
    unsigned long long m = (seconds % 3600) / 60;
    unsigned long long s = seconds % 60;
    if (h > 0) return [NSString stringWithFormat:@"%llu:%02llu:%02llu", h, m, s];
    return [NSString stringWithFormat:@"%02llu:%02llu", m, s];
}
