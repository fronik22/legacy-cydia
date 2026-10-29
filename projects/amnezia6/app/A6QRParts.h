#import <Foundation/Foundation.h>
/* Official Amnezia QDataStream QR series; no profile is saved here. */
@interface A6QRParts : NSObject {
    NSMutableDictionary *_parts;
    NSUInteger _total;
    NSTimeInterval _started;
}
- (NSData *)consume:(NSString *)text atTime:(NSTimeInterval)now error:(NSString **)error;
- (void)reset;
- (BOOL)expireAtTime:(NSTimeInterval)now;
- (NSUInteger)received;
- (NSUInteger)total;
@end
