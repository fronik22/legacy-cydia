#import "A6QRParts.h"
#import "A6Import.h"
#include "qr_frame.h"
#include "quirc.h"
#include "b64.h"
#include <assert.h>
static NSString *Frame(NSString *path,BOOL rotated) {
    FILE *f=fopen([path fileSystemRepresentation],"rb");assert(f);int w,h,max;assert(fscanf(f,"P5 %d %d %d",&w,&h,&max)==3&&max==255&&w==h);fgetc(f);
    unsigned char *gray=malloc(w*h),*bgra=malloc((w*4+16)*h);assert(gray&&bgra&&fread(gray,w,h,f)==(size_t)h);fclose(f);memset(bgra,123,(w*4+16)*h);
    for(int y=0;y<h;y++)for(int x=0;x<w;x++){unsigned char v=gray[rotated?(w-1-x)*w+y:y*w+x];unsigned char *p=bgra+y*(w*4+16)+x*4;p[0]=p[1]=p[2]=v;p[3]=255;}
    char text[QUIRC_MAX_PAYLOAD+1];struct quirc *q=quirc_new();assert(q);int n=a6_qr_decode_frame(q,bgra,w,h,w*4+16,4,text,sizeof text);if(n<=0)fprintf(stderr,"decode %s: %d\n",[path UTF8String],n);assert(n>0);
    assert(a6_qr_decode_frame(q,bgra,w,h,1,4,text,sizeof text)==-1);
    memset(bgra,255,(w*4+16)*h);assert(a6_qr_decode_frame(q,bgra,w,h,w*4+16,4,text,sizeof text)==0);quirc_destroy(q);free(gray);free(bgra);
    return [NSString stringWithUTF8String:text];
}
static NSString *Encode(const unsigned char *raw,size_t n){char encoded[1200];size_t size;assert(!b64_encode(raw,n,encoded,sizeof encoded,&size));while(size&&encoded[size-1]=='=')size--;encoded[size]=0;for(size_t i=0;i<size;i++){if(encoded[i]=='+')encoded[i]='-';else if(encoded[i]=='/')encoded[i]='_';}return[NSString stringWithUTF8String:encoded];}
static NSString *Alter(NSString *text,int offset,unsigned char value){unsigned char raw[858];size_t n=0;assert(!b64_decode([text UTF8String],[text length],raw,sizeof raw,&n));raw[offset]=value;return Encode(raw,n);}
static NSString *OnePart(NSData *data){assert([data length]<=850);unsigned n=(unsigned)[data length];unsigned char raw[858]={7,192,1,0,0,0,(unsigned char)(n>>8),(unsigned char)n};memcpy(raw+8,[data bytes],n);return Encode(raw,n+8);}

int main(int argc,char **argv){NSAutoreleasePool *pool=[NSAutoreleasePool new];assert(argc==2);NSString *base=[NSString stringWithUTF8String:argv[1]];NSMutableArray *frames=[NSMutableArray array];
 for(int i=0;i<4;i++){NSString *frame=Frame([base stringByAppendingPathComponent:[NSString stringWithFormat:@"animated-%d.pgm",i]],i&1);assert(([frame isEqual:[NSString stringWithContentsOfFile:[base stringByAppendingPathComponent:[NSString stringWithFormat:@"animated-%d.txt",i]]encoding:NSUTF8StringEncoding error:NULL]]));[frames addObject:frame];}
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
 [parts release];puts("Animated QR: official four-part QR -> BGRA frames (rotated, padded stride) -> quirc -> assembler -> validated profile; order/repeat/malformed/mixed/checksum/bounds/timeout/static passed");[pool drain];return 0;}
