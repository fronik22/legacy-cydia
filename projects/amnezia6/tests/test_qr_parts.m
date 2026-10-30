#import "A6QRParts.h"
#import "A6Import.h"
#include "qr_frame.h"
#include "config.h"
#include "quirc.h"
#include "b64.h"
#include <assert.h>
#include <zlib.h>
static NSString *Frame(NSString *path,BOOL rotated) {
    FILE *f=fopen([path fileSystemRepresentation],"rb");assert(f);int w,h,max;assert(fscanf(f,"P5 %d %d %d",&w,&h,&max)==3&&max==255&&w==h);fgetc(f);
    unsigned char *gray=malloc(w*h),*bgra=malloc((w*4+16)*h);assert(gray&&bgra&&fread(gray,w,h,f)==(size_t)h);fclose(f);memset(bgra,123,(w*4+16)*h);
    for(int y=0;y<h;y++)for(int x=0;x<w;x++){unsigned char v=gray[rotated?(w-1-x)*w+y:y*w+x];unsigned char *p=bgra+y*(w*4+16)+x*4;p[0]=p[1]=p[2]=v;p[3]=255;}
    char text[QUIRC_MAX_PAYLOAD+1];struct quirc *q=quirc_new();assert(q);int n=a6_qr_decode_frame(q,bgra,w,h,w*4+16,4,text,sizeof text);if(n<=0)fprintf(stderr,"decode %s: %d\n",[path UTF8String],n);assert(n>0);
    assert(a6_qr_decode_frame(q,bgra,w,h,1,4,text,sizeof text)==-1);
    memset(bgra,255,(w*4+16)*h);assert(a6_qr_decode_frame(q,bgra,w,h,w*4+16,4,text,sizeof text)==0);quirc_destroy(q);free(gray);free(bgra);
    return [NSString stringWithUTF8String:text];
}
static NSString *EncodeWithPadding(const unsigned char *raw,size_t n,BOOL padding){char encoded[1200];size_t size;assert(!b64_encode(raw,n,encoded,sizeof encoded,&size));if(!padding)while(size&&encoded[size-1]=='=')size--;encoded[size]=0;for(size_t i=0;i<size;i++){if(encoded[i]=='+')encoded[i]='-';else if(encoded[i]=='/')encoded[i]='_';}return[NSString stringWithUTF8String:encoded];}
static NSString *Encode(const unsigned char *raw,size_t n){return EncodeWithPadding(raw,n,NO);}
static NSString *Alter(NSString *text,int offset,unsigned char value){unsigned char raw[858];size_t n=0;assert(!b64_decode([text UTF8String],[text length],raw,sizeof raw,&n));raw[offset]=value;return Encode(raw,n);}
static NSString *OnePart(NSData *data){assert([data length]<=850);unsigned n=(unsigned)[data length];unsigned char raw[858]={7,192,1,0,0,0,(unsigned char)(n>>8),(unsigned char)n};memcpy(raw+8,[data bytes],n);return Encode(raw,n+8);}

