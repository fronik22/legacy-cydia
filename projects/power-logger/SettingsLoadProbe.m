// Read-only loader check. Never instantiates a controller or changes preferences.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <dlfcn.h>
int main(int argc,char**argv){@autoreleasepool{
 if(argc<2)return 64;void*h=dlopen("/System/Library/PrivateFrameworks/Preferences.framework/Preferences",RTLD_NOW);if(!h){fprintf(stderr,"Preferences unavailable: %s\n",dlerror());return 2;}
 Class base=NSClassFromString(@"PSListController");BOOL abi=class_getInstanceMethod(base,NSSelectorFromString(@"loadSpecifiersFromPlistName:target:"))&&class_getInstanceMethod(base,NSSelectorFromString(@"setSpecifiers:"));NSMutableArray*rows=[NSMutableArray array];BOOL all=abi;
 for(int i=1;i<argc;i++){NSString*path=[NSString stringWithUTF8String:argv[i]];NSBundle*b=[NSBundle bundleWithPath:path];NSError*error=nil;BOOL loaded=[b loadAndReturnError:&error];NSString*principal=[b objectForInfoDictionaryKey:@"NSPrincipalClass"];Class cls=principal?NSClassFromString(principal):Nil;BOOL good=loaded&&cls&&class_getSuperclass(cls)==base&&class_getInstanceMethod(cls,NSSelectorFromString(@"specifiers"));all=all&&good;
 [rows addObject:@{@"bundle":path.lastPathComponent,@"loaded":@(loaded),@"principal":principal?:@"",@"subclass_and_specifiers":@(good),@"error":error.localizedDescription?:@""}];}
 NSData*d=[NSJSONSerialization dataWithJSONObject:@{@"bits":@(sizeof(void*)*8),@"base_abi_available":@(abi),@"bundles":rows} options:0 error:NULL];if(d){fwrite(d.bytes,1,d.length,stdout);puts("");}return all&&d?0:1;
}}
