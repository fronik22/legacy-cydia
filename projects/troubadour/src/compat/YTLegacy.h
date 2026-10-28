#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <Security/SecureTransport.h>
SSLContextRef YTLegacyCreateTLSContext(void);
void YTLegacyReleaseTLSContext(SSLContextRef context);
NSHTTPURLResponse *YTLegacyHTTPResponse(NSURL *url, NSInteger status, NSString *version, NSDictionary *headers);
@interface YTLegacyJSONSerialization : NSObject
+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)options error:(NSError **)error;
+ (NSData *)dataWithJSONObject:(id)object options:(NSJSONWritingOptions)options error:(NSError **)error;
@end
NSString *YTLegacyAdaptJavaScript(NSString *source);
NSData *YTLegacyAdaptPlayer(NSData *data);
#define NSJSONSerialization YTLegacyJSONSerialization
#endif
