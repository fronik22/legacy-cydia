#import "LSLegacy.h"
#import "JSONKit.h"
@implementation LSLegacyJSONSerialization
+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)options error:(NSError **)error {
    if (!data) { if(error)*error=[NSError errorWithDomain:NSCocoaErrorDomain code:3840 userInfo:nil];return nil; }
    return options & NSJSONReadingMutableContainers
        ? [data mutableObjectFromJSONDataWithParseOptions:JKParseOptionStrict error:error]
        : [data objectFromJSONDataWithParseOptions:JKParseOptionStrict error:error];
}
+ (NSData *)dataWithJSONObject:(id)object options:(NSJSONWritingOptions)options error:(NSError **)error {
    if (![object isKindOfClass:[NSArray class]] && ![object isKindOfClass:[NSDictionary class]]) {
        if(error)*error=[NSError errorWithDomain:NSCocoaErrorDomain code:3840 userInfo:nil];return nil;
    }
    return [object JSONDataWithOptions:(options & NSJSONWritingPrettyPrinted) ? JKSerializeOptionPretty : JKSerializeOptionNone error:error];
}
@end
