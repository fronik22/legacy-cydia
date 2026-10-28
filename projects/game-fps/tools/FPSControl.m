#import <Foundation/Foundation.h>
#include <notify.h>
#include <unistd.h>
#include <stdlib.h>
int main(int argc,char**argv){NSAutoreleasePool*p=[NSAutoreleasePool new];if(getuid()!=0||argc!=3)return 64;
 NSDictionary *keys=@{@"worms":@"Worms2Enabled",@"worms3":@"Worms3Enabled",@"minigore":@"MinigoreEnabled",@"minigore2":@"Minigore2Enabled"};NSString *key=keys[@(argv[1])];BOOL worms=key!=nil,blastron=!strcmp(argv[1],"blastron");if(!worms&&!blastron)return 64;char*end=NULL;long value=strtol(argv[2],&end,10);if(*end||(!worms&&value!=-1&&value!=30&&value!=60)||(worms&&value!=0&&value!=1))return 64;
 NSString*path=worms?@"/var/mobile/Library/Preferences/com.local.legacygamefps.plist":@"/var/mobile/Library/Preferences/com.local.perfoverlay.plist";NSDictionary*old=[NSDictionary dictionaryWithContentsOfFile:path];NSMutableDictionary*d=old?[NSMutableDictionary dictionaryWithDictionary:old]:[NSMutableDictionary dictionary];d[worms?key:@"BlastronFPS"]=@(value);if(![d writeToFile:path atomically:YES]||chown(path.UTF8String,501,501))return 2;notify_post(worms?"com.local.legacygamefps.changed":"com.local.perfoverlay.settings");printf("%s=%ld\n",argv[1],value);[p drain];return 0;}
