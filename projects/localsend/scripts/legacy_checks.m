#import "LSLegacy.h"
#import "LSReceiver.h"
#import "LSTransport.h"
#import "LSDesign.h"
#import <assert.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>
@interface LSLayoutCheck : NSObject
@property(nonatomic) NSUInteger calls;
@end
@implementation LSLayoutCheck
- (void)layoutInterface { self.calls++; }
@end
static int selftest(void) {
    puts("stage weak");
    __weak NSObject *weak;
    @autoreleasepool { NSObject *value=[NSObject new];weak=value;assert(weak==value); }
    assert(weak==nil);
    puts("stage JSON");
    NSDictionary *value=@{@"unicode":@"Привет 🌍",@"array":@[@YES,[NSNull null],@42]};
    NSError *error=nil;NSData *json=[NSJSONSerialization dataWithJSONObject:value options:0 error:&error];
    assert(json && !error && [[NSJSONSerialization JSONObjectWithData:json options:0 error:&error] isEqual:value]);
    assert(![NSJSONSerialization JSONObjectWithData:[@"{broken" dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error]);
    NSMutableDictionary *mutable=[NSJSONSerialization JSONObjectWithData:json options:NSJSONReadingMutableContainers error:nil];mutable[@"extra"]=@3;assert([mutable[@"extra"] intValue]==3);
    puts("stage legacy asset API");
    assert([ALAssetRepresentation instancesRespondToSelector:@selector(url)]);
    assert([ALAssetRepresentation instancesRespondToSelector:@selector(getBytes:fromOffset:length:error:)]);
    CFStringRef jpg=UTTypeCopyPreferredTagWithClass(CFSTR("public.jpeg"),kUTTagClassFilenameExtension);
    CFStringRef mov=UTTypeCopyPreferredTagWithClass(CFSTR("com.apple.quicktime-movie"),kUTTagClassFilenameExtension);
    assert(jpg && ([(__bridge NSString *)jpg isEqual:@"jpeg"] || [(__bridge NSString *)jpg isEqual:@"jpg"]));
    assert(mov && [(__bridge NSString *)mov isEqual:@"mov"]);CFRelease(jpg);CFRelease(mov);
    puts("stage UUID/response");
    NSString *a=LSUUIDString(),*b=LSUUIDString();assert(a.length==36 && b.length==36 && ![a isEqual:b]);
    NSHTTPURLResponse *response=LSLegacyHTTPResponse([NSURL URLWithString:@"https://127.0.0.1/"],206,@"HTTP/1.1",@{@"content-type":@"text/plain; charset=utf-8",@"CONTENT-LENGTH":@"12"});
    assert(response.statusCode==206 && response.expectedContentLength==12 && [response.MIMEType isEqual:@"text/plain"] && [response.textEncodingName isEqual:@"utf-8"]);
    puts("PASS weak lifetime, JSON Unicode/roundtrip/mutable/malformed, UUID and HTTP response");return 0;
}

static int sendfile(int argc,char **argv) {
    if(argc!=5)return 2;
    NSString *base=[NSString stringWithUTF8String:argv[2]],*pin=[NSString stringWithUTF8String:argv[3]];
    NSData *payload=[NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[4]]];assert(payload);
    NSDictionary *metadata=@{@"info":@{@"alias":@"Native client"},@"files":@{@"id":@{@"id":@"id",@"fileName":@"Native.bin",@"size":@(payload.length),@"fileType":@"application/octet-stream"}}};
    NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:[base stringByAppendingString:@"/prepare-upload"]]];r.HTTPMethod=@"POST";r.HTTPBody=[NSJSONSerialization dataWithJSONObject:metadata options:0 error:nil];
    NSURLResponse *response=nil;NSError *error=nil;NSData *answer=LSHTTPSRequest(r,pin,&response,&error);
    if(!answer || [(NSHTTPURLResponse *)response statusCode]!=200){fprintf(stderr,"prepare: %s\n",error.description.UTF8String);return 1;}
    NSDictionary *session=[NSJSONSerialization JSONObjectWithData:answer options:0 error:nil];
    r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/upload?sessionId=%@&fileId=id&token=%@",base,session[@"sessionId"],session[@"files"][@"id"]]]];r.HTTPMethod=@"POST";r.HTTPBody=payload;
    answer=LSHTTPSRequest(r,pin,&response,&error);if(!answer || [(NSHTTPURLResponse *)response statusCode]!=200){fprintf(stderr,"upload: %s\n",error.description.UTF8String);return 1;}
    puts("PASS native pinned HTTPS sender, cached identity and uploaded file");return 0;
}
int main(int argc,char **argv) { setbuf(stdout,NULL); @autoreleasepool {
    if(argc==2 && !strcmp(argv[1],"selftest"))return selftest();
    if(argc>1 && !strcmp(argv[1],"send"))return sendfile(argc,argv);
    if(argc!=4 || strcmp(argv[1],"receiver"))return 2;
    LSReceiver *receiver=[LSReceiver new];receiver.port=atoi(argv[3]);receiver.alias=@"Test iPad";receiver.documentsPath=[NSString stringWithUTF8String:argv[2]];
    receiver.eventHandler=^(NSDictionary *state){if([state[@"phase"] isEqual:@"offer"]){NSString *sender=state[@"sender"];if([sender isEqual:@"Wait"])return;[receiver respond:![sender isEqual:@"Decline"]];}};
    [receiver start:^(NSError *error){if(error){fprintf(stderr,"%s\n",error.description.UTF8String);exit(1);}NSData *data=[NSJSONSerialization dataWithJSONObject:[receiver deviceInfo] options:0 error:nil];puts([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding].UTF8String);fflush(stdout);}];
    [[NSRunLoop currentRunLoop] run];return 0;
} }
