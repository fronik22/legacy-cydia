#import "../app/A6Profiles.h"
#import "../app/A6Daemon.h"
#import "../app/A6Import.h"
#include <assert.h>
#include "config.h"
#include <sys/stat.h>
#include <unistd.h>
#import <dispatch/dispatch.h>
static dispatch_semaphore_t enteredStart,allowStart;
@interface FakeDaemon:A6Daemon { @public int starts,stops;BOOL failStart,failSave,failStop; A6Status state; }
@end
@implementation FakeDaemon
-(A6StatusReport*)statusReport {A6StatusReport*r=[[[A6StatusReport alloc]init]autorelease];r.status=state;return r;}
-(BOOL)startWithError:(NSString**)error {starts++;if(enteredStart){dispatch_semaphore_signal(enteredStart);dispatch_semaphore_wait(allowStart,DISPATCH_TIME_FOREVER);}if(failStart){failStart=NO;if(error)*error=@"start failure";return NO;}state=A6StatusConnected;return YES;}
-(BOOL)stopWithError:(NSString**)error {stops++;if(failStop){if(error)*error=@"stop failure";return NO;}state=A6StatusIdle;return YES;}
-(BOOL)saveConfig:(NSString*)text error:(NSString**)error {if(failSave){failSave=NO;if(error)*error=@"save failure";return NO;}return[super saveConfig:text error:error];}
@end
@interface A6Profiles(TestPersist)
-(BOOL)writeState:(NSDictionary*)state error:(NSString**)error;
@end
@interface FailStore:A6Profiles { @public BOOL failPersist; }
@end
@implementation FailStore
-(BOOL)writeState:(NSDictionary*)state error:(NSString**)error {if(failPersist){failPersist=NO;if(error)*error=@"persist failure";return NO;}return[super writeState:state error:error];}
@end
static NSString*Conf(NSString*host){return[NSString stringWithFormat:@"[Interface]\nPrivateKey=AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=\nAddress=10.0.0.2/32\nContentPaddingAddition=10-20\n[Peer]\nPublicKey=AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI=\nEndpoint=%@:443\nAllowedIPs=0.0.0.0/0\n",host];}
static void TestDNSImport(void){
 NSString *error=nil,*text=[Conf(@"192.0.2.1")stringByReplacingOccurrencesOfString:@"[Peer]"withString:@"DNS=$PRIMARY_DNS, $SECONDARY_DNS\n[Peer]"];
 NSMutableDictionary *inner=[NSMutableDictionary dictionaryWithObject:text forKey:@"config"];
 NSMutableDictionary *awg=[NSMutableDictionary dictionary];
 NSMutableDictionary *bundle=[NSMutableDictionary dictionaryWithObjectsAndKeys:@"192.0.2.53",@"dns1",@"198.51.100.53",@"dns2",[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:@"amnezia-awg",@"container",awg,@"awg",nil]],@"containers",nil];
 for(int object=0;object<=1;object++){
  id last=object?(id)inner:(id)[[[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:inner options:0 error:NULL]encoding:NSUTF8StringEncoding]autorelease];[awg setObject:last forKey:@"last_config"];
  NSString *imported=A6ImportConfig([NSJSONSerialization dataWithJSONObject:bundle options:0 error:NULL],&error);assert(imported&&[imported rangeOfString:@"$PRIMARY_DNS"].location==NSNotFound);
  a6_config_t cfg;char why[256];assert(!a6_config_parse([imported UTF8String],[imported lengthOfBytesUsingEncoding:NSUTF8StringEncoding],&cfg,why,sizeof why));assert(!strcmp(cfg.dns,"192.0.2.53,198.51.100.53"));a6_config_wipe(&cfg);
 }
 for(id invalid in [NSArray arrayWithObjects:@"",@"resolver.example",@"192.0.2.53\n[Peer]",@"2001:db8::53",[NSNumber numberWithInt:1],[NSArray arrayWithObject:@"192.0.2.53"],nil]){
  [bundle setObject:invalid forKey:@"dns1"];assert(!A6ImportConfig([NSJSONSerialization dataWithJSONObject:bundle options:0 error:NULL],&error)&&[error rangeOfString:@"DNS"].location!=NSNotFound);
 }
 [bundle removeObjectForKey:@"dns1"];assert(!A6ImportConfig([NSJSONSerialization dataWithJSONObject:bundle options:0 error:NULL],&error)&&[error rangeOfString:@"dns1"].location!=NSNotFound);
 [bundle setObject:@"192.0.2.53"forKey:@"dns1"];[bundle removeObjectForKey:@"dns2"];assert(!A6ImportConfig([NSJSONSerialization dataWithJSONObject:bundle options:0 error:NULL],&error)&&[error rangeOfString:@"dns2"].location!=NSNotFound);
 [bundle setObject:@"198.51.100.53"forKey:@"dns2"];
 [inner setObject:[text stringByReplacingOccurrencesOfString:@"$PRIMARY_DNS"withString:@"$UNKNOWN_DNS"]forKey:@"config"];assert(!A6ImportConfig([NSJSONSerialization dataWithJSONObject:bundle options:0 error:NULL],&error)&&[error rangeOfString:@"unresolved"].location!=NSNotFound);
 NSString *explicit=[text stringByReplacingOccurrencesOfString:@"$PRIMARY_DNS, $SECONDARY_DNS"withString:@"203.0.113.53,192.0.2.54"];
 [inner setObject:explicit forKey:@"config"];[bundle setObject:@"invalid metadata unused by explicit DNS"forKey:@"dns1"];
 assert([A6ImportConfig([NSJSONSerialization dataWithJSONObject:bundle options:0 error:NULL],&error)isEqual:explicit]);
 puts("Amnezia DNS templates: string/object last_config, both resolvers, explicit preservation, missing/invalid/IPv6 metadata and unresolved tokens passed");
}
int main(int argc,char**argv){NSAutoreleasePool*pool=[NSAutoreleasePool new];char temp[]="/tmp/a6-profiles.XXXXXX";assert(mkdtemp(temp));NSString*directory=[NSString stringWithUTF8String:temp];
 FakeDaemon*d=[FakeDaemon new];d.configPath=[directory stringByAppendingPathComponent:@"amnezia6.conf"];d->state=A6StatusIdle;NSString*error=nil;assert([d saveConfig:Conf(@"192.0.2.1")error:&error]);
 FailStore*s=[[FailStore alloc]initWithDaemon:d];assert(![s loadError]&&[[s profiles]count]==1);NSString*original=[[s activeIdentifier]copy];
 d->state=A6StatusConnected;NSString*b=[[s saveName:@"Server B" config:Conf(@"192.0.2.2")identifier:nil error:&error]copy];assert(b&&d->starts==0&&d->stops==0);assert([[s activeIdentifier]isEqual:original]);
 assert(![s saveName:@"bad" config:@"[Interface]\nPrivateKey=bad"identifier:nil error:&error]);assert([[s profiles]count]==2);
 enteredStart=dispatch_semaphore_create(0);allowStart=dispatch_semaphore_create(0);dispatch_semaphore_t operationDone=dispatch_semaphore_create(0),metadataDone=dispatch_semaphore_create(0);
 dispatch_async(dispatch_get_global_queue(0,0),^{NSAutoreleasePool*p=[NSAutoreleasePool new];assert([s activate:b error:NULL]);dispatch_semaphore_signal(operationDone);[p drain];});
 assert(!dispatch_semaphore_wait(enteredStart,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC)));
 dispatch_async(dispatch_get_global_queue(0,0),^{NSAutoreleasePool*p=[NSAutoreleasePool new];[s profiles];[s activeIdentifier];dispatch_semaphore_signal(metadataDone);[p drain];});
 long blocked=dispatch_semaphore_wait(metadataDone,dispatch_time(DISPATCH_TIME_NOW,200*NSEC_PER_MSEC));dispatch_semaphore_signal(allowStart);
 assert(!dispatch_semaphore_wait(operationDone,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC)));enteredStart=NULL;assert(!blocked);assert(d->starts==1&&d->stops==1&&[[s activeIdentifier]isEqual:b]);assert([[d configContents]isEqual:Conf(@"192.0.2.2")]);
 d->failStop=YES;assert(![s activate:original error:&error]);assert([[s activeIdentifier]isEqual:b]&&[[d configContents]isEqual:Conf(@"192.0.2.2")]);d->failStop=NO;
 d->failSave=YES;assert(![s activate:original error:&error]);assert([[s activeIdentifier]isEqual:b]&&d->state==A6StatusConnected);
 s->failPersist=YES;assert(![s activate:original error:&error]);assert([[s activeIdentifier]isEqual:b]&&[[d configContents]isEqual:Conf(@"192.0.2.2")]&&d->state==A6StatusConnected);
 d->failStart=YES;assert(![s activate:original error:&error]);assert([[s activeIdentifier]isEqual:b]&&[[d configContents]isEqual:Conf(@"192.0.2.2")]&&d->state==A6StatusConnected);
 int before=d->starts;assert([s saveName:@"renamed"config:Conf(@"192.0.2.2")identifier:b error:&error]);assert(d->starts==before);
 assert(![s remove:b error:&error]);assert([s remove:original error:&error]);assert([[s profiles]count]==1);
 [s release];s=[[FailStore alloc]initWithDaemon:d];assert(![s loadError]&&[[s activeIdentifier]isEqual:b]);
 struct stat st;assert(!stat([[directory stringByAppendingPathComponent:@"profiles.plist"]fileSystemRepresentation],&st)&&(st.st_mode&0777)==0600);assert(!stat([directory fileSystemRepresentation],&st)&&(st.st_mode&0777)==0700);
 /* Interrupted two-file commit: preserve both the selected saved profile and the new live file. */
 assert([d saveConfig:Conf(@"192.0.2.3")error:&error]);[s release];s=[[FailStore alloc]initWithDaemon:d];assert(![s loadError]&&[[s profiles]count]==2);assert([[s profile:b][@"config"]isEqual:Conf(@"192.0.2.2")]);assert(![[s activeIdentifier]isEqual:b]);
 /* OFF switching does not issue START. */
 d->state=A6StatusIdle;before=d->starts;assert([s activate:b error:&error]);assert(d->starts==before&&d->state==A6StatusIdle);
 TestDNSImport();
 NSString*path=[directory stringByAppendingPathComponent:@"profiles.plist"];[@"broken"writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];[s release];s=[[FailStore alloc]initWithDaemon:d];assert([s loadError]);assert(![s saveName:@"x"config:Conf(@"192.0.2.4")identifier:nil error:&error]);assert([[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL]isEqual:@"broken"]);
 /* Same normalizer serves clipboard, file, URL and QR input. */
 assert(A6ImportConfig([Conf(@"192.0.2.1")dataUsingEncoding:NSUTF8StringEncoding],&error));assert(!A6ImportConfig([@"not a vpn profile"dataUsingEncoding:NSUTF8StringEncoding],&error));
 if(argc>1){NSString*base=[NSString stringWithUTF8String:argv[1]];for(NSString*name in[NSArray arrayWithObjects:@"profile.conf",@"profile.vpn",@"profile.json",@"profile-awg31-full-template.json",@"profile-wireguard-full-template.json",nil]){NSString*text=A6ImportConfig([NSData dataWithContentsOfFile:[base stringByAppendingPathComponent:name]],&error);assert(text&&[text rangeOfString:@"192.0.2.1:443"].location!=NSNotFound);}
 assert(!A6ImportConfig([NSData dataWithContentsOfFile:[base stringByAppendingPathComponent:@"bomb.vpn"]],&error));}
 [s release];[d release];[original release];[b release];[[NSFileManager defaultManager]removeItemAtPath:directory error:NULL];puts("Profiles: migration, selection, restart, OFF, rollback, crash recovery, modes, malformed imports and bundles passed");[pool drain];return 0;}
