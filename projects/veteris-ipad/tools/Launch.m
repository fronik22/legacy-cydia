#import <Foundation/Foundation.h>
#import <dlfcn.h>
int main(int argc, char **argv) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    void *lib = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
    int (*launch)(CFStringRef, Boolean) = lib ? dlsym(lib, "SBSLaunchApplicationWithIdentifier") : NULL;
    if (argc > 2 || (argc == 2 && strcmp(argv[1], "settings"))) return 64;
    int result = launch ? launch(argc == 2 ? CFSTR("com.apple.Preferences") : CFSTR("com.victorlobe.veteris"), false) : 127;
    printf("launch result=%d\n", result);
    [pool drain];
    return result;
}
