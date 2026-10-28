#import <Foundation/Foundation.h>
#import <dlfcn.h>
int main(int argc, char **argv) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    void *lib = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
    int (*launch)(CFStringRef, Boolean) = lib ? dlsym(lib, "SBSLaunchApplicationWithIdentifier") : NULL;
    if (argc > 2) return 64;
    NSDictionary *bundles=@{@"settings":@"com.apple.Preferences",@"worms":@"com.team17.worms2",@"worms3":@"com.team17.worms3",@"minigore":@"com.chillingo.minigorehd",@"minigore2":@"ms.games.minigore2"};
    NSString *bundle=bundles[argc==2?@(argv[1]):@"worms"];if(!bundle)return 64;
    int result = launch ? launch((CFStringRef)bundle, false) : 127;
    printf("launch result=%d\n", result);
    [pool drain];
    return result;
}
