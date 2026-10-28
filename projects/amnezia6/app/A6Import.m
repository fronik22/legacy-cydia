#import "A6Import.h"
#include "amnezia_bundle.h"
#include "config.h"
NSString *A6ImportConfig(NSData *data, NSString **error) {
    if(![data length]||[data length]>768*1024){if(error)*error=@"Файл пуст или превышает 768 КБ";return nil;}
    NSString *text=[[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]autorelease];
    if(!text){if(error)*error=@"Нужен текстовый профиль UTF-8";return nil;}
    text=[text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if([text hasPrefix:@"\ufeff"])text=[text substringFromIndex:1];
    NSData *input=[text dataUsingEncoding:NSUTF8StringEncoding];
    if(![text hasPrefix:@"[Interface]"]&&![text hasPrefix:@"#"]&&![text hasPrefix:@";"]){
        char *buffer=malloc(131073);char why[256]={0};size_t length=0;
        amz_status_t status=buffer?amz_bundle_extract_conf([input bytes],[input length],buffer,131073,&length,why,sizeof why):AMZ_ERR_SPACE;
        if(status==AMZ_OK)text=[[[NSString alloc]initWithBytes:buffer length:length encoding:NSUTF8StringEncoding]autorelease];
        else if(status!=AMZ_ERR_NOT_BUNDLE){if(error)*error=[NSString stringWithFormat:@"Импорт Amnezia: %s",why[0]?why:"некорректный профиль"];free(buffer);return nil;}
        if(buffer){memset(buffer,0,131073);free(buffer);}
    }
    NSData *plain=[text dataUsingEncoding:NSUTF8StringEncoding];a6_config_t cfg;char why[256];
    if(!plain||a6_config_parse([plain bytes],[plain length],&cfg,why,sizeof why)){
        if(error)*error=plain?[NSString stringWithUTF8String:why]:@"Некорректный текст";return nil;
    }
    a6_config_wipe(&cfg);return [text stringByAppendingString:[text hasSuffix:@"\n"]?@"":@"\n"];
}
