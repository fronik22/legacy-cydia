#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "YTLegacy.h"

@interface YTLegacyHTTPURLResponse : NSHTTPURLResponse
@property(nonatomic,copy) NSDictionary *legacyHeaders;
@property(nonatomic) NSInteger legacyStatus;
@end
@implementation YTLegacyHTTPURLResponse
- (NSDictionary *)allHeaderFields { return _legacyHeaders; }
- (NSInteger)statusCode { return _legacyStatus; }
@end

NSHTTPURLResponse *YTLegacyHTTPResponse(NSURL *url, NSInteger status, NSString *version, NSDictionary *headers) {
    if ([NSHTTPURLResponse instancesRespondToSelector:@selector(initWithURL:statusCode:HTTPVersion:headerFields:)])
        return [[NSHTTPURLResponse alloc] initWithURL:url statusCode:status HTTPVersion:version headerFields:headers];
    // The HTTP response initializer was added in iOS 5.
    NSString *type=nil, *encoding=nil;
    long long length=-1;
    for (NSString *key in headers) {
        NSString *name=[key lowercaseString];
        if ([name isEqual:@"content-length"]) length=[[headers objectForKey:key] longLongValue];
        if ([name isEqual:@"content-type"]) {
            NSArray *parts=[[headers objectForKey:key] componentsSeparatedByString:@";"];
            type=[[parts objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            for (NSString *part in parts) {
                NSRange match=[part rangeOfString:@"charset=" options:NSCaseInsensitiveSearch];
                if (match.location!=NSNotFound)
                    encoding=[[part substringFromIndex:NSMaxRange(match)] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" \t\"'"]];
            }
        }
    }
    YTLegacyHTTPURLResponse *response=[[YTLegacyHTTPURLResponse alloc] initWithURL:url MIMEType:type expectedContentLength:length textEncodingName:encoding];
    response.legacyStatus=status;
    response.legacyHeaders=headers;
    return response;
}
static id firstObject(NSArray *array,SEL selector) { return [array count] ? [array objectAtIndex:0] : nil; }
__attribute__((constructor)) static void installArrayCompatibility(void) {
    if (![NSArray instancesRespondToSelector:@selector(firstObject)])
        class_addMethod([NSArray class],@selector(firstObject),(IMP)firstObject,"@@:");
}
