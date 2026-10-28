#import <Foundation/Foundation.h>

typedef enum {
    A6StatusUnavailable = 0,
    A6StatusIdle,
    A6StatusConnecting,
    A6StatusConnected,
    A6StatusError
} A6Status;

@interface A6StatusReport : NSObject
@property (nonatomic, assign) A6Status status;
@property (nonatomic, copy) NSString *stateName;
@property (nonatomic, assign) unsigned long long uptime;
@property (nonatomic, assign) unsigned long long txBytes;
@property (nonatomic, assign) unsigned long long rxBytes;
@property (nonatomic, assign) unsigned long long txPackets;
@property (nonatomic, assign) unsigned long long rxPackets;
@property (nonatomic, copy) NSString *endpoint;
@property (nonatomic, copy) NSString *ifname;
@property (nonatomic, copy) NSString *address;
@property (nonatomic, copy) NSString *errorText;
@end

/*
 * Thin Objective-C wrapper around the C control client. Every call is
 * synchronous and expected to run off the main thread.
 */
@interface A6Daemon : NSObject

+ (A6Daemon *)shared;

@property (nonatomic, copy) NSString *socketPath;
@property (nonatomic, copy) NSString *configPath;
@property (nonatomic, copy) NSString *logPath;

- (BOOL)isReachable;
- (NSString *)runCommand:(NSString *)command;
- (A6StatusReport *)statusReport;
- (NSString *)versionString;
- (BOOL)startWithError:(NSString **)error;
- (BOOL)stopWithError:(NSString **)error;
- (NSString *)logContents;
- (BOOL)clearLogWithError:(NSString **)error;

- (NSString *)configContents;
- (NSString *)configuredEndpoint;
- (BOOL)saveConfig:(NSString *)text error:(NSString **)error;

@end

/* Human readable helpers shared by the controllers. */
NSString *A6FormatBytes(unsigned long long bytes);
NSString *A6FormatDuration(unsigned long long seconds);
