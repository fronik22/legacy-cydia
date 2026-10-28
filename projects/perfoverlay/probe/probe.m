// Runtime capability probe for old iOS. Run over SSH on the device.
#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <mach/host_info.h>
#include <mach/processor_info.h>
#include <sys/sysctl.h>
#include <unistd.h>
#include <dlfcn.h>

// Avoid SDK/IOKit headers: the 9.3 SDK only ships stubs, and current macOS
// headers are marked unavailable on iOS. These are stable C ABI symbols.
typedef mach_port_t io_object_t;
typedef mach_port_t io_iterator_t;
typedef char io_name_t[128];
typedef unsigned int IOOptionBits;
static CFMutableDictionaryRef (*pIOServiceMatching)(const char *);
static kern_return_t (*pIOServiceGetMatchingServices)(mach_port_t, CFDictionaryRef, io_iterator_t *);
static io_object_t (*pIOIteratorNext)(io_iterator_t);
static kern_return_t (*pIOObjectRelease)(io_object_t);
static kern_return_t (*pIOObjectGetClass)(io_object_t, io_name_t);
static kern_return_t (*pIORegistryEntryGetName)(io_object_t, io_name_t);
static kern_return_t (*pIORegistryEntryCreateCFProperties)(io_object_t, CFMutableDictionaryRef *, CFAllocatorRef, IOOptionBits);
static CFTypeRef (*pIORegistryEntryCreateCFProperty)(io_object_t, CFStringRef, CFAllocatorRef, IOOptionBits);
static kern_return_t (*pIORegistryEntryGetChildIterator)(io_object_t, const io_name_t, io_iterator_t *);
static int IOKitReady = 0;

static void LoadIOKit(void) {
    if (IOKitReady) return;
    void *h = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (!h) { printf("IOKit dlopen failed: %s\n", dlerror()); return; }
    pIOServiceMatching = dlsym(h, "IOServiceMatching");
    pIOServiceGetMatchingServices = dlsym(h, "IOServiceGetMatchingServices");
    pIOIteratorNext = dlsym(h, "IOIteratorNext");
    pIOObjectRelease = dlsym(h, "IOObjectRelease");
    pIOObjectGetClass = dlsym(h, "IOObjectGetClass");
    pIORegistryEntryGetName = dlsym(h, "IORegistryEntryGetName");
    pIORegistryEntryCreateCFProperties = dlsym(h, "IORegistryEntryCreateCFProperties");
    pIORegistryEntryCreateCFProperty = dlsym(h, "IORegistryEntryCreateCFProperty");
    pIORegistryEntryGetChildIterator = dlsym(h, "IORegistryEntryGetChildIterator");
    IOKitReady = pIOServiceMatching && pIOServiceGetMatchingServices && pIOIteratorNext && pIOObjectRelease;
    printf("IOKit loaded=%d\n", IOKitReady);
}

static void DumpService(io_object_t service) {
    io_name_t cls = "?"; io_name_t name = "?";
    if (pIOObjectGetClass) pIOObjectGetClass(service, cls);
    if (pIORegistryEntryGetName) pIORegistryEntryGetName(service, name);
    printf("service class=%s name=%s\n", cls, name);
    CFMutableDictionaryRef props = NULL;
    if (pIORegistryEntryCreateCFProperties &&
        pIORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS && props) {
        printf("props: %s\n", [[(NSDictionary *)props description] UTF8String]);
        CFRelease(props);
    }
    CFTypeRef perf = pIORegistryEntryCreateCFProperty ?
        pIORegistryEntryCreateCFProperty(service, CFSTR("PerformanceStatistics"), kCFAllocatorDefault, 0) : NULL;
    if (perf) {
        printf("PerformanceStatistics: %s\n", [[(NSObject *)perf description] UTF8String]);
        CFRelease(perf);
    }
}

static void DumpTree(io_object_t service, int depth) {
    if (depth > 5) return;
    io_name_t cls = "?"; io_name_t name = "?";
    if (pIOObjectGetClass) pIOObjectGetClass(service, cls);
    if (pIORegistryEntryGetName) pIORegistryEntryGetName(service, name);
    printf("%*s%s / %s\n", depth * 2, "", cls, name);
    CFMutableDictionaryRef props = NULL;
    if (pIORegistryEntryCreateCFProperties &&
        pIORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS && props) {
        printf("%*sprops: %s\n", depth * 2, "", [[(NSDictionary *)props description] UTF8String]);
        CFRelease(props);
    }
    if (!pIORegistryEntryGetChildIterator) return;
    io_iterator_t iter = 0;
    if (pIORegistryEntryGetChildIterator(service, "IOService", &iter) != KERN_SUCCESS) return;
    io_object_t child;
    while ((child = pIOIteratorNext(iter))) {
        DumpTree(child, depth + 1);
        pIOObjectRelease(child);
    }
    pIOObjectRelease(iter);
}

