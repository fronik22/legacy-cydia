#import "../app/A6Daemon.h"
#include <assert.h>
@interface ReplyDaemon:A6Daemon
@property(nonatomic,copy)NSString*reply;
@end
@implementation ReplyDaemon
-(NSString*)runCommand:(NSString*)command{return self.reply;}
@end
int main(void){NSAutoreleasePool*p=[NSAutoreleasePool new];ReplyDaemon*d=[ReplyDaemon new];for(NSString*s in @[@"",@"unexpected",@"ERR failed",@"OK\n"]){d.reply=s;NSString*error=nil;BOOL expected=[s isEqual:@"OK\n"];assert([d startWithError:&error]==expected);if(!expected)assert([error length]>0);error=nil;assert([d stopWithError:&error]==expected);if(!expected)assert([error length]>0);}d.reply=nil;assert(![d startWithError:NULL]&&![d stopWithError:NULL]);[d release];[p drain];puts("Start/stop require an actual OK acknowledgement");}
