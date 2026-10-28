#import "A6Profiles.h"
#import "A6Daemon.h"
#import "config.h"
#import <dispatch/dispatch.h>
#include <sys/stat.h>

static BOOL Fail(NSString **error, NSString *message) { if (error) *error=message; return NO; }
static NSString *Endpoint(NSString *text, NSString **error) {
    NSData *data=[text dataUsingEncoding:NSUTF8StringEncoding]; a6_config_t cfg; char why[256];
    if (!data || a6_config_parse([data bytes],[data length],&cfg,why,sizeof why)) {
        if(error)*error=data?[NSString stringWithUTF8String:why]:@"Некорректный текст"; return nil;
    }
    NSString *result=[NSString stringWithFormat:@"%s:%u",cfg.endpoint_host,cfg.endpoint_port];
    a6_config_wipe(&cfg); return result;
}
@interface A6Profiles ()
- (BOOL)writeState:(NSDictionary *)state error:(NSString **)error;
- (BOOL)commit:(NSMutableDictionary *)next error:(NSString **)error;
@end
@implementation A6Profiles
+ (A6Profiles *)shared { static A6Profiles *store; if(!store)store=[[self alloc]initWithDaemon:[A6Daemon shared]]; return store; }
- (id)initWithDaemon:(A6Daemon *)daemon {
    if (!(self=[super init])) return nil;
    _daemon=[daemon retain];_stateLock=[NSLock new];
    NSString *directory=[daemon.configPath stringByDeletingLastPathComponent];
    _path=[[directory stringByAppendingPathComponent:@"profiles.plist"]copy];
    NSError *failure=nil;
    if(![[NSFileManager defaultManager]createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0700]forKey:NSFilePosixPermissions] error:&failure])
        _loadError=[[failure localizedDescription]copy];
    chmod([directory fileSystemRepresentation],0700);
    NSDictionary *saved=nil;
    if([[NSFileManager defaultManager]fileExistsAtPath:_path]) {
        NSDictionary *attrs=[[NSFileManager defaultManager]attributesOfItemAtPath:_path error:NULL];
        if([[attrs objectForKey:NSFileType]isEqual:NSFileTypeRegular]&&[[attrs objectForKey:NSFileSize]unsignedLongLongValue]<=4*1024*1024)
            saved=[NSDictionary dictionaryWithContentsOfFile:_path];
        BOOL valid=[saved isKindOfClass:[NSDictionary class]]&&[[saved objectForKey:@"profiles"]isKindOfClass:[NSArray class]]&&[[saved objectForKey:@"active"]isKindOfClass:[NSString class]];
        NSMutableSet *ids=[NSMutableSet set];
        if(valid)for(id row in[saved objectForKey:@"profiles"]) {
            if(![row isKindOfClass:[NSDictionary class]]){valid=NO;break;}
            for(NSString *key in[NSArray arrayWithObjects:@"id",@"name",@"config",@"endpoint",nil])
                if(![[row objectForKey:key]isKindOfClass:[NSString class]])valid=NO;
            if(!valid||[ids containsObject:[row objectForKey:@"id"]]){valid=NO;break;}[ids addObject:[row objectForKey:@"id"]];
        }
        if(valid&&[[saved objectForKey:@"active"]length]&&![ids containsObject:[saved objectForKey:@"active"]])valid=NO;
        if(!valid){[_loadError release];_loadError=[@"Хранилище профилей повреждено. Исходный файл сохранён."copy];}
    }
    _state=[(saved&&!_loadError?saved:[NSDictionary dictionaryWithObjectsAndKeys:[NSArray array],@"profiles",@"",@"active",nil])mutableCopy];
    if(!saved&&!_loadError) {
        NSString *text=[daemon configContents];NSString *endpoint=Endpoint(text,NULL);
        if(endpoint) {
            CFUUIDRef uuid=CFUUIDCreate(NULL);NSString *identifier=[(NSString *)CFUUIDCreateString(NULL,uuid)autorelease];CFRelease(uuid);
            NSDictionary *row=[NSDictionary dictionaryWithObjectsAndKeys:identifier,@"id",endpoint,@"name",text,@"config",endpoint,@"endpoint",nil];
            [_state setObject:[NSArray arrayWithObject:row]forKey:@"profiles"];[_state setObject:identifier forKey:@"active"];
            NSString *why=nil;if(![self writeState:_state error:&why])_loadError=[why copy];
        }
    }
    /* Recover a crash between the two atomic writes without discarding either profile. */
    if(saved&&!_loadError) {
        NSString *current=[daemon configContents];NSString *endpoint=Endpoint(current,NULL);
        if(endpoint) {
            NSString *match=nil;
            for(NSDictionary *row in[self profiles])if([[row objectForKey:@"config"]isEqual:current])match=[row objectForKey:@"id"];
            if(!match){
                CFUUIDRef uuid=CFUUIDCreate(NULL);match=[(NSString *)CFUUIDCreateString(NULL,uuid)autorelease];CFRelease(uuid);
                NSMutableArray *rows=[NSMutableArray arrayWithArray:[self profiles]];
                [rows addObject:[NSDictionary dictionaryWithObjectsAndKeys:match,@"id",endpoint,@"name",current,@"config",endpoint,@"endpoint",nil]];
                [_state setObject:rows forKey:@"profiles"];
            }
            if(![match isEqual:[self activeIdentifier]]) {
                [_state setObject:match forKey:@"active"];NSString *why=nil;
                if(![self writeState:_state error:&why])_loadError=[why copy];
            }
        }
    }
    return self;
}
- (void)dealloc {[_daemon release];[_state release];[_path release];[_loadError release];[_stateLock release];[super dealloc];}
- (NSString *)loadError {return _loadError;}
- (NSArray *)profiles {[_stateLock lock];NSArray *rows=[[[_state objectForKey:@"profiles"]copy]autorelease];[_stateLock unlock];return rows;}
- (NSString *)activeIdentifier {[_stateLock lock];NSString *identifier=[[[_state objectForKey:@"active"]copy]autorelease];[_stateLock unlock];return identifier;}
- (NSDictionary *)profile:(NSString *)identifier {
    for(NSDictionary *row in[self profiles])if([[row objectForKey:@"id"]isEqualToString:identifier])return row;return nil;
}
- (BOOL)writeState:(NSDictionary *)state error:(NSString **)error {
    NSData *data=[NSPropertyListSerialization dataFromPropertyList:state format:NSPropertyListXMLFormat_v1_0 errorDescription:NULL];
    if(!data||[data length]>4*1024*1024)return Fail(error,@"Слишком много данных профилей");
    A6Daemon *writer=[[[A6Daemon alloc]init]autorelease];writer.configPath=_path;
    return [writer saveConfig:[[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]autorelease]error:error];
}
- (BOOL)commit:(NSMutableDictionary *)next error:(NSString **)error {
    if(_loadError)return Fail(error,_loadError);
    NSString *active=[next objectForKey:@"active"];NSString *config=nil;
    for(NSDictionary *row in[next objectForKey:@"profiles"])if([[row objectForKey:@"id"]isEqual:active])config=[row objectForKey:@"config"];
    NSString *old=[_daemon configContents];
    NSDictionary *oldSelected=[self profile:[self activeIdentifier]];
    BOOL selectedChange=![active isEqual:[self activeIdentifier]]||![config isEqual:[oldSelected objectForKey:@"config"]];
    BOOL change=selectedChange&&config&&![config isEqualToString:old];BOOL reconnect=NO;
    if(change) {
        A6Status status=[_daemon statusReport].status;
        if(status==A6StatusUnavailable)return Fail(error,@"Демон не отвечает; текущий профиль не изменён");
        reconnect=status==A6StatusConnected||status==A6StatusConnecting;
        if(reconnect&&![_daemon stopWithError:error])return NO;
        if(![_daemon saveConfig:config error:error]){if(reconnect)[_daemon startWithError:NULL];return NO;}
    }
    if(![self writeState:next error:error]){
        if(change)[_daemon saveConfig:old error:NULL];if(reconnect)[_daemon startWithError:NULL];return NO;
    }
    if(reconnect&&![_daemon startWithError:error]) {
        [_daemon stopWithError:NULL];
        BOOL restored=[_daemon saveConfig:old error:NULL]&&[self writeState:_state error:NULL];
        if(restored)[_daemon startWithError:NULL];else Fail(error,@"Ошибка восстановления профиля; проверьте конфигурацию");
        return NO;
    }
    [_stateLock lock];[_state release];_state=[next mutableCopy];[_stateLock unlock];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]postNotificationName:@"A6ProfilesDidChange" object:nil];
    });
    return YES;
}
- (NSString *)saveName:(NSString *)name config:(NSString *)config identifier:(NSString *)identifier error:(NSString **)error {
    @synchronized(self) {
        if(_loadError){Fail(error,_loadError);return nil;}
        NSString *endpoint=Endpoint(config,error);if(!endpoint)return nil;
        name=[name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if(![name length])name=endpoint;if([name length]>128){Fail(error,@"Название слишком длинное");return nil;}
        if(identifier&&![self profile:identifier]){Fail(error,@"Профиль не найден");return nil;}
        if(!identifier){CFUUIDRef uuid=CFUUIDCreate(NULL);identifier=[(NSString *)CFUUIDCreateString(NULL,uuid)autorelease];CFRelease(uuid);}
        NSMutableArray *rows=[NSMutableArray arrayWithArray:[self profiles]];NSUInteger index=NSNotFound;
        for(NSUInteger i=0;i<[rows count];i++)if([[[rows objectAtIndex:i]objectForKey:@"id"]isEqual:identifier])index=i;
        NSDictionary *row=[NSDictionary dictionaryWithObjectsAndKeys:identifier,@"id",name,@"name",config,@"config",endpoint,@"endpoint",nil];
        if(index==NSNotFound)[rows addObject:row];else[rows replaceObjectAtIndex:index withObject:row];
        NSMutableDictionary *next=[_state mutableCopy];[next setObject:rows forKey:@"profiles"];
        if(![[next objectForKey:@"active"]length])[next setObject:identifier forKey:@"active"];
        BOOL ok=[self commit:next error:error];[next release];return ok?identifier:nil;
    }
}
- (BOOL)activate:(NSString *)identifier error:(NSString **)error {
    @synchronized(self){NSDictionary *row=[self profile:identifier];if(!row||!Endpoint([row objectForKey:@"config"],error))return Fail(error,@"Профиль не найден или некорректен");
        NSMutableDictionary *next=[_state mutableCopy];[next setObject:identifier forKey:@"active"];BOOL ok=[self commit:next error:error];[next release];return ok;}
}
- (BOOL)remove:(NSString *)identifier error:(NSString **)error {
    @synchronized(self){if([identifier isEqual:[self activeIdentifier]])return Fail(error,@"Сначала выберите другой профиль");
        NSMutableArray *rows=[NSMutableArray arrayWithArray:[self profiles]];NSDictionary *row=[self profile:identifier];if(!row)return Fail(error,@"Профиль не найден");[rows removeObject:row];
        NSMutableDictionary *next=[_state mutableCopy];[next setObject:rows forKey:@"profiles"];BOOL ok=[self commit:next error:error];[next release];return ok;}
}
@end
