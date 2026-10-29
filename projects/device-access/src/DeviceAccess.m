#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <sys/stat.h>
#import <sys/wait.h>
#import <unistd.h>
#import <stdio.h>
static NSString *UUID(void){CFUUIDRef value=CFUUIDCreate(NULL);CFStringRef text=CFUUIDCreateString(NULL,value);CFRelease(value);return [(NSString *)text autorelease];}
int main(int argc,char **argv){
    NSAutoreleasePool *pool=[NSAutoreleasePool new];int status=3;
    if(argc==2 && !strcmp(argv[1],"--help")){puts("codex-device-access status|unlock|lock [--simulate-passcode]\nExplicit root SSH operation. Configured passcodes are refused.");[pool drain];return 0;}
    if(getuid()!=0){fputs("Root access is required.\n",stderr);[pool drain];return 2;}
    if(argc<2 || argc>3 || (strcmp(argv[1],"status") && strcmp(argv[1],"unlock") && strcmp(argv[1],"lock")) || (argc==3 && strcmp(argv[2],"--simulate-passcode"))){fputs("Use --help.\n",stderr);[pool drain];return 64;}
    NSDictionary *system=[NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];NSString *version=[system objectForKey:@"ProductVersion"];
    if(![version isEqual:@"4.3.3"] && ![version isEqual:@"6.1.3"] && [version intValue]!=7){fprintf(stderr,"Unverified OS %s; refusing injection.\n",[version UTF8String]);[pool drain];return 2;}
    FILE *list=popen("/bin/launchctl list","r");char line[2048],label[1024];unsigned springboard=0,pid=0;
    if(list){while(fgets(line,sizeof(line),list)){if(sscanf(line,"%u %*s %1023s",&pid,label)==2 && !strcmp(label,"com.apple.SpringBoard")){springboard=pid;break;}}pclose(list);}
    if(!springboard){fputs("SpringBoard PID unavailable.\n",stderr);[pool drain];return 3;}
    char temporary[]="/var/tmp/codex-device-access-XXXXXX";char *created=mkdtemp(temporary);if(!created){perror("mkdtemp");[pool drain];return 3;}chmod(created,0755);
    NSString *folder=[NSString stringWithUTF8String:created],*nonce=UUID();NSString *reply=[@"/var/mobile/Library/Caches/codex-device-access-" stringByAppendingFormat:@"%@.plist",nonce];NSString *library=[folder stringByAppendingPathComponent:@"AccessOnce.dylib"];
    @try{
        NSError *error=nil;if(![[NSFileManager defaultManager] copyItemAtPath:@"/usr/lib/codex-device-access/AccessOnce.dylib" toPath:library error:&error])@throw [NSException exceptionWithName:@"Payload" reason:error.description userInfo:nil];chmod([library fileSystemRepresentation],0644);
        NSDictionary *request=[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithUTF8String:argv[1]],@"action",nonce,@"nonce",reply,@"resultPath",[NSNumber numberWithBool:argc==3],@"simulatePasscode",nil];
        if(![request writeToFile:[folder stringByAppendingPathComponent:@"request.plist"] atomically:YES])@throw [NSException exceptionWithName:@"Request" reason:@"Cannot write request" userInfo:nil];
        pid_t child=fork();if(child==0){char process[24];snprintf(process,sizeof(process),"%u",springboard);execl("/usr/bin/cynject","cynject",process,[library fileSystemRepresentation],NULL);_exit(127);}int code=0;if(child<0 || waitpid(child,&code,0)<0 || !WIFEXITED(code) || WEXITSTATUS(code))@throw [NSException exceptionWithName:@"Injection" reason:@"cynject failed" userInfo:nil];
        NSDictionary *result=nil;for(unsigned i=0;i<100;i++){result=[NSDictionary dictionaryWithContentsOfFile:reply];if([[result objectForKey:@"nonce"] isEqual:nonce])break;usleep(100000);}
        if(!result || ![[result objectForKey:@"nonce"] isEqual:nonce])@throw [NSException exceptionWithName:@"Timeout" reason:@"No matching one-shot reply" userInfo:nil];
        NSData *data=[NSData dataWithContentsOfFile:reply];fwrite(data.bytes,1,data.length,stdout);
        NSString *state=[result objectForKey:@"result"];status=([state isEqual:@"status"] || [state isEqual:@"unlocked"] || [state isEqual:@"locked"])?0:2;
        FILE *log=fopen("/var/log/codex-device-access.log","a");if(log){chmod("/var/log/codex-device-access.log",0600);fprintf(log,"%s os=%s action=%s result=%s\n",[[[NSDate date] description] UTF8String],[version UTF8String],argv[1],[state UTF8String]);fclose(log);}
    }@catch(NSException *error){fprintf(stderr,"%s\n",[error.description UTF8String]);}
    [[NSFileManager defaultManager] removeItemAtPath:reply error:nil];[[NSFileManager defaultManager] removeItemAtPath:folder error:nil];[pool drain];return status;
}
