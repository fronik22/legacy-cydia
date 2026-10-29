#import <Foundation/Foundation.h>
#include <stdint.h>
#include <string.h>
static void Require(BOOL ok,NSString *message){if(!ok)[NSException raise:@"TimezoneValidation" format:@"%@",message];}
static uint32_t LE32(const unsigned char *b){return b[0]|(uint32_t)b[1]<<8|(uint32_t)b[2]<<16|(uint32_t)b[3]<<24;}
static void Put32(NSMutableData *d,NSUInteger at,uint32_t value){unsigned char b[]={value,value>>8,value>>16,value>>24};[d replaceBytesInRange:NSMakeRange(at,4) withBytes:b];}
static NSArray *PackItems(NSData *data){
 const unsigned char *b=data.bytes;NSUInteger size=data.length;Require(size>=32,@"Truncated ICU package");unsigned h=b[0]|b[1]<<8;Require(h>=24&&h%16==0&&h+4<=size&&b[2]==0xda&&b[3]==0x27&&b[8]==0&&b[9]==0&&b[10]==2&&!memcmp(b+12,"CmnD",4)&&b[16]==1,@"Unsupported ICU package header");
 unsigned n=LE32(b+h);Require(n>0&&n<10000&&4+(uint64_t)n*8<=size-h,@"Invalid ICU TOC");NSUInteger table=4+n*8;NSMutableArray *items=[NSMutableArray array];uint32_t firstData=UINT32_MAX,lastData=0;NSMutableSet *names=[NSMutableSet set];
 for(unsigned i=0;i<n;i++){uint32_t no=LE32(b+h+4+i*8),off=LE32(b+h+8+i*8);Require(no>=table&&no<size-h&&off>=table&&off<size-h&&off%16==0&&(!i||off>lastData),@"Invalid ICU item offset");lastData=off;if(off<firstData)firstData=off;
  const unsigned char *end=memchr(b+h+no,0,size-h-no);Require(end!=NULL,@"Unterminated ICU name");NSUInteger len=end-(b+h+no);Require(len>0&&len<512&&no+len<firstData,@"Invalid ICU item name");NSString *name=[[[NSString alloc]initWithBytes:b+h+no length:len encoding:NSASCIIStringEncoding]autorelease];Require(name!=nil&&![names containsObject:name],@"Duplicate/invalid ICU item name");[names addObject:name];[items addObject:[NSDictionary dictionaryWithObjectsAndKeys:name,@"name",[NSNumber numberWithUnsignedInt:off],@"offset",nil]];
 }
 return items;
}
static NSData *RepackICU(NSData *original,NSDictionary *replacements){
 NSArray *items=PackItems(original);const unsigned char *b=original.bytes;NSUInteger h=b[0]|b[1]<<8,n=items.count;NSMutableData *out=[NSMutableData dataWithBytes:b length:h];[out increaseLengthBy:4+n*8];Put32(out,h,(uint32_t)n);NSMutableArray *nameOffsets=[NSMutableArray array];NSMutableSet *used=[NSMutableSet set];
 for(NSDictionary *item in items){[nameOffsets addObject:[NSNumber numberWithUnsignedInteger:out.length-h]];NSData *name=[[item objectForKey:@"name"]dataUsingEncoding:NSASCIIStringEncoding];[out appendData:name];unsigned char zero=0;[out appendBytes:&zero length:1];}
 while(out.length%16)[out increaseLengthBy:1];
 for(NSUInteger i=0;i<n;i++){NSDictionary *item=[items objectAtIndex:i];NSString *name=[item objectForKey:@"name"],*key=[name lastPathComponent];NSData *replacement=[replacements objectForKey:key];Put32(out,h+4+i*8,[[nameOffsets objectAtIndex:i]unsignedIntValue]);Require(out.length-h<UINT32_MAX,@"ICU package too large");Put32(out,h+8+i*8,(uint32_t)(out.length-h));
  if(replacement){const unsigned char *r=replacement.bytes;Require(replacement.length>=24&&r[2]==0xda&&r[3]==0x27&&r[8]==0&&r[9]==0&&r[10]==2&&!memcmp(r+12,"ResB",4)&&r[16]==2,@"Unsupported replacement resource");Require(![used containsObject:key],@"Ambiguous ICU replacement");[out appendData:replacement];[used addObject:key];}
  else{NSUInteger start=[[item objectForKey:@"offset"]unsignedIntValue],end=i+1<n?[[[items objectAtIndex:i+1]objectForKey:@"offset"]unsignedIntValue]:original.length-h;Require(end>start&&end<=original.length-h,@"Invalid ICU item size");[out appendBytes:b+h+start length:end-start];}
  while(out.length%16)[out increaseLengthBy:1];
 }
 Require(used.count==replacements.count,@"Required timezone resources absent from ICU package");PackItems(out);return out;
}
