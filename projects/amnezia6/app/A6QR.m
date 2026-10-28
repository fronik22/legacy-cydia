#import "A6QR.h"
#include "quirc.h"
NSString *A6DecodeQR(UIImage *image, NSString **error) {
    CGImageRef source=image.CGImage;
    size_t w=source?CGImageGetWidth(source):0,h=source?CGImageGetHeight(source):0;
    if(!w||!h){if(error)*error=@"Не удалось прочитать изображение";return nil;}
    double scale=MIN(1.0,2048.0/MAX(w,h));w=MAX(1,(size_t)(w*scale));h=MAX(1,(size_t)(h*scale));
    struct quirc *decoder=quirc_new();
    if(!decoder||quirc_resize(decoder,(int)w,(int)h)){if(decoder)quirc_destroy(decoder);if(error)*error=@"Недостаточно памяти для QR";return nil;}
    uint8_t *pixels=quirc_begin(decoder,NULL,NULL);CGColorSpaceRef gray=CGColorSpaceCreateDeviceGray();
    CGContextRef ctx=CGBitmapContextCreate(pixels,w,h,8,w,gray,kCGImageAlphaNone);CGColorSpaceRelease(gray);
    if(!ctx){quirc_destroy(decoder);if(error)*error=@"Ошибка чтения QR";return nil;}
    CGContextSetInterpolationQuality(ctx,kCGInterpolationHigh);CGContextTranslateCTM(ctx,0,h);CGContextScaleCTM(ctx,1,-1);
    CGContextDrawImage(ctx,CGRectMake(0,0,w,h),source);CGContextRelease(ctx);quirc_end(decoder);
    NSString *result=nil;int decoded=0;
    struct quirc_code *code=malloc(sizeof *code);struct quirc_data *data=malloc(sizeof *data);
    if(code&&data)for(int i=0;i<quirc_count(decoder);i++){
        quirc_extract(decoder,i,code);quirc_decode_error_t status=quirc_decode(code,data);
        if(status==QUIRC_ERROR_DATA_ECC){quirc_flip(code);status=quirc_decode(code,data);}
        if(status||data->payload_len<=0||memchr(data->payload,0,data->payload_len))continue;
        NSString *text=[[[NSString alloc]initWithBytes:data->payload length:data->payload_len encoding:NSUTF8StringEncoding]autorelease];
        if(text){result=text;decoded++;}
    }
    if(data){memset(data,0,sizeof *data);free(data);}if(code){memset(code,0,sizeof *code);free(code);}quirc_destroy(decoder);
    if(decoded!=1){if(error)*error=decoded>1?@"На изображении несколько QR. Оставьте один.":@"QR не найден. Снимите код крупнее и без бликов.";return nil;}
    return result;
}
