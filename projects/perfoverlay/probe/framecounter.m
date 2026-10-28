// Check whether QuartzCore exposes a global render-server frame counter.
#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <dlfcn.h>
#include <unistd.h>
#include <stdint.h>

typedef uint32_t (*FrameCounterFn)(mach_port_t);
extern kern_return_t bootstrap_look_up(mach_port_t bootstrap_port, const char *service_name,
                                       mach_port_t *service_port);

int main(void) {
    @autoreleasepool {
        void *h = dlopen("/System/Library/Frameworks/QuartzCore.framework/QuartzCore", RTLD_LAZY);
        printf("QuartzCore=%p err=%s\n", h, h ? "" : dlerror());
        void *sym = h ? dlsym(h, "CARenderServerGetFrameCounter") : NULL;
        void *sym2 = h ? dlsym(h, "CARenderServerGetFrameCounterByIndex") : NULL;
        printf("GetFrameCounter=%p ByIndex=%p\n", sym, sym2);

        mach_port_t bootstrap = MACH_PORT_NULL;
        task_get_bootstrap_port(mach_task_self(), &bootstrap);
        mach_port_t server = MACH_PORT_NULL;
        kern_return_t kr = bootstrap_look_up(bootstrap, "com.apple.CARenderServer", &server);
        printf("bootstrap=%u renderServer=%u kr=%d\n", bootstrap, server, kr);

        if (sym) {
            FrameCounterFn f = (FrameCounterFn)sym;
            for (int i = 0; i < 6; i++) {
                uint32_t count = f(server);
                printf("frameCounter[%d]=%u\n", i, count);
                fflush(stdout);
                sleep(1);
            }
        }
    }
    return 0;
}
