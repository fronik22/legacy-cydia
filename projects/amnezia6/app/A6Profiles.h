#import <Foundation/Foundation.h>
@class A6Daemon;
@interface A6Profiles : NSObject {
    A6Daemon *_daemon;
    NSMutableDictionary *_state;
    NSString *_path;
    NSString *_loadError;
    NSLock *_stateLock;
}
+ (A6Profiles *)shared;
- (id)initWithDaemon:(A6Daemon *)daemon;
- (NSArray *)profiles;
- (NSString *)activeIdentifier;
- (NSDictionary *)profile:(NSString *)identifier;
- (NSString *)loadError;
- (NSString *)saveName:(NSString *)name config:(NSString *)config identifier:(NSString *)identifier error:(NSString **)error;
- (BOOL)activate:(NSString *)identifier error:(NSString **)error;
- (BOOL)remove:(NSString *)identifier error:(NSString **)error;
@end
