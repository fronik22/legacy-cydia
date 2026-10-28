#import <Foundation/Foundation.h>
#include <string.h>
#include <assert.h>
#include <stdio.h>
#import <UIKit/UIKit.h>
#import "YTLegacy.h"
#import "YTNowPlaying.h"
#import <AVFoundation/AVFoundation.h>

int __isPlatformVersionAtLeast(unsigned platform,unsigned major,unsigned minor,unsigned patch) {
    if (platform!=2) return 0;
    return major<4 || (major==4 && (minor<3 || (minor==3 && patch<=3)));
}

int YTLegacySelfTest(void) {
    __weak NSObject *weak=nil;
    @autoreleasepool { NSObject *target=[NSObject new];weak=target;assert(weak==target); }
    assert(weak==nil);
    NSError *error=nil;
    NSDictionary *value=@{@"text":@"тест 🎵",@"items":@[@1,[NSNull null],@YES]};
    NSData *json=[NSJSONSerialization dataWithJSONObject:value options:0 error:&error];
    assert(json && !error);
    assert([[NSJSONSerialization JSONObjectWithData:json options:0 error:&error] isEqual:value]);
    assert(![NSJSONSerialization JSONObjectWithData:[@"{bad" dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error]);
    assert([@[@1] firstObject]!=nil && [@[] firstObject]==nil);
    NSURL *url=[NSURL URLWithString:@"https://example.com/test"];
    NSHTTPURLResponse *response=YTLegacyHTTPResponse(url,206,@"HTTP/1.1",@{@"Content-Type":@"text/plain; charset=\"utf-8\"",@"Content-Length":@"12"});
    assert([response isKindOfClass:[NSHTTPURLResponse class]] && response.statusCode==206);
    assert([response.URL isEqual:url] && [response.MIMEType isEqual:@"text/plain"] && response.expectedContentLength==12);
    assert([response.textEncodingName isEqual:@"utf-8"] && response.allHeaderFields.count==2);
    response=YTLegacyHTTPResponse(url,204,@"HTTP/1.1",@{});
    assert(response.statusCode==204 && response.expectedContentLength==-1);
    printf("PASS legacy HTTP response status/headers/URL/MIME/charset/length\n");
    AVPlayer *player=[AVPlayer playerWithPlayerItem:nil];
    assert(player);
    [YTNowPlaying showTitle:@"Compatibility test" channel:@"Test" artwork:nil player:player duration:10];
    [YTNowPlaying refreshWithPlayer:player duration:10];
    [YTNowPlaying clear];
    printf("PASS Now Playing on the target OS\n");
    printf("PASS weak lifetime, JSON Unicode/roundtrip/rejection, firstObject\n");
    printf("HTTP response initializer=%d; presentViewController=%d; dismissViewController=%d\n",
        [NSHTTPURLResponse instancesRespondToSelector:@selector(initWithURL:statusCode:HTTPVersion:headerFields:)],
        [UIViewController instancesRespondToSelector:@selector(presentViewController:animated:completion:)],
        [UIViewController instancesRespondToSelector:@selector(dismissViewControllerAnimated:completion:)]);
    return 0;
}
