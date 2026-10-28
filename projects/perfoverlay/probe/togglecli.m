// Developer-only helper: load the NCSettings toggle dylib and exercise the
// same C entry points that NCSettings uses. Not part of the package.
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    @autoreleasepool {
        const char *path = "/var/mobile/Library/NCSettings/Toggles/PerfOverlay/Toggle.dylib";
        void *h = dlopen(path, RTLD_LAZY);
        if (!h) {
            fprintf(stderr, "dlopen: %s\n", dlerror());
            return 2;
        }
        BOOL (*isCapable)(void) = (BOOL (*)(void))dlsym(h, "isCapable");
        BOOL (*isEnabled)(void) = (BOOL (*)(void))dlsym(h, "isEnabled");
        NSString *(*localizedName)(void) = (NSString *(*)(void))dlsym(h, "localizedName");
        void (*setState)(BOOL) = (void (*)(BOOL))dlsym(h, "setState");
        if (!isCapable || !isEnabled || !localizedName || !setState) {
            fprintf(stderr, "missing symbol\n");
            return 3;
        }
        printf("capable=%d enabled=%d name=%s\n", isCapable(), isEnabled(),
               [localizedName() UTF8String]);
        if (argc > 1) {
            BOOL state = atoi(argv[1]) != 0;
            setState(state);
            printf("set=%d now=%d\n", state, isEnabled());
        }
        return 0;
    }
}