static void TwoPartPadding(NSData *fixture){
 NSMutableDictionary *profile=[[NSJSONSerialization JSONObjectWithData:fixture options:NSJSONReadingMutableContainers error:NULL]mutableCopy];assert(profile);
 NSString *padding=[[profile objectForKey:@"qr_test_padding"]copy];assert([padding length]>=1200);
 NSMutableDictionary *awg=[[[profile objectForKey:@"containers"]objectAtIndex:0]objectForKey:@"awg"];
 NSString *last=[awg objectForKey:@"last_config"];NSMutableDictionary *inner=[[NSJSONSerialization JSONObjectWithData:[last dataUsingEncoding:NSUTF8StringEncoding]options:NSJSONReadingMutableContainers error:NULL]mutableCopy];
 [inner setObject:[[inner objectForKey:@"config"]stringByReplacingOccurrencesOfString:@"[Peer]"withString:@"DNS=$PRIMARY_DNS, $SECONDARY_DNS\n[Peer]"]forKey:@"config"];
 [awg setObject:inner forKey:@"last_config"];[inner release];[profile setObject:@"192.0.2.53"forKey:@"dns1"];[profile setObject:@"198.51.100.53"forKey:@"dns2"];
 for(int equals=1;equals<=2;equals++){
  NSData *json=nil;unsigned char compressed[1700];uLongf size=0;BOOL matched=NO;
  for(NSUInteger length=900;length<1200;length++){
   [profile setObject:[padding substringToIndex:length]forKey:@"qr_test_padding"];json=[NSJSONSerialization dataWithJSONObject:profile options:0 error:NULL];assert(json);
   NSUInteger n=[json length];compressed[0]=(n>>24)&255;compressed[1]=(n>>16)&255;compressed[2]=(n>>8)&255;compressed[3]=n&255;
   size=sizeof compressed-4;assert(compress2(compressed+4,&size,[json bytes],n,8)==Z_OK);size+=4;
   if(size>850&&size<=1700&&((size-850+8)%3)==(unsigned)(3-equals)){matched=YES;break;}
  }
  assert(matched);
  for(int padded=0;padded<=1;padded++){
   NSMutableArray *frames=[NSMutableArray array];
   for(unsigned i=0;i<2;i++){
    unsigned n=i?(unsigned)size-850:850;unsigned char raw[858]={7,192,2,(unsigned char)i,0,0,(unsigned char)(n>>8),(unsigned char)n};memcpy(raw+8,compressed+850*i,n);
    [frames addObject:EncodeWithPadding(raw,n+8,padded)];
   }
   A6QRParts *parts=[A6QRParts new];NSString *error=nil;
   assert(![parts consume:[frames objectAtIndex:1]atTime:1 error:&error]&&!error&&[parts received]==1);
   assert(![parts consume:[frames objectAtIndex:1]atTime:2 error:&error]&&!error&&[parts received]==1);
   NSData *result=[parts consume:[frames objectAtIndex:0]atTime:3 error:&error];assert(result&&[result isEqual:json]&&!error);NSString *imported=A6ImportConfig(result,&error);assert(imported);
   a6_config_t cfg;char why[256];assert(!a6_config_parse([imported UTF8String],[imported lengthOfBytesUsingEncoding:NSUTF8StringEncoding],&cfg,why,sizeof why));assert(!strcmp(cfg.dns,"192.0.2.53,198.51.100.53"));a6_config_wipe(&cfg);assert([[[parts diagnostic]objectForKey:@"event"]isEqual:@"complete"]);assert([[[parts diagnostic]objectForKey:@"count"]intValue]==2);
   if(padded)for(NSString *suffix in [NSArray arrayWithObjects:@"=",@"===",@"\n",nil]){
    [parts reset];assert(![parts consume:[[frames objectAtIndex:1]stringByAppendingString:suffix]atTime:4 error:&error]&&error&&![parts received]);
   }
   [parts release];
  }
 }
 [padding release];[profile release];
}