static void MatchTree(const char *matching) {
    LoadIOKit();
    if (!IOKitReady) return;
    io_iterator_t iter = 0;
    CFMutableDictionaryRef dict = pIOServiceMatching(matching);
    if (!dict) return;
    if (pIOServiceGetMatchingServices(0, dict, &iter) != KERN_SUCCESS) return;
    printf("\n== tree %s ==\n", matching);
    io_object_t service; int n = 0;
    while ((service = pIOIteratorNext(iter))) {
        DumpTree(service, 0);
        pIOObjectRelease(service);
        if (++n > 4) break;
    }
    pIOObjectRelease(iter);
}

static void MatchAndDump(const char *matching) {
    LoadIOKit();
    if (!IOKitReady) return;
    io_iterator_t iter = 0;
    CFMutableDictionaryRef dict = pIOServiceMatching(matching);
    if (!dict) { printf("\n== IOServiceMatching(%s): no dict ==\n", matching); return; }
    kern_return_t kr = pIOServiceGetMatchingServices(0, dict, &iter);
    printf("\n== IOServiceMatching(%s) kr=%d ==\n", matching, kr);
    if (kr != KERN_SUCCESS) return;
    io_object_t service;
    int n = 0;
    while ((service = pIOIteratorNext(iter))) {
        DumpService(service);
        pIOObjectRelease(service);
        if (++n > 20) { printf("...truncated\n"); break; }
    }
    pIOObjectRelease(iter);
    if (!n) printf("(none)\n");
}

static void ListInteresting(void) {
    LoadIOKit();
    if (!IOKitReady) return;
    io_iterator_t iter = 0;
    CFMutableDictionaryRef dict = pIOServiceMatching("IOService");
    if (!dict) return;
    if (pIOServiceGetMatchingServices(0, dict, &iter) != KERN_SUCCESS) return;
    printf("\n== interesting IOService classes ==\n");
    io_object_t service; int n = 0;
    while ((service = pIOIteratorNext(iter))) {
        io_name_t cls = "?"; if (pIOObjectGetClass) pIOObjectGetClass(service, cls);
        NSString *c = [NSString stringWithUTF8String:cls];
        NSArray *keys = @[@"Accel", @"GPU", @"SGX", @"GL", @"Display", @"Surface", @"Framebuffer", @"Video"];
        for (NSString *k in keys) {
            if ([c rangeOfString:k options:NSCaseInsensitiveSearch].location != NSNotFound) {
                io_name_t name = "?";
                if (pIORegistryEntryGetName) pIORegistryEntryGetName(service, name);
                printf("%s / %s\n", cls, name);
                ++n; break;
            }
        }
        pIOObjectRelease(service);
        if (n > 120) { printf("...truncated\n"); break; }
    }
    pIOObjectRelease(iter);
}

static void Memory(void) {
    uint64_t memsize = 0; size_t len = sizeof(memsize);
    sysctlbyname("hw.memsize", &memsize, &len, NULL, 0);
    vm_size_t page = 0; host_page_size(mach_host_self(), &page);
    vm_statistics_data_t vm; mach_msg_type_number_t count = HOST_VM_INFO_COUNT;
    kern_return_t kr = host_statistics(mach_host_self(), HOST_VM_INFO, (host_info_t)&vm, &count);
    uint64_t active = (uint64_t)vm.active_count * page;
    uint64_t inactive = (uint64_t)vm.inactive_count * page;
    uint64_t wired = (uint64_t)vm.wire_count * page;
    uint64_t freeb = (uint64_t)vm.free_count * page;
    printf("\n== memory kr=%d page=%u ==\n", kr, (unsigned)page);
    printf("total=%llu active=%llu inactive=%llu wired=%llu free=%llu\n",
           memsize, active, inactive, wired, freeb);
}

static void CPU(void) {
    natural_t ncpu = 0; processor_info_array_t info = NULL; mach_msg_type_number_t infoCount = 0;
    kern_return_t kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &ncpu, &info, &infoCount);
    printf("\n== cpu kr=%d ncpu=%u ==\n", kr, (unsigned)ncpu);
    if (kr != KERN_SUCCESS) return;
    for (natural_t i = 0; i < ncpu; i++) {
        processor_cpu_load_info_data_t *l = (processor_cpu_load_info_data_t *)info + i;
        printf("cpu%u user=%u system=%u nice=%u idle=%u\n", (unsigned)i,
               l->cpu_ticks[CPU_STATE_USER], l->cpu_ticks[CPU_STATE_SYSTEM],
               l->cpu_ticks[CPU_STATE_NICE], l->cpu_ticks[CPU_STATE_IDLE]);
    }
    vm_deallocate(mach_task_self(), (vm_address_t)info, infoCount * sizeof(natural_t));
}

int main(void) {
    @autoreleasepool {
        printf("probe start pid=%d\n", getpid());
        Memory();
        CPU();
        ListInteresting();
        MatchTree("SGXDriver543");
        MatchAndDump("SGXDriver543");
        MatchAndDump("IOAccelerator");
        MatchAndDump("SGXAccelerator");
        MatchAndDump("IOGPU");
        MatchAndDump("IOFramebuffer");
        MatchAndDump("IOGraphicsAccelerator2");
        printf("probe end\n");
    }
    return 0;
}
