// Sample PowerVR performance counters on old iOS. Usage: gpuwatch [seconds]
#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <unistd.h>
#include <dlfcn.h>
#include <stdlib.h>

typedef mach_port_t io_object_t;
typedef mach_port_t io_iterator_t;
typedef char io_name_t[128];
typedef unsigned int IOOptionBits;
static CFMutableDictionaryRef (*pIOServiceMatching)(const char *);
static kern_return_t (*pIOServiceGetMatchingServices)(mach_port_t, CFDictionaryRef, io_iterator_t *);
static io_object_t (*pIOIteratorNext)(io_iterator_t);
static kern_return_t (*pIOObjectRelease)(io_object_t);
static CFTypeRef (*pIORegistryEntryCreateCFProperty)(io_object_t, CFStringRef, CFAllocatorRef, IOOptionBits);
static int ready;

static void load(void) {
    void *h = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (!h) return;
    pIOServiceMatching = dlsym(h, "IOServiceMatching");
    pIOServiceGetMatchingServices = dlsym(h, "IOServiceGetMatchingServices");
    pIOIteratorNext = dlsym(h, "IOIteratorNext");
    pIOObjectRelease = dlsym(h, "IOObjectRelease");
    pIORegistryEntryCreateCFProperty = dlsym(h, "IORegistryEntryCreateCFProperty");
    ready = pIOServiceMatching && pIOServiceGetMatchingServices && pIOIteratorNext && pIOObjectRelease && pIORegistryEntryCreateCFProperty;
}

static CFDictionaryRef copy_stats(void) {
    if (!ready) load();
    if (!ready) return NULL;
    const char *names[] = {"SGXDriver543", "SGXDriver554", "SGXDriver", "IOAccelerator", "IOGPU", NULL};
    for (int i = 0; names[i]; i++) {
        io_iterator_t it = 0;
        CFMutableDictionaryRef m = pIOServiceMatching(names[i]);
        if (!m || pIOServiceGetMatchingServices(0, m, &it) != KERN_SUCCESS) continue;
        io_object_t svc;
        while ((svc = pIOIteratorNext(it))) {
            CFTypeRef ps = pIORegistryEntryCreateCFProperty(svc, CFSTR("PerformanceStatistics"), kCFAllocatorDefault, 0);
            pIOObjectRelease(svc);
            if (ps) {
                if (CFGetTypeID(ps) == CFDictionaryGetTypeID()) {
                    pIOObjectRelease(it);
                    return (CFDictionaryRef)ps;
                }
                CFRelease(ps);
            }
        }
        pIOObjectRelease(it);
    }
    return NULL;
}

static void print_num(CFDictionaryRef d, const char *key) {
    CFStringRef k = CFStringCreateWithCString(NULL, key, kCFStringEncodingUTF8);
    CFTypeRef v = CFDictionaryGetValue(d, k);
    if (v) printf("%s=%s ", key, [[(NSObject *)v description] UTF8String]);
    CFRelease(k);
}

int main(int argc, char **argv) {
    int seconds = argc > 1 ? atoi(argv[1]) : 10;
    printf("gpuwatch %d s, pid=%d\n", seconds, getpid());
    for (int i = 0; i < seconds * 2; i++) {
        @autoreleasepool {
            CFDictionaryRef d = copy_stats();
            if (!d) { printf("t=%.1f no stats\n", i * 0.5); fflush(stdout); usleep(500000); continue; }
            printf("t=%.1f ", i * 0.5);
            print_num(d, "Device Utilization %");
            print_num(d, "Renderer Utilization %");
            print_num(d, "Tiler Utilization %");
            print_num(d, "CommandBufferSubmitCount");
            print_num(d, "CommandBufferRenderCount");
            print_num(d, "CommandBufferAllocatedBytes");
            print_num(d, "ResourceBytes");
            printf("\n");
            fflush(stdout);
            CFRelease(d);
        }
        usleep(500000);
    }
    return 0;
}