int main(int argc,char **argv){NSAutoreleasePool *pool=[NSAutoreleasePool new];assert(argc==2||argc==3);NSString *base=[NSString stringWithUTF8String:argv[1]];NSMutableArray *frames=[NSMutableArray array];
 for(int i=0;i<4;i++){NSString *frame=Frame([base stringByAppendingPathComponent:[NSString stringWithFormat:@"animated-%d.pgm",i]],i&1);assert(([frame isEqual:[NSString stringWithContentsOfFile:[base stringByAppendingPathComponent:[NSString stringWithFormat:@"animated-%d.txt",i]]encoding:NSUTF8StringEncoding error:NULL]]));[frames addObject:frame];}
 TwoPartPadding([NSData dataWithContentsOfFile:[base stringByAppendingPathComponent:@"animated-profile.json"]]);
 if(argc==3){
  NSString *dnsBase=[NSString stringWithUTF8String:argv[2]];A6QRParts *parts=[A6QRParts new];NSString *error=nil;NSData *data=nil;int order[]={1,1,0};
  for(int i=0;i<3;i++){NSString *frame=Frame([dnsBase stringByAppendingPathComponent:[NSString stringWithFormat:@"animated-%d.pgm",order[i]]],i&1);data=[parts consume:frame atTime:1+i error:&error];assert(!error);if(i<2)assert(!data);}
  assert(data&&[data isEqual:[NSData dataWithContentsOfFile:[dnsBase stringByAppendingPathComponent:@"animated-profile.json"]]]);NSString *imported=A6ImportConfig(data,&error);assert(imported);
  a6_config_t cfg;char why[256];assert(!a6_config_parse([imported UTF8String],[imported lengthOfBytesUsingEncoding:NSUTF8StringEncoding],&cfg,why,sizeof why));assert(!strcmp(cfg.dns,"192.0.2.53,198.51.100.53"));assert(cfg.persistent_keepalive.min==25&&cfg.persistent_keepalive.max==35&&cfg.has_header_protection&&cfg.random_trailers&&cfg.disable_cookies&&cfg.max_handshake_attempts.min==15&&cfg.max_handshake_attempts.max==20&&cfg.keepalive_timeout.min==5&&cfg.keepalive_timeout.max==15);a6_config_wipe(&cfg);[parts release];puts("Official two-part fullAWG3.1 template QR images -> BGRA -> collector -> import -> both DNS resolvers passed");
 }
 A6QRParts *parts=[A6QRParts new];NSString *error=nil;NSData *data=nil;
 int order[]={3,1,1,0,2};for(int i=0;i<5;i++){data=[parts consume:[frames objectAtIndex:order[i]]atTime:10+i error:&error];assert(!error);if(i<4)assert(!data);}
 assert(data&&![parts total]);assert([data isEqual:[NSData dataWithContentsOfFile:[base stringByAppendingPathComponent:@"animated-profile.json"]]]);assert(A6ImportConfig(data,&error));
 assert(![parts consume:[frames objectAtIndex:0]atTime:100 error:&error]&&[parts received]==1);
 assert(![parts consume:[frames objectAtIndex:0]atTime:159 error:&error]&&[parts received]==1);assert([parts expireAtTime:160]&&![parts received]);
 assert(![parts consume:[frames objectAtIndex:1]atTime:200 error:&error]);assert([parts expireAtTime:199]);
 assert(![parts consume:[frames objectAtIndex:0]atTime:300 error:&error]);assert(![parts consume:Alter([frames objectAtIndex:0],9,42)atTime:301 error:&error]&&error&&![parts total]);
 assert(![parts consume:[frames objectAtIndex:0]atTime:310 error:&error]);assert(![parts consume:Alter([frames objectAtIndex:1],2,5)atTime:311 error:&error]&&error&&![parts total]);
 for(NSString *bad in[NSArray arrayWithObjects:@"B8A",@"B8AA",@"B8A!",Alter([frames objectAtIndex:0],2,0),Alter([frames objectAtIndex:0],3,4),Alter([frames objectAtIndex:0],4,255),[[frames objectAtIndex:0]stringByAppendingString:@"AAAA"],[[frames objectAtIndex:0]stringByAppendingString:@"="],[[frames objectAtIndex:0]stringByAppendingString:@"\n"],nil]){assert(![parts consume:bad atTime:400 error:&error]&&error&&![parts total]);}
 assert(![parts consume:[@"B8A" stringByPaddingToLength:1200 withString:@"A" startingAtIndex:0]atTime:400 error:&error]&&error);
 // Missing parts never finish; unrelated static QR cannot interrupt a series.
 assert(![parts consume:[frames objectAtIndex:2]atTime:500 error:&error]);assert(![parts consume:@"vpn://other"atTime:501 error:&error]&&error&&[parts received]==1);[parts reset];
 // A changed, otherwise valid chunk reaches the final checksum and must fail.
 for(int i=0;i<4;i++){data=[parts consume:i==1?Alter([frames objectAtIndex:i],30,42):[frames objectAtIndex:i]atTime:600+i error:&error];assert(!data);}assert(error&&![parts total]);
 for(int i=0;i<4;i++){data=[parts consume:i==0?Alter([frames objectAtIndex:i],8,255):[frames objectAtIndex:i]atTime:650+i error:&error];assert(!data);}assert(error&&![parts total]);
 NSData *staticQR=[parts consume:[NSString stringWithContentsOfFile:[base stringByAppendingPathComponent:@"profile.vpn"]encoding:NSUTF8StringEncoding error:NULL]atTime:700 error:&error];assert(staticQR&&A6ImportConfig(staticQR,&error));
 NSData *json=[NSData dataWithContentsOfFile:[base stringByAppendingPathComponent:@"profile.json"]];assert([[parts consume:OnePart(json)atTime:701 error:&error]isEqual:json]);
 NSString *link=[[[NSString alloc]initWithData:staticQR encoding:NSUTF8StringEncoding]autorelease];NSData *body=[[link substringFromIndex:6]dataUsingEncoding:NSUTF8StringEncoding];unsigned char compressed[850];size_t compressedSize;assert(!b64_decode([body bytes],[body length],compressed,sizeof compressed,&compressedSize));
 NSData *single=[parts consume:OnePart([NSData dataWithBytes:compressed length:compressedSize])atTime:702 error:&error];assert(single&&A6ImportConfig(single,&error));
 [parts release];puts("Animated QR: padded/unpadded two-part compressed tails (=, ==); official four-part QR -> BGRA frames (rotated, padded stride) -> quirc -> assembler -> validated profile; order/repeat/malformed/mixed/checksum/bounds/timeout/static passed");[pool drain];return 0;}
