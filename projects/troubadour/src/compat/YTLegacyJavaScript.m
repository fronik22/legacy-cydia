#import "YTLegacy.h"
#import <JavaScriptCore/JavaScript.h>
#include <dlfcn.h>

#import <JavaScriptCore/JSStringRefCF.h>

NSString *YTLegacyAdaptJavaScript(NSString *player) {
    if (![player length]) return nil;
    static void *library;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ library=dlopen("/System/Library/PrivateFrameworks/JavaScriptCore.framework/JavaScriptCore",RTLD_NOW); });
    if (!library) return nil;
#define API(name) __typeof__(&name) api##name=dlsym(library,#name); if (!api##name) return nil
    API(JSGlobalContextCreate);API(JSGlobalContextRelease);
    API(JSStringCreateWithCFString);API(JSStringCopyCFString);API(JSStringRelease);
    API(JSEvaluateScript);API(JSValueToStringCopy);
#undef API
    NSString *path=[[NSBundle mainBundle] pathForResource:@"legacy-es3" ofType:@"js"];
    NSString *helper=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    if (!helper || !player) return nil;
    NSData *json=[NSJSONSerialization dataWithJSONObject:@[player] options:0 error:NULL];
    NSString *argument=[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    argument=[[argument stringByReplacingOccurrencesOfString:@"\u2028" withString:@"\\u2028"]
        stringByReplacingOccurrencesOfString:@"\u2029" withString:@"\\u2029"];
    NSString *code=[helper stringByAppendingFormat:@"\n(function(){var s=YTLegacyPlayerScript(%@[0]);Function(s);return s;}());",argument];
    JSGlobalContextRef context=apiJSGlobalContextCreate(NULL);
    if (!context) return nil;
    JSStringRef script=apiJSStringCreateWithCFString((__bridge CFStringRef)code);
    JSValueRef exception=NULL;
    JSValueRef value=apiJSEvaluateScript(context,script,NULL,NULL,1,&exception);
    apiJSStringRelease(script);
    JSStringRef result=value && !exception ? apiJSValueToStringCopy(context,value,&exception) : NULL;
    NSString *text=result && !exception ? CFBridgingRelease(apiJSStringCopyCFString(kCFAllocatorDefault,result)) : nil;
    if (result) apiJSStringRelease(result);
    if (exception) {
        JSStringRef message=apiJSValueToStringCopy(context,exception,NULL);
        if (message) {
            NSLog(@"[Troubadour/JS] %@",CFBridgingRelease(apiJSStringCopyCFString(kCFAllocatorDefault,message)));
            apiJSStringRelease(message);
        }
    }
    apiJSGlobalContextRelease(context);
    return text;
}

NSData *YTLegacyAdaptPlayer(NSData *data) {
    if (![data length]) return nil;
    // Preserve the byte-to-character mapping used by the solver's atob().
    NSString *player=[[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    return [YTLegacyAdaptJavaScript(player) dataUsingEncoding:NSISOLatin1StringEncoding];
}
