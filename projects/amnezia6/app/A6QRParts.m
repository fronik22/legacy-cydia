#import "A6QRParts.h"
#include "b64.h"
#include <zlib.h>
static uint32_t BE32(const unsigned char *p) {return ((uint32_t)p[0]<<24)|((uint32_t)p[1]<<16)|((uint32_t)p[2]<<8)|p[3];}
@implementation A6QRParts
- (id)init {if((self=[super init]))_parts=[NSMutableDictionary new];return self;}
- (void)dealloc {[self reset];[_parts release];[super dealloc];}
- (void)reset {[_parts removeAllObjects];_total=0;_started=0;}
- (BOOL)expireAtTime:(NSTimeInterval)now {if(_total&&(now<_started||now-_started>=60)){[self reset];return YES;}return NO;}
- (NSUInteger)received {return [_parts count];}
- (NSUInteger)total {return _total;}
- (NSData *)consume:(NSString *)text atTime:(NSTimeInterval)now error:(NSString **)error {
    if(error)*error=nil;
    if([self expireAtTime:now]&&error)*error=@"Время сборки QR истекло. Сканируйте заново.";
    NSData *utf8=[text dataUsingEncoding:NSUTF8StringEncoding];
    if(![utf8 length]||[utf8 length]>768*1024){if(error)*error=@"QR пуст или слишком велик";return nil;}
    unsigned char raw[858];size_t n=0;
    BOOL multipart=[text hasPrefix:@"B8"];
    if([utf8 length]<=1144&&!b64_decode([utf8 bytes],[utf8 length],raw,sizeof raw,&n)&&n>=2&&raw[0]==7&&raw[1]==192)multipart=YES;
    if(!multipart){if(_total){if(error)*error=@"Показывайте только один динамический QR";return nil;}return utf8;}
    char encoded[1145];size_t encodedLength=0;BOOL canonical=NO;
    if(n&&!b64_encode(raw,n,encoded,sizeof encoded,&encodedLength)){
        while(encodedLength&&encoded[encodedLength-1]=='=')encodedLength--;
        for(size_t i=0;i<encodedLength;i++){if(encoded[i]=='+')encoded[i]='-';else if(encoded[i]=='/')encoded[i]='_';}
        canonical=encodedLength==[utf8 length]&&!memcmp(encoded,[utf8 bytes],encodedLength);
    }
    if(!canonical||n<9||raw[0]!=7||raw[1]!=192||!raw[2]||raw[3]>=raw[2]||BE32(raw+4)!=n-8||n-8>850||(raw[3]+1<raw[2]&&n-8!=850)){
        if(error)*error=@"Повреждённая часть QR";return nil;
    }
    /* shortcut: upstream has no series ID; conflicts reset, zlib checks the completed stream. Scan one sender at a time. */
    NSNumber *index=[NSNumber numberWithUnsignedInt:raw[3]];NSData *part=[NSData dataWithBytes:raw+8 length:n-8];
    NSData *old=[_parts objectForKey:index];
    if((_total&&_total!=raw[2])||(old&&![old isEqual:part])){
        [self reset];if(error)*error=@"QR изменился. Сканируйте один код заново.";return nil;
    }
    if(!_total){_total=raw[2];_started=now;}
    [_parts setObject:part forKey:index];
    if([_parts count]!=_total)return nil;
    NSMutableData *joined=[NSMutableData dataWithCapacity:_total*850];
    for(NSUInteger i=0;i<_total;i++)[joined appendData:[_parts objectForKey:[NSNumber numberWithUnsignedInteger:i]]];
    const unsigned char *p=[joined bytes];NSUInteger length=[joined length];NSData *result=nil;
    if(length&&p[0]=='{')result=[[joined copy]autorelease];
    else if(length>=6){
        uint32_t declared=BE32(p);
        if(declared&&declared<=768*1024){
            NSMutableData *plain=[NSMutableData dataWithLength:declared];z_stream stream;memset(&stream,0,sizeof stream);
            stream.next_in=(Bytef *)p+4;stream.avail_in=(uInt)length-4;stream.next_out=[plain mutableBytes];stream.avail_out=declared;
            if(inflateInit(&stream)==Z_OK){int status=inflate(&stream,Z_FINISH);
                if(status==Z_STREAM_END&&stream.total_out==declared&&stream.avail_in==0)result=plain;
                inflateEnd(&stream);
            }
        }
    }
    [self reset];if(!result&&error)*error=@"QR повреждён или содержит части разных профилей. Сканируйте заново.";
    return result;
}
@end
